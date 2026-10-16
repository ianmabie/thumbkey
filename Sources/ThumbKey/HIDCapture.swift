import Foundation
import IOKit.hid
import ThumbKeyCore

struct NagaInterface: Identifiable {
    let id: UInt64
    let name: String
    let productID: Int
    let transport: String
    let device: IOHIDDevice
    let layout: KeyboardReportLayout
}
final class HIDCapture {
    private let manager = IOHIDManagerCreate(kCFAllocatorDefault, IOHIDManagerOptions.independentDevices.rawValue)
    private var interfaces: [UInt64:NagaInterface] = [:]
    private var endpoints: [UInt64:Endpoint] = [:]
    private var reports: [String:Set<UInt32>] = [:]
    private var lastKeys = Set<UInt32>()
    var enabled=false
    var onDevices: (([NagaInterface])->Void)?
    var onKeys: ((Set<UInt32>,Set<UInt32>)->Void)?
    var onError: ((String)->Void)?
    var onDisconnect: (()->Void)?
    init() {
        IOHIDManagerSetDeviceMatching(manager,[kIOHIDVendorIDKey:0x1532] as CFDictionary)
        let context=Unmanaged.passUnretained(self).toOpaque()
        IOHIDManagerRegisterDeviceMatchingCallback(manager,{ context,_,_,device in
            guard let context else{return}; Unmanaged<HIDCapture>.fromOpaque(context).takeUnretainedValue().connected(device)
        },context)
        IOHIDManagerRegisterDeviceRemovalCallback(manager,{ context,_,_,device in
            guard let context else{return}; Unmanaged<HIDCapture>.fromOpaque(context).takeUnretainedValue().disconnected(device)
        },context)
        IOHIDManagerScheduleWithRunLoop(manager,CFRunLoopGetMain(),CFRunLoopMode.commonModes.rawValue)
        IOHIDManagerOpen(manager,0) // IndependentDevices: never opens the underlying devices here.
        if let devices=IOHIDManagerCopyDevices(manager) as? Set<IOHIDDevice> { for d in devices { connected(d) } }
    }
    static func number(_ d:IOHIDDevice,_ key:String)->Int { (IOHIDDeviceGetProperty(d,key as CFString) as? NSNumber)?.intValue ?? 0 }
    static func text(_ d:IOHIDDevice,_ key:String)->String { IOHIDDeviceGetProperty(d,key as CFString) as? String ?? "" }
    static func identifier(_ d:IOHIDDevice)->UInt64 { var id:UInt64=0; IORegistryEntryGetRegistryEntryID(IOHIDDeviceGetService(d),&id); return id }
    private func connected(_ d:IOHIDDevice) {
        let name=Self.text(d,kIOHIDProductKey)
        guard DevicePolicy.accepts(vendor:Self.number(d,kIOHIDVendorIDKey),name:name,keyboard:Self.number(d,kIOHIDPrimaryUsagePageKey)==1 && Self.number(d,kIOHIDPrimaryUsageKey)==6,mouse:((IOHIDDeviceGetProperty(d,kIOHIDDeviceUsagePairsKey as CFString) as? [[String:Any]]) ?? []).contains { ($0[kIOHIDDeviceUsagePageKey] as? Int)==1 && ($0[kIOHIDDeviceUsageKey] as? Int)==2 },builtIn:Self.number(d,"Built-In") != 0),let data=IOHIDDeviceGetProperty(d,kIOHIDReportDescriptorKey as CFString) as? Data else{return}
        let layout=KeyboardReportLayout(descriptor:Array(data)); guard layout.isSupported else { onError?("The Naga keyboard report format is not supported yet."); return }
        let id=Self.identifier(d)
        interfaces[id]=NagaInterface(id:id,name:name,productID:Self.number(d,kIOHIDProductIDKey),transport:Self.text(d,kIOHIDTransportKey),device:d,layout:layout)
        onDevices?(Array(interfaces.values).sorted{$0.id<$1.id})
        if enabled { open(id) }
    }
    private func disconnected(_ d:IOHIDDevice) {
        let id=Self.identifier(d); guard interfaces[id] != nil else{return}
        // Any disconnect releases all owned keys; other held buttons must be pressed again.
        closeAll(); onDisconnect?(); interfaces.removeValue(forKey:id)
        onDevices?(Array(interfaces.values).sorted{$0.id<$1.id})
        if enabled { for id in interfaces.keys { open(id) } }
    }
    func start() { enabled=true; for id in interfaces.keys { open(id) } }
    func stop() { enabled=false; closeAll() }
    private func open(_ id:UInt64) {
        guard endpoints[id]==nil,let i=interfaces[id] else{return}
        let result=IOHIDDeviceOpen(i.device,IOOptionBits(kIOHIDOptionsTypeSeizeDevice))
        guard result==kIOReturnSuccess else { onError?("Could not capture the Naga side pad (\(String(format:"0x%08x",UInt32(bitPattern:result)))). Check Input Monitoring, quit other mouse remappers, then retry."); return }
        let endpoint=Endpoint(interface:i,owner:self)
        endpoints[id]=endpoint
        IOHIDDeviceRegisterInputReportCallback(i.device,endpoint.buffer,endpoint.capacity,{ context,result,_,_,reportID,report,length in
            guard result==kIOReturnSuccess,let context,length<=512 else{return}
            let endpoint=Unmanaged<Endpoint>.fromOpaque(context).takeUnretainedValue()
            guard let keys=endpoint.interface.layout.decode(reportID:UInt8(truncatingIfNeeded:reportID),bytes:Array(UnsafeBufferPointer(start:report,count:length))) else{return}
            endpoint.owner?.received(id:endpoint.interface.id,reportID:reportID,keys:keys)
        },Unmanaged.passUnretained(endpoint).toOpaque())
        IOHIDDeviceScheduleWithRunLoop(i.device,CFRunLoopGetMain(),CFRunLoopMode.commonModes.rawValue)
    }
    var capturedCount: Int { endpoints.count }
    var deviceList: [NagaInterface] { Array(interfaces.values).sorted{$0.id<$1.id} }
    private func received(id:UInt64,reportID:UInt32,keys:Set<UInt32>) {
        reports["\(id):\(reportID)"]=keys
        let all=reports.values.reduce(into:Set<UInt32>()){$0.formUnion($1)}
        let downs=all.subtracting(lastKeys),ups=lastKeys.subtracting(all); lastKeys=all
        onKeys?(downs,ups)
    }
    private func closeAll() {
        for endpoint in endpoints.values {
            let d=endpoint.interface.device
            IOHIDDeviceUnscheduleFromRunLoop(d,CFRunLoopGetMain(),CFRunLoopMode.commonModes.rawValue)
            IOHIDDeviceRegisterInputReportCallback(d,endpoint.buffer,endpoint.capacity,nil,nil)
            IOHIDDeviceClose(d,IOOptionBits(kIOHIDOptionsTypeSeizeDevice))
        }
        endpoints.removeAll(); reports.removeAll(); lastKeys=[]
    }
    deinit { stop(); IOHIDManagerUnscheduleFromRunLoop(manager,CFRunLoopGetMain(),CFRunLoopMode.commonModes.rawValue); IOHIDManagerClose(manager,0) }
}
private final class Endpoint {
    let interface:NagaInterface
    weak var owner:HIDCapture?
    let capacity=512
    let buffer=UnsafeMutablePointer<UInt8>.allocate(capacity:512)
    init(interface:NagaInterface,owner:HIDCapture){self.interface=interface;self.owner=owner}
    deinit{buffer.deallocate()}
}
