import Foundation

public enum SidePlate:Int,Codable,CaseIterable,Identifiable {
    case two=2,six=6,twelve=12
    public var id:Int {rawValue}
    public var label:String {"\(rawValue)-button plate"}
    public var buttonIDs:[Int] {switch self {case .twelve:return Array(1...12);case .six:return Array(101...106);case .two:return Array(201...202)}}
}

public enum MouseControls {
    public static let extraIDs=Array(13...17)
    public static let allIDs=SidePlate.allCases.flatMap(\.buttonIDs)+extraIDs
    public static func number(_ id:Int)->Int {id>=200 ? id-200:id>=100 ? id-100:id}
    public static func title(_ id:Int)->String {
        switch id {
        case 13:return "Left edge · front"
        case 14:return "Left edge · rear"
        case 15:return "Behind wheel · front"
        case 16:return "Behind wheel · rear"
        case 17:return "Ring-finger button"
        case 201:return "Side button 1 · Back"
        case 202:return "Side button 2 · Forward"
        default:return "Side button \(number(id))"
        }
    }
    public static func location(_ id:Int)->String {
        switch id {
        case 13:return "The front small button beside the left mouse button. Usually DPI up."
        case 14:return "The rear small button beside the left mouse button. Usually DPI down."
        case 15:return "The front button directly behind the scroll wheel. Usually scroll-mode control. Use Identify to check its input."
        case 16:return "The rear button behind the scroll wheel. Usually AI Prompt Master."
        case 17:return "The button to the right of right-click, under your ring finger. Check its physical lock if it does not press."
        default:return "Button \(number(id)) on the \(id>=200 ? 2:id>=100 ? 6:12)-button side plate."
        }
    }
    public static func defaults()->[ButtonBinding] {
        let twelve=(1...12).map{ButtonBinding(id:$0,usage:UInt32($0<10 ? $0+29:$0==10 ? 39:$0==11 ? 45:46))}
        let six=(1...6).map{ButtonBinding(id:100+$0,usage:UInt32($0+29))}
        let two=[ButtonBinding(id:201,usage:InputSource.mouse(4)),ButtonBinding(id:202,usage:InputSource.mouse(5))]
        let extra=[ButtonBinding(id:13,usage:InputSource.vendor(0x20)),ButtonBinding(id:14,usage:InputSource.vendor(0x21)),
                   ButtonBinding(id:15,usage:nil),ButtonBinding(id:16,usage:InputSource.vendor(0xd2)),ButtonBinding(id:17,usage:InputSource.vendor(0x59))]
        return twelve+extra+six+two
    }
}

public enum InputSource {
    public static func mouse(_ button:UInt32)->UInt32 {0x0009_0000|button}
    public static func vendor(_ code:UInt32)->UInt32 {0xff00_0000|code}
    public static func isVendor(_ value:UInt32)->Bool {value&0xffff_ff00 == 0xff00_0000 && value&255>0}
    public static func mouseButton(_ value:UInt32)->UInt32? {value&0xffff_0000 == 0x0009_0000 && (4...32).contains(value&0xffff) ? value&0xffff:nil}
    public static func valid(_ value:UInt32)->Bool {isVendor(value) || mouseButton(value) != nil || ((4...255).contains(value) && !(224...231).contains(value))}
    public static func eventCode(_ value:UInt32)->UInt16? {
        if let button=mouseButton(value){return UInt16(0x100+button-1)}
        return KeyboardMap.usageToKey[value]
    }
    public static func description(_ value:UInt32)->String {
        if isVendor(value){return "Mouse hardware signal \(String(format:"%02X",value&255))"}
        if let button=mouseButton(value){return "Mouse button \(button)"}
        if (30...38).contains(value){return "Keyboard \(value-29)"}
        if value==39{return "Keyboard 0"};if value==45{return "Keyboard −"};if value==46{return "Keyboard ="}
        return "Keyboard input \(value)"
    }
}

public enum ModifierKey {
    // macOS device-dependent modifier bits distinguish left from right keys.
    public static let deviceBits:[UInt16:UInt64]=[59:1,56:2,60:4,55:8,54:16,58:32,61:64,62:8192]
    public static let familyBits:[UInt16:UInt64]=[55:1<<20,54:1<<20,56:1<<17,60:1<<17,58:1<<19,61:1<<19,59:1<<18,62:1<<18]
    public static let names:[UInt16:String]=[55:"Left Command",54:"Right Command",56:"Left Shift",60:"Right Shift",58:"Left Option",61:"Right Option",59:"Left Control",62:"Right Control"]
    public static func flags(physical:UInt64,pressed:Set<UInt16>)->UInt64 {
        let allowed=deviceBits.values.reduce(UInt64(0),|) | familyBits.values.reduce(UInt64(0),|) | (1<<16) | (1<<23)
        return pressed.reduce(physical&allowed){$0 | (deviceBits[$1] ?? 0) | (familyBits[$1] ?? 0)}
    }
}
