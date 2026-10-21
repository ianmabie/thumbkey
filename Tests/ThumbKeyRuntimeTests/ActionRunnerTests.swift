import XCTest
import AppKit
@testable import ThumbKey
import ThumbKeyCore

final class ActionRunnerTests:XCTestCase {
    struct Key:Equatable{let code:UInt16,down:Bool,location:UInt32,flags:UInt64}
    final class Recorder {
        let lock=NSLock()
        private var captured=[Key]()
        func add(_ code:UInt16,_ down:Bool,_ location:CGEventTapLocation,_ flags:CGEventFlags){lock.lock();captured.append(Key(code:code,down:down,location:location.rawValue,flags:flags.rawValue));lock.unlock()}
        var keys:[Key]{lock.lock();defer{lock.unlock()};return captured}
    }
    func binding(_ id:Int,_ mode:ActionMode,_ chord:Chord=Chord())->ButtonBinding{
        var binding=ButtonBinding(id:id,usage:UInt32(id+29));binding.mode=mode;binding.chord=chord;return binding
    }
    func testFigmaCommentTapsCOnPressWithoutHoldingOrSendingOldCustomKeys(){
        let output=Recorder(),runner=ActionRunner(keyOutput:{output.add($0,$1,$2,$3)},physicalFlags:{0},foregroundPID:{1})
        let comment=binding(5,.figmaComment,Chord(keyCode:2,modifiers:.control,keyLabel:"D"))
        runner.setPhysicalEnabled(true)
        runner.physicalInput(34,down:true,binding:comment);runner.finishStopping()
        XCTAssertEqual(output.keys.map(\.code),[8,8])
        XCTAssertEqual(output.keys.map(\.down),[true,false])
        runner.physicalInput(34,down:false,binding:nil);runner.finishStopping()
        XCTAssertEqual(output.keys.count,2)
        runner.physicalInput(34,down:true,binding:comment)
        runner.physicalInput(34,down:false,binding:nil);runner.finishStopping()
        XCTAssertEqual(output.keys.map(\.down),[true,false,true,false])
        XCTAssertTrue(output.keys.allSatisfy{$0.code==8 && $0.flags==0 && $0.location==CGEventTapLocation.cgSessionEventTap.rawValue})
    }
    func testFigmaZoomStepsTapCommandKeysAndScrollZoomReleasesItsModifier(){
        let output=Recorder(),runner=ActionRunner(keyOutput:{output.add($0,$1,$2,$3)},physicalFlags:{0},foregroundPID:{1})
        runner.setPhysicalEnabled(true)
        let stale=Chord(keyCode:2,modifiers:.control,keyLabel:"D")
        for (usage,mode):(UInt32,ActionMode) in [(35,.figmaZoomIn),(36,.figmaZoomOut)]{
            runner.physicalInput(usage,down:true,binding:binding(6,mode,stale))
            runner.physicalInput(usage,down:false,binding:nil)
        }
        runner.finishStopping()
        XCTAssertEqual(output.keys.map(\.code),[55,24,24,55,55,27,27,55])
        XCTAssertEqual(output.keys.map(\.down),[true,true,false,false,true,true,false,false])
        for key in output.keys where key.code != 55{XCTAssertTrue(CGEventFlags(rawValue:key.flags).contains(.maskCommand))}
        let scroll=binding(8,.figmaZoomScroll,stale)
        runner.physicalInput(37,down:true,binding:scroll);runner.finishStopping()
        XCTAssertEqual(output.keys.count,9);XCTAssertEqual(output.keys.last?.code,55);XCTAssertEqual(output.keys.last?.down,true)
        runner.physicalInput(37,down:false,binding:nil);runner.finishStopping()
        XCTAssertEqual(output.keys.last?.down,false)
        runner.physicalInput(37,down:true,binding:scroll);runner.finishStopping()
        runner.setPhysicalEnabled(false);runner.finishStopping()
        XCTAssertEqual(output.keys.suffix(4).map(\.code),[55,55,55,55])
        XCTAssertEqual(output.keys.suffix(4).map(\.down),[true,false,true,false])
        XCTAssertEqual(output.keys.last?.flags,0)
    }
    func testFigmaPanPressReleaseOrderingMovementAndPauseCleanup()throws{
        let lock=NSLock();var sequence=[String]()
        func append(_ value:String){lock.lock();sequence.append(value);lock.unlock()}
        func events()->[String]{lock.lock();defer{lock.unlock()};return sequence}
        let point=CGPoint(x:120,y:240)
        let runner=ActionRunner(keyOutput:{code,down,_,_ in append("key \(code) \(down)")},
            mouseOutput:{down,location,flags in
                XCTAssertEqual(location,point);XCTAssertEqual(flags.rawValue,0);append("mouse \(down)")
            },pointerLocation:{point},physicalFlags:{0},foregroundPID:{1})
        let pan=binding(4,.figmaPan,Chord(keyCode:2,modifiers:.control,keyLabel:"D"))
        runner.setPhysicalEnabled(true)
        runner.physicalInput(33,down:true,binding:pan);runner.finishStopping()
        XCTAssertEqual(events(),["key 49 true","mouse true"])
        runner.physicalInput(33,down:true,binding:pan);runner.finishStopping()
        XCTAssertEqual(events().count,2)
        let motion=try XCTUnwrap(CGEvent(mouseEventSource:nil,mouseType:.mouseMoved,mouseCursorPosition:point,mouseButton:.left))
        motion.setIntegerValueField(.mouseEventDeltaX,value:12);motion.setIntegerValueField(.mouseEventDeltaY,value:-7)
        runner.routePointerMotion(motion)
        XCTAssertEqual(motion.type,.leftMouseDragged);XCTAssertEqual(motion.location,point)
        XCTAssertEqual(motion.getIntegerValueField(.mouseEventButtonNumber),0)
        XCTAssertEqual(motion.getIntegerValueField(.mouseEventDeltaX),12);XCTAssertEqual(motion.getIntegerValueField(.mouseEventDeltaY),-7)
        runner.physicalInput(33,down:false,binding:nil);runner.finishStopping()
        XCTAssertEqual(events(),["key 49 true","mouse true","mouse false","key 49 false"])
        motion.type = .mouseMoved;runner.routePointerMotion(motion);XCTAssertEqual(motion.type,.mouseMoved)
        runner.physicalInput(33,down:true,binding:pan);runner.finishStopping()
        runner.setPhysicalEnabled(false);runner.finishStopping()
        XCTAssertEqual(Array(events().suffix(4)),["key 49 true","mouse true","mouse false","key 49 false"])
        runner.cancelAll();runner.finishStopping();XCTAssertEqual(events().count,8)
    }
    func testFigmaPanSharedOwnersRapidPressesAndAppSwitchDoNotReleaseOtherHolds()throws{
        let output=Recorder(),lock=NSLock();var mouse=[Bool]()
        let runner=ActionRunner(keyOutput:{output.add($0,$1,$2,$3)},mouseOutput:{down,_,_ in
            lock.lock();mouse.append(down);lock.unlock()
        },pointerLocation:{.zero},physicalFlags:{0},foregroundPID:{1})
        func clicks()->[Bool]{lock.lock();defer{lock.unlock()};return mouse}
        let pan=binding(4,.figmaPan)
        runner.setPhysicalEnabled(true)
        runner.physicalInput(30,down:true,binding:binding(1,.hold,Chord(keyCode:2,modifiers:.control,keyLabel:"D")))
        runner.physicalInput(33,down:true,binding:pan);runner.physicalInput(34,down:true,binding:pan)
        runner.physicalInput(33,down:false,binding:nil);runner.finishStopping()
        XCTAssertEqual(clicks(),[true])
        runner.cancelCanvasDrag();runner.finishStopping()
        XCTAssertEqual(clicks(),[true,false]);XCTAssertEqual(output.keys.last?.code,49);XCTAssertEqual(output.keys.last?.down,false)
        XCTAssertEqual(output.keys.filter{[59,2].contains($0.code)}.map(\.down),[true,true])
        runner.physicalInput(34,down:false,binding:nil);runner.finishStopping();XCTAssertEqual(clicks(),[true,false])
        for _ in 0..<100 {
            runner.physicalInput(33,down:true,binding:pan);runner.physicalInput(33,down:false,binding:nil)
        }
        runner.finishStopping()
        runner.physicalInput(33,down:true,binding:pan);runner.finishStopping()
        runner.cancelAll();runner.finishStopping()
        let clicks=clicks();XCTAssertEqual(clicks.count,204)
        XCTAssertTrue(stride(from:0,to:clicks.count,by:2).allSatisfy{clicks[$0] && !clicks[$0+1]})
        XCTAssertEqual(output.keys.filter{[2,59].contains($0.code)}.map(\.down),[true,true,false,false])
        let motion=try XCTUnwrap(CGEvent(mouseEventSource:nil,mouseType:.otherMouseDragged,mouseCursorPosition:.zero,mouseButton:.center))
        runner.routePointerMotion(motion);XCTAssertEqual(motion.type,.otherMouseDragged)
    }
    func testCompleteMacroDeliversShortcutThenTextInOrder() {
        let done=expectation(description:"text after shortcut"),output=Recorder()
        let runner=ActionRunner(keyOutput:{output.add($0,$1,$2,$3)},textOutput:{value in
            XCTAssertEqual(value,"after keys");done.fulfill()
        },physicalFlags:{0},foregroundPID:{1})
        var macro=binding(4,.macro),key=MacroStep(),text=MacroStep(kind:.text)
        key.chord=Chord(keyCode:8,modifiers:.command,keyLabel:"C");text.text="after keys"
        macro.steps=[key,text];runner.down(33,binding:macro)
        wait(for:[done],timeout:2);runner.cancelAll();runner.finishStopping()
        XCTAssertEqual(output.keys.map(\.code),[55,8,8,55])
        XCTAssertEqual(output.keys.map(\.down),[true,true,false,false])
    }
    func testMacroStopsWhenForegroundAppChanges() {
        let first=expectation(description:"first macro step"),settled=expectation(description:"focus change settles")
        let lock=NSLock();var pid:pid_t=1,text=[String]()
        let runner=ActionRunner(keyOutput:{_,_,_,_ in},textOutput:{value in
            lock.lock();text.append(value);pid=2;lock.unlock();first.fulfill()
        },physicalFlags:{0},foregroundPID:{lock.lock();defer{lock.unlock()};return pid})
        var macro=binding(4,.macro),a=MacroStep(kind:.text),b=MacroStep(kind:.text)
        a.text="first";b.text="must not run";macro.steps=[a,b]
        runner.down(33,binding:macro);wait(for:[first],timeout:2)
        DispatchQueue.global().asyncAfter(deadline:.now()+0.1){settled.fulfill()}
        wait(for:[settled],timeout:2);runner.finishStopping()
        lock.lock();let actual=text;lock.unlock();XCTAssertEqual(actual,["first"])
    }
    func testCancelledOverlayCannotOpenLaterOnMainQueue() {
        let unexpected=expectation(description:"cancelled overlay");unexpected.isInverted=true
        let runner=ActionRunner(keyOutput:{_,_,_,_ in},physicalFlags:{0},foregroundPID:{1})
        runner.showShortcuts={unexpected.fulfill()}
        let sequence={
            runner.down(39,binding:self.binding(10,.showShortcuts));runner.finishStopping()
            runner.cancelAll();runner.finishStopping()
        }
        if Thread.isMainThread{sequence()}else{DispatchQueue.main.sync(execute:sequence)}
        wait(for:[unexpected],timeout:0.05)
    }
    func testRapidActionsPostWithoutServicingTheMainRunLoopAndKeepSharedModifiers(){
        let output=Recorder(),runner=ActionRunner(keyOutput:{output.add($0,$1,$2,$3)},physicalFlags:{0},foregroundPID:{1})
        runner.setPhysicalEnabled(true)
        runner.physicalInput(30,down:true,binding:binding(1,.hold,Chord(keyCode:2,modifiers:.control,keyLabel:"D")))
        for _ in 0..<100 {
            runner.physicalInput(31,down:true,binding:binding(2,.missionControl));runner.physicalInput(31,down:false,binding:nil)
            runner.physicalInput(32,down:true,binding:binding(3,.appExpose));runner.physicalInput(32,down:false,binding:nil)
        }
        runner.physicalInput(30,down:false,binding:nil)
        runner.finishStopping()
        let keys=output.keys
        XCTAssertEqual(keys.count,404)
        XCTAssertEqual(keys.filter{$0.code==59 && $0.down}.count,1)
        XCTAssertEqual(keys.filter{$0.code==59 && !$0.down}.count,1)
        XCTAssertEqual(keys.filter{$0.code==126 && $0.down}.count,100)
        XCTAssertEqual(keys.filter{$0.code==125 && $0.down}.count,100)
        for key in keys where [125,126].contains(key.code){
            XCTAssertEqual(key.location,CGEventTapLocation.cghidEventTap.rawValue)
            XCTAssertTrue(CGEventFlags(rawValue:key.flags).contains([.maskControl,.maskSecondaryFn,.maskNumericPad]))
        }
        var held=Set<UInt16>();for key in keys{if key.down{held.insert(key.code)}else{held.remove(key.code)}}
        XCTAssertTrue(held.isEmpty)
    }
    func testCancelInvalidatesQueuedActionsAndReleasesAnAlreadyPostedHold(){
        let output=Recorder(),entered=DispatchSemaphore(value:0),resume=DispatchSemaphore(value:0)
        let runner=ActionRunner(keyOutput:{code,down,location,flags in
            output.add(code,down,location,flags)
            if code==2 && down{entered.signal();_ = resume.wait(timeout:.now()+3)}
        },physicalFlags:{0},foregroundPID:{1})
        runner.setPhysicalEnabled(true)
        runner.physicalInput(30,down:true,binding:binding(1,.hold,Chord(keyCode:2,modifiers:.control,keyLabel:"D")))
        XCTAssertEqual(entered.wait(timeout:.now()+3),.success)
        for _ in 0..<50{runner.physicalInput(31,down:true,binding:binding(2,.missionControl))}
        runner.cancelAll();resume.signal();runner.finishStopping()
        XCTAssertEqual(output.keys.map(\.code),[59,2,2,59])
        XCTAssertEqual(output.keys.map(\.down),[true,true,false,false])
    }
    func testDisabledPhysicalInputDoesNotBlockExplicitShortcutTests(){
        let output=Recorder(),runner=ActionRunner(keyOutput:{output.add($0,$1,$2,$3)},physicalFlags:{0},foregroundPID:{1})
        runner.physicalInput(31,down:true,binding:binding(2,.missionControl));runner.finishStopping()
        XCTAssertTrue(output.keys.isEmpty)
        runner.down(31,binding:binding(2,.missionControl));runner.finishStopping()
        XCTAssertEqual(output.keys.map(\.code),[59,126,126,59])
    }
    func testMacroSequenceAndCancellationRespectQueuedDelays(){
        let first=expectation(description:"first text"),end=expectation(description:"macro cancellation settles")
        let lock=NSLock();var text=[String]()
        let runner=ActionRunner(keyOutput:{_,_,_,_ in},textOutput:{value in
            lock.lock();text.append(value);lock.unlock();if value=="first"{first.fulfill()}
        },physicalFlags:{0},foregroundPID:{1})
        var macro=binding(4,.macro),step=MacroStep(kind:.text),delay=MacroStep(kind:.delay)
        step.text="first";delay.milliseconds=100
        var second=MacroStep(kind:.text);second.text="second"
        macro.steps=[step,delay,second]
        runner.down(33,binding:macro)
        wait(for:[first],timeout:2)
        runner.cancelAll();runner.finishStopping()
        DispatchQueue.global().asyncAfter(deadline:.now()+0.2){end.fulfill()}
        wait(for:[end],timeout:2)
        lock.lock();let actual=text;lock.unlock();XCTAssertEqual(actual,["first"])
    }
}
