import XCTest
@testable import ThumbKeyCore

final class ThumbKeyTests:XCTestCase {
    func bytes(_ hex:String)->[UInt8]{stride(from:0,to:hex.count,by:2).map{i in let a=hex.index(hex.startIndex,offsetBy:i);let b=hex.index(a,offsetBy:2);return UInt8(hex[a..<b],radix:16)!}}
    let boot="05010906a101050719e029e715002501750195088102810119002aff00150026ff007508950681000508190129031500250175019503910295059101c0"
    let extended="05010906a1018501050719e029e71500250175019508810219002aff00150026ff007508950e8100c0050c0901a101850219002a3c021500263c029501751081007508950d8101c005010980a10185031981298315002501750195038102950581017508950e8101c005010900a10185040903150026ff00350046ff007508950f8100c005010900a10185050903150026ff00350046ff007508950f8100c0"
    func testFactoryTwelveInputsAreDistinct()throws{
        let config=try Configuration().validated();let buttons=config.profiles[0].buttons
        XCTAssertEqual(buttons.compactMap(\.usage),Array(30...39)+[45,46])
        XCTAssertEqual(Set(buttons.compactMap(\.usage)).count,12)
    }
    func testActualNagaBootDescriptorPressChordAndRelease(){
        let layout=KeyboardReportLayout(descriptor:bytes(boot));XCTAssertTrue(layout.isSupported)
        XCTAssertEqual(layout.decode(reportID:0,bytes:[3,0,30,45,0,0,0,0]),Set([224,225,30,45]))
        XCTAssertEqual(layout.decode(reportID:0,bytes:Array(repeating:0,count:8)),Set())
        XCTAssertNil(layout.decode(reportID:0,bytes:[0,0,1,1,1,1,1,1]))
        XCTAssertNil(layout.decode(reportID:0,bytes:[0,0,30]))
    }
    func testActualNagaExtendedDescriptorWithAndWithoutPrefix(){
        let layout=KeyboardReportLayout(descriptor:bytes(extended))
        let body:[UInt8]=[4,30,31,46]+Array(repeating:0,count:11)
        XCTAssertEqual(layout.decode(reportID:1,bytes:body),Set([226,30,31,46]))
        XCTAssertEqual(layout.decode(reportID:1,bytes:[1]+body),Set([226,30,31,46]))
        XCTAssertNil(layout.decode(reportID:2,bytes:Array(repeating:0,count:16)))
        XCTAssertEqual(layout.decode(reportID:1,bytes:[1]+Array(repeating:0,count:15)),Set())
    }
    func testSharedModifiersReleaseOnlyAfterFinalOwner(){
        var owner=KeyOwnership();let a=UUID(),b=UUID()
        XCTAssertEqual(owner.press([55,8],owner:a),[55,8])
        XCTAssertEqual(owner.press([55,9],owner:b),[9])
        XCTAssertEqual(owner.release(owner:a),[8]);XCTAssertEqual(owner.heldKeys,Set([55,9]))
        XCTAssertEqual(owner.release(owner:b),[9,55]);XCTAssertTrue(owner.heldKeys.isEmpty)
        XCTAssertEqual(owner.release(owner:b),[])
    }
    func testPanicReleaseIncludesAllKeysOnce(){
        var owner=KeyOwnership();let a=UUID(),b=UUID()
        _=owner.press([59,58,49],owner:a);_=owner.press([59,8],owner:b)
        let released=owner.releaseAll();XCTAssertEqual(Set(released),Set([59,58,49,8]));XCTAssertEqual(released.count,4);XCTAssertTrue(owner.heldKeys.isEmpty)
        XCTAssertEqual(owner.release(owner:a),[])
    }
    func testDeviceIsolation(){
        XCTAssertTrue(DevicePolicy.accepts(vendor:0x1532,name:"Razer Naga V3 Pro",keyboard:true,mouse:false,builtIn:false))
        XCTAssertFalse(DevicePolicy.accepts(vendor:1452,name:"Magic Keyboard",keyboard:true,mouse:false,builtIn:false))
        XCTAssertFalse(DevicePolicy.accepts(vendor:0x1532,name:"Razer BlackWidow",keyboard:true,mouse:false,builtIn:false))
        XCTAssertFalse(DevicePolicy.accepts(vendor:0x1532,name:"Razer Naga V3 Pro",keyboard:true,mouse:true,builtIn:false))
    }
    func testProfileRoutingAndMacroRoundTrip()throws{
        var config=Configuration();var figma=Profile();figma.name="Figma";figma.bundleID="com.figma.Desktop"
        figma.buttons[0].mode = .hold;figma.buttons[0].chord=Chord(modifiers:.command)
        var text=MacroStep(kind:.text);text.text="Hello 👋";var delay=MacroStep(kind:.delay);delay.milliseconds=500
        figma.buttons[1].mode = .macro;figma.buttons[1].steps=[text,delay];config.profiles.append(figma)
        let copy=try JSONDecoder().decode(Configuration.self,from:JSONEncoder().encode(config)).validated()
        XCTAssertEqual(copy,config);XCTAssertEqual(copy.profile(for:"com.figma.Desktop").id,figma.id);XCTAssertEqual(copy.profile(for:"anything").id,config.profiles[0].id)
    }
    func testMalformedImportsAreRejected(){
        var c=Configuration();c.profiles[0].buttons[1].usage=c.profiles[0].buttons[0].usage;XCTAssertThrowsError(try c.validated())
        c=Configuration();c.profiles[0].buttons.removeLast();XCTAssertThrowsError(try c.validated())
        c=Configuration();var s=MacroStep(kind:.delay);s.milliseconds = -1;c.profiles[0].buttons[0].steps=[s];XCTAssertThrowsError(try c.validated())
        c=Configuration();s.milliseconds=60000;c.profiles[0].buttons[0].steps=Array(repeating:s,count:6);XCTAssertThrowsError(try c.validated())
        c=Configuration();c.profiles[0].buttons[0].chord=Chord(keyCode:900);XCTAssertThrowsError(try c.validated())
    }
}

final class CorrelationTests:XCTestCase {
    func testNagaEvidenceIsConsumedOnce(){
        var c=InputCorrelation();c.record(.init(usage:30,down:true,timestamp:1_000_000_000,naga:true,device:1))
        XCTAssertEqual(c.consume(keyCode:18,down:true,timestamp:1_000_010_000),.naga(30))
        XCTAssertEqual(c.consume(keyCode:18,down:true,timestamp:1_000_010_000),.missing)
    }
    func testRegularKeyboardAndSyntheticInputsStayNative(){
        var c=InputCorrelation();c.record(.init(usage:30,down:true,timestamp:1_000_000_000,naga:false,device:2))
        XCTAssertEqual(c.consume(keyCode:18,down:true,timestamp:1_000_000_000),.otherKeyboard)
        XCTAssertEqual(c.consume(keyCode:18,down:true,timestamp:1_050_000_000),.missing)
    }
    func testStaleMousePressCannotRemapLaterTyping(){
        var c=InputCorrelation();c.record(.init(usage:30,down:true,timestamp:1_000_000_000,naga:true,device:1))
        XCTAssertEqual(c.consume(keyCode:18,down:true,timestamp:1_100_000_000),.missing)
        XCTAssertEqual(c.consume(keyCode:19,down:true,timestamp:1_000_000_000),.missing)
        XCTAssertEqual(c.consume(keyCode:18,down:false,timestamp:1_000_000_000),.missing)
    }
    func testAmbiguousSimultaneousKeysAreNotIntercepted(){
        var c=InputCorrelation()
        c.record(.init(usage:30,down:true,timestamp:1_000_000_000,naga:true,device:1))
        c.record(.init(usage:30,down:true,timestamp:1_000_020_000,naga:false,device:2))
        XCTAssertEqual(c.consume(keyCode:18,down:true,timestamp:1_000_010_000),.ambiguous)
        XCTAssertEqual(c.consume(keyCode:18,down:true,timestamp:1_000_010_000),.missing)
    }
    func testReleaseAndKeyboardRepeatGuard(){
        var c=InputCorrelation()
        c.record(.init(usage:30,down:true,timestamp:1_000_000_000,naga:true,device:1))
        XCTAssertTrue(c.nagaHeld(keyCode:18));XCTAssertFalse(c.otherHeld(keyCode:18))
        c.record(.init(usage:30,down:true,timestamp:1_010_000_000,naga:false,device:2))
        XCTAssertTrue(c.otherHeld(keyCode:18))
        c.record(.init(usage:30,down:false,timestamp:1_020_000_000,naga:true,device:1))
        XCTAssertFalse(c.nagaHeld(keyCode:18));XCTAssertTrue(c.otherHeld(keyCode:18))
        XCTAssertEqual(c.consume(keyCode:18,down:false,timestamp:1_020_000_000),.naga(30))
        c.reset();XCTAssertFalse(c.otherHeld(keyCode:18))
    }
    func testDuplicateNagaInterfacesDoNotLookLikeAnotherKeyboard(){
        var c=InputCorrelation()
        for d:UInt64 in [1,2]{c.record(.init(usage:30,down:true,timestamp:1_000_000_000,naga:true,device:d))}
        XCTAssertEqual(c.consume(keyCode:18,down:true,timestamp:1_000_000_000),.naga(30))
    }
}

final class DelayedEvidenceTests:XCTestCase {
    func testLaterKeyboardEvidenceInvalidatesAnEarlyMouseMatch(){
        var c=InputCorrelation()
        c.record(.init(usage:30,down:true,timestamp:1_000_000_000,naga:true,device:1))
        XCTAssertEqual(c.peek(keyCode:18,down:true,timestamp:1_000_000_000),.naga(30))
        c.record(.init(usage:30,down:true,timestamp:1_000_100_000,naga:false,device:2))
        XCTAssertEqual(c.consume(keyCode:18,down:true,timestamp:1_000_000_000),.ambiguous)
    }
}
