import AppKit
import SwiftUI
import ThumbKeyCore

private final class ShortcutPanel:NSPanel {
    override var canBecomeKey:Bool{false}
    override var canBecomeMain:Bool{false}
}

final class ShortcutOverlayController {
    private var panel:ShortcutPanel?
    private var monitors=[Any]()
    var onDismiss:(()->Void)?
    var isVisible:Bool{panel?.isVisible == true}

    func show(model:AppModel,whileHeld:Bool=false){
        dismiss()
        guard let screen=NSScreen.screens.first(where:{$0.frame.contains(NSEvent.mouseLocation)}) ?? NSScreen.main else{return}
        let visible=screen.visibleFrame
        let size=NSSize(width:min(720,visible.width-48),height:min(max(320,240+CGFloat(model.configuredShortcuts.count)*76),min(620,visible.height-64)))
        let panel=ShortcutPanel(contentRect:NSRect(origin:.zero,size:size),styleMask:[.borderless,.nonactivatingPanel],backing:.buffered,defer:false)
        panel.title="ThumbKey shortcuts";panel.isReleasedWhenClosed=false
        panel.backgroundColor = .clear;panel.isOpaque=false;panel.hasShadow=true
        panel.level = .floating;panel.collectionBehavior=[.canJoinAllSpaces,.fullScreenAuxiliary]
        panel.hidesOnDeactivate=false;panel.isMovableByWindowBackground=true
        panel.contentView=NSHostingView(rootView:ShortcutOverlayView(model:model,whileHeld:whileHeld,dismiss:{[weak self] in self?.dismiss()}))
        panel.setFrameOrigin(NSPoint(x:visible.midX-size.width/2,y:visible.midY-size.height/2))
        self.panel=panel;panel.orderFrontRegardless()
        // Nonactivating: mouse actions and app profiles keep targeting the user's app.
        if let monitor=NSEvent.addGlobalMonitorForEvents(matching:[.keyDown,.leftMouseDown,.rightMouseDown],handler:{[weak self] event in
            if (event.type == .keyDown && event.keyCode==53) || (!whileHeld && event.type != .keyDown){self?.dismiss()}
        }){monitors.append(monitor)}
        if let monitor=NSEvent.addLocalMonitorForEvents(matching:[.keyDown,.leftMouseDown,.rightMouseDown],handler:{[weak self,weak panel] event in
            if event.type == .keyDown,event.keyCode==53{self?.dismiss();return nil}
            if !whileHeld,event.type != .keyDown,event.window !== panel{self?.dismiss()}
            return event
        }){monitors.append(monitor)}
    }
    func dismiss(){
        guard panel != nil || !monitors.isEmpty else{return}
        monitors.forEach{NSEvent.removeMonitor($0)};monitors=[]
        panel?.orderOut(nil);panel?.contentView=nil;panel=nil
        onDismiss?()
    }
    deinit{dismiss()}
}

private struct ShortcutOverlayView:View {
    @ObservedObject var model:AppModel
    let whileHeld:Bool
    let dismiss:()->Void
    var body:some View {
        VStack(alignment:.leading,spacing:0){
            HStack(alignment:.top,spacing:12){
                Image(nsImage:MouseIllustration.thumbnail(family:model.selectedMouse,plate:model.selectedMouse == .naga ? model.sidePlate:.twelve))
                    .renderingMode(.original).resizable().interpolation(.high).scaledToFit()
                    .frame(width:116,height:116).allowsHitTesting(false)
                    .accessibilityLabel("Static 3D render of " + model.selectedMouse.name + (model.selectedMouse == .naga ? ", " + model.sidePlate.label:""))
                VStack(alignment:.leading,spacing:5){
                    Text("Your shortcuts").font(.title2.bold())
                    Text(model.shortcutContext).font(.subheadline).foregroundStyle(.secondary)
                    if !model.activeAppName.isEmpty{Text("Active app: " + model.activeAppName).font(.caption).foregroundStyle(.secondary)}
                }
                Spacer()
                Button(action:dismiss){Image(systemName:"xmark").font(.body.weight(.medium)).frame(width:28,height:28)}
                    .buttonStyle(.bordered).buttonBorderShape(.circle).accessibilityLabel("Close shortcut overlay")
            }.padding(22)
            if !model.enabled {
                Label(model.mappingStatus,systemImage:"pause.circle").font(.callout).foregroundStyle(.orange).padding(.horizontal,22).padding(.bottom,12)
            }
            Divider().padding(.horizontal,22)
            if model.configuredShortcuts.isEmpty {
                VStack(spacing:10){
                    Image(systemName:"keyboard").font(.largeTitle).foregroundStyle(.secondary)
                    Text("No shortcuts assigned").font(.headline)
                    Text("Choose a mouse button and assign an action in ThumbKey.").font(.callout).foregroundStyle(.secondary)
                }.frame(maxWidth:.infinity,maxHeight:.infinity).padding(24)
            }else{
                ScrollView {
                    LazyVStack(spacing:8){ForEach(model.configuredShortcuts){reference in
                        HStack(spacing:16){
                            Text(reference.buttonName).font(.callout.weight(.medium)).foregroundStyle(.secondary).frame(width:150,alignment:.leading)
                            VStack(alignment:.leading,spacing:4){
                                Text(reference.actionName).font(.body.weight(.semibold)).lineLimit(2)
                                if let issue=model.shortcutIssue(reference){Text(issue).font(.caption).foregroundStyle(.orange)}
                            }
                            Spacer(minLength:8)
                            Text(reference.keys).font(.callout.monospaced()).lineLimit(2).multilineTextAlignment(.trailing)
                                .padding(.horizontal,10).padding(.vertical,7).background(Color.primary.opacity(0.06),in:RoundedRectangle(cornerRadius:7))
                        }.padding(14).frame(maxWidth:.infinity,alignment:.leading)
                            .background(Color.primary.opacity(0.035),in:RoundedRectangle(cornerRadius:11))
                    }}.padding(.horizontal,22).padding(.vertical,14)
                }
            }
            HStack{
                Text(whileHeld ? "Release the mouse button to close. Esc dismisses early.":"Preview · press Esc or click outside to close.")
                Spacer()
                Text("ThumbKey").fontWeight(.medium)
            }.font(.caption).foregroundStyle(.secondary).padding(.horizontal,22).padding(.bottom,18)
        }.modifier(SystemFloatingSurface(cornerRadius: 20))
    }
}
