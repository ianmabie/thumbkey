import Foundation
import IOKit.hid
import ThumbKeyCore

/// HID++ requests and events are isolated by receiver slot, feature, and software ID.
private final class LogitechLink {
    let device:IOHIDDevice
    let transport:String
    private let condition=NSCondition()
    private var responses=[[UInt8]]()
    private var cancelled=false
    private let buffer=UnsafeMutablePointer<UInt8>.allocate(capacity:64)
    private var packetHandler:(([UInt8])->Void)?
    var onPacket:(([UInt8])->Void)? {
        get {condition.lock();defer{condition.unlock()};return packetHandler}
        set {condition.lock();packetHandler=newValue;condition.unlock()}
    }
    init(source:IOHIDDevice)throws {
        guard let fresh=IOHIDDeviceCreate(kCFAllocatorDefault,IOHIDDeviceGetService(source)) else{throw ScribeMouseError("Could not create the Logitech input connection.")}
        device=fresh;transport=HIDCapture.text(source,kIOHIDTransportKey)
        let opened=IOHIDDeviceOpen(device,0)
        guard opened==kIOReturnSuccess else{throw ScribeMouseError("Could not open the Logitech receiver. Check Input Monitoring and reconnect it.")}
        IOHIDDeviceSetDispatchQueue(device,DispatchQueue(label:"personal.thumbkey.logitech.reports",qos:.userInteractive))
        IOHIDDeviceRegisterInputReportCallback(device,buffer,64,{context,status,_,_,id,bytes,length in
            guard status==0,let context,length<=64 else{return}
            let owner=Unmanaged<LogitechLink>.fromOpaque(context).takeUnretainedValue()
            guard let packet=LogitechProtocol.normalize(reportID:UInt8(truncatingIfNeeded:id),bytes:Array(UnsafeBufferPointer(start:bytes,count:length))) else{return}
            owner.condition.lock();owner.responses.append(packet)
            if owner.responses.count>64{owner.responses.removeFirst(owner.responses.count-64)}
            owner.condition.broadcast();let callback=owner.packetHandler;owner.condition.unlock()
            callback?(packet)
        },Unmanaged.passUnretained(self).toOpaque())
        IOHIDDeviceSetCancelHandler(device){[self] in IOHIDDeviceClose(device,0)}
        IOHIDDeviceActivate(device)
    }
    func request(_ index:UInt8,_ feature:UInt8,_ function:UInt8,_ payload:[UInt8]=[])throws->[UInt8] {
        let packet=LogitechProtocol.request(device:index,feature:feature,function:function,payload:payload)
        condition.lock();responses=[];condition.unlock()
        guard IOHIDDeviceSetReport(device,kIOHIDReportTypeOutput,0x11,packet,packet.count)==0 else{throw ScribeMouseError("The Logitech control connection was lost. Reconnect the mouse.")}
        condition.lock();defer{condition.unlock()}
        let deadline=Date(timeIntervalSinceNow:0.55)
        while Date()<deadline {
            if let reply=responses.first(where:{$0[1]==index && (($0[2]==feature && $0[3]==packet[3]) || ($0[2]==0xff && $0[3]==feature && $0[4]==packet[3]))}) {
                guard reply[2] != 0xff else{throw ScribeMouseError("Logitech rejected the button request (\(reply[5])).")}
                return Array(reply.dropFirst(4))
            }
            condition.wait(until:deadline)
        }
        throw ScribeMouseError("The MX Master 3S did not answer. Move it to wake it, then enable mappings again.")
    }
    func close(){guard !cancelled else{return};cancelled=true;IOHIDDeviceCancel(device)}
    deinit{buffer.deallocate()}
}

final class LogitechController {
    private var link:LogitechLink?
    private var index:UInt8=0,feature:UInt8=0
    private var original=[UInt16:Bool]()
    private var supported=Set<UInt16>()
    private var cachedIndex:UInt8?
    private let lock=NSLock()
    private var running=false,learning=false
    private var generation=UUID()
    private var bindings=[UInt16:ButtonBinding]()
    private var active=[UInt16:(ButtonBinding?,Bool)]()
    private var pressed=Set<UInt16>()
    var onInput:((UInt32,Bool,ButtonBinding?,Bool)->Void)?
    var isConnected:Bool{link != nil}
    var connection:MouseConnection{link?.transport.lowercased().contains("bluetooth") == true ? .bluetooth:.wireless}
    var supportedControls:Set<UInt16>{supported}
    func connect()throws {
        if link != nil{return}
        let manager=IOHIDManagerCreate(kCFAllocatorDefault,IOHIDManagerOptions.independentDevices.rawValue)
        IOHIDManagerSetDeviceMatching(manager,[kIOHIDVendorIDKey:0x046d] as CFDictionary);IOHIDManagerOpen(manager,0)
        defer{IOHIDManagerClose(manager,0)}
        let sources=(IOHIDManagerCopyDevices(manager) as? Set<IOHIDDevice> ?? []).filter {
            let pid=HIDCapture.number($0,kIOHIDProductIDKey)
            return [0xc548,0xb034,0xb043].contains(pid) && ((IOHIDDeviceGetProperty($0,kIOHIDReportDescriptorKey as CFString) as? Data)?.range(of:Data([0x85,0x11])) != nil)
        }
        for source in sources {
            let candidate=try LogitechLink(source:source)
            let slots=HIDCapture.text(source,kIOHIDTransportKey).lowercased().contains("bluetooth") ? [UInt8(255)]:Array(1...6).map(UInt8.init)
            let targets: [UInt8]
            if let cachedIndex{targets=[cachedIndex]+slots.filter{$0 != cachedIndex}}else{targets=slots}
            for slot in targets {
                do {
                    let nameFeature=try candidate.request(slot,0,0,[0,5])[0]
                    guard nameFeature>0 else{continue}
                    let length=Int(try candidate.request(slot,nameFeature,0)[0]);var name=[UInt8]()
                    guard length>0,length<=64 else{continue}
                    for offset in stride(from:0,to:length,by:16){name += try candidate.request(slot,nameFeature,1,[UInt8(offset)]).prefix(min(16,length-offset))}
                    let text=String(bytes:name,encoding:.utf8)?.lowercased() ?? ""
                    guard text.contains("mx master 3s") else{continue}
                    let controlFeature=try candidate.request(slot,0,0,[0x1b,4])[0]
                    guard controlFeature>0 else{continue}
                    let count=Int(try candidate.request(slot,controlFeature,0)[0]);var controls=Set<UInt16>()
                    for n in 0..<min(count,32) {
                        let result=try candidate.request(slot,controlFeature,1,[UInt8(n)])
                        let cid=UInt16(result[0])<<8|UInt16(result[1])
                        if result[4]&0x20 != 0 && LogitechProtocol.controlIDs.contains(cid){controls.insert(cid)}
                    }
                    guard !controls.isEmpty else{continue}
                    index=slot;feature=controlFeature;supported=controls;cachedIndex=slot;link=candidate
                    candidate.onPacket={ [weak self] in self?.receive($0) };return
                }catch{continue}
            }
            candidate.close()
        }
        throw ScribeMouseError("No awake MX Master 3S answered over Bolt or Bluetooth. Move the mouse, check its connection, and enable again.")
    }
    func configure(_ next:[ButtonBinding],learning:Bool)throws {
        guard let link else{return}
        let mapped=Dictionary(uniqueKeysWithValues:next.compactMap{binding in binding.usage.flatMap(InputSource.logitechControl).map{($0,binding)}})
        let desired=learning ? supported:Set(mapped.filter{$0.value.mode != .passthrough}.keys)
        guard desired.isSubset(of:supported) else{throw ScribeMouseError("This mouse did not report that button as programmable.")}
        for cid in Set(original.keys).subtracting(desired) {
            try setDiversion(cid,enabled:original[cid] ?? false,link:link);original.removeValue(forKey:cid)
        }
        for cid in desired.subtracting(Set(original.keys)) {
            let state=try link.request(index,feature,2,[UInt8(cid>>8),UInt8(cid&255)])
            guard UInt16(state[0])<<8|UInt16(state[1])==cid else{throw ScribeMouseError("The Logitech button response did not match its request.")}
            let wasDiverted=state[2]&1 != 0
            original[cid]=wasDiverted
            if !wasDiverted{try setDiversion(cid,enabled:true,link:link)}
        }
        lock.lock();bindings=mapped;self.learning=learning;running=true;lock.unlock()
    }
    private func setDiversion(_ cid:UInt16,enabled:Bool,link:LogitechLink)throws {
        _ = try link.request(index,feature,3,LogitechProtocol.diversion(cid,enabled:enabled))
        let state=try link.request(index,feature,2,[UInt8(cid>>8),UInt8(cid&255)])
        guard (state[2]&1 != 0)==enabled else{throw ScribeMouseError("Could not verify Logitech button reporting. Reconnect the mouse.")}
    }
    func power()->MousePower {
        guard let link,let battery=try? link.request(index,0,0,[0x10,4])[0],battery>0,let status=try? link.request(index,battery,1) else{return .init(percent:nil,charging:nil)}
        return .logitech(status)
    }
    func stop()throws {
        lock.lock();running=false;generation=UUID();pressed=[];active=[:];lock.unlock()
        guard let current=link else{return}
        var failure:Error?
        for (cid,state) in original{do{try setDiversion(cid,enabled:state,link:current)}catch{failure=error}}
        original=[:];current.onPacket=nil;current.close();link=nil;supported=[]
        if let failure{throw ScribeMouseError("Could not restore a Logitech button: \(failure.localizedDescription). Reconnect the mouse.")}
    }
    private func receive(_ packet:[UInt8]) {
        lock.lock();defer{lock.unlock()}
        guard running,let now=LogitechProtocol.pressed(packet,device:index,feature:feature) else{return}
        for cid in now.subtracting(pressed) {
            let binding=bindings[cid],intercepted=learning || (binding != nil && binding!.mode != .passthrough)
            active[cid]=(binding,intercepted)
            deliver(cid,true,binding,intercepted)
        }
        for cid in pressed.subtracting(now) {let value=active.removeValue(forKey:cid);deliver(cid,false,value?.0,value?.1 ?? false)}
        pressed=now
    }
    private func deliver(_ cid:UInt16,_ down:Bool,_ binding:ButtonBinding?,_ intercepted:Bool) {
        let current=generation
        DispatchQueue.main.async{[weak self] in
            guard let self else{return}
            self.lock.lock();let valid=self.running && self.generation==current;self.lock.unlock()
            if valid{self.onInput?(InputSource.logitech(cid),down,binding,intercepted)}
        }
    }
    deinit{try? stop()}
}
private struct ScribeMouseError:LocalizedError {
    let text:String
    init(_ text:String){self.text=text}
    var errorDescription:String?{text}
}
