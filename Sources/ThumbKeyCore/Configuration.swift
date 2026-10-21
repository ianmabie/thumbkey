import Foundation

public struct Modifiers: OptionSet, Codable, Hashable {
    public let rawValue: UInt8
    public init(rawValue: UInt8) { self.rawValue = rawValue }
    public static let control = Self(rawValue: 1)
    public static let option = Self(rawValue: 2)
    public static let shift = Self(rawValue: 4)
    public static let command = Self(rawValue: 8)
    public var symbols: String { [(Self.control,"⌃"),(.option,"⌥"),(.shift,"⇧"),(.command,"⌘")].filter { contains($0.0) }.map(\.1).joined() }
    public var keyCodes: [UInt16] { [(Self.control,UInt16(59)),(.option,58),(.shift,56),(.command,55)].filter { contains($0.0) }.map(\.1) }
}
public struct Chord: Codable, Equatable, Hashable {
    public var keyCode: UInt16?
    public var modifiers: Modifiers
    public var keyLabel: String
    public init(keyCode: UInt16? = nil, modifiers: Modifiers = [], keyLabel: String = "") { self.keyCode=keyCode; self.modifiers=modifiers; self.keyLabel=keyLabel }
    public static let rightCommand=Chord(keyCode:54,keyLabel:"Right Command")
    public var keys: [UInt16] {var seen=Set<UInt16>();return (modifiers.keyCodes + (keyCode.map { [$0] } ?? [])).filter{seen.insert($0).inserted}}
    public var isEmpty: Bool { keys.isEmpty }
    public var label: String { isEmpty ? "Choose keys…" : modifiers.symbols + (keyCode.flatMap{ModifierKey.names[$0]} ?? keyLabel) }
}
public enum ActionMode: String, Codable, CaseIterable { case passthrough, shortcut, hold, macro, disabled, missionControl, appExpose, showDesktop, previousDesktop, nextDesktop, showShortcuts, figmaPan, figmaComment, figmaZoomScroll, figmaZoomIn, figmaZoomOut
    public var label: String { switch self { case .passthrough: return "Keep default action"; case .shortcut: return "Press a shortcut once"; case .hold: return "Hold keys while pressed"; case .macro: return "Run a sequence of actions"; case .disabled: return "Disable this button"; case .missionControl:return "Mission Control"; case .appExpose:return "App Exposé"; case .showDesktop:return "Show Desktop"; case .previousDesktop:return "Previous Desktop"; case .nextDesktop:return "Next Desktop"; case .showShortcuts:return "Show shortcut overlay"; case .figmaPan:return "Drag canvas (hold button)"; case .figmaComment:return "Add comment (C)"; case .figmaZoomScroll:return "Zoom with scroll wheel (hold ⌘)"; case .figmaZoomIn:return "Zoom in"; case .figmaZoomOut:return "Zoom out" } }
    public static let customActions:[Self] = [.passthrough,.shortcut,.hold,.macro,.disabled]
    public static let macOSActions:[Self] = [.missionControl,.appExpose,.showDesktop,.previousDesktop,.nextDesktop]
    public static let figmaActions:[Self] = [.figmaPan,.figmaComment,.figmaZoomScroll,.figmaZoomIn,.figmaZoomOut]
    public var holdsKeys:Bool{self == .hold || self == .figmaPan || self == .figmaZoomScroll}
    public static let thumbKeyActions:[Self] = [.showShortcuts]
    public var presetChord:Chord? {switch self {
    case .figmaPan:return Chord(keyCode:49,keyLabel:"Space")
    case .figmaComment:return Chord(keyCode:8,keyLabel:"C")
    case .figmaZoomScroll:return Chord(modifiers:.command)
    case .figmaZoomIn:return Chord(keyCode:24,modifiers:.command,keyLabel:"+")
    case .figmaZoomOut:return Chord(keyCode:27,modifiers:.command,keyLabel:"−")
    case .missionControl:return Chord(keyCode:126,modifiers:.control,keyLabel:"↑")
    case .appExpose:return Chord(keyCode:125,modifiers:.control,keyLabel:"↓")
    case .showDesktop:return Chord(keyCode:103,keyLabel:"F11")
    case .previousDesktop:return Chord(keyCode:123,modifiers:.control,keyLabel:"←")
    case .nextDesktop:return Chord(keyCode:124,modifiers:.control,keyLabel:"→")
    default:return nil
    }}
    /// macOS symbolic hotkeys distinguish navigation/function keys by these flags.
    /// A physical Control–Up trace carries both SecondaryFn and NumericPad.
    public var presetKeyFlags:UInt64 {switch self {
    case .missionControl,.appExpose,.previousDesktop,.nextDesktop:return (1<<23) | (1<<21)
    case .showDesktop:return 1<<23
    default:return 0
    }}
    public var explanation:String {switch self {
    case .passthrough:return "ThumbKey leaves this input alone. The mouse or foreground app handles it."
    case .shortcut:return "Press the mouse button once to send these keys once, like Copy or Paste."
    case .hold:return "The chosen keys stay down for as long as you hold the mouse button. Release the button to release the keys. Use this for push-to-talk or a modifier such as Right Command."
    case .macro:return "Run the steps below in order: shortcuts, text, and optional delays."
    case .figmaPan:return "Hold this mouse button and move the mouse over Figma’s canvas. ThumbKey holds Space and the left mouse button together; release to stop dragging and return to your previous tool. Click the canvas first if a text field is focused."
    case .figmaComment:return "Press this mouse button to enter Figma’s comment mode, then click the canvas where you want to leave a comment and type your message. Press Escape to exit comment mode. Click the canvas first if a text field is focused."
    case .figmaZoomScroll:return "Hold this mouse button and scroll the wheel over Figma’s canvas to zoom in or out. Release the button to return to normal scrolling."
    case .figmaZoomIn:return "Press this mouse button to zoom into Figma’s canvas by one step. Click the canvas first if a text field is focused."
    case .figmaZoomOut:return "Press this mouse button to zoom out of Figma’s canvas by one step. Click the canvas first if a text field is focused."
    case .disabled:return "Ignore this button while ThumbKey mappings are enabled."
    case .missionControl:return "Show all open windows and desktops. Press again to return."
    case .appExpose:return "Show all windows belonging to the current app."
    case .showDesktop:return "Move windows aside to show the desktop. Press again to bring them back."
    case .previousDesktop:return "Switch to the desktop or full-screen space on the left."
    case .nextDesktop:return "Switch to the desktop or full-screen space on the right."
    case .showShortcuts:return "Show the shortcuts for your active mouse, side plate, and app profile. Press again, press Escape, or click outside to close. Your current app keeps keyboard focus."
    }}
}
public enum StepKind: String, Codable, CaseIterable { case shortcut, text, delay }
public struct MacroStep: Codable, Identifiable, Equatable {
    public var id: UUID = UUID()
    public var kind: StepKind = .shortcut
    public var chord = Chord()
    public var text = ""
    public var milliseconds: Int = 150
    public init(kind: StepKind = .shortcut) { self.kind=kind }
}
public struct ButtonBinding: Codable, Identifiable, Equatable {
    public var id: Int
    public var name: String = ""
    public var usage: UInt32?
    public var mode: ActionMode = .passthrough
    public var chord = Chord()
    public var steps: [MacroStep] = []
    public init(id: Int, usage: UInt32?) { self.id=id; self.usage=usage }
    public var title: String { name.isEmpty ? (mode.presetChord == nil && mode != .showShortcuts ? MouseControls.title(id):mode.label) : name }
    public var effectiveChord:Chord {mode.presetChord ?? chord}
    public var detail: String { switch mode { case .passthrough: return MouseControls.extraIDs.contains(id) ? "Not assigned":"Default action"; case .disabled: return "Disabled"; case .shortcut: return chord.label; case .hold: return "Hold " + chord.label; case .figmaPan:return "Hold Space + left mouse"; case .figmaZoomScroll:return "Hold ⌘ + scroll"; case .macro: return "\(steps.count) " + (steps.count==1 ? "action":"actions"); case .missionControl,.appExpose,.showDesktop,.previousDesktop,.nextDesktop,.showShortcuts,.figmaComment,.figmaZoomIn,.figmaZoomOut:return mode.label } }
}
public struct Profile: Codable, Identifiable, Equatable {
    public var id = UUID()
    public var name = "Everywhere"
    public var bundleID: String = ""
    public var buttons = MouseControls.defaults()
    public init() {}
    public func buttons(for family:MouseFamily,plate:SidePlate)->[ButtonBinding]{family == .naga ? buttons(for:plate):buttons.filter{MouseControls.mxIDs.contains($0.id)}}
    public func buttons(for plate:SidePlate)->[ButtonBinding] {buttons.filter{plate.buttonIDs.contains($0.id) || MouseControls.extraIDs.contains($0.id)}}
}
public struct Configuration: Codable, Equatable {
    public var version = 3
    public var profiles = [Profile()]
    public init() {}
    public func profile(for bundleID: String?) -> Profile { profiles.first { !$0.bundleID.isEmpty && $0.bundleID == bundleID } ?? profiles[0] }
    public func validated() throws -> Self {
        if version==1 {
            var migrated=self
            for i in migrated.profiles.indices {
                guard migrated.profiles[i].buttons.count==12,Set(migrated.profiles[i].buttons.map(\.id))==Set(1...12) else{throw ConfigError.invalid}
                migrated.profiles[i].buttons += MouseControls.defaults().filter{$0.id>12 && !MouseControls.mxIDs.contains($0.id)}
            }
            migrated.version=2;return try migrated.validated()
        }
        if version==2 {
            var migrated=self
            for i in migrated.profiles.indices {
                guard Set(migrated.profiles[i].buttons.map(\.id))==Set(MouseControls.nagaIDs),migrated.profiles[i].buttons.count==MouseControls.nagaIDs.count else{throw ConfigError.invalid}
                migrated.profiles[i].buttons += MouseControls.mxDefaults()
            }
            migrated.version=3;return try migrated.validated()
        }
        guard version == 3, !profiles.isEmpty, profiles.count <= 50, profiles[0].bundleID.isEmpty else { throw ConfigError.invalid }
        guard Set(profiles.map(\.id)).count == profiles.count else { throw ConfigError.invalid }
        let scoped = profiles.dropFirst().map(\.bundleID)
        guard !scoped.contains(""), Set(scoped).count == scoped.count else { throw ConfigError.invalid }
        for profile in profiles {
            guard profile.buttons.count == MouseControls.allIDs.count, Set(profile.buttons.map(\.id)) == Set(MouseControls.allIDs), profile.name.count <= 100, profile.bundleID.count <= 255 else { throw ConfigError.invalid }
            for plate in SidePlate.allCases {
                let usages=profile.buttons(for:plate).compactMap(\.usage)
                guard Set(usages).count==usages.count,usages.allSatisfy(InputSource.valid) else{throw ConfigError.invalid}
            }
            let mx=profile.buttons(for:.mxMaster3s,plate:.twelve).compactMap(\.usage)
            guard Set(mx).count==mx.count,mx.allSatisfy({InputSource.logitechControl($0).map{LogitechProtocol.controlIDs.contains($0)} ?? false}) else{throw ConfigError.invalid}
            for b in profile.buttons {
                guard b.steps.count <= 100, Set(b.steps.map(\.id)).count == b.steps.count, b.name.count <= 100, valid(b.chord) else { throw ConfigError.invalid }
                for s in b.steps { guard valid(s.chord), s.text.utf16.count <= 4096, (0...60000).contains(s.milliseconds) else { throw ConfigError.invalid } }
                guard b.steps.filter({$0.kind == .delay}).reduce(0, {$0 + $1.milliseconds}) <= 300000 else { throw ConfigError.invalid }
            }
        }
        return self
    }
    /// Change physical identity atomically across profiles, keeping other plates intact.
    public func identifying(button target:Int,usage:UInt32,plate:SidePlate,family:MouseFamily = .naga) throws -> Self {
        guard InputSource.valid(usage),(family == .mxMaster3s ? MouseControls.mxIDs.contains(target):plate.buttonIDs.contains(target) || MouseControls.extraIDs.contains(target)) else{throw ConfigError.invalid}
        var next=self
        let group=family == .mxMaster3s ? MouseControls.mxIDs:MouseControls.extraIDs.contains(target) ? MouseControls.extraIDs:plate.buttonIDs
        for p in next.profiles.indices {
            guard let index=next.profiles[p].buttons.firstIndex(where:{$0.id==target}) else{throw ConfigError.invalid}
            let old=next.profiles[p].buttons[index].usage
            if let other=next.profiles[p].buttons.firstIndex(where:{group.contains($0.id) && $0.id != target && $0.usage==usage}){next.profiles[p].buttons[other].usage=old}
            next.profiles[p].buttons[index].usage=usage
        }
        return try next.validated()
    }
    private func valid(_ c: Chord) -> Bool { (c.keyCode == nil || c.keyCode! <= 126) && c.modifiers.rawValue <= 15 && c.keyLabel.count <= 40 }
}
public enum ConfigError: LocalizedError { case invalid; public var errorDescription: String? { "This configuration is invalid or exceeds the supported limits." } }

// Reference counting prevents one button releasing a modifier still held by another.
public struct KeyOwnership {
    private var owners: [UInt16: Set<UUID>] = [:]
    private var chords: [UUID: [UInt16]] = [:]
    public init() {}
    public var heldKeys: Set<UInt16> { Set(owners.keys) }
    public mutating func press(_ keys: [UInt16], owner: UUID) -> [UInt16] {
        guard chords[owner] == nil else { return [] }
        chords[owner] = keys
        return keys.filter { key in let fresh = owners[key, default: []].isEmpty; owners[key, default: []].insert(owner); return fresh }
    }
    public mutating func release(owner: UUID) -> [UInt16] {
        let keys = chords.removeValue(forKey: owner) ?? []
        return keys.reversed().filter { key in owners[key]?.remove(owner); if owners[key]?.isEmpty == true { owners.removeValue(forKey: key); return true }; return false }
    }
    public mutating func releaseAll() -> [UInt16] { let keys = owners.keys.sorted { a,b in let mods:Set<UInt16>=[55,56,58,59,54,60,61,62]; return mods.contains(a) == mods.contains(b) ? a < b : !mods.contains(a) }; owners.removeAll(); chords.removeAll(); return keys }
}

public enum KeyboardMap {
    // USB HID keyboard usages -> macOS virtual key codes. Locale-specific labels come from the recorder.
    public static let usageToKey: [UInt32: UInt16] = [
        4:0,5:11,6:8,7:2,8:14,9:3,10:5,11:4,12:34,13:38,14:40,15:37,16:46,17:45,18:31,19:35,20:12,21:15,22:1,23:17,24:32,25:9,26:13,27:7,28:16,29:6,
        30:18,31:19,32:20,33:21,34:23,35:22,36:26,37:28,38:25,39:29,40:36,41:53,42:51,43:48,44:49,45:27,46:24,47:33,48:30,49:42,50:10,51:41,52:39,53:50,54:43,55:47,56:44,57:57,
        58:122,59:120,60:99,61:118,62:96,63:97,64:98,65:100,66:101,67:109,68:103,69:111,70:105,71:107,72:113,73:114,74:115,75:116,76:117,77:119,78:121,79:124,80:123,81:125,82:126,
        83:71,84:75,85:67,86:78,87:69,88:76,89:83,90:84,91:85,92:86,93:87,94:88,95:89,96:91,97:92,98:82,99:65,103:81,104:105,105:107,106:113,107:106,108:64,109:79,110:80,111:90,
        224:59,225:56,226:58,227:55,228:62,229:60,230:61,231:54
    ]
}
