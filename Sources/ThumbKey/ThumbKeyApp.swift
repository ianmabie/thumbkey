import AppKit
import SwiftUI
import ThumbKeyCore

@main struct ThumbKeyApp:App {
    @StateObject private var model:AppModel
    init(){
        if CommandLine.arguments.contains("--devices") {
            let capture=HIDCapture()
            for i in capture.deviceList {print("\(i.name) | \(i.transport) | product=\(String(format:"%04x",i.productID)) | keyboard interface \(i.id)")}
            print("\(capture.deviceList.count) supported Naga keyboard interfaces; no input capture opened.")
            exit(0)
        }
        _model=StateObject(wrappedValue:AppModel())
    }
    var body:some Scene {
        Window("ThumbKey",id:"main") {ContentView().environmentObject(model).frame(minWidth:920,minHeight:680)}
            .defaultSize(width:1020,height:760)
            .commands {CommandGroup(replacing:.newItem){};CommandGroup(after:.appSettings){Button(model.enabled ? "Pause mappings":"Enable mappings"){model.toggleEnabled()}.keyboardShortcut("p",modifiers:[.command,.option,.control])}}
        MenuBarExtra("ThumbKey",systemImage:model.enabled ? "circle.grid.3x3.fill":"circle.grid.3x3") {
            MenuControls().environmentObject(model)
        }
    }
}
struct MenuControls:View {
    @EnvironmentObject var model:AppModel
    @Environment(\.openWindow) var openWindow
    var body:some View {
        Text(model.deviceName)
        Button("Open ThumbKey"){openWindow(id:"main");NSApp.activate(ignoringOtherApps:true)}
        Button(model.enabled ? "Pause mappings":"Enable mappings"){model.toggleEnabled()}
        Divider()
        Button("Release held keys & pause"){model.pause()}
        Button("Quit ThumbKey"){model.pause();NSApp.terminate(nil)}
    }
}
struct ContentView:View {
    @EnvironmentObject var model:AppModel
    private let accent=Color(red:0.04,green:0.46,blue:0.37)
    var body:some View {
        VStack(spacing:0) {
            HStack(spacing:14){
                Image(systemName:"circle.grid.3x3.fill").font(.system(size:26)).foregroundStyle(accent)
                VStack(alignment:.leading,spacing:3){Text("ThumbKey").font(.title2.bold());Text("Twelve buttons. Your shortcuts.").font(.subheadline).foregroundStyle(.secondary)}
                Spacer()
                VStack(alignment:.trailing,spacing:4){Label(model.enabled ? "Mappings on":"Mappings paused",systemImage:model.enabled ? "circle.fill":"pause.circle").foregroundStyle(model.enabled ? accent:.secondary).font(.subheadline.weight(.medium));Text(model.deviceName).font(.caption).foregroundStyle(.secondary)}
                Button(model.enabled ? "Pause":"Enable mappings"){model.toggleEnabled()}.buttonStyle(.borderedProminent).tint(accent)
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
                    HStack{Text("SIDE BUTTONS").font(.caption.weight(.semibold)).foregroundStyle(.secondary);Spacer();if let last=model.lastButton{Text("Last press: \(last)").font(.caption).foregroundStyle(accent)}}
                    LazyVGrid(columns:Array(repeating:GridItem(.flexible(),spacing:10),count:3),spacing:10){ForEach(model.profile.buttons.sorted{$0.id<$1.id}){button in
                        Button{model.select(button.id)}label:{
                            VStack(alignment:.leading,spacing:10){HStack{Text("\(button.id)").font(.system(size:26,weight:.semibold,design:.rounded));Spacer();if button.id==model.selectedButton{Image(systemName:"checkmark.circle.fill").foregroundStyle(accent)}};Text(button.title).font(.subheadline.weight(.medium)).lineLimit(1);Text(button.detail).font(.caption).foregroundStyle(.secondary).lineLimit(2).frame(maxWidth:.infinity,alignment:.leading)}
                                .padding(14).frame(maxWidth:.infinity,minHeight:104,alignment:.topLeading)
                                .background(button.id==model.selectedButton ? accent.opacity(0.10):Color(nsColor:.controlBackgroundColor),in:RoundedRectangle(cornerRadius:12))
                                .overlay(RoundedRectangle(cornerRadius:12).stroke(button.id==model.selectedButton ? accent:Color.primary.opacity(0.1),lineWidth:button.id==model.selectedButton ? 2:1))
                        }.buttonStyle(.plain).accessibilityLabel("Button \(button.id), \(button.title), \(button.detail)")
                    }}
                    Text("Numbers follow the labels on your 12-button plate. Use Learn if a press activates the wrong slot.").font(.caption).foregroundStyle(.secondary)
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
struct ButtonEditor:View {
    @EnvironmentObject var model:AppModel
    func field<T>(_ key:WritableKeyPath<ButtonBinding,T>)->Binding<T>{Binding(get:{model.button[keyPath:key]},set:{value in model.editButton{$0[keyPath:key]=value}})}
    var body:some View {
        VStack(alignment:.leading,spacing:20){
            HStack{VStack(alignment:.leading,spacing:5){Text("Button \(model.selectedButton)").font(.title2.bold());Text(model.profileIndex==0 ? "Used everywhere unless an app profile overrides it.":"Used when \(model.profile.name) is the active app.").font(.caption).foregroundStyle(.secondary)};Spacer()}
            VStack(alignment:.leading,spacing:6){Text("Name").font(.subheadline.weight(.medium));TextField("What does this button do?",text:field(\.name)).textFieldStyle(.roundedBorder)}
            VStack(alignment:.leading,spacing:6){Text("Action").font(.subheadline.weight(.medium));Picker("Action",selection:field(\.mode)){ForEach(ActionMode.allCases,id:\.self){Text($0.label).tag($0)}}.labelsHidden()}
            if model.button.mode == .shortcut || model.button.mode == .hold {
                VStack(alignment:.leading,spacing:8){
                    Text(model.button.mode == .hold ? "Keys held while the button is down":"Shortcut sent once per press").font(.subheadline.weight(.medium))
                    ShortcutRecorder(chord:field(\.chord),onRecording:model.recordChanged).frame(height:40)
                    Text(model.button.mode == .hold ? "Press a combination on your keyboard. For a modifier alone, press and release it. Releasing the mouse button releases the keys.":"Click the recorder, then press your shortcut on the keyboard.").font(.caption).foregroundStyle(.secondary)
                }
                Button("Use LocalScribe dictation preset"){model.dictationPreset()}.font(.callout)
                if model.button.name=="Dictation"{Text("Holds Control–Option–Space. LocalScribe must be running and configured to use that shortcut.").font(.caption).foregroundStyle(.secondary)}
            }
            if model.button.mode == .passthrough {Text("This button keeps its original keyboard input. Change Action to assign something else.").font(.callout).foregroundStyle(.secondary)}
            if model.button.mode == .disabled {Text("Presses are swallowed while mappings are enabled.").font(.callout).foregroundStyle(.secondary)}
            if model.button.mode == .macro {MacroEditor()}
            Divider()
            VStack(alignment:.leading,spacing:8){
                Text("Physical button").font(.subheadline.weight(.medium))
                Text(model.button.usage.map{"HID key \($0)"} ?? "Not learned").font(.caption.monospaced()).foregroundStyle(.secondary)
                Button(model.learning==model.selectedButton ? "Waiting for side button…":"Learn this button"){model.learn()}.disabled(model.learning != nil)
                Text("Click Learn, then press the matching numbered button on your mouse. This updates the physical mapping across all profiles.").font(.caption).foregroundStyle(.secondary)
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
