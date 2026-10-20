import AppKit
import SwiftUI
import IOKit.hid
import UniformTypeIdentifiers
import ThumbKeyCore
import Carbon

final class AppModel: ObservableObject {
    @Published var configuration = Configuration() { didSet { save(); updateRouting() } }
    @Published var selectedProfile = UUID()
    @Published var selectedButton = 1
    @Published private(set) var selectedMouse=MouseFamily(rawValue:UserDefaults.standard.string(forKey:"selectedMouse") ?? "") ?? .naga
    @Published private(set) var battery=MousePower(percent:nil,charging:nil)
    @Published private(set) var connection=MouseConnection.unknown
    @Published private(set) var mouseStatuses=[MouseFamily:MouseStatus]()
    private let hardware=MouseHardware()
    @Published private(set) var connecting=false
    private var checkingExtraButtons=false
    private var lastNagaActivity=Date.distantPast
    private var batteryTimer:Timer?
    @Published private(set) var sidePlate=SidePlate(rawValue:UserDefaults.standard.integer(forKey:"sidePlate")) ?? .twelve
    @Published private(set) var extraButtonsEnabled=UserDefaults.standard.bool(forKey:"extraButtonsEnabled")
    @Published private(set) var extraButtonsActive=false
    @Published private(set) var lastPlateSignal="No plate identity signal received"
    @Published var learning: Int?
    @Published var lastButton: Int?
    @Published var enabled=false
    @Published private(set) var recovery=MappingRecovery(requested:UserDefaults.standard.bool(forKey:"mappingsRequested")) {
        didSet {UserDefaults.standard.set(recovery.requested,forKey:"mappingsRequested")}
    }
    var wantsMappings:Bool {recovery.requested}
    var secureInputBlocked:Bool {recovery.secureInputBlocked}
    var mappingStatus:String {wantsMappings && secureInputBlocked ? "Blocked by Secure Input":enabled ? "Mappings on" : wantsMappings ? (recovery.sleeping ? "Waiting for wake":connecting ? "Connecting mappings…":"Waiting for mouse…") : "Mappings paused"}
    @Published var deviceName="No Naga connected"
    @Published var interfaceCount=0
    @Published var inputAllowed=false
    @Published var accessibilityAllowed=false
    @Published var message=""
    @Published var saveError=""
    let capture=HIDCapture()
    let runner=ActionRunner()
    private let shortcutOverlay=ShortcutOverlayController()
    @Published private(set) var shortcutOverlayVisible=false
    @Published private(set) var activeBundleID:String?
    @Published private(set) var activeAppName=""
    @Published private(set) var testingShortcut=false
    private var shortcutTestRelease:DispatchWorkItem?
    private var permissionTimer:Timer?
    private var observers:[NSObjectProtocol]=[]
    private var learnedTimeout:DispatchWorkItem?
    private var recoveryWork:DispatchWorkItem?
    private var loaded=false
    private let directory=FileManager.default.urls(for:.applicationSupportDirectory,in:.userDomainMask)[0].appendingPathComponent("ThumbKey")
    var file: URL { directory.appendingPathComponent("bindings.json") }
    init() {
        do {
            if FileManager.default.fileExists(atPath:file.path) {
                let data=try Data(contentsOf:file)
                let original=try JSONDecoder().decode(Configuration.self,from:data)
                configuration=try original.validated()
                if original.version != configuration.version {
                    try data.write(to:directory.appendingPathComponent("bindings-before-v2-\(UUID().uuidString).json"),options:.atomic)
                    try JSONEncoder().encode(configuration).write(to:file,options:.atomic)
                }
            }
            else {
                configuration.profiles[0].buttons[0].name="Dictation"
                configuration.profiles[0].buttons[0].mode = .hold
                configuration.profiles[0].buttons[0].chord=Chord(keyCode:49,modifiers:[.control,.option],keyLabel:"Space")
            }
        } catch { saveError="Could not read saved mappings. They have not been overwritten: \(error.localizedDescription)" }
        selectedProfile=configuration.profiles[0].id;selectedButton=selectedMouse == .naga ? sidePlate.buttonIDs[0]:301
        loaded=saveError.isEmpty
        capture.onDevices={ [weak self] devices in self?.updateDevices(devices);self?.refreshMouseStatus() }
        hardware.onInput={ [weak self] usage,down,binding,intercepted in self?.received(usage:usage,down:down,binding:binding,intercepted:intercepted) }
        capture.onInput={ [weak self] usage,down,binding,intercepted in self?.received(usage:usage,down:down,binding:binding,intercepted:intercepted,actionDelivered:true) }
        capture.onActionInput={ [weak runner] usage,down,binding in runner?.physicalInput(usage,down:down,binding:binding) }
        capture.onReset={ [weak runner] in runner?.cancelAll() }
        capture.onDisconnect={ [weak self] reason in self?.interrupted(reason) }
        capture.onError={ [weak self] text in self?.message=text }
        capture.onPlateSignal={ [weak self] signal in self?.lastPlateSignal=signal }
        capture.onActivity={ [weak self] in self?.noteNagaActivity();self?.checkExtraButtonMode() }
        runner.status={ [weak self] text in self?.message=text }
        runner.showShortcuts={ [weak self] in self?.toggleShortcutOverlay() }
        shortcutOverlay.onDismiss={ [weak self] in self?.shortcutOverlayVisible=false }
        refreshActiveApplication()
        updateDevices(capture.deviceList); refreshPermissions();updateRouting()
        observers.append(NSWorkspace.shared.notificationCenter.addObserver(forName:NSWorkspace.didActivateApplicationNotification,object:nil,queue:.main){[weak self] _ in self?.refreshActiveApplication();self?.updateRouting()})
        permissionTimer=Timer.scheduledTimer(withTimeInterval:2,repeats:true){[weak self] _ in self?.refreshPermissions()}
        observers.append(NSWorkspace.shared.notificationCenter.addObserver(forName:NSWorkspace.willSleepNotification,object:nil,queue:.main){[weak self] _ in
            guard let self else{return};self.recovery.sleep();self.stopCapture();self.message=self.wantsMappings ? "Paused for sleep. Mappings will resume after wake.":"Mappings paused. Side buttons send their original keys."
        })
        observers.append(NSWorkspace.shared.notificationCenter.addObserver(forName:NSWorkspace.didWakeNotification,object:nil,queue:.main){[weak self] _ in
            guard let self else{return};self.recovery.wake();self.scheduleRecovery()
        })
        observers.append(NotificationCenter.default.addObserver(forName:NSApplication.willTerminateNotification,object:nil,queue:.main){[weak self] _ in self?.shutdown()})
        batteryTimer=Timer.scheduledTimer(withTimeInterval:60,repeats:true){[weak self] _ in self?.refreshMouseStatus()}
        DispatchQueue.main.async{[weak self] in self?.refreshMouseStatus()}
        if wantsMappings {scheduleRecovery()}
    }
    var profileIndex:Int {configuration.profiles.firstIndex{$0.id==selectedProfile} ?? 0}
    var profile:Profile {configuration.profiles[profileIndex]}
    var button:ButtonBinding {profile.buttons.first{$0.id==selectedButton}!}
    var activeProfile:Profile{configuration.profile(for:activeBundleID)}
    var configuredShortcuts:[ShortcutReference]{ShortcutReference.configured(in:activeProfile,family:selectedMouse,plate:sidePlate)}
    var shortcutContext:String {
        [selectedMouse.name,selectedMouse == .naga ? sidePlate.label:nil,activeProfile.name].compactMap{$0}.joined(separator:" · ")
    }
    private func refreshActiveApplication(){
        let app=NSWorkspace.shared.frontmostApplication
        activeBundleID=app?.bundleIdentifier;activeAppName=app?.localizedName ?? ""
    }
    func shortcutIssue(_ reference:ShortcutReference)->String? {
        if reference.binding.usage==nil{return "Needs identification"}
        if selectedMouse == .naga,MouseControls.extraIDs.contains(reference.id),!extraButtonsActive{return "Extra-button reporting unavailable"}
        return nil
    }
    func toggleShortcutOverlay(){
        if shortcutOverlay.isVisible{shortcutOverlay.dismiss();return}
        refreshActiveApplication()
        shortcutOverlay.show(model:self);shortcutOverlayVisible=shortcutOverlay.isVisible
    }
    func editButton(_ edit:(inout ButtonBinding)->Void) {
        cancelShortcutTest();cancelLearning();runner.cancelAll()
        guard let i=configuration.profiles[profileIndex].buttons.firstIndex(where:{$0.id==selectedButton}) else{return}
        edit(&configuration.profiles[profileIndex].buttons[i])
    }
    func editStep(_ id:UUID,_ edit:(inout MacroStep)->Void) {editButton { b in if let i=b.steps.firstIndex(where:{$0.id==id}){edit(&b.steps[i])} } }
    var sideButtons:[ButtonBinding] {profile.buttons.filter{(selectedMouse == .naga ? sidePlate.buttonIDs:MouseControls.mxIDs).contains($0.id)}}
    var plateLayoutButtons:[ButtonBinding] {
        let ids=sidePlate.visualRows.flatMap{$0}
        return ids.compactMap{id in sideButtons.first{$0.id==id}}
    }
    var extraButtons:[ButtonBinding] {profile.buttons.filter{MouseControls.extraIDs.contains($0.id)}}
    func select(_ id:Int){cancelLearning();selectedButton=id}
    func selectMouse(_ family:MouseFamily){
        guard family != selectedMouse else{return}
        let resume=wantsMappings
        stopCapture()
        selectedMouse=family
        UserDefaults.standard.set(family.rawValue,forKey:"selectedMouse")
        selectedButton=family == .naga ? sidePlate.buttonIDs[0]:301;lastButton=nil
        updateDevices(capture.deviceList);updateRouting()
        if resume{attemptStart()}
    }
    func status(for family:MouseFamily)->MouseStatus {mouseStatuses[family] ?? MouseStatus()}
    private var detectedConnections:[MouseFamily:MouseConnection] {
        var result=[MouseFamily:MouseConnection]()
        for family in MouseFamily.allCases {
            if let device=capture.deviceList.first(where:{$0.matches(family)}){
                result[family]=MouseConnection.resolve(vendor:HIDCapture.number(device.device,kIOHIDVendorIDKey),product:device.productID,transport:device.transport)
            }
        }
        return result
    }
    var noMouseDetected:Bool {MouseFamily.allCases.allSatisfy{status(for:$0).presence == .notDetected}}
    func refreshMouseStatus(){
        let connections=detectedConnections
        hardware.refreshStatus(connections){[weak self] statuses in
            guard let self else{return}
            var updated=statuses
            if Date().timeIntervalSince(self.lastNagaActivity)<120,connections[.naga] != nil{updated[.naga]?.presence = .connected}
            self.mouseStatuses=updated;self.updateSelectedStatus()
            if self.wantsMappings && !self.enabled && !self.connecting && self.status(for:self.selectedMouse).connected {
                self.recovery.resetAttempts();self.scheduleRecovery()
            }
        }
    }
    private func updateSelectedStatus(){let current=status(for:selectedMouse);battery=current.power;connection=current.connection}
    private func noteNagaActivity(){
        guard detectedConnections[.naga] != nil else{return}
        lastNagaActivity=Date()
        if mouseStatuses[.naga]?.presence != .connected{mouseStatuses[.naga]?.presence = .connected}
    }
    func selectPlate(_ plate:SidePlate){
        runner.cancelAll();cancelLearning();sidePlate=plate
        UserDefaults.standard.set(plate.rawValue,forKey:"sidePlate")
        if !MouseControls.extraIDs.contains(selectedButton){selectedButton=plate.buttonIDs[0]}
        updateRouting();message="Using the \(plate.label). Each plate keeps its own mappings."
    }
    func setExtraButtons(_ value:Bool){
        let resume=wantsMappings
        stopCapture()
        extraButtonsEnabled=value;UserDefaults.standard.set(value,forKey:"extraButtonsEnabled")
        if resume{attemptStart()}
    }
    private func checkExtraButtonMode(){
        guard enabled,extraButtonsActive,!checkingExtraButtons else{return}
        checkingExtraButtons=true
        hardware.checkExtraButtons{[weak self] result in
            guard let self else{return};self.checkingExtraButtons=false
            switch result {
            case .success(let restored):
                if restored {
                    self.runner.cancelAll()
                    guard self.capture.start() else{self.pause();self.message="Could not restart input observation after mouse idle.";return}
                    self.message="Extra-button reporting restored after mouse idle."
                }
            case .failure(let error):
                self.runner.cancelAll()
                self.extraButtonsActive=false;self.capture.setExtraButtonsEnabled(false)
                self.message="Side-panel mappings are on. Extra-button connection lost: \(error.localizedDescription)"
            }
        }
    }
    private func updateDevices(_ devices:[NagaInterface]) {
        let connections=detectedConnections
        for family in MouseFamily.allCases {
            guard let connection=connections[family] else{mouseStatuses[family]=MouseStatus();continue}
            if mouseStatuses[family]?.connection != connection || mouseStatuses[family]?.presence == .notDetected{
                mouseStatuses[family]=MouseStatus(presence:connection == .wireless ? .receiver:.connected,connection:connection)
            }
        }
        updateSelectedStatus()
        let matching=devices.filter{$0.matches(selectedMouse)}
        interfaceCount=matching.count
        if let first=matching.first {deviceName="\(selectedMouse.name) · \(MouseConnection.resolve(vendor:HIDCapture.number(first.device,kIOHIDVendorIDKey),product:first.productID,transport:first.transport).rawValue)"} else {deviceName="\(selectedMouse.name) · Not connected"}
        if wantsMappings && !enabled && !connecting {recovery.resetAttempts();scheduleRecovery()}
    }
    func refreshPermissions() {
        inputAllowed=IOHIDCheckAccess(kIOHIDRequestTypeListenEvent)==kIOHIDAccessTypeGranted
        accessibilityAllowed=AXIsProcessTrusted()
        if wantsMappings && (!inputAllowed || !accessibilityAllowed){pause();message="Mappings paused. Grant Input Monitoring and Accessibility, then enable again."}
        let wasBlocked=secureInputBlocked
        recovery.setSecureInput(IsSecureEventInputEnabled())
        if wantsMappings && secureInputBlocked {
            if enabled || connecting{stopCapture()}
            if !wasBlocked || message.isEmpty{message="macOS Secure Input is blocking mouse mappings. Close any password prompt, or lock and unlock your Mac. Mappings will resume automatically."}
        } else if wasBlocked && wantsMappings {
            message="Secure Input cleared. Reconnecting mappings…";scheduleRecovery()
        }
    }
    func requestInput(){_ = IOHIDRequestAccess(kIOHIDRequestTypeListenEvent);openPrivacy("ListenEvent")}
    func requestAccessibility(){let options=[kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String:true] as CFDictionary;_ = AXIsProcessTrustedWithOptions(options);openPrivacy("Accessibility")}
    private func openPrivacy(_ pane:String){if let u=URL(string:"x-apple.systempreferences:com.apple.preference.security?Privacy_\(pane)"){NSWorkspace.shared.open(u)}}
    func toggleEnabled(){wantsMappings ? pause() : start()}
    func start() {
        recovery.enable();attemptStart()
    }
    private func attemptStart() {
        guard wantsMappings,!recovery.sleeping,!connecting else{return}
        recoveryWork?.cancel();recoveryWork=nil
        refreshPermissions()
        guard !secureInputBlocked else{return}
        guard inputAllowed && accessibilityAllowed else {message="Grant both permissions first, then enable mappings.";return}
        guard interfaceCount>0 else {message="Waiting for your selected mouse. Mappings will resume when it reconnects.";return}
        guard saveError.isEmpty else {pause();message="Resolve the configuration error before enabling mappings.";return}
        message="";updateRouting();let started=capture.start()
        guard started && capture.capturedCount==interfaceCount else {capture.stop();runner.cancelAll();enabled=false;scheduleRecovery();return}
        connecting=true
        let family=selectedMouse
        let buttons=configuration.profile(for:NSWorkspace.shared.frontmostApplication?.bundleIdentifier).buttons(for:family,plate:sidePlate)
        hardware.prepare(family:family,extraButtons:extraButtonsEnabled,buttons:buttons){[weak self] result in
            guard let self else{return};self.connecting=false
            switch result {
            case .success(let (extraActive,warning)):
                self.extraButtonsActive=extraActive;self.capture.setExtraButtonsEnabled(extraActive)
                self.enabled=true;self.runner.setPhysicalEnabled(true);self.recovery.resetAttempts()
                if family == .mxMaster3s{self.mouseStatuses[family]?.presence = .connected}
                self.updateRouting()
                self.message=warning ?? "Ready. Press a mouse button to check its mapping."
            case .failure(let error):
                // An asleep/offline mouse must not turn off the user's mapping intent
                // for the next mouse they select. Refresh retries after it answers.
                self.stopCapture();self.message="Waiting for \(family.name). \(error.localizedDescription) Wake it and press Refresh to reconnect."
            }
        }
    }
    private func stopCapture(){
        runner.setPhysicalEnabled(false)
        shortcutOverlay.dismiss()
        recoveryWork?.cancel();recoveryWork=nil;enabled=false;connecting=false;checkingExtraButtons=false
        cancelShortcutTest();cancelLearning();capture.stop();runner.cancelAll()
        capture.setExtraButtonsEnabled(false);extraButtonsActive=false
        hardware.stop{[weak self] failure in
            guard let self,let failure else{return}
            self.recovery.pause();self.message="Mappings paused. \(failure) Reconnect the mouse before enabling again."
        }
    }
    func pause(){recovery.pause();stopCapture();message="Mappings paused. Side buttons send their original keys."}
    func shutdown(){stopCapture();runner.finishStopping();hardware.finishStopping()}
    private func interrupted(_ reason:String){
        stopCapture();message="\(reason) Held keys released. Reconnecting…";scheduleRecovery()
    }
    private func scheduleRecovery(){
        guard wantsMappings,!recovery.sleeping,!secureInputBlocked,!connecting,recoveryWork==nil else{return}
        guard interfaceCount>0 else{message="Waiting for your selected mouse. Mappings will resume when it reconnects.";return}
        guard let delay=recovery.nextDelay() else{
            let detail=message;pause();message="Could not resume mappings after three attempts. Enable mappings to retry. \(detail)";return
        }
        let work=DispatchWorkItem{[weak self] in self?.recoveryWork=nil;self?.attemptStart()}
        recoveryWork=work;DispatchQueue.main.asyncAfter(deadline:.now()+delay,execute:work)
    }
    func learn(){
        if !enabled {start()};guard enabled else{return}
        runner.cancelAll();learning=selectedButton;updateRouting();message="Press \(MouseControls.title(selectedButton)). Other mappings are paused while identifying it."
        learnedTimeout?.cancel();let work=DispatchWorkItem{[weak self] in self?.cancelLearning();self?.message="Button learning timed out. Try again when ready."};learnedTimeout=work
        DispatchQueue.main.asyncAfter(deadline:.now()+15,execute:work)
    }
    func cancelLearning(){learning=nil;learnedTimeout?.cancel();learnedTimeout=nil;updateRouting()}
    private func updateRouting(){
        let buttons=configuration.profile(for:NSWorkspace.shared.frontmostApplication?.bundleIdentifier).buttons(for:selectedMouse,plate:sidePlate)
        capture.setFamily(selectedMouse);capture.setBindings(buttons,learning:selectedMouse == .naga && learning != nil)
        if selectedMouse == .mxMaster3s,enabled {
            hardware.configure(buttons,learning:learning != nil){[weak self] error in self?.pause();self?.message=error}
        }
    }
    private func received(usage:UInt32,down:Bool,binding:ButtonBinding?,intercepted:Bool,actionDelivered:Bool=false) {
        if !down {if !actionDelivered{runner.up(usage)};if intercepted,let binding{message="\(MouseControls.title(binding.id)) released."};return}
        guard enabled else{return}
        if let target=learning {
            runner.cancelAll()
            do {
                configuration=try configuration.identifying(button:target,usage:usage,plate:sidePlate,family:selectedMouse)
                cancelLearning();lastButton=target;message="Identified \(MouseControls.title(target)). Saved for all app profiles."
            } catch {cancelLearning();message="Could not identify this button: \(error.localizedDescription)"}
            return
        }
        if let binding{lastButton=binding.id;message="\(MouseControls.title(binding.id)) · \(binding.mode.label)"}
        if intercepted && !actionDelivered{runner.physicalInput(usage,down:true,binding:binding)}
    }
    func recordChanged(_ recording:Bool){cancelShortcutTest();cancelLearning();runner.cancelAll();runner.suspend=recording}
    private func cancelShortcutTest(){
        shortcutTestRelease?.cancel();shortcutTestRelease=nil
        if testingShortcut{runner.up(UInt32.max);testingShortcut=false}
    }
    func testShortcut(){
        guard accessibilityAllowed,!button.effectiveChord.isEmpty,!testingShortcut else{return}
        cancelLearning();runner.cancelAll();runner.suspend=false
        let usage=UInt32.max,binding=button
        testingShortcut=true
        runner.down(usage,binding:binding)
        let work=DispatchWorkItem{[weak self] in
            self?.runner.up(usage);self?.testingShortcut=false;self?.shortcutTestRelease=nil
        }
        shortcutTestRelease=work
        DispatchQueue.main.asyncAfter(deadline:.now()+3,execute:work)
    }
    func rightCommandPreset(){editButton{$0.name="Superwhispr";$0.mode = .hold;$0.chord = .rightCommand}}
    var localScribeChord:Chord {
        struct Saved:Decodable{let keyCode:UInt32,modifiers:UInt32;let label:String}
        if let data=UserDefaults(suiteName:"local.localscribe.mac")?.data(forKey:"shortcut"),let saved=try? JSONDecoder().decode(Saved.self,from:data),saved.keyCode<=126 {
            var flags=Modifiers()
            for (carbon,key) in [(UInt32(4096),Modifiers.control),(2048,.option),(512,.shift),(256,.command)]{if saved.modifiers&carbon != 0{flags.insert(key)}}
            return Chord(keyCode:UInt16(saved.keyCode),modifiers:flags,keyLabel:saved.keyCode==49 ? "Space":saved.label.filter{!"⌃⌥⇧⌘".contains($0)})
        }
        return Chord(keyCode:49,modifiers:[.control,.option],keyLabel:"Space")
    }
    func dictationPreset(){let chord=localScribeChord;editButton{$0.name="Dictation";$0.mode = .hold;$0.chord=chord}}
    func addProfile(_ app:NSRunningApplication){
        guard let bundle=app.bundleIdentifier,!configuration.profiles.contains(where:{$0.bundleID==bundle}) else{return}
        var copy=configuration.profiles[0];copy.id=UUID();copy.name=app.localizedName ?? bundle;copy.bundleID=bundle
        configuration.profiles.append(copy);selectedProfile=copy.id
    }
    func availableApps()->[NSRunningApplication]{NSWorkspace.shared.runningApplications.filter{ app in app.activationPolicy == .regular && app.bundleIdentifier != nil && !configuration.profiles.contains{$0.bundleID==app.bundleIdentifier}}.sorted{($0.localizedName ?? "")<($1.localizedName ?? "")}}
    func removeProfile(){guard profileIndex>0 else{return};configuration.profiles.remove(at:profileIndex);selectedProfile=configuration.profiles[0].id;runner.cancelAll()}
    private func save(){
        guard loaded else{return}
        do { _ = try configuration.validated();try FileManager.default.createDirectory(at:directory,withIntermediateDirectories:true);let data=try JSONEncoder().encode(configuration);try data.write(to:file,options:.atomic);saveError="" } catch {saveError="Could not save mappings: \(error.localizedDescription)"}
    }
    func exportSettings(){
        let panel=NSSavePanel();panel.nameFieldStringValue="ThumbKey-bindings.json";panel.allowedContentTypes=[.json]
        if panel.runModal() == .OK,let url=panel.url {do {let e=JSONEncoder();e.outputFormatting=[.prettyPrinted,.sortedKeys];try e.encode(configuration).write(to:url,options:.atomic)}catch{message=error.localizedDescription}}
    }
    func importSettings(){
        let panel=NSOpenPanel();panel.allowedContentTypes=[.json];panel.allowsMultipleSelection=false
        guard panel.runModal() == .OK,let url=panel.url else{return}
        do {
            guard (try url.resourceValues(forKeys:[.fileSizeKey]).fileSize ?? 0)<=2_000_000 else {throw ConfigError.invalid}
            let next=try JSONDecoder().decode(Configuration.self,from:Data(contentsOf:url)).validated()
            pause()
            if FileManager.default.fileExists(atPath:file.path) {try FileManager.default.copyItem(at:file,to:directory.appendingPathComponent("bindings-backup-\(UUID().uuidString).json"))}
            loaded=true;configuration=next;selectedProfile=next.profiles[0].id;message="Mappings imported. Previous settings were backed up.";
        } catch {message="Import failed: \(error.localizedDescription)"}
    }
    deinit{permissionTimer?.invalidate();batteryTimer?.invalidate();recoveryWork?.cancel();observers.forEach{NotificationCenter.default.removeObserver($0);NSWorkspace.shared.notificationCenter.removeObserver($0)}}
}
