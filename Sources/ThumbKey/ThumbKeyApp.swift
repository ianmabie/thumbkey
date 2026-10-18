import AppKit
import SwiftUI
import ThumbKeyCore

@main struct ThumbKeyApp:App {
    @StateObject private var model:AppModel
    init(){
        if CommandLine.arguments.contains("--devices") {
            let capture=HIDCapture()
            for i in capture.deviceList {print("\(i.name) | \(i.transport) | product=\(String(format:"%04x",i.productID)) | input interface \(i.id)")}
            print("\(capture.deviceList.count) supported Naga input interfaces; no input capture opened.")
            exit(0)
        }
        if CommandLine.arguments.contains("--check-extra-mode") {
            let mode=NagaDriverMode()
            do {
                try mode.activate();print("Confirmed temporary extra-button reporting mode (03 00).")
                try mode.restore();print("Confirmed restoration of the original reporting mode.");exit(0)
            } catch {print("Extra-button mode check failed: \(error.localizedDescription)");exit(1)}
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
            HStack(spacing:14){
                Image(systemName:"circle.grid.3x3.fill").font(.system(size:26)).foregroundStyle(accent)
                VStack(alignment:.leading,spacing:3){Text("ThumbKey").font(.title2.bold());Text("Your mouse. Your shortcuts.").font(.subheadline).foregroundStyle(.secondary)}
                Spacer()
                VStack(alignment:.trailing,spacing:4){Label(model.mappingStatus,systemImage:model.enabled ? "circle.fill":"exclamationmark.circle").foregroundStyle(model.enabled ? accent:Color.orange).font(.subheadline.weight(.medium));Text(model.deviceName).font(.caption).foregroundStyle(.secondary)}
                Button(model.wantsMappings ? "Pause":"Enable mappings"){model.toggleEnabled()}.buttonStyle(.borderedProminent).tint(accent)
            }.padding(24)
            Divider()
            if !model.inputAllowed || !model.accessibilityAllowed {
                HStack(alignment:.center,spacing:16){Image(systemName:"hand.raised").font(.title2);VStack(alignment:.leading,spacing:4){Text("Allow ThumbKey to remap your side pad").font(.headline);Text("Input Monitoring reads the Naga buttons. Accessibility sends your chosen shortcuts.").font(.caption).foregroundStyle(.secondary)};Spacer();Button(model.inputAllowed ? "Input Monitoring ✓":"Allow Input Monitoring"){model.requestInput()}.disabled(model.inputAllowed);Button(model.accessibilityAllowed ? "Accessibility ✓":"Allow Accessibility"){model.requestAccessibility()}.disabled(model.accessibilityAllowed)}.padding(16).background(accent.opacity(0.06));Divider()
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
                    Text("SIDE PLATE").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                    Picker("Attached side plate",selection:Binding(get:{model.sidePlate},set:{model.selectPlate($0)})) {
                        ForEach(SidePlate.allCases){plate in Text("\(plate.rawValue) buttons").tag(plate)}
                    }.pickerStyle(.segmented)
                    Text("Select the attached plate after swapping it. Each plate saves its own mappings; automatic detection is not available yet.").font(.caption).foregroundStyle(.secondary)
                    LazyVGrid(columns:Array(repeating:GridItem(.flexible(),spacing:10),count:model.sidePlate == .two ? 2:3),spacing:10){
                        ForEach(model.sideButtons){button in ButtonTile(button:button)}
                    }
                    Divider()
                    HStack{Text("TOP & RING-FINGER BUTTONS").font(.caption.weight(.semibold)).foregroundStyle(.secondary);Spacer()}
                    Toggle("Enable extra-button reporting",isOn:Binding(get:{model.extraButtonsEnabled},set:{model.setExtraButtons($0)}))
                    Text("Uses a temporary mouse mode over USB or the USB receiver. The original mode returns when you pause or quit. Unassigned extra buttons may stop their usual DPI or wheel functions while enabled.").font(.caption).foregroundStyle(.secondary)
                    VStack(spacing:8){ForEach(model.extraButtons){button in ButtonTile(button:button,compact:true)}}
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
                    HStack(spacing:12){Image(systemName:selected ? "checkmark.circle.fill":"circle").foregroundStyle(selected ? accent:Color.secondary);VStack(alignment:.leading,spacing:4){Text(MouseControls.title(button.id)).font(.subheadline.weight(.medium));Text(button.detail).font(.caption).foregroundStyle(.secondary)};Spacer()}
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
            VStack(alignment:.leading,spacing:6){Text("Action").font(.subheadline.weight(.medium));Picker("Action",selection:field(\.mode)){ForEach(ActionMode.allCases,id:\.self){Text($0.label).tag($0)}}.labelsHidden();Text(model.button.mode.explanation).font(.callout).foregroundStyle(.secondary)}
            if model.button.mode == .shortcut || model.button.mode == .hold {
                VStack(alignment:.leading,spacing:8){
                    Text(model.button.mode == .hold ? "Keys held while the button is down":"Shortcut sent once per press").font(.subheadline.weight(.medium))
                    ShortcutRecorder(chord:field(\.chord),onRecording:model.recordChanged).frame(height:40)
                    Text(model.button.mode == .hold ? "Press a combination on your keyboard. For a modifier alone, press and release it. Releasing the mouse button releases the keys.":"Click the recorder, then press your shortcut on the keyboard.").font(.caption).foregroundStyle(.secondary)
                }
            }
            Menu {
                Button("Superwhispr · Hold Right Command"){model.rightCommandPreset()}
                Button("LocalScribe · Hold Control–Option–Space"){model.dictationPreset()}
            } label:{Label("Fill in a dictation shortcut",systemImage:"waveform")}
            if model.button.mode == .hold && model.button.chord.keys == Chord.rightCommand.keys {
                Text("This fills in Hold Right Command. Choose Right Command as the push-to-talk key in Superwhispr, and keep Superwhispr running.").font(.caption).foregroundStyle(.secondary)
            } else if model.button.mode == .hold && model.button.chord.keys == Chord(keyCode:49,modifiers:[.control,.option]).keys {
                Text("This fills in Hold Control–Option–Space. LocalScribe must be running with the same dictation shortcut. This does not launch or configure LocalScribe.").font(.caption).foregroundStyle(.secondary)
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
                Button(model.learning==model.selectedButton ? "Press the mouse button now…":"Identify this physical button…"){model.learn()}.disabled(model.learning != nil || (MouseControls.extraIDs.contains(model.selectedButton) && !model.extraButtonsActive))
                Text("Only needed if this slot does not respond, or responds to the wrong button. Click Identify, then press this button on the mouse. This teaches ThumbKey which input belongs here; it does not choose an action. Applies to all app profiles for this plate.").font(.caption).foregroundStyle(.secondary)
                if MouseControls.extraIDs.contains(model.selectedButton),!model.extraButtonsActive {
                    Text("Enable extra-button reporting and mappings first.").font(.caption).foregroundStyle(.secondary)
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
