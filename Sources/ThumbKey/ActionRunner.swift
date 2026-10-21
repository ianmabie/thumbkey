import AppKit
import ThumbKeyCore

/// Key ownership and posting stay on one serial queue, independent of AppKit's
/// run loop (which can stall while Mission Control animates).
final class ActionRunner {
    typealias KeyOutput=(UInt16,Bool,CGEventTapLocation,CGEventFlags)->Void
    private let queue=DispatchQueue(label:"personal.thumbkey.actions",qos:.userInteractive)
    private let lifetime=RequestGeneration()
    private let keyOutput:KeyOutput?
    private let textOutput:((String)->Void)?
    private let physicalFlags:()->UInt64
    private let foregroundPID:()->pid_t?
    private var ownership=KeyOwnership()
    private var held=[UInt32:UUID]()
    private var macros=[UInt32:UUID]()
    private var watchdogs=[UInt32:DispatchWorkItem]()
    private var postedKeys=Set<UInt16>()
    private var suspended=false,physicalEnabled=false
    var status:((String)->Void)?
    var showShortcuts:(()->Void)?
    init(keyOutput:KeyOutput?=nil,textOutput:((String)->Void)?=nil,
         physicalFlags:@escaping()->UInt64={CGEventSource.flagsState(.hidSystemState).rawValue},
         foregroundPID:@escaping()->pid_t?={NSWorkspace.shared.frontmostApplication?.processIdentifier}){
        self.keyOutput=keyOutput;self.textOutput=textOutput
        self.physicalFlags=physicalFlags;self.foregroundPID=foregroundPID
    }
    var suspend:Bool {
        get{queue.sync{suspended}}
        set{queue.async{self.suspended=newValue}}
    }
    func setPhysicalEnabled(_ value:Bool){
        if !value{lifetime.next()}
        queue.async{self.physicalEnabled=value;if !value{self.clear()}}
    }
    private func submit(_ work:@escaping(UUID)->Void){
        let request=lifetime.current()
        queue.async{[self] in guard lifetime.matches(request) else{return};work(request)}
    }
    func physicalInput(_ usage:UInt32,down:Bool,binding:ButtonBinding?){
        submit{[self] request in
            if down {if physicalEnabled{pressButton(usage,binding:binding,request:request)}}else{releaseButton(usage)}
        }
    }
    // Explicit UI tests are available even while physical mappings are paused.
    func down(_ usage:UInt32,binding:ButtonBinding?){submit{request in self.pressButton(usage,binding:binding,request:request)}}
    func up(_ usage:UInt32){submit{_ in self.releaseButton(usage)}}
    func cancelAll(){lifetime.next();queue.async{self.clear()}}
    func finishStopping(){queue.sync{}}
    private func report(_ text:String){DispatchQueue.main.async{[weak self] in self?.status?(text)}}
    private func post(_ code:UInt16,down:Bool,at location:CGEventTapLocation = .cgSessionEventTap,keyFlags:CGEventFlags=[]){
        if down{postedKeys.insert(code)}else{postedKeys.remove(code)}
        var flags=CGEventFlags(rawValue:ModifierKey.flags(physical:physicalFlags(),pressed:postedKeys))
        if ModifierKey.familyBits[code]==nil{flags.formUnion(keyFlags)}
        if let keyOutput{keyOutput(code,down,location,flags);return}
        guard let event=CGEvent(keyboardEventSource:nil,virtualKey:code,keyDown:down) else{return}
        event.flags=flags
        if ModifierKey.familyBits[code] != nil{event.type = .flagsChanged}
        event.setIntegerValueField(.eventSourceUserData,value:0x54484D424B4559)
        event.post(tap:location)
    }
    private func press(_ chord:Chord,owner:UUID,at location:CGEventTapLocation = .cgSessionEventTap,keyFlags:CGEventFlags=[]){
        for key in ownership.press(chord.keys,owner:owner){post(key,down:true,at:location,keyFlags:keyFlags)}
    }
    private func release(_ owner:UUID,at location:CGEventTapLocation = .cgSessionEventTap,keyFlags:CGEventFlags=[]){
        for key in ownership.release(owner:owner){post(key,down:false,at:location,keyFlags:keyFlags)}
    }
    private func tap(_ chord:Chord,at location:CGEventTapLocation = .cgSessionEventTap,keyFlags:CGEventFlags=[]){
        let owner=UUID();press(chord,owner:owner,at:location,keyFlags:keyFlags);release(owner,at:location,keyFlags:keyFlags)
    }
    private func text(_ text:String){
        if let textOutput{textOutput(text);return}
        let units=Array(text.utf16)
        var index=0
        while index<units.count {
            var end=min(index+18,units.count)
            if end<units.count && (0xD800...0xDBFF).contains(units[end-1]){end-=1}
            let slice=Array(units[index..<end])
            for down in [true,false]{
                if let event=CGEvent(keyboardEventSource:nil,virtualKey:0,keyDown:down){
                    slice.withUnsafeBufferPointer{event.keyboardSetUnicodeString(stringLength:$0.count,unicodeString:$0.baseAddress!)}
                    event.flags=[];event.setIntegerValueField(.eventSourceUserData,value:0x54484D424B4559)
                    event.post(tap:.cgSessionEventTap)
                }
            }
            index=end
        }
    }
    private func pressButton(_ usage:UInt32,binding:ButtonBinding?,request:UUID){
        guard !suspended,held[usage]==nil,macros[usage]==nil else{return}
        let binding=binding ?? ButtonBinding(id:0,usage:usage)
        switch binding.mode {
        case .disabled:break
        case .showShortcuts:
            DispatchQueue.main.async{[weak self] in guard let self,self.lifetime.matches(request) else{return};self.showShortcuts?()}
        case .passthrough:
            if let code=KeyboardMap.usageToKey[usage]{let owner=UUID();held[usage]=owner;press(Chord(keyCode:code),owner:owner)}
            else{report("This original key cannot be forwarded. Assign it a hotkey instead.")}
        case .hold,.figmaPan:
            let owner=UUID();held[usage]=owner;press(binding.effectiveChord,owner:owner)
        case .shortcut:tap(binding.chord)
        case .missionControl,.appExpose,.showDesktop,.previousDesktop,.nextDesktop:
            tap(binding.effectiveChord,at:.cghidEventTap,keyFlags:CGEventFlags(rawValue:binding.mode.presetKeyFlags))
        case .macro:
            let token=UUID();macros[usage]=token
            runMacro(binding.steps,index:0,usage:usage,token:token,pid:foregroundPID(),request:request)
        }
        if held[usage] != nil {
            let work=DispatchWorkItem{[weak self] in self?.releaseButton(usage);self?.report("Released a key held for more than two minutes.")}
            watchdogs[usage]=work;queue.asyncAfter(deadline:.now()+120,execute:work)
        }
    }
    private func runMacro(_ steps:[MacroStep],index:Int,usage:UInt32,token:UUID,pid:pid_t?,request:UUID){
        guard lifetime.matches(request),macros[usage]==token else{return}
        guard index<min(steps.count,100) else{macros.removeValue(forKey:usage);return}
        guard foregroundPID()==pid else{macros.removeValue(forKey:usage);report("Macro stopped because the active app changed.");return}
        let step=steps[index],delay:Double
        switch step.kind {
        case .shortcut:tap(step.chord);delay=0.025
        case .text:text(step.text);delay=0.025
        case .delay:delay=Double(max(0,min(60000,step.milliseconds)))/1000
        }
        queue.asyncAfter(deadline:.now()+delay){[weak self] in self?.runMacro(steps,index:index+1,usage:usage,token:token,pid:pid,request:request)}
    }
    private func releaseButton(_ usage:UInt32){
        watchdogs.removeValue(forKey:usage)?.cancel()
        if let owner=held.removeValue(forKey:usage){release(owner)}
    }
    private func clear(){
        macros.removeAll();watchdogs.values.forEach{$0.cancel()};watchdogs.removeAll();held.removeAll()
        for key in ownership.releaseAll(){post(key,down:false)}
    }
}
