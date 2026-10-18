import Foundation

/// Wire-format facts from OpenRazer's Naga V3 Pro support. No firmware/profile writes.
public enum NagaProtocol {
    public static func modeRequest(set mode:UInt8?=nil)->[UInt8] {
        precondition(mode == nil || mode == 0 || mode == 3)
        var packet=[UInt8](repeating:0,count:90)
        packet[1]=0xff;packet[5]=2;packet[7]=mode == nil ? 0x84:0x04;packet[8]=mode ?? 0
        packet[88]=packet[2..<88].reduce(0,^);return packet
    }
    public static func modeResponse(_ packet:[UInt8],command:UInt8)->UInt8? {
        guard packet.count==90,packet[0]==2,packet[1]==0xff,packet[5]==2,packet[6]==0,packet[7]==command,
              packet[88]==packet[2..<88].reduce(0,^),packet[9]==0,(packet[8]==0 || packet[8]==3) else{return nil}
        return packet[8]
    }
    public static func buttons(reportID:UInt8,bytes:[UInt8])->Set<UInt32>? {
        guard reportID==4 else{return nil}
        let body: [UInt8]
        if bytes.count==16,bytes.first==4 {body=Array(bytes.dropFirst())}
        else if bytes.count==15 {body=bytes}
        else{return nil}
        return Set(body.filter{$0 != 0}.map{InputSource.vendor(UInt32($0))})
    }
}
