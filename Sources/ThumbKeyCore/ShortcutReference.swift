import Foundation

/// A read-only reference to the actions that actually route in a given context.
/// Macro text is intentionally represented by action counts, never its contents.
public struct ShortcutReference:Identifiable,Equatable {
    public let binding:ButtonBinding
    public var id:Int{binding.id}
    public var buttonName:String{MouseControls.title(id)}
    public var actionName:String {
        if !binding.name.isEmpty{return binding.name}
        switch binding.mode {
        case .shortcut:return "Keyboard shortcut"
        case .hold:return "Hold keys"
        case .macro:return "Macro"
        default:return binding.mode.label
        }
    }
    public var keys:String {
        switch binding.mode {
        case .shortcut:return binding.chord.label
        case .figmaPan:return "Hold Space + left mouse"
        case .hold,.figmaZoomScroll:return "Hold " + binding.effectiveChord.label
        case .macro:return binding.detail
        case .showShortcuts:return "Toggle overlay"
        default:return binding.effectiveChord.label
        }
    }
    public var menuTitle:String{"\(buttonName) · \(actionName)  —  \(keys)"}
    public static func configured(in profile:Profile,family:MouseFamily,plate:SidePlate)->[Self] {
        let ids=family == .naga ? plate.buttonIDs+MouseControls.extraIDs:MouseControls.mxIDs
        return ids.compactMap{id in
            guard let binding=profile.buttons.first(where:{$0.id==id}) else{return nil}
            switch binding.mode {
            case .passthrough,.disabled:return nil
            case .shortcut,.hold:guard !binding.chord.isEmpty else{return nil}
            case .macro:
                guard binding.steps.contains(where:{($0.kind == .shortcut && !$0.chord.isEmpty) || ($0.kind == .text && !$0.text.isEmpty)}) else{return nil}
            default:break
            }
            return Self(binding:binding)
        }
    }
}
