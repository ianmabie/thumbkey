import AppKit
import ThumbKeyCore

final class ActionRunner {
    private var ownership=KeyOwnership()
    private var held:[UInt32:UUID]=[:]
    private var tasks:[UInt32:Task<Void,Never>]=[:]
    private var lifetimes:[UInt32:UUID]=[:]
    private var watchdogs:[UInt32:DispatchWorkItem]=[:]
    private var postedKeys=Set<UInt16>()
    var status: ((String)->Void)?
    var suspend=false
    private func post(_ code:UInt16,down:Bool) {
        guard let e=CGEvent(keyboardEventSource:nil,virtualKey:code,keyDown:down) else{return}
        if down{postedKeys.insert(code)}else{postedKeys.remove(code)}
        e.flags=CGEventFlags(rawValue:ModifierKey.flags(physical:CGEventSource.flagsState(.hidSystemState).rawValue,pressed:postedKeys))
        if ModifierKey.familyBits[code] != nil { e.type = .flagsChanged }
        e.setIntegerValueField(.eventSourceUserData,value:0x54484D424B4559)
        e.post(tap:.cgSessionEventTap)
    }
    private func press(_ chord:Chord,owner:UUID) { for key in ownership.press(chord.keys,owner:owner) { post(key,down:true) } }
    private func release(_ owner:UUID) { for key in ownership.release(owner:owner) { post(key,down:false) } }
    private func tap(_ chord:Chord) { let owner=UUID();press(chord,owner:owner);release(owner) }
    private func text(_ text:String) {
        let units=Array(text.utf16)
        // CGEvent Unicode has a small length limit. Preserve surrogate pairs at boundaries.
        var index=0
        while index<units.count {
            var end=min(index+18,units.count)
            if end<units.count && (0xD800...0xDBFF).contains(units[end-1]) {end-=1}
            let slice=Array(units[index..<end])
            for down in [true,false] {
                if let event=CGEvent(keyboardEventSource:nil,virtualKey:0,keyDown:down) { slice.withUnsafeBufferPointer{event.keyboardSetUnicodeString(stringLength:$0.count,unicodeString:$0.baseAddress!)};event.flags=[];event.post(tap:.cgSessionEventTap) }
            }
            index=end
        }
    }
    func down(_ usage:UInt32,binding:ButtonBinding?) {
        guard !suspend,held[usage]==nil,tasks[usage]==nil else{return}
        let b=binding ?? ButtonBinding(id:0,usage:usage)
        switch b.mode {
        case .disabled:break
        case .passthrough:
            if let code=KeyboardMap.usageToKey[usage] { let owner=UUID();held[usage]=owner;press(Chord(keyCode:code),owner:owner) }
            else {status?("This original key cannot be forwarded. Assign it a hotkey instead.")}
        case .hold:
            let owner=UUID();held[usage]=owner;press(b.chord,owner:owner)
        case .shortcut:tap(b.chord)
        case .macro:
            let pid=NSWorkspace.shared.frontmostApplication?.processIdentifier
            let generation=UUID();lifetimes[usage]=generation
            tasks[usage]=Task { @MainActor [weak self] in
                guard let self else{return}
                defer { if self.lifetimes[usage]==generation {self.tasks.removeValue(forKey:usage);self.lifetimes.removeValue(forKey:usage)} }
                for step in b.steps.prefix(100) {
                    guard !Task.isCancelled,NSWorkspace.shared.frontmostApplication?.processIdentifier==pid else { self.status?("Macro stopped because the active app changed."); return }
                    switch step.kind {
                    case .shortcut:self.tap(step.chord)
                    case .text:self.text(step.text)
                    case .delay:try? await Task.sleep(nanoseconds:UInt64(max(0,min(60000,step.milliseconds)))*1_000_000)
                    }
                    if step.kind != .delay { try? await Task.sleep(nanoseconds:25_000_000) }
                }
            }
        }
        if held[usage] != nil {
            let work=DispatchWorkItem{[weak self] in self?.up(usage);self?.status?("Released a key held for more than two minutes.")}
            watchdogs[usage]=work;DispatchQueue.main.asyncAfter(deadline:.now()+120,execute:work)
        }
    }
    func up(_ usage:UInt32) { watchdogs.removeValue(forKey:usage)?.cancel();if let owner=held.removeValue(forKey:usage){release(owner)} }
    func cancelAll() {
        tasks.values.forEach{$0.cancel()};tasks.removeAll();lifetimes.removeAll()
        watchdogs.values.forEach{$0.cancel()};watchdogs.removeAll();held.removeAll()
        for key in ownership.releaseAll(){post(key,down:false)}
    }
}
