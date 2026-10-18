import AppKit
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
    let isNaga:Bool
    let isMouse:Bool
}

/// Read HID reports without seizing a device; filter keyboard/side-mouse events with
/// matching, one-use Naga hardware evidence. Unmatched/ambiguous events stay native.
final class HIDCapture {
    private let manager=IOHIDManagerCreate(kCFAllocatorDefault,IOHIDManagerOptions.independentDevices.rawValue)
    private let hidQueue=DispatchQueue(label:"personal.thumbkey.hid",qos:.userInteractive)
    private let condition=NSCondition()
    private var interfaces:[UInt64:NagaInterface]=[:]
    private var endpoints:[UInt64:Endpoint]=[:]
    private var correlation=InputCorrelation()
    private var bindings:[UInt32:ButtonBinding]=[:]
    private var keyCodes=Set<UInt16>()
    private var learning=false
    private var active:[UInt16:Press]=[:]
    private var vendorStates:[UInt64:Set<UInt32>]=[:]
    private var activeVendor:[UInt32:Press]=[:]
    private var extraButtons=false
    private var activityAt=Date.distantPast
    private var tap:CFMachPort?
    private var tapContext:TapContext?
    private var tapLoop:CFRunLoop?
    private var generation=UUID()
    private var running=false
    var onDevices:(([NagaInterface])->Void)?
    var onInput:((UInt32,Bool,ButtonBinding?,Bool)->Void)?
    var onHardwarePress:((UInt32)->Void)?
    var onError:((String)->Void)?
    var onDisconnect:((String)->Void)?
    var onActivity:(()->Void)?
    var onPlateSignal:((String)->Void)?
    private static let timebase:mach_timebase_info_data_t={var info=mach_timebase_info_data_t();mach_timebase_info(&info);return info}()
    init(){
        // Other keyboards provide transient collision evidence; their events never run actions.
        IOHIDManagerSetDeviceMatching(manager,nil)
        let context=Unmanaged.passUnretained(self).toOpaque()
        IOHIDManagerRegisterDeviceMatchingCallback(manager,{context,_,_,d in guard let context else{return};Unmanaged<HIDCapture>.fromOpaque(context).takeUnretainedValue().connected(d)},context)
        IOHIDManagerRegisterDeviceRemovalCallback(manager,{context,_,_,d in guard let context else{return};Unmanaged<HIDCapture>.fromOpaque(context).takeUnretainedValue().disconnected(d)},context)
        IOHIDManagerScheduleWithRunLoop(manager,CFRunLoopGetMain(),CFRunLoopMode.commonModes.rawValue)
        IOHIDManagerOpen(manager,0)
        if let devices=IOHIDManagerCopyDevices(manager) as? Set<IOHIDDevice>{for d in devices{connected(d)}}
    }
    static func number(_ d:IOHIDDevice,_ key:String)->Int{(IOHIDDeviceGetProperty(d,key as CFString) as? NSNumber)?.intValue ?? 0}
    static func text(_ d:IOHIDDevice,_ key:String)->String{IOHIDDeviceGetProperty(d,key as CFString) as? String ?? ""}
    static func identifier(_ d:IOHIDDevice)->UInt64{var id:UInt64=0;IORegistryEntryGetRegistryEntryID(IOHIDDeviceGetService(d),&id);return id}
    var deviceList:[NagaInterface]{interfaces.values.filter(\.isNaga).sorted{$0.id<$1.id}}
    var capturedCount:Int{endpoints.values.filter{$0.interface.isNaga}.count}
    var isRunning:Bool{condition.lock();defer{condition.unlock()};return running}
    func setExtraButtonsEnabled(_ enabled:Bool){condition.lock();extraButtons=enabled;condition.unlock()}
    func setBindings(_ next:[ButtonBinding],learning:Bool){
        condition.lock();defer{condition.unlock()}
        bindings=Dictionary(uniqueKeysWithValues:next.compactMap{b in b.usage.map{($0,b)}})
        self.learning=learning
        let sources=learning ? Array(KeyboardMap.usageToKey.keys).filter{$0>=4 && $0<224} + (4...32).map{InputSource.mouse(UInt32($0))}:Array(bindings.keys)
        keyCodes=Set(sources.compactMap(InputSource.eventCode))
    }
    private func connected(_ d:IOHIDDevice){
        guard Self.number(d,kIOHIDPrimaryUsagePageKey)==1 else{return}
        let primary=Self.number(d,kIOHIDPrimaryUsageKey)
        guard primary==6 || primary==2 else{return}
        let name=Self.text(d,kIOHIDProductKey)
        guard let data=IOHIDDeviceGetProperty(d,kIOHIDReportDescriptorKey as CFString) as? Data else{return}
        let naga=DevicePolicy.accepts(vendor:Self.number(d,kIOHIDVendorIDKey),name:name,keyboard:primary==6,mouse:primary==2,builtIn:Self.number(d,"Built-In") != 0)
        let layout=KeyboardReportLayout(descriptor:Array(data),usagePage:primary==2 ? 9:7);guard layout.isSupported else{return}
        let id=Self.identifier(d)
        if interfaces[id] != nil{return}
        interfaces[id]=NagaInterface(id:id,name:name,productID:Self.number(d,kIOHIDProductIDKey),transport:Self.text(d,kIOHIDTransportKey),device:d,layout:layout,isNaga:naga,isMouse:primary==2)
        onDevices?(deviceList)
        if isRunning && !open(id){stop();onDisconnect?("Keyboard observation changed.")}
    }
    private func disconnected(_ d:IOHIDDevice){
        let id=Self.identifier(d);guard interfaces[id] != nil else{return}
        // Stop even when a keyboard guard disconnects: no stale device evidence may remain.
        let name=interfaces[id]?.name ?? "Keyboard"
        let wasRunning=isRunning;stop();interfaces.removeValue(forKey:id);onDevices?(deviceList)
        if wasRunning{onDisconnect?("\(name) disconnected.")}
    }
    @discardableResult func start()->Bool{
        stop()
        for id in interfaces.keys.sorted(){if !open(id){stop();return false}}
        guard capturedCount>0 else{stop();onError?("No supported Naga side pad is connected.");return false}
        let mask=(1 << CGEventType.keyDown.rawValue) | (1 << CGEventType.keyUp.rawValue) | (1 << CGEventType.otherMouseDown.rawValue) | (1 << CGEventType.otherMouseUp.rawValue)
        let current=UUID()
        let context=TapContext(owner:self,generation:current)
        guard let port=CGEvent.tapCreate(tap:.cgSessionEventTap,place:.headInsertEventTap,options:.defaultTap,eventsOfInterest:CGEventMask(mask),callback:{_,type,event,context in
            guard let context else{return Unmanaged.passUnretained(event)}
            let state=Unmanaged<TapContext>.fromOpaque(context).takeUnretainedValue()
            guard let owner=state.owner else{return Unmanaged.passUnretained(event)}
            return owner.filter(type:type,event:event,generation:state.generation)
        },userInfo:Unmanaged.passUnretained(context).toOpaque()) else{
            stop();onError?("macOS could not create the keyboard event filter. Check Accessibility, then quit and reopen ThumbKey.");return false
        }
        tap=port;tapContext=context
        condition.lock();generation=current;running=true;condition.unlock()
        let source=CFMachPortCreateRunLoopSource(kCFAllocatorDefault,port,0)!
        let thread=Thread{[weak self,context] in
            guard let self else{return}
            let loop=CFRunLoopGetCurrent()!
            CFRunLoopAddSource(loop,source,.commonModes)
            self.condition.lock();let valid=self.running && self.generation==current
            if valid{self.tapLoop=loop};self.condition.unlock()
            if valid{withExtendedLifetime(context){CFRunLoopRun()}}
            CFRunLoopRemoveSource(loop,source,.commonModes)
        }
        thread.name="ThumbKey keyboard filter";thread.qualityOfService = .userInteractive;thread.start()
        CGEvent.tapEnable(tap:port,enable:true)
        return true
    }
    func stop(){
        condition.lock();running=false;generation=UUID();correlation.reset();active=[:];vendorStates=[:];activeVendor=[:];let loop=tapLoop;tapLoop=nil;condition.broadcast();condition.unlock()
        if let tap{CGEvent.tapEnable(tap:tap,enable:false);CFMachPortInvalidate(tap);self.tap=nil};tapContext=nil
        if let loop{CFRunLoopPerformBlock(loop,CFRunLoopMode.commonModes.rawValue){CFRunLoopStop(loop)};CFRunLoopWakeUp(loop)}
        for endpoint in endpoints.values{IOHIDDeviceCancel(endpoint.device)}
        endpoints.removeAll()
    }
    private func open(_ id:UInt64)->Bool{
        guard endpoints[id]==nil,let info=interfaces[id] else{return true}
        // A fresh object allows pause/resume after the previous dispatch source was cancelled.
        guard let d=IOHIDDeviceCreate(kCFAllocatorDefault,IOHIDDeviceGetService(info.device)) else{return false}
        let result=IOHIDDeviceOpen(d,0)
        guard result==kIOReturnSuccess else{onError?("Could not observe \(info.isNaga ? "the Naga side pad":"a keyboard needed for input isolation") (\(String(format:"0x%08x",UInt32(bitPattern:result)))). Check Input Monitoring, then quit and reopen ThumbKey.");return false}
        let endpoint=Endpoint(interface:info,device:d,owner:self)
        endpoints[id]=endpoint
        IOHIDDeviceSetDispatchQueue(d,hidQueue)
        IOHIDDeviceRegisterInputReportWithTimeStampCallback(d,endpoint.buffer,512,{context,result,_,_,reportID,report,length,ticks in
            guard result==kIOReturnSuccess,let context,length>=0,length<=512 else{return}
            let endpoint=Unmanaged<Endpoint>.fromOpaque(context).takeUnretainedValue()
            let bytes=Array(UnsafeBufferPointer(start:report,count:length)),reportID=UInt8(truncatingIfNeeded:reportID)
            if endpoint.interface.isNaga {
                endpoint.owner?.activity()
                if [0x00e7,0x00e8].contains(endpoint.interface.productID),endpoint.interface.layout.hasRazerButtonReport,let buttons=NagaProtocol.buttons(reportID:reportID,bytes:bytes){endpoint.owner?.vendorReport(device:endpoint.interface.id,buttons:buttons);return}
                if reportID==5 {endpoint.owner?.plateSignal(bytes)}
            }
            guard let decoded=endpoint.interface.layout.decode(reportID:reportID,bytes:bytes) else{return}
            let keys=endpoint.interface.isMouse ? Set(decoded.filter{(4...32).contains($0)}.map(InputSource.mouse)):decoded
            let previous=endpoint.reports[UInt32(reportID)] ?? []
            endpoint.reports[UInt32(reportID)]=keys
            let stamp=UInt64(Double(ticks)*Double(HIDCapture.timebase.numer)/Double(HIDCapture.timebase.denom))
            endpoint.owner?.record(endpoint:endpoint,downs:keys.subtracting(previous),ups:previous.subtracting(keys),timestamp:stamp)
        },Unmanaged.passUnretained(endpoint).toOpaque())
        // The cancel handler retains the buffer/context until all callbacks have drained.
        IOHIDDeviceSetCancelHandler(d){[endpoint] in IOHIDDeviceClose(endpoint.device,0)}
        IOHIDDeviceActivate(d)
        return true
    }
    private func record(endpoint:Endpoint,downs:Set<UInt32>,ups:Set<UInt32>,timestamp:UInt64){
        condition.lock();defer{condition.unlock()};guard running else{return}
        for (keys,down) in [(downs,true),(ups,false)]{for usage in keys where InputSource.eventCode(usage) != nil && !(224...231).contains(usage){
            correlation.record(.init(usage:usage,down:down,timestamp:timestamp,naga:endpoint.interface.isNaga,device:endpoint.interface.id))
            if endpoint.interface.isNaga && down{let current=generation;DispatchQueue.main.async{[weak self] in guard let self,self.isCurrent(current) else{return};self.onHardwarePress?(usage)}}
        }}
        condition.broadcast()
    }
    private func activity(){
        let now=Date();guard now.timeIntervalSince(activityAt)>5 else{return};activityAt=now
        DispatchQueue.main.async{[weak self] in self?.onActivity?()}
    }
    private func plateSignal(_ bytes:[UInt8]){
        let signature=bytes.prefix(20).map{String(format:"%02x",$0)}.joined()
        DispatchQueue.main.async{[weak self] in self?.onPlateSignal?(signature)}
    }
    private func vendorReport(device:UInt64,buttons:Set<UInt32>){
        condition.lock();defer{condition.unlock()};guard running,extraButtons else{return}
        let before=vendorStates.values.reduce(into:Set<UInt32>()){$0.formUnion($1)}
        vendorStates[device]=buttons
        let after=vendorStates.values.reduce(into:Set<UInt32>()){$0.formUnion($1)}
        for usage in after.subtracting(before){
            let binding=bindings[usage],intercepted=learning || (binding != nil && binding!.mode != .passthrough)
            activeVendor[usage]=Press(usage:usage,binding:binding,intercepted:intercepted)
            deliver(usage:usage,down:true,binding:binding,intercepted:intercepted)
        }
        for usage in before.subtracting(after){
            let press=activeVendor.removeValue(forKey:usage)
            deliver(usage:usage,down:false,binding:press?.binding,intercepted:press?.intercepted ?? false)
        }
    }
    private func isCurrent(_ current:UUID)->Bool{condition.lock();defer{condition.unlock()};return running && generation==current}
    private func filter(type:CGEventType,event:CGEvent,generation current:UUID)->Unmanaged<CGEvent>?{
        guard isCurrent(current) else{return Unmanaged.passUnretained(event)}
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput{
            DispatchQueue.main.async{[weak self] in guard let self,self.isCurrent(current) else{return};self.stop();self.onDisconnect?("macOS disabled the keyboard filter.")}
            return Unmanaged.passUnretained(event)
        }
        let mouse=type == .otherMouseDown || type == .otherMouseUp
        guard mouse || type == .keyDown || type == .keyUp,event.getIntegerValueField(.eventSourceUserData) != 0x54484D424B4559 else{return Unmanaged.passUnretained(event)}
        let button=event.getIntegerValueField(.mouseEventButtonNumber)
        if mouse && !(3...31).contains(button){return Unmanaged.passUnretained(event)}
        let code=mouse ? UInt16(0x100+button):UInt16(event.getIntegerValueField(.keyboardEventKeycode)),down=type == .keyDown || type == .otherMouseDown
        condition.lock();defer{condition.unlock()}
        guard running,keyCodes.contains(code) || active[code] != nil else{return Unmanaged.passUnretained(event)}
        if !mouse && down && event.getIntegerValueField(.keyboardEventAutorepeat) != 0{
            // Native repeats have no new HID transition. Only suppress an already-routed
            // Naga hold when no regular keyboard holds the same key.
            if let press=active[code],press.intercepted,correlation.nagaHeld(keyCode:code),!correlation.otherHeld(keyCode:code){return nil}
            return Unmanaged.passUnretained(event)
        }
        let deadline=Date(timeIntervalSinceNow:0.012)
        // Wait briefly for both HID streams before attributing a Naga event. A
        // keyboard collision arriving after the mouse report must still fail open.
        var match=correlation.peek(keyCode:code,down:down,timestamp:event.timestamp)
        while running && Date()<deadline{
            if match == .otherKeyboard || match == .ambiguous{break}
            condition.wait(until:deadline)
            match=correlation.peek(keyCode:code,down:down,timestamp:event.timestamp)
        }
        match=correlation.consume(keyCode:code,down:down,timestamp:event.timestamp)
        guard running else{return Unmanaged.passUnretained(event)}
        guard case .naga(let usage)=match else{
            // If identity is ambiguous, stop the remapped hold and leave this event native.
            if let press=active.removeValue(forKey:code),press.intercepted{deliver(usage:press.usage,down:false,binding:press.binding,intercepted:true)}
            return Unmanaged.passUnretained(event)
        }
        if down{
            if let existing=active[code]{return existing.intercepted ? nil:Unmanaged.passUnretained(event)}
            let binding=bindings[usage],intercepted=learning || (binding != nil && binding!.mode != .passthrough)
            active[code]=Press(usage:usage,binding:binding,intercepted:intercepted)
            deliver(usage:usage,down:true,binding:binding,intercepted:intercepted)
            return intercepted ? nil:Unmanaged.passUnretained(event)
        }
        let press=active.removeValue(forKey:code) ?? Press(usage:usage,binding:nil,intercepted:false)
        deliver(usage:usage,down:false,binding:press.binding,intercepted:press.intercepted)
        return press.intercepted ? nil:Unmanaged.passUnretained(event)
    }
    // Called under the condition lock; the UI/actions execute later on the main queue.
    private func deliver(usage:UInt32,down:Bool,binding:ButtonBinding?,intercepted:Bool){
        let current=generation
        DispatchQueue.main.async{[weak self] in guard let self,self.isCurrent(current) else{return};self.onInput?(usage,down,binding,intercepted)}
    }
    deinit{stop();IOHIDManagerUnscheduleFromRunLoop(manager,CFRunLoopGetMain(),CFRunLoopMode.commonModes.rawValue);IOHIDManagerClose(manager,0)}
}
private struct Press{let usage:UInt32;let binding:ButtonBinding?;let intercepted:Bool}
private final class Endpoint{
    let interface:NagaInterface,device:IOHIDDevice
    weak var owner:HIDCapture?
    let buffer=UnsafeMutablePointer<UInt8>.allocate(capacity:512)
    var reports:[UInt32:Set<UInt32>]=[:]
    init(interface:NagaInterface,device:IOHIDDevice,owner:HIDCapture){self.interface=interface;self.device=device;self.owner=owner}
    deinit{buffer.deallocate()}
}

private final class TapContext{weak var owner:HIDCapture?;let generation:UUID;init(owner:HIDCapture,generation:UUID){self.owner=owner;self.generation=generation}}
