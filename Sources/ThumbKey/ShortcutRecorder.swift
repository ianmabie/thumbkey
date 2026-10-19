import AppKit
import SwiftUI
import ThumbKeyCore

struct ShortcutRecorder:NSViewRepresentable {
    @Binding var chord:Chord
    var onRecording:(Bool)->Void
    func makeNSView(context:Context)->Recorder {
        let v=Recorder();v.changed={chord=$0};v.recordingChanged=onRecording;return v
    }
    func updateNSView(_ v:Recorder,context:Context){v.canRecord=context.environment.isEnabled;v.chord=chord;v.changed={chord=$0};v.recordingChanged=onRecording;v.needsDisplay=true;v.setAccessibilityLabel("Shortcut: \(chord.label). Click to record.")}
    final class Recorder:NSView {
        var chord=Chord(),recording=false,seenModifiers=Modifiers()
        var canRecord=true {didSet{if !canRecord{finish(nil)}}}
        var seenModifierKeys=Set<UInt16>()
        var changed:((Chord)->Void)?,recordingChanged:((Bool)->Void)?
        override var acceptsFirstResponder:Bool{true}
        override func mouseDown(with event:NSEvent){guard canRecord else{return};window?.makeFirstResponder(self);recording=true;seenModifiers=[];seenModifierKeys=[];recordingChanged?(true);needsDisplay=true}
        override func resignFirstResponder()->Bool{finish(nil);return super.resignFirstResponder()}
        override func draw(_ rect:NSRect){
            (recording ? NSColor.controlAccentColor.withAlphaComponent(0.1) : NSColor.controlBackgroundColor).setFill();NSBezierPath(roundedRect:bounds,xRadius:8,yRadius:8).fill()
            let text=recording ? "Press your keys, then release · Esc cancels" : chord.label + "  ·  click to change"
            text.draw(at:NSPoint(x:12,y:10),withAttributes:[.font:NSFont.systemFont(ofSize:13,weight:.medium),.foregroundColor:NSColor.labelColor])
        }
        func flags(_ event:NSEvent)->Modifiers{
            var m=Modifiers();let f=event.modifierFlags
            if f.contains(.command){m.insert(.command)};if f.contains(.control){m.insert(.control)};if f.contains(.option){m.insert(.option)};if f.contains(.shift){m.insert(.shift)};return m
        }
        override func flagsChanged(with event:NSEvent){
            guard recording else{return};let current=flags(event)
            if !current.isEmpty {
                seenModifiers.formUnion(current)
                if ModifierKey.names[event.keyCode] != nil {seenModifierKeys.insert(event.keyCode)}
            }else if !seenModifiers.isEmpty{
                if seenModifierKeys.count==1,let code=seenModifierKeys.first {finish(Chord(keyCode:code,keyLabel:ModifierKey.names[code] ?? "Modifier"))}
                else{finish(Chord(modifiers:seenModifiers))}
            }
        }
        override func performKeyEquivalent(with event:NSEvent)->Bool{if recording{keyDown(with:event);return true};return super.performKeyEquivalent(with:event)}
        override func keyDown(with event:NSEvent){
            guard recording else{super.keyDown(with:event);return}
            if event.keyCode==53{finish(nil);return}
            let labels:[UInt16:String]=[49:"Space",36:"Return",48:"Tab",51:"Delete",117:"Forward Delete",123:"←",124:"→",125:"↓",126:"↑",115:"Home",119:"End",116:"Page Up",121:"Page Down",122:"F1",120:"F2",99:"F3",118:"F4",96:"F5",97:"F6",98:"F7",100:"F8",101:"F9",109:"F10",103:"F11",111:"F12",105:"F13",107:"F14",113:"F15",106:"F16",64:"F17",79:"F18",80:"F19",90:"F20"]
            finish(Chord(keyCode:event.keyCode,modifiers:flags(event),keyLabel:labels[event.keyCode] ?? event.charactersIgnoringModifiers?.uppercased() ?? "Key \(event.keyCode)"))
        }
        private func finish(_ result:Chord?){guard recording else{return};recording=false;if let result{changed?(result)};recordingChanged?(false);needsDisplay=true}
        override func viewDidMoveToWindow(){setAccessibilityElement(true);setAccessibilityRole(.button)}
    }
}
