import Foundation

public enum MouseFamily:String,Codable,CaseIterable,Identifiable {
    case naga,mxMaster3s
    public var id:String{rawValue}
    public var name:String{self == .naga ? "Razer Naga":"Logitech MX Master 3S"}
}
public enum MouseConnection:String,Sendable {case wired="Wired USB",wireless="2.4 GHz wireless",bluetooth="Bluetooth",unknown="Connection unavailable"
    public static func resolve(vendor:Int,product:Int,transport:String)->Self {
        if transport.lowercased().contains("bluetooth"){return .bluetooth}
        if vendor==0x1532 && product==0x00e8 || vendor==0x046d && [0xc548,0xc52b].contains(product){return .wireless}
        if transport=="USB"{return .wired};return .unknown
    }
}
public struct MousePower:Sendable {
    public let percent:Int?,charging:Bool?
    public init(percent:Int?,charging:Bool?){self.percent=percent.flatMap{(0...100).contains($0) ? $0:nil};self.charging=charging}
    public var label:String {percent.map{"\($0)%"+(charging == true ? " · Charging":"")} ?? "Battery unavailable"}
    public static func logitech(_ payload:[UInt8])->Self {
        guard payload.count>=4 else{return .init(percent:nil,charging:nil)}
        let percent=payload[0]>0 || payload[1]==0 ? Int(payload[0]):nil
        return .init(percent:percent,charging:(1...4).contains(payload[2]))
    }
}
public enum LogitechProtocol {
    public static let softwareID:UInt8=12
    public static let controlIDs:Set<UInt16>=[0x52,0x53,0x56,0xc3,0xc4]
    public static func request(device:UInt8,feature:UInt8,function:UInt8,payload:[UInt8]=[])->[UInt8] {
        var result=[UInt8](repeating:0,count:20);result[0]=0x11;result[1]=device;result[2]=feature;result[3]=(function<<4)|softwareID
        for (i,byte) in payload.prefix(16).enumerated(){result[4+i]=byte};return result
    }
    public static func normalize(reportID:UInt8,bytes:[UInt8])->[UInt8]? {
        if bytes.count==20,bytes.first==0x11{return bytes}
        if reportID==0x11,bytes.count==19{return [0x11]+bytes};return nil
    }
    public static func pressed(_ packet:[UInt8],device:UInt8,feature:UInt8)->Set<UInt16>? {
        guard packet.count==20,packet[0]==0x11,packet[1]==device,packet[2]==feature,packet[3]==0 else{return nil}
        return Set(stride(from:4,to:12,by:2).map{UInt16(packet[$0])<<8|UInt16(packet[$0+1])}.filter{$0 != 0})
    }
    public static func diversion(_ cid:UInt16,enabled:Bool)->[UInt8] {
        // Only temporary diversion is valid/changed; never persistent remapping or raw XY.
        [UInt8(cid>>8),UInt8(cid&255),enabled ? 3:2,0,0]
    }
}
