import Foundation
import IOKit.hid
import ThumbKeyCore

enum MouseTelemetry {
    static func nagaPower()->MousePower {
        let manager=IOHIDManagerCreate(kCFAllocatorDefault,IOHIDManagerOptions.independentDevices.rawValue)
        IOHIDManagerSetDeviceMatching(manager,[kIOHIDVendorIDKey:0x1532] as CFDictionary);IOHIDManagerOpen(manager,0)
        defer{IOHIDManagerClose(manager,0)}
        let targets=(IOHIDManagerCopyDevices(manager) as? Set<IOHIDDevice> ?? []).filter {
            [0x00e7,0x00e8].contains(HIDCapture.number($0,kIOHIDProductIDKey)) && HIDCapture.number($0,kIOHIDPrimaryUsagePageKey)==1 && HIDCapture.number($0,kIOHIDPrimaryUsageKey)==3
        }
        guard targets.count==1,let source=targets.first,let device=IOHIDDeviceCreate(kCFAllocatorDefault,IOHIDDeviceGetService(source)),IOHIDDeviceOpen(device,0)==0 else{return .init(percent:nil,charging:nil)}
        defer{IOHIDDeviceClose(device,0)}
        func query(_ command:UInt8)->UInt8? {
            var packet=[UInt8](repeating:0,count:90);packet[1]=0xff;packet[5]=2;packet[6]=7;packet[7]=command;packet[88]=packet[2..<88].reduce(0,^)
            guard IOHIDDeviceSetReport(device,kIOHIDReportTypeFeature,0,packet,90)==0 else{return nil}
            Thread.sleep(forTimeInterval:0.1)
            var result=[UInt8](repeating:0,count:90),length=90
            guard IOHIDDeviceGetReport(device,kIOHIDReportTypeFeature,0,&result,&length)==0,length==90,result[0]==2,result[6]==7,result[7]==command,result[88]==result[2..<88].reduce(0,^) else{return nil}
            return result[9]
        }
        let battery=query(0x80),charge=query(0x84)
        return .init(percent:battery.map{Int((Double($0)*100/255).rounded())},charging:charge.map{$0==1})
    }
}
