import AppKit
import SwiftUI
import ThumbKeyCore

final class ThumbKeyAppDelegate:NSObject,NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification:Notification) {
        // In-place updates can leave the Dock's previous icon cached. Load the
        // actual bundled mouse icon instead of relying on the cached app image.
        if let url=Bundle.main.url(forResource:"ThumbKeyMouse",withExtension:"icns"),
           let icon=NSImage(contentsOf:url) {
            NSApplication.shared.applicationIconImage=icon
        }
    }
}

@main struct ThumbKeyApp:App {
    @NSApplicationDelegateAdaptor(ThumbKeyAppDelegate.self) private var appDelegate
    @StateObject private var model:AppModel
    init(){
        if let index=CommandLine.arguments.firstIndex(of:"--render-mice"),CommandLine.arguments.count>index+1 {
            do{try MouseIllustration.exportPreviews(to:URL(fileURLWithPath:CommandLine.arguments[index+1]));print("Rendered mouse model previews.");exit(0)}catch{print(error.localizedDescription);exit(1)}
        }
        if CommandLine.arguments.contains("--devices") {
            let capture=HIDCapture()
            for i in capture.deviceList {print("\(i.name) | \(i.transport) | product=\(String(format:"%04x",i.productID)) | input interface \(i.id)")}
            print("\(capture.deviceList.count) supported mouse input interfaces; no input capture opened.")
            exit(0)
        }
        if CommandLine.arguments.contains("--check-extra-mode") {
            let mode=NagaDriverMode()
            do {
                try mode.activate();print("Confirmed temporary extra-button reporting mode (03 00).")
                try mode.restore();print("Confirmed restoration of the original reporting mode.");exit(0)
            } catch {print("Extra-button mode check failed: \(error.localizedDescription)");exit(1)}
        }
        if CommandLine.arguments.contains("--check-mx") || CommandLine.arguments.contains("--check-mx-buttons") {
            let controller=LogitechController()
            do {
                try controller.connect();print("MX Master 3S · \(controller.connection.rawValue) · \(controller.power().label)")
                print("Programmable controls: \(controller.supportedControls.sorted().map{String(format:"%04x",$0)}.joined(separator:", "))")
                if CommandLine.arguments.contains("--check-mx-buttons") {
                    var buttons=MouseControls.mxDefaults();for i in buttons.indices{buttons[i].mode = .disabled}
                    try controller.configure(buttons,learning:false);print("Verified temporary diversion for all five buttons.")
                }
                try controller.stop();print("Original button reporting restored.");exit(0)
            }catch{try? controller.stop();print(error.localizedDescription);exit(1)}
        }
        _model=StateObject(wrappedValue:AppModel())
    }
    var body:some Scene {
        Window("ThumbKey",id:"main") {ContentView().environmentObject(model).frame(minWidth:920,minHeight:680)}
            .defaultSize(width:1020,height:760)
            .commands {CommandGroup(replacing:.newItem){};CommandGroup(after:.appSettings){Button(model.wantsMappings ? "Pause mappings":"Enable mappings"){model.toggleEnabled()}.keyboardShortcut("p",modifiers:[.command,.option,.control])}}
        MenuBarExtra("ThumbKey",systemImage:model.enabled ? "circle.grid.3x3.fill":"exclamationmark.circle") {
            MenuControls().environmentObject(model)
        }
    }
}
struct MenuControls:View {
    @EnvironmentObject var model:AppModel
    @Environment(\.openWindow) var openWindow
    var body:some View {
        Text(model.deviceName)
        Text(model.mappingStatus)
        Button("Open ThumbKey"){openWindow(id:"main");NSApp.activate(ignoringOtherApps:true)}
        Button(model.wantsMappings ? "Pause mappings":"Enable mappings"){model.toggleEnabled()}
        Divider()
        Button("Release held keys & pause"){model.pause()}
        Button("Quit ThumbKey"){model.shutdown();NSApp.terminate(nil)}
    }
}
struct ContentView:View {
    @EnvironmentObject var model:AppModel
    private let accent=Color(red:0.04,green:0.46,blue:0.37)
    var body:some View {
        VStack(spacing:0) {
            HStack(spacing:18){
                VStack(alignment:.leading,spacing:5){Text("ThumbKey").font(.title2.bold());Text("Your mouse. Your shortcuts.").font(.caption).foregroundStyle(.secondary)}
                HStack(spacing:10){ForEach(MouseFamily.allCases){family in MouseDeviceCard(family:family)}}
                Spacer(minLength:0)
                VStack(alignment:.trailing,spacing:10){
                    Label(model.mappingStatus,systemImage:model.wantsMappings && model.secureInputBlocked ? "exclamationmark.triangle.fill":model.enabled ? "circle.fill":"pause.circle").foregroundStyle(model.wantsMappings && model.secureInputBlocked ? Color.orange:model.enabled ? accent:Color.secondary).font(.caption.weight(.medium))
                    HStack{Button{model.refreshMouseStatus()}label:{Image(systemName:"arrow.clockwise")}.buttonStyle(.plain).help("Refresh mouse batteries and connections")
                        Button(model.wantsMappings ? "Pause":"Enable mappings"){model.toggleEnabled()}.buttonStyle(.borderedProminent).tint(accent)}
                }
            }.padding(.horizontal,24).padding(.vertical,16)
            Divider()
            if model.noMouseDetected {
                HStack(spacing:12){
                    Image(systemName:"computermouse").font(.title2).foregroundStyle(.secondary)
                    VStack(alignment:.leading,spacing:3){
                        Text("No supported mouse detected").font(.headline)
                        Text("Connect your Naga V3 Pro or MX Master 3S by cable, receiver, or Bluetooth. You can still edit saved mappings.").font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                }.padding(.horizontal,24).padding(.vertical,12).background(Color.secondary.opacity(0.06))
                Divider()
            }
            if !model.inputAllowed || !model.accessibilityAllowed {
                HStack(alignment:.center,spacing:16){Image(systemName:"hand.raised").font(.title2);VStack(alignment:.leading,spacing:4){Text("Allow ThumbKey to remap your side pad").font(.headline);Text("Input Monitoring reads mouse buttons. Accessibility sends your chosen shortcuts.").font(.caption).foregroundStyle(.secondary)};Spacer();Button(model.inputAllowed ? "Input Monitoring ✓":"Allow Input Monitoring"){model.requestInput()}.disabled(model.inputAllowed);Button(model.accessibilityAllowed ? "Accessibility ✓":"Allow Accessibility"){model.requestAccessibility()}.disabled(model.accessibilityAllowed)}.padding(16).background(accent.opacity(0.06));Divider()
            }
            HStack(spacing:12){
                Text("Profile").foregroundStyle(.secondary)
                Picker("Profile",selection:$model.selectedProfile){ForEach(model.configuration.profiles){p in Text(p.name).tag(p.id)}}.labelsHidden().frame(width:210).onChange(of:model.selectedProfile){_,_ in model.cancelLearning()}
                Menu {ForEach(model.availableApps(),id:\.processIdentifier){app in Button(app.localizedName ?? app.bundleIdentifier ?? "App"){model.addProfile(app)}}} label:{Label("Add app profile",systemImage:"plus")}
                if model.profileIndex>0 {Button("Remove profile"){model.removeProfile()}.foregroundStyle(.secondary)}
                Spacer()
                Menu{Button("Export mappings…"){model.exportSettings()};Button("Import mappings…"){model.importSettings()}}label:{Image(systemName:"ellipsis.circle")}.menuStyle(.borderlessButton).frame(width:30)
            }.padding(.horizontal,24).padding(.vertical,14)
            Divider()
            HSplitView {
                ScrollView { VStack(alignment:.leading,spacing:18){
                    MouseMappingScene().frame(height:390)

                    if model.selectedMouse == .naga {
                    Text("SIDE PLATE").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                    Picker("Attached side plate",selection:Binding(get:{model.sidePlate},set:{model.selectPlate($0)})) {
                        ForEach(SidePlate.allCases){plate in Text("\(plate.rawValue) buttons").tag(plate)}
                    }.pickerStyle(.segmented)
                    Text("Select the attached plate after swapping it. Each plate saves its own mappings; automatic detection is not available yet.").font(.caption).foregroundStyle(.secondary)
                    LazyVGrid(columns:Array(repeating:GridItem(.flexible(),spacing:10),count:model.sidePlate == .twelve ? 4:model.sidePlate == .two ? 2:3),spacing:10){
                        ForEach(model.plateLayoutButtons){button in ButtonTile(button:button)}
                    }
                    Divider()
                    HStack{Text("TOP & RING-FINGER BUTTONS").font(.caption.weight(.semibold)).foregroundStyle(.secondary);Spacer()}
                    Toggle("Enable extra-button reporting",isOn:Binding(get:{model.extraButtonsEnabled},set:{model.setExtraButtons($0)}))
                    Text("Uses a temporary mouse mode over USB or the USB receiver. The original mode returns when you pause or quit. Unassigned extra buttons may stop their usual DPI or wheel functions while enabled.").font(.caption).foregroundStyle(.secondary)
                    VStack(spacing:8){ForEach(model.extraButtons){button in ButtonTile(button:button,compact:true)}}
                    } else {
                        Text("MX MASTER 3S BUTTONS").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                        Text("Choose a button, then assign a shortcut or macro. ThumbKey temporarily takes control only of assigned buttons. Pause restores their original behavior.").font(.caption).foregroundStyle(.secondary)
                        VStack(spacing:10){ForEach(model.sideButtons){button in ButtonTile(button:button,compact:true)}}
                        Label("Scrolling and primary clicks keep working normally.",systemImage:"cursorarrow").font(.caption).foregroundStyle(.secondary)
                    }
                    if let last=model.lastButton{Label("Last press: \(MouseControls.title(last))",systemImage:"checkmark.circle").font(.caption).foregroundStyle(accent)}
                    Spacer(minLength:0)
                    Label("Runs locally. No accounts or network requests.",systemImage:"lock").font(.caption).foregroundStyle(.secondary)
                }.padding(24) }.frame(minWidth:410,idealWidth:460,maxWidth:560)
                ScrollView{ButtonEditor().padding(24)}.frame(minWidth:360,maxWidth:.infinity)
            }
            if !model.message.isEmpty || !model.saveError.isEmpty {
                Divider();HStack{Image(systemName:model.saveError.isEmpty ? "info.circle":"exclamationmark.triangle");Text(model.saveError.isEmpty ? model.message:model.saveError).font(.callout);Spacer();if model.learning != nil{Button("Cancel"){model.cancelLearning()}}else{Button{model.message=""}label:{Image(systemName:"xmark")}.buttonStyle(.plain)}}.padding(14).background(Color(nsColor:.controlBackgroundColor))
            }
        }.background(Color(nsColor:.windowBackgroundColor)).tint(accent)
    }
}
struct ButtonTile:View {
    @EnvironmentObject var model:AppModel
    let button:ButtonBinding
    var compact=false
    private var selected:Bool{model.selectedButton==button.id}
    private let accent=Color(red:0.04,green:0.46,blue:0.37)
    var body:some View {
        Button{model.select(button.id)}label:{
            Group {
                if compact {
                    HStack(spacing:12){Text("\(button.id>=301 ? button.id-300:MouseControls.number(button.id))").font(.caption.weight(.bold)).frame(width:25,height:25).background(selected ? accent.opacity(0.15):Color.primary.opacity(0.06),in:Circle()).foregroundStyle(selected ? accent:Color.secondary);VStack(alignment:.leading,spacing:4){Text(MouseControls.title(button.id)).font(.subheadline.weight(.medium));Text(button.detail).font(.caption).foregroundStyle(.secondary)};Spacer()}
                } else {
                    VStack(alignment:.leading,spacing:8){HStack{Text("\(MouseControls.number(button.id))").font(.system(size:26,weight:.semibold,design:.rounded));Spacer();if selected{Image(systemName:"checkmark.circle.fill").foregroundStyle(accent)}};Text(button.title).font(.subheadline.weight(.medium)).lineLimit(1);Text(button.detail).font(.caption).foregroundStyle(.secondary).lineLimit(2).frame(maxWidth:.infinity,alignment:.leading)}.frame(minHeight:80)
                }
            }.padding(14).frame(maxWidth:.infinity,alignment:.leading)
                .background(selected ? accent.opacity(0.10):Color(nsColor:.controlBackgroundColor),in:RoundedRectangle(cornerRadius:12))
                .overlay(RoundedRectangle(cornerRadius:12).stroke(selected ? accent:Color.primary.opacity(0.1),lineWidth:selected ? 2:1))
        }.buttonStyle(.plain).accessibilityLabel("\(MouseControls.title(button.id)), \(button.title), \(button.detail)")
    }
}
struct ButtonEditor:View {
    @EnvironmentObject var model:AppModel
    func field<T>(_ key:WritableKeyPath<ButtonBinding,T>)->Binding<T>{Binding(get:{model.button[keyPath:key]},set:{value in model.editButton{$0[keyPath:key]=value}})}
    var body:some View {
        VStack(alignment:.leading,spacing:20){
            HStack{VStack(alignment:.leading,spacing:5){Text(MouseControls.title(model.selectedButton)).font(.title2.bold());Text(model.profileIndex==0 ? "Used everywhere unless an app profile overrides it.":"Used when \(model.profile.name) is the active app.").font(.caption).foregroundStyle(.secondary)};Spacer()}
            VStack(alignment:.leading,spacing:6){Text("Name (optional)").font(.subheadline.weight(.medium));TextField("What does this button do?",text:field(\.name)).textFieldStyle(.roundedBorder)}
            VStack(alignment:.leading,spacing:6){Text("Action").font(.subheadline.weight(.medium));Picker("Action",selection:field(\.mode)){ForEach(ActionMode.customActions,id:\.self){Text($0.label).tag($0)};Divider();Section("macOS actions"){ForEach(ActionMode.macOSActions,id:\.self){Text($0.label).tag($0)}}}.labelsHidden();Text(model.button.mode.explanation).font(.callout).foregroundStyle(.secondary)}
            if let chord=model.button.mode.presetChord {
                VStack(alignment:.leading,spacing:8){
                    HStack{Text("Shortcut sent once per press").font(.subheadline.weight(.medium));Spacer();Text(chord.label).font(.body.monospaced()).padding(.horizontal,10).padding(.vertical,5).background(Color.primary.opacity(0.06),in:RoundedRectangle(cornerRadius:6))}
                    Button(model.testingShortcut ? "Testing…":"Test " + model.button.mode.label){model.testShortcut()}
                        .disabled(model.testingShortcut || !model.accessibilityAllowed || model.secureInputBlocked)
                    Text("Uses the standard macOS shortcut. Enable it in System Settings → Keyboard → Keyboard Shortcuts → Mission Control. If you changed the keys there, choose Press a shortcut once to use your custom keys.").font(.caption).foregroundStyle(.secondary)
                }
            }
            if model.button.mode == .shortcut || model.button.mode == .hold {
                VStack(alignment:.leading,spacing:8){
                    Text(model.button.mode == .hold ? "Keys held while the button is down":"Shortcut sent once per press").font(.subheadline.weight(.medium))
                    ShortcutRecorder(chord:field(\.chord),onRecording:model.recordChanged).frame(height:40)
                        .disabled(model.secureInputBlocked)
                    if model.secureInputBlocked{Text("Shortcut recording is unavailable while macOS Secure Input is active. You can still use the LocalScribe preset below.").font(.caption).foregroundStyle(.orange)}
                    Button(model.testingShortcut ? "Testing shortcut…":"Test shortcut"){model.testShortcut()}
                        .disabled(model.testingShortcut || model.button.chord.isEmpty || !model.accessibilityAllowed)
                    Text(model.button.mode == .hold ? "Tests these keys for three seconds, then releases them. Use this to check the receiving app without pressing the mouse button.":"Sends this shortcut once to check the receiving app.").font(.caption).foregroundStyle(.secondary)
                    Text(model.button.mode == .hold ? "Press a combination on your keyboard. For a modifier alone, press and release it. Releasing the mouse button releases the keys.":"Click the recorder, then press your shortcut on the keyboard.").font(.caption).foregroundStyle(.secondary)
                }
            }
            Menu {
                Button("Superwhispr · Hold Right Command"){model.rightCommandPreset()}
                Button("LocalScribe · Hold " + model.localScribeChord.label){model.dictationPreset()}
            } label:{Label("Fill in a dictation shortcut",systemImage:"waveform")}
            if model.button.mode == .hold && model.button.chord.keys == Chord.rightCommand.keys {
                Text("This fills in Hold Right Command. Choose Right Command as the push-to-talk key in Superwhispr, and keep Superwhispr running.").font(.caption).foregroundStyle(.secondary)
            } else if model.button.mode == .hold && model.button.chord.keys == model.localScribeChord.keys {
                Text("Matches LocalScribe’s configured dictation shortcut (" + model.localScribeChord.label + "). Keep LocalScribe running. If you change its shortcut, fill in this preset again.").font(.caption).foregroundStyle(.secondary)
            }
            if MouseControls.extraIDs.contains(model.selectedButton),model.button.mode == .passthrough {
                Text("This extra button has no ThumbKey action yet. In extra-button reporting mode, its firmware action may be unavailable. Choose an action above.").font(.caption).foregroundStyle(.secondary)
            }
            if model.button.mode == .macro {MacroEditor()}
            Divider()
            VStack(alignment:.leading,spacing:8){
                Text("Which mouse button?").font(.subheadline.weight(.medium))
                Text(MouseControls.location(model.selectedButton)).font(.callout).foregroundStyle(.secondary)
                if model.button.usage==nil{Label("Needs identification before it can be mapped",systemImage:"questionmark.circle").font(.caption).foregroundStyle(.orange)}
                if model.selectedMouse == .naga {
                Button(model.learning==model.selectedButton ? "Press the mouse button now…":"Identify this physical button…"){model.learn()}.disabled(model.learning != nil || (MouseControls.extraIDs.contains(model.selectedButton) && !model.extraButtonsActive))
                Text("Only needed if this slot does not respond, or responds to the wrong button. Click Identify, then press this button on the mouse. This teaches ThumbKey which input belongs here; it does not choose an action. Applies to all app profiles for this plate.").font(.caption).foregroundStyle(.secondary)
                if MouseControls.extraIDs.contains(model.selectedButton),!model.extraButtonsActive {
                    Text("Enable extra-button reporting and mappings first.").font(.caption).foregroundStyle(.secondary)
                }
                } else {
                    Text("Identified directly by the mouse. Assigning an action uses temporary Logitech button reporting; DPI and onboard settings are unchanged.").font(.caption).foregroundStyle(.secondary)
                }
                DisclosureGroup("Technical input details"){
                    Text(model.button.usage.map{InputSource.description($0)+" · source \($0)"} ?? "No input assigned").font(.caption.monospaced()).foregroundStyle(.secondary)
                    Text("Keyboard 1 means this mouse button sends the same input as the 1 key. It is an input identifier, not your chosen shortcut.").font(.caption).foregroundStyle(.secondary)
                    Text("Plate status report: \(model.lastPlateSignal)").font(.caption.monospaced()).textSelection(.enabled)
                }.font(.caption)
            }

            Spacer()
        }.frame(maxWidth:.infinity,alignment:.leading)
    }
}
struct MacroEditor:View {
    @EnvironmentObject var model:AppModel
    func stepField<T>(_ id:UUID,_ key:WritableKeyPath<MacroStep,T>)->Binding<T>{Binding(get:{(model.button.steps.first{$0.id==id} ?? MacroStep())[keyPath:key]},set:{value in model.editStep(id){$0[keyPath:key]=value}})}
    var body:some View{
        VStack(alignment:.leading,spacing:12){
            Text("Macro steps").font(.subheadline.weight(.medium))
            Text("Runs once per press, in order. Stops if you switch apps. Add delays when an app needs time to respond.").font(.caption).foregroundStyle(.secondary)
            ForEach(Array(model.button.steps.enumerated()),id:\.element.id){index,step in
                VStack(alignment:.leading,spacing:8){
                    HStack{Text("\(index+1)").font(.caption.monospaced());Picker("Step type",selection:stepField(step.id,\.kind)){Text("Shortcut").tag(StepKind.shortcut);Text("Type text").tag(StepKind.text);Text("Wait").tag(StepKind.delay)}.labelsHidden();Spacer();Button{model.editButton{b in if let i=b.steps.firstIndex(where:{$0.id==step.id}),i>0{b.steps.swapAt(i,i-1)}}}label:{Image(systemName:"arrow.up")}.disabled(index==0);Button{model.editButton{$0.steps.removeAll{$0.id==step.id}}}label:{Image(systemName:"minus.circle")}}
                    switch step.kind {
                    case .shortcut:ShortcutRecorder(chord:stepField(step.id,\.chord),onRecording:model.recordChanged).frame(height:40)
                    case .text:TextEditor(text:stepField(step.id,\.text)).font(.body).frame(minHeight:70,maxHeight:120).overlay(RoundedRectangle(cornerRadius:5).stroke(Color.primary.opacity(0.15)))
                    case .delay:HStack{TextField("Milliseconds",value:stepField(step.id,\.milliseconds),format:.number).textFieldStyle(.roundedBorder).frame(width:90);Text("milliseconds (0–60,000)").font(.caption).foregroundStyle(.secondary)}
                    }
                }.padding(12).background(Color(nsColor:.controlBackgroundColor),in:RoundedRectangle(cornerRadius:10))
            }
            Menu{Button("Shortcut"){model.editButton{$0.steps.append(MacroStep())}};Button("Type text"){model.editButton{$0.steps.append(MacroStep(kind:.text))}};Button("Wait"){model.editButton{$0.steps.append(MacroStep(kind:.delay))}}}label:{Label("Add step",systemImage:"plus")}.disabled(model.button.steps.count>=100)
        }
    }
}
