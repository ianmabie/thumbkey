import Foundation

public struct KeyboardField {
    let report: UInt8, offset: Int, width: Int, count: Int
    let variable: Bool
    let usages: [UInt32]
    let minimum: UInt32
}
public struct KeyboardReportLayout {
    private var fields: [KeyboardField] = []
    private var sizes: [UInt8:Int] = [:]
    public private(set) var numbered = false
    private var usagePage:UInt32=7
    public private(set) var hasRazerButtonReport=false
    public init(descriptor: [UInt8],usagePage:UInt32=7) {
        self.usagePage=usagePage
        struct Globals { var page:UInt32=0; var size=0; var count=0; var report:UInt8=0 }
        var g=Globals(), stack:[Globals]=[], usages:[UInt32]=[], minimum:UInt32=0
        var offsets:[UInt8:Int]=[:], i=0
        while i < descriptor.count {
            let prefix=descriptor[i]; i+=1
            if prefix == 0xfe { guard i+2 <= descriptor.count else { break }; let length=Int(descriptor[i]); i += 2+length; continue }
            let length=[0,1,2,4][Int(prefix&3)]
            guard i+length <= descriptor.count else { break }
            var value:UInt32=0; for n in 0..<length { value |= UInt32(descriptor[i+n]) << (n*8) }; i += length
            let type=(prefix>>2)&3, tag=prefix>>4
            if type == 1 {
                switch tag { case 0:g.page=value; case 7:g.size=Int(value); case 8:g.report=UInt8(truncatingIfNeeded:value); numbered=true; case 9:g.count=Int(value); case 10:stack.append(g); case 11:if let saved=stack.popLast(){g=saved}; default:break }
            } else if type == 2 {
                if tag==0 { usages.append(value) }; if tag==1 { minimum=value }
            } else if type == 0 {
                if tag == 8, g.size > 0, g.size <= 32, g.count > 0, g.count <= 4096 {
                    let offset=offsets[g.report,default:0]
                    if value&1 == 0 && g.page==usagePage { fields.append(KeyboardField(report:g.report,offset:offset,width:g.size,count:g.count,variable:value&2 != 0,usages:usages,minimum:minimum)) }
                    if value&1 == 0 && g.page==1 && usages==[3] && g.report==4 && g.size==8 && g.count==15 {hasRazerButtonReport=true}
                    offsets[g.report]=offset + g.size*g.count
                }
                usages=[]; minimum=0
            }
        }
        sizes=offsets
    }
    public var isSupported: Bool { !fields.isEmpty }
    // A nil result is not a keyboard report, truncated, or a rollover error. Keep prior state.
    public func decode(reportID: UInt8, bytes: [UInt8]) -> Set<UInt32>? {
        let selected=fields.filter{$0.report==reportID}; guard !selected.isEmpty, let bits=sizes[reportID] else{return nil}
        let required=(bits+7)/8
        var body=bytes
        if numbered && body.count==required+1 && body.first==reportID { body.removeFirst() }
        guard body.count==required else { return nil }
        var keys=Set<UInt32>()
        for f in selected {
            for n in 0..<f.count {
                let start=f.offset+n*f.width
                var value:UInt32=0
                for b in 0..<f.width { if body[(start+b)/8] & (1 << ((start+b)%8)) != 0 { value |= 1 << b } }
                if f.variable { if value != 0 { keys.insert(n < f.usages.count ? f.usages[n] : f.minimum + UInt32(n)) } }
                else { if usagePage==7 && (1...3).contains(value) { return nil }; if value != 0 { keys.insert(value) } }
            }
        }
        return keys
    }
}
public enum DevicePolicy {
    public static func accepts(vendor: Int, name: String, keyboard: Bool, mouse: Bool, builtIn: Bool) -> Bool {
        vendor == 0x1532 && name.lowercased().contains("naga") && (keyboard || mouse) && !builtIn
    }
}
