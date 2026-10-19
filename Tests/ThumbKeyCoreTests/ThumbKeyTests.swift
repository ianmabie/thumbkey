import XCTest
@testable import ThumbKeyCore

final class ThumbKeyTests:XCTestCase {
    func testNewSelectionAndPauseInvalidatePendingHardwareWork(){
        let requests=RequestGeneration()
        let naga=requests.next(),logitech=requests.next()
        XCTAssertFalse(requests.matches(naga))
        XCTAssertTrue(requests.matches(logitech))
        let paused=requests.next()
        XCTAssertFalse(requests.matches(logitech))
        XCTAssertTrue(requests.matches(paused))
        // A completion for an earlier mouse must stay invalid even after switching back.
        _=requests.next()
        XCTAssertFalse(requests.matches(naga))
        XCTAssertFalse(requests.matches(paused))
    }
    func testSecureInputWaitsWithoutExhaustingRetriesAndResumesUserIntent(){
        var recovery=MappingRecovery(requested:true)
        recovery.setSecureInput(true)
        for _ in 0..<10{XCTAssertNil(recovery.nextDelay())}
        XCTAssertTrue(recovery.requested)
        recovery.sleep();recovery.wake()
        XCTAssertNil(recovery.nextDelay())
        recovery.setSecureInput(false)
        XCTAssertEqual(recovery.nextDelay(),0.5)
        recovery.setSecureInput(true);recovery.pause();recovery.setSecureInput(false)
        XCTAssertNil(recovery.nextDelay())
        XCTAssertFalse(recovery.requested)
    }
    func testPhysicalPlateLayoutsKeepEveryMappingInItsPhotographedPosition() {
        XCTAssertEqual(SidePlate.twelve.visualRows, [[3,6,9,12],[2,5,8,11],[1,4,7,10]])
        XCTAssertEqual(SidePlate.six.visualRows, [[101,102,103],[106,105,104]])
        XCTAssertEqual(SidePlate.two.visualRows, [[202,201]])
        for plate in SidePlate.allCases {
            let ids=plate.visualRows.flatMap{$0}
            XCTAssertEqual(ids.count,plate.rawValue)
            XCTAssertEqual(Set(ids),Set(plate.buttonIDs))
        }
    }

    func testRecoverySurvivesSleepAndReconnectButHonorsManualPause() {
        var recovery=MappingRecovery()
        XCTAssertNil(recovery.nextDelay())
        recovery.enable()
        XCTAssertEqual(recovery.nextDelay(),0.5)
        recovery.sleep()
        XCTAssertTrue(recovery.requested)
        XCTAssertNil(recovery.nextDelay())
        recovery.wake()
        XCTAssertEqual(recovery.nextDelay(),0.5)
        recovery.pause()
        recovery.resetAttempts()
        XCTAssertNil(recovery.nextDelay())
        XCTAssertFalse(recovery.requested)
    }
    func testRecoveryRetriesAreBoundedAndLaunchRestoresOnlyExplicitIntent() {
        var recovery=MappingRecovery(requested:true)
        XCTAssertEqual(recovery.nextDelay(),0.5)
        XCTAssertEqual(recovery.nextDelay(),1)
        XCTAssertEqual(recovery.nextDelay(),2)
        XCTAssertNil(recovery.nextDelay())
        recovery.resetAttempts()
        XCTAssertEqual(recovery.nextDelay(),0.5)
        recovery.pause() // Also used when permission is revoked.
        recovery.wake()
        XCTAssertNil(recovery.nextDelay())
    }
    func bytes(_ hex:String)->[UInt8]{stride(from:0,to:hex.count,by:2).map{i in let a=hex.index(hex.startIndex,offsetBy:i);let b=hex.index(a,offsetBy:2);return UInt8(hex[a..<b],radix:16)!}}
    let boot="05010906a101050719e029e715002501750195088102810119002aff00150026ff007508950681000508190129031500250175019503910295059101c0"
    let extended="05010906a1018501050719e029e71500250175019508810219002aff00150026ff007508950e8100c0050c0901a101850219002a3c021500263c029501751081007508950d8101c005010980a10185031981298315002501750195038102950581017508950e8101c005010900a10185040903150026ff00350046ff007508950f8100c005010900a10185050903150026ff00350046ff007508950f8100c0"
    func testFactoryTwelveInputsAreDistinct()throws{
        let config=try Configuration().validated();let buttons=config.profiles[0].buttons.filter{SidePlate.twelve.buttonIDs.contains($0.id)}
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
        XCTAssertTrue(DevicePolicy.accepts(vendor:0x1532,name:"Razer Naga V3 Pro",keyboard:false,mouse:true,builtIn:false))
        XCTAssertFalse(DevicePolicy.accepts(vendor:1452,name:"Magic Mouse",keyboard:false,mouse:true,builtIn:false))
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

final class ExtraControlTests:XCTestCase {
    private func decode(_ hex:String)->[UInt8]{stride(from:0,to:hex.count,by:2).map{i in let a=hex.index(hex.startIndex,offsetBy:i);return UInt8(hex[a..<hex.index(a,offsetBy:2)],radix:16)!}}
    func testLegacyMigrationPreservesEveryProfileAndBinding()throws {
        var legacy=Configuration();legacy.version=1
        legacy.profiles[0].buttons=Array(legacy.profiles[0].buttons.prefix(12))
        legacy.profiles[0].buttons[0].name="My dictation"
        legacy.profiles[0].buttons[0].mode = .hold
        legacy.profiles[0].buttons[0].chord=Chord(keyCode:49,modifiers:[.control,.option],keyLabel:"Space")
        var app=legacy.profiles[0];app.id=UUID();app.bundleID="example.Editor";app.name="Editor"
        app.buttons[1].mode = .disabled;legacy.profiles.append(app)
        let migrated=try legacy.validated()
        XCTAssertEqual(migrated.version,3)
        for index in legacy.profiles.indices {
            XCTAssertEqual(Array(migrated.profiles[index].buttons.prefix(12)),legacy.profiles[index].buttons)
            XCTAssertEqual(migrated.profiles[index].id,legacy.profiles[index].id)
            XCTAssertEqual(migrated.profiles[index].buttons.count,30)
        }
        XCTAssertEqual(try JSONDecoder().decode(Configuration.self,from:JSONEncoder().encode(migrated)).validated(),migrated)
    }
    func testPlateRoutingAndIdentificationKeepOtherBanksIntact()throws {
        var config=Configuration();var app=Profile();app.name="Editor";app.bundleID="example.Editor";config.profiles.append(app)
        config.profiles[0].buttons[0].name="Twelve only"
        let original=config
        config=try config.identifying(button:101,usage:31,plate:.six)
        for index in config.profiles.indices {
            let p=config.profiles[index]
            XCTAssertEqual(p.buttons.first{$0.id==101}?.usage,31)
            XCTAssertEqual(p.buttons.first{$0.id==102}?.usage,30)
            XCTAssertEqual(p.buttons.filter{SidePlate.twelve.buttonIDs.contains($0.id)},original.profiles[index].buttons.filter{SidePlate.twelve.buttonIDs.contains($0.id)})
            for plate in SidePlate.allCases {
                let route=p.buttons(for:plate)
                XCTAssertEqual(route.count,plate.rawValue+5)
                XCTAssertEqual(Set(route.compactMap(\.usage)).count,route.compactMap(\.usage).count)
            }
        }
        // An extra button may not steal an active plate's source; reject atomically.
        XCTAssertThrowsError(try config.identifying(button:17,usage:30,plate:.six))
        XCTAssertThrowsError(try config.identifying(button:1,usage:40,plate:.six))
    }
    func testDedicatedButtonReportDoesNotCollideWithKeyboardNumbers() {
        let body:[UInt8]=[0x20,0x59]+Array(repeating:0,count:13)
        XCTAssertEqual(NagaProtocol.buttons(reportID:4,bytes:body),[InputSource.vendor(0x20),InputSource.vendor(0x59)])
        XCTAssertEqual(NagaProtocol.buttons(reportID:4,bytes:[4]+body),[InputSource.vendor(0x20),InputSource.vendor(0x59)])
        XCTAssertEqual(NagaProtocol.buttons(reportID:4,bytes:Array(repeating:0,count:15)),[])
        XCTAssertNil(NagaProtocol.buttons(reportID:5,bytes:body))
        XCTAssertNil(NagaProtocol.buttons(reportID:4,bytes:[0x20]))
        XCTAssertNotEqual(InputSource.vendor(0x20),UInt32(0x20))
        XCTAssertNil(InputSource.eventCode(InputSource.vendor(0x20)))
    }
    func testModeProtocolChecksRepliesAndLimitsWrites() {
        let query=NagaProtocol.modeRequest();XCTAssertEqual(query.count,90);XCTAssertEqual(query[7],0x84)
        for mode:UInt8 in [0,3] {
            var reply=NagaProtocol.modeRequest(set:mode);XCTAssertEqual(reply[7],4);XCTAssertEqual(reply[8],mode)
            reply[0]=2
            XCTAssertEqual(NagaProtocol.modeResponse(reply,command:4),mode)
            XCTAssertNil(NagaProtocol.modeResponse(reply,command:0x84))
            reply[8] ^= 1;XCTAssertNil(NagaProtocol.modeResponse(reply,command:4))
        }
        XCTAssertNil(NagaProtocol.modeResponse(Array(query.dropLast()),command:0x84))
    }
    func testActualMouseDescriptorSeparatesPrimaryClicksFromSideButtons() {
        let hex="05010902a1010901a100050919012905150025017501950581027501950b8103050c0a38021581257f750895018106050109381581257f7508950181060930093116018026ff7f751095028106c0c0"
        let layout=KeyboardReportLayout(descriptor:decode(hex),usagePage:9)
        XCTAssertTrue(layout.isSupported)
        XCTAssertEqual(layout.decode(reportID:0,bytes:[0x19,0,0,0,0,0,0,0]),[1,4,5])
        var correlation=InputCorrelation()
        correlation.record(.init(usage:InputSource.mouse(4),down:true,timestamp:1_000_000,naga:true,device:1))
        XCTAssertEqual(correlation.consume(keyCode:0x103,down:true,timestamp:1_000_000),.naga(InputSource.mouse(4)))
        XCTAssertFalse(InputSource.valid(InputSource.mouse(1)))
        XCTAssertTrue(KeyboardReportLayout(descriptor:decode("05010906a1018501050719e029e71500250175019508810219002aff00150026ff007508950e8100c005010900a10185040903150026ff00350046ff007508950f8100c0")).hasRazerButtonReport)
    }
    func testRightCommandHasDistinctPressAndReleaseFlags() {
        XCTAssertEqual(Chord.rightCommand.keys,[54]);XCTAssertEqual(Chord.rightCommand.label,"Right Command")
        let right=ModifierKey.flags(physical:0,pressed:[54])
        XCTAssertEqual(right,(1<<20)|16)
        XCTAssertEqual(right&8,0)
        XCTAssertEqual(ModifierKey.flags(physical:0,pressed:[]),0)
        XCTAssertEqual(ModifierKey.flags(physical:(1<<17)|2,pressed:[54]),right|(1<<17)|2)
        XCTAssertEqual(Chord(keyCode:55,modifiers:.command).keys,[55])
    }
}

final class LogitechTests:XCTestCase {
    func testVersionTwoMigrationKeepsNagaAndAddsSeparateMXBank()throws {
        var old=Configuration();old.version=2
        old.profiles[0].buttons.removeAll{MouseControls.mxIDs.contains($0.id)}
        old.profiles[0].buttons[0].name="Existing dictation"
        let previous=old.profiles[0].buttons
        let next=try old.validated()
        XCTAssertEqual(next.version,3)
        XCTAssertEqual(next.profiles[0].buttons.filter{MouseControls.nagaIDs.contains($0.id)},previous)
        let mx=next.profiles[0].buttons(for:.mxMaster3s,plate:.twelve)
        XCTAssertEqual(mx.map(\.id),Array(301...305))
        XCTAssertEqual(mx.compactMap(\.usage),[0x53,0x56,0x52,0xc3,0xc4].map{InputSource.logitech(UInt16($0))})
        XCTAssertTrue(mx.compactMap(\.usage).allSatisfy{InputSource.eventCode($0)==nil})
    }
    func testHIDPPRequestsChangeOnlyTemporaryDiversion() {
        let packet=LogitechProtocol.request(device:2,feature:9,function:3,payload:LogitechProtocol.diversion(0xc3,enabled:true))
        XCTAssertEqual(packet.count,20)
        XCTAssertEqual(Array(packet.prefix(9)),[17,2,9,0x3c,0,0xc3,3,0,0])
        XCTAssertEqual(LogitechProtocol.diversion(0xc3,enabled:false),[0,0xc3,2,0,0])
        XCTAssertEqual(LogitechProtocol.normalize(reportID:17,bytes:Array(packet.dropFirst())),packet)
        XCTAssertNil(LogitechProtocol.normalize(reportID:17,bytes:[17,2,9]))
    }
    func testButtonReportsCannotCrossReceiverSlotsOrFeatures() {
        var packet=[UInt8](repeating:0,count:20);packet[0]=17;packet[1]=2;packet[2]=9;packet[5]=0x53;packet[7]=0xc3
        XCTAssertEqual(LogitechProtocol.pressed(packet,device:2,feature:9),[0x53,0xc3])
        XCTAssertNil(LogitechProtocol.pressed(packet,device:1,feature:9))
        XCTAssertNil(LogitechProtocol.pressed(packet,device:2,feature:8))
        packet[3]=0x0c;XCTAssertNil(LogitechProtocol.pressed(packet,device:2,feature:9))
        packet[3]=0;packet[5]=0;packet[7]=0;XCTAssertEqual(LogitechProtocol.pressed(packet,device:2,feature:9),[])
    }
    func testBatteryAndConnectionUseObservedTransportAndValidatedValues() {
        XCTAssertEqual(MouseConnection.resolve(vendor:0x46d,product:0xc548,transport:"USB"),.wireless)
        XCTAssertEqual(MouseConnection.resolve(vendor:0x46d,product:0xb034,transport:"Bluetooth Low Energy"),.bluetooth)
        XCTAssertEqual(MouseConnection.resolve(vendor:0x1532,product:0x00e7,transport:"USB"),.wired)
        XCTAssertEqual(MouseConnection.resolve(vendor:0x1532,product:0x00e8,transport:"USB"),.wireless)
        XCTAssertEqual(MousePower.logitech([87,4,0,0]).percent,87)
        XCTAssertEqual(MousePower.logitech([87,4,1,0]).charging,true)
        XCTAssertNil(MousePower.logitech([0,4,0,0]).percent)
        XCTAssertNil(MousePower.logitech([150,4,0,0]).percent)
        XCTAssertEqual(MousePower.logitech([]).label,"Battery unavailable")
    }
}
