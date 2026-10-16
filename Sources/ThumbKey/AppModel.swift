import AppKit
import SwiftUI
import IOKit.hid
import UniformTypeIdentifiers
import ThumbKeyCore

final class AppModel: ObservableObject {
    @Published var configuration = Configuration() { didSet { save(); updateRouting() } }
    @Published var selectedProfile = UUID()
    @Published var selectedButton = 1
    @Published var learning: Int?
    @Published var lastButton: Int?
    @Published var enabled=false
    @Published var deviceName="No Naga connected"
    @Published var interfaceCount=0
    @Published var inputAllowed=false
    @Published var accessibilityAllowed=false
    @Published var message=""
    @Published var saveError=""
    let capture=HIDCapture()
    let runner=ActionRunner()
    private var permissionTimer:Timer?
    private var observers:[NSObjectProtocol]=[]
    private var learnedTimeout:DispatchWorkItem?
    private var loaded=false
    private let directory=FileManager.default.urls(for:.applicationSupportDirectory,in:.userDomainMask)[0].appendingPathComponent("ThumbKey")
    var file: URL { directory.appendingPathComponent("bindings.json") }
    init() {
        do {
            if FileManager.default.fileExists(atPath:file.path) { configuration=try JSONDecoder().decode(Configuration.self,from:Data(contentsOf:file)).validated() }
            else {
                configuration.profiles[0].buttons[0].name="Dictation"
                configuration.profiles[0].buttons[0].mode = .hold
                configuration.profiles[0].buttons[0].chord=Chord(keyCode:49,modifiers:[.control,.option],keyLabel:"Space")
            }
        } catch { saveError="Could not read saved mappings. They have not been overwritten: \(error.localizedDescription)" }
        selectedProfile=configuration.profiles[0].id
        loaded=saveError.isEmpty
        capture.onDevices={ [weak self] devices in self?.updateDevices(devices) }
        capture.onInput={ [weak self] usage,down,binding,intercepted in self?.received(usage:usage,down:down,binding:binding,intercepted:intercepted) }
        capture.onDisconnect={ [weak self] in self?.pause();self?.message="Input device disconnected or filter stopped. Mappings paused; held keys released." }
        capture.onError={ [weak self] text in self?.message=text }
        runner.status={ [weak self] text in self?.message=text }
        updateDevices(capture.deviceList); refreshPermissions();updateRouting()
        observers.append(NSWorkspace.shared.notificationCenter.addObserver(forName:NSWorkspace.didActivateApplicationNotification,object:nil,queue:.main){[weak self] _ in self?.updateRouting()})
        permissionTimer=Timer.scheduledTimer(withTimeInterval:2,repeats:true){[weak self] _ in self?.refreshPermissions()}
        observers.append(NSWorkspace.shared.notificationCenter.addObserver(forName:NSWorkspace.willSleepNotification,object:nil,queue:.main){[weak self] _ in self?.pause();self?.message="Paused for sleep. Enable mappings when you return."})
        observers.append(NotificationCenter.default.addObserver(forName:NSApplication.willTerminateNotification,object:nil,queue:.main){[weak self] _ in self?.pause()})
    }
    var profileIndex:Int {configuration.profiles.firstIndex{$0.id==selectedProfile} ?? 0}
    var profile:Profile {configuration.profiles[profileIndex]}
    var button:ButtonBinding {profile.buttons.first{$0.id==selectedButton}!}
    func editButton(_ edit:(inout ButtonBinding)->Void) {
        runner.cancelAll()
        guard let i=configuration.profiles[profileIndex].buttons.firstIndex(where:{$0.id==selectedButton}) else{return}
        edit(&configuration.profiles[profileIndex].buttons[i])
    }
    func editStep(_ id:UUID,_ edit:(inout MacroStep)->Void) {editButton { b in if let i=b.steps.firstIndex(where:{$0.id==id}){edit(&b.steps[i])} } }
    func select(_ id:Int){cancelLearning();selectedButton=id}
    private func updateDevices(_ devices:[NagaInterface]) {
        interfaceCount=devices.count
        if let first=devices.first {deviceName="\(first.name) · \(first.transport)"} else {deviceName="No Naga connected"}
    }
    func refreshPermissions() {
        inputAllowed=IOHIDCheckAccess(kIOHIDRequestTypeListenEvent)==kIOHIDAccessTypeGranted
        accessibilityAllowed=AXIsProcessTrusted()
        if enabled && (!inputAllowed || !accessibilityAllowed){pause();message="Mappings paused. Grant Input Monitoring and Accessibility, then enable again."}
    }
    func requestInput(){_ = IOHIDRequestAccess(kIOHIDRequestTypeListenEvent);openPrivacy("ListenEvent")}
    func requestAccessibility(){let options=[kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String:true] as CFDictionary;_ = AXIsProcessTrustedWithOptions(options);openPrivacy("Accessibility")}
    private func openPrivacy(_ pane:String){if let u=URL(string:"x-apple.systempreferences:com.apple.preference.security?Privacy_\(pane)"){NSWorkspace.shared.open(u)}}
    func toggleEnabled(){enabled ? pause() : start()}
    func start() {
        refreshPermissions()
        guard inputAllowed && accessibilityAllowed else {message="Grant both permissions first, then enable mappings.";return}
        guard interfaceCount>0 else {message="Connect your Naga using its cable or receiver, then retry.";return}
        guard saveError.isEmpty else {message="Resolve the configuration error before enabling mappings.";return}
        message="";updateRouting();let started=capture.start()
        guard started && capture.capturedCount==interfaceCount else {capture.stop();runner.cancelAll();enabled=false;return}
        enabled=true;message="Ready. Press a side button to check its mapping."
    }
    func pause(){enabled=false;cancelLearning();capture.stop();runner.cancelAll();message=""}
    func learn(){
        if !enabled {start()};guard enabled else{return}
        runner.cancelAll();learning=selectedButton;updateRouting();message="Press physical side button \(selectedButton). Other mappings are paused while learning."
        learnedTimeout?.cancel();let work=DispatchWorkItem{[weak self] in self?.cancelLearning();self?.message="Button learning timed out. Try again when ready."};learnedTimeout=work
        DispatchQueue.main.asyncAfter(deadline:.now()+15,execute:work)
    }
    func cancelLearning(){learning=nil;learnedTimeout?.cancel();learnedTimeout=nil;updateRouting()}
    private func updateRouting(){capture.setBindings(configuration.profile(for:NSWorkspace.shared.frontmostApplication?.bundleIdentifier).buttons,learning:learning != nil)}
    private func received(usage:UInt32,down:Bool,binding:ButtonBinding?,intercepted:Bool) {
        if !down {runner.up(usage);if intercepted,let binding{message="Button \(binding.id) released."};return}
        if let target=learning {
            runner.cancelAll()
            // Input identity belongs to the physical pad and is shared by all app profiles.
            for p in configuration.profiles.indices {
                let old=configuration.profiles[p].buttons.first{$0.id==target}?.usage
                if let other=configuration.profiles[p].buttons.firstIndex(where:{$0.usage==usage && $0.id != target}){configuration.profiles[p].buttons[other].usage=old}
                if let index=configuration.profiles[p].buttons.firstIndex(where:{$0.id==target}){configuration.profiles[p].buttons[index].usage=usage}
            }
            cancelLearning();lastButton=target;message="Button \(target) learned. Its original input is HID \(usage).";return
        }
        if let binding{lastButton=binding.id;message="Button \(binding.id) · \(binding.mode.label)"}
        if intercepted{runner.down(usage,binding:binding)}
    }
    func recordChanged(_ recording:Bool){runner.cancelAll();runner.suspend=recording}
    func dictationPreset(){editButton{$0.name="Dictation";$0.mode = .hold;$0.chord=Chord(keyCode:49,modifiers:[.control,.option],keyLabel:"Space")}}
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
    deinit{permissionTimer?.invalidate();observers.forEach{NotificationCenter.default.removeObserver($0);NSWorkspace.shared.notificationCenter.removeObserver($0)}}
}
