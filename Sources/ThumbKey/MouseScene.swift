import AppKit
import SwiftUI
import SceneKit
import ThumbKeyCore

enum MousePresence {case notDetected,receiver,connected}
struct MouseStatus {
    var presence=MousePresence.notDetected
    var connection=MouseConnection.unknown
    var power=MousePower(percent:nil,charging:nil)
    var connected:Bool{presence == .connected}
    var label:String{switch presence{case .notDetected:return "Not detected";case .receiver:return "Receiver detected";case .connected:return "Connected"}}
    var batteryIcon:String {
        if power.charging == true{return "battery.100percent.bolt"}
        guard let percent=power.percent else{return "battery.0percent"}
        return "battery.\(percent<=10 ? 0:percent<=35 ? 25:percent<=60 ? 50:percent<=85 ? 75:100)percent"
    }
}

struct MouseDeviceCard:View {
    @EnvironmentObject var model:AppModel
    let family:MouseFamily
    private var selected:Bool{model.selectedMouse==family}
    private var status:MouseStatus{model.status(for:family)}
    var body:some View {
        Button{model.selectMouse(family)}label:{
            HStack(spacing:7){
                Image(nsImage:MouseIllustration.thumbnail(family:family,plate:family == .naga ? model.sidePlate:.twelve))
                    .renderingMode(.original).resizable().interpolation(.high).frame(width:76,height:78).opacity(status.presence == .notDetected ? 0.3:1).accessibilityHidden(true)
                VStack(alignment:.leading,spacing:5){
                    HStack(spacing:5){Text(family == .naga ? "Naga V3 Pro":"MX Master 3S").font(.caption.weight(.semibold));if selected{Image(systemName:"checkmark.circle.fill").foregroundStyle(.teal)}}
                    HStack(spacing:4){
                        Circle().fill(status.connected ? Color.teal:status.presence == .receiver ? Color.orange:Color.secondary).frame(width:5,height:5)
                        Text(status.label).fontWeight(.medium)
                    }.font(.system(size:10)).foregroundStyle(status.presence == .notDetected ? .secondary:.primary)
                    if status.presence != .notDetected{Text(status.connection.rawValue).font(.system(size:10)).foregroundStyle(.secondary)}
                    if status.power.percent != nil && status.connected{
                        Label(status.power.label,systemImage:status.batteryIcon).font(.system(size:10)).foregroundStyle(.secondary)
                    }else if status.presence == .notDetected{
                        Text("Edit saved mappings").font(.system(size:10)).foregroundStyle(.secondary)
                    }
                }
            }.padding(.horizontal,8).frame(height:88)
                .background(selected ? Color.teal.opacity(status.presence == .notDetected ? 0.04:0.09):Color(nsColor:.controlBackgroundColor),in:RoundedRectangle(cornerRadius:13))
                .overlay(RoundedRectangle(cornerRadius:13).stroke(selected ? Color.teal:Color.primary.opacity(0.15),style:StrokeStyle(lineWidth:selected ? 2:1,dash:status.presence == .notDetected ? [4,3]:[])))
        }.buttonStyle(.plain).help(status.presence == .receiver ? "The wireless receiver is present. Move or press the mouse to confirm it is awake.":status.presence == .notDetected ? "Connect this mouse to use its mappings. You can edit saved mappings while it is disconnected.":family.name)
            .accessibilityLabel("Select \(family.name). \(selected ? "Selected. ":"")\(status.label). \(status.presence == .notDetected ? "Edit saved mappings.":status.connection.rawValue)\(status.connected && status.power.percent != nil ? ", "+status.power.label:"")")
    }
}

struct MouseMappingScene:View {
    @EnvironmentObject var model:AppModel
    @State private var cameraRequest=UUID()
    @State private var manuallyRotated=false
    @State private var angle=MouseViewAngle.overview
    var body:some View {
        VStack(spacing:8){
            HStack{Text(model.selectedMouse == .naga ? "BUTTON MAP · \(model.sidePlate.rawValue)-BUTTON PLATE":"BUTTON MAP").font(.caption.weight(.semibold)).foregroundStyle(.secondary);Spacer();Button{angle = .overview;manuallyRotated=false;cameraRequest=UUID()}label:{Image(systemName:"arrow.counterclockwise")}.buttonStyle(.plain).help("Reset 3D view")}
            HStack(spacing:2){ForEach(MouseViewAngle.allCases){preset in
                Button{angle=preset;manuallyRotated=false;cameraRequest=UUID()}label:{
                    Text(preset.title).font(.caption).frame(maxWidth:.infinity).padding(.vertical,5)
                        .background(!manuallyRotated && angle==preset ? Color(nsColor:.controlBackgroundColor):Color.clear,in:RoundedRectangle(cornerRadius:5))
                }.buttonStyle(.plain).accessibilityLabel(preset.title)
                    .accessibilityAddTraits(!manuallyRotated && angle==preset ? .isSelected:[])
            }}.padding(3).background(Color.primary.opacity(0.06),in:RoundedRectangle(cornerRadius:8))
            MouseSceneView(family:model.selectedMouse,plate:model.sidePlate,selected:model.selectedButton,interactive:true,angle:angle,cameraRequest:cameraRequest,onRotate:{manuallyRotated=true},onSelect:model.select)
                .accessibilityLabel("Rotatable 3D mouse illustration. Switch to List view to select a mapping with the keyboard.")
            HStack(spacing:5){Text("Drag to rotate");Spacer();Text("3D illustration").help("Built-in illustration with approximate button positions, not a manufacturer scan.")}.font(.system(size:10)).foregroundStyle(.secondary)
            HStack(spacing:6){Circle().fill(.teal).frame(width:6,height:6);Text(MouseControls.title(model.selectedButton)).fontWeight(.medium);Text("·");Text(model.button.detail).lineLimit(1);Spacer()}.font(.caption)
        }.padding(14).background(Color(nsColor:.controlBackgroundColor),in:RoundedRectangle(cornerRadius:14))
            .onChange(of:model.selectedMouse){_,_ in manuallyRotated=false;cameraRequest=UUID()}
            .onChange(of:model.sidePlate){_,_ in manuallyRotated=false;cameraRequest=UUID()}
    }
}

private final class MouseSCNView:SCNView {
    var choose:((Int)->Void)?
    var onRotate:(()->Void)?
    override func mouseDragged(with event:NSEvent){onRotate?();super.mouseDragged(with:event)}
    let loading=NSProgressIndicator()
    override func scrollWheel(with event:NSEvent){
        // Let the surrounding page scroll without changing the model's camera.
        nextResponder?.scrollWheel(with:event)
    }
    override func mouseDown(with event:NSEvent){
        let point=convert(event.locationInWindow,from:nil)
        for hit in hitTest(point,options:[.searchMode:SCNHitTestSearchMode.closest.rawValue]) {
            var node:SCNNode?=hit.node
            while let current=node {
                if let name=current.name,name.hasPrefix("button-"),let id=Int(name.dropFirst(7)){choose?(id);return}
                node=current.parent
            }
        }
        super.mouseDown(with:event)
    }
}

struct MouseSceneView:NSViewRepresentable {
    let family:MouseFamily
    let plate:SidePlate
    let selected:Int?
    let interactive:Bool
    var angle=MouseViewAngle.overview
    let cameraRequest:UUID
    let onRotate:()->Void
    let onSelect:(Int)->Void
    final class Coordinator {
        struct Asset {
            let scene:SCNScene,camera:SCNNode
            let buttons:[Int:SCNNode]
            let colors:[Int:NSColor],legends:[Int:NSColor]
            init(family:MouseFamily,plate:SidePlate,interactive:Bool){
                let result=MouseIllustration.make(family:family,plate:plate,hotspots:interactive)
                scene=result.0;camera=result.1;buttons=result.2
                colors=result.2.mapValues{$0.geometry?.firstMaterial?.diffuse.contents as? NSColor ?? .darkGray}
                legends=result.2.mapValues{$0.childNodes.first(where:{$0.geometry is SCNText})?.geometry?.firstMaterial?.diffuse.contents as? NSColor ?? .white}
            }
        }
        private let queue=DispatchQueue(label:"personal.thumbkey.models",qos:.userInitiated)
        private var assets=[String:Asset](),pending=Set<String>()
        private var currentKey="",angle=MouseViewAngle.overview,selected:Int?,interactive=true
        private var installedKey="",installedAngle:MouseViewAngle?
        private var request=UUID(),installedRequest:UUID?
        private func key(_ family:MouseFamily,_ plate:SidePlate,_ interactive:Bool)->String{"\(family.rawValue)-\(family == .naga ? plate.rawValue:12)-\(interactive)"}
        func update(_ view:SCNView,family:MouseFamily,plate:SidePlate,selected:Int?,interactive:Bool,angle:MouseViewAngle,cameraRequest:UUID){
            currentKey=key(family,plate,interactive);self.selected=selected;self.angle=angle;self.interactive=interactive;request=cameraRequest
            if let asset=assets[currentKey]{install(asset,in:view)}else{
                view.scene=nil;installedKey="";installedAngle=nil
                (view as? MouseSCNView)?.loading.startAnimation(nil)
                build(family,plate,interactive,view:view)
            }
            // Warm the other selector card's full scene without blocking the interface.
            build(family == .naga ? .mxMaster3s:.naga,.twelve,interactive,view:view)
        }
        private func build(_ family:MouseFamily,_ plate:SidePlate,_ interactive:Bool,view:SCNView){
            let assetKey=key(family,plate,interactive)
            guard assets[assetKey]==nil,pending.insert(assetKey).inserted else{return}
            queue.async{[weak self,weak view] in
                let asset=Asset(family:family,plate:plate,interactive:interactive)
                DispatchQueue.main.async{
                    guard let self else{return};self.pending.remove(assetKey);self.assets[assetKey]=asset
                    if self.currentKey==assetKey,let view{self.install(asset,in:view)}
                }
            }
        }
        private func install(_ asset:Asset,in view:SCNView){
            if installedKey != currentKey {
                view.defaultCameraController.stopInertia();view.scene=asset.scene;view.pointOfView=asset.camera
                installedKey=currentKey;installedAngle=nil;installedRequest=nil
            }
            (view as? MouseSCNView)?.loading.stopAnimation(nil)
            if installedAngle != angle || installedRequest != request {
                view.defaultCameraController.stopInertia()
                SCNTransaction.begin();SCNTransaction.disableActions=true
                // SceneKit may switch to an interactive camera while orbiting.
                // Explicit commands always reclaim the original camera and pose.
                asset.camera.transform=SCNMatrix4Identity
                MouseIllustration.position(asset.camera,angle:angle,thumbnail:!interactive)
                view.pointOfView=asset.camera
                view.defaultCameraController.pointOfView=asset.camera
                view.defaultCameraController.automaticTarget=false
                view.defaultCameraController.target=SCNVector3(-4,20,0)
                SCNTransaction.commit()
                installedAngle=angle;installedRequest=request
            }
            for (id,node) in asset.buttons {
                node.geometry?.firstMaterial?.diffuse.contents=id==selected ? NSColor(red:0.07,green:0.46,blue:0.49,alpha:1):asset.colors[id]
                node.geometry?.firstMaterial?.emission.contents=id==selected ? NSColor(red:0.01,green:0.06,blue:0.065,alpha:1):NSColor.black
                for child in node.childNodes where child.geometry is SCNText {
                    child.geometry?.firstMaterial?.diffuse.contents=id==selected ? NSColor.white:asset.legends[id]
                }
            }
        }
    }
    func makeCoordinator()->Coordinator{Coordinator()}
    func makeNSView(context:Context)->SCNView {
        let view=MouseSCNView()
        view.backgroundColor = .clear;view.antialiasingMode = .multisampling4X
        view.allowsCameraControl=interactive;view.autoenablesDefaultLighting=false
        view.defaultCameraController.interactionMode = .orbitArcball
        view.defaultCameraController.inertiaEnabled=true
        view.defaultCameraController.automaticTarget=false
        view.defaultCameraController.target=SCNVector3(-4,20,0)
        view.loading.style = .spinning;view.loading.controlSize = .small;view.loading.isDisplayedWhenStopped=false
        view.loading.translatesAutoresizingMaskIntoConstraints=false;view.addSubview(view.loading)
        NSLayoutConstraint.activate([view.loading.centerXAnchor.constraint(equalTo:view.centerXAnchor),view.loading.centerYAnchor.constraint(equalTo:view.centerYAnchor)])
        updateNSView(view,context:context);return view
    }
    func updateNSView(_ view:SCNView,context:Context){
        (view as? MouseSCNView)?.choose=onSelect
        (view as? MouseSCNView)?.onRotate=onRotate
        context.coordinator.update(view,family:family,plate:plate,selected:selected,interactive:interactive,angle:angle,cameraRequest:cameraRequest)
    }
}
