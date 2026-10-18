import AppKit
import SwiftUI
import SceneKit
import ThumbKeyCore

struct MouseStatus {
    var connected=false
    var connection=MouseConnection.unknown
    var power=MousePower(percent:nil,charging:nil)
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
                MouseSceneView(family:family,plate:.twelve,selected:nil,interactive:false,onSelect:{_ in}).frame(width:76,height:78).allowsHitTesting(false).accessibilityHidden(true)
                VStack(alignment:.leading,spacing:5){
                    HStack(spacing:5){Text(family == .naga ? "Naga V3 Pro":"MX Master 3S").font(.caption.weight(.semibold));if selected{Image(systemName:"checkmark.circle.fill").foregroundStyle(.teal)}}
                    Text(status.connected ? status.connection.rawValue:"Not connected").font(.system(size:10)).foregroundStyle(.secondary)
                    Label(status.connected ? status.power.label:"—",systemImage:status.batteryIcon).font(.system(size:10)).foregroundStyle(.secondary)
                }
            }.padding(.horizontal,8).frame(height:88)
                .background(selected ? Color.teal.opacity(0.09):Color(nsColor:.controlBackgroundColor),in:RoundedRectangle(cornerRadius:13))
                .overlay(RoundedRectangle(cornerRadius:13).stroke(selected ? Color.teal:Color.primary.opacity(0.10),lineWidth:selected ? 2:1))
        }.buttonStyle(.plain).accessibilityLabel("Select \(family.name). \(selected ? "Selected. ":"")\(status.connected ? status.connection.rawValue+", "+status.power.label:"Not connected")")
    }
}

struct MouseMappingScene:View {
    @EnvironmentObject var model:AppModel
    @State private var resetID=UUID()
    var body:some View {
        VStack(spacing:8){
            HStack{Text("BUTTON MAP").font(.caption.weight(.semibold)).foregroundStyle(.secondary);Spacer();Button{resetID=UUID()}label:{Image(systemName:"arrow.counterclockwise")}.buttonStyle(.plain).help("Reset 3D view")}
            MouseSceneView(family:model.selectedMouse,plate:model.sidePlate,selected:model.selectedButton,interactive:true,onSelect:model.select).id(resetID)
                .accessibilityLabel("Rotatable 3D mouse illustration. Use the button list below to select a mapping with the keyboard.")
            HStack(spacing:5){Text("Drag to rotate · scroll to zoom");Spacer();Text("3D illustration").help("Built-in illustration with approximate button positions, not a manufacturer scan.")}.font(.system(size:10)).foregroundStyle(.secondary)
            HStack(spacing:6){Circle().fill(.teal).frame(width:6,height:6);Text(MouseControls.title(model.selectedButton)).fontWeight(.medium);Text("·");Text(model.button.detail).lineLimit(1);Spacer()}.font(.caption)
        }.padding(14).background(Color(nsColor:.controlBackgroundColor),in:RoundedRectangle(cornerRadius:14))
    }
}

private final class MouseSCNView:SCNView {
    var choose:((Int)->Void)?
    override func mouseDown(with event:NSEvent){
        let point=convert(event.locationInWindow,from:nil)
        for hit in hitTest(point,options:[:]) {
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
    let onSelect:(Int)->Void
    final class Coordinator {
        var family:MouseFamily?;var plate:SidePlate?
        var buttons=[Int:SCNNode]()
    }
    func makeCoordinator()->Coordinator{Coordinator()}
    func makeNSView(context:Context)->SCNView {
        let view=MouseSCNView()
        view.backgroundColor = .clear;view.antialiasingMode = .multisampling4X
        view.allowsCameraControl=interactive;view.autoenablesDefaultLighting=false
        view.defaultCameraController.interactionMode = .orbitTurntable
        view.defaultCameraController.inertiaEnabled=true
        view.defaultCameraController.minimumVerticalAngle=8
        view.defaultCameraController.maximumVerticalAngle=85
        view.choose=onSelect
        updateNSView(view,context:context);return view
    }
    func updateNSView(_ view:SCNView,context:Context){
        if context.coordinator.family != family || context.coordinator.plate != plate {
            let result=MouseIllustration.make(family:family,plate:plate,hotspots:interactive)
            view.scene=result.0;view.pointOfView=result.1;context.coordinator.buttons=result.2
            context.coordinator.family=family;context.coordinator.plate=plate
        }
        (view as? MouseSCNView)?.choose=onSelect
        for (id,node) in context.coordinator.buttons {
            node.geometry?.firstMaterial?.diffuse.contents=id==selected ? NSColor.systemTeal:NSColor(calibratedWhite:0.27,alpha:1)
            node.geometry?.firstMaterial?.emission.contents=id==selected ? NSColor.systemTeal.withAlphaComponent(0.3):NSColor.black
        }
    }
}

/// Original procedural illustrations. Coordinates indicate locations, not measured CAD geometry.
private enum MouseIllustration {
    static func material(_ color:NSColor,metal:CGFloat=0,rough:CGFloat=0.65)->SCNMaterial {
        let m=SCNMaterial();m.lightingModel = .blinn;m.diffuse.contents=color;m.metalness.contents=metal;m.roughness.contents=rough;m.specular.contents=NSColor(calibratedWhite:0.3,alpha:1);m.shininess=0.25;return m
    }
    static func make(family:MouseFamily,plate:SidePlate,hotspots:Bool)->(SCNScene,SCNNode,[Int:SCNNode]) {
        let scene=SCNScene();var buttons=[Int:SCNNode]()
        let shell=material(NSColor(calibratedWhite:0.17,alpha:1)),rubber=material(NSColor(calibratedWhite:0.10,alpha:1))
        let root=scene.rootNode
        func box(_ size:SCNVector3,_ position:SCNVector3,_ mat:SCNMaterial,radius:CGFloat=0.04)->SCNNode{
            let mesh=SCNBox(width:CGFloat(size.x),height:CGFloat(size.y),length:CGFloat(size.z),chamferRadius:radius);mesh.materials=[mat]
            let node=SCNNode(geometry:mesh);node.position=position;root.addChildNode(node);return node
        }
        func sphere(_ scale:SCNVector3,_ position:SCNVector3,_ mat:SCNMaterial)->SCNNode{
            let mesh=SCNSphere(radius:1);mesh.segmentCount=48;mesh.materials=[mat]
            let node=SCNNode(geometry:mesh);node.scale=scale;node.position=position;root.addChildNode(node);return node
        }
        _=sphere(SCNVector3(0.64,0.39,1.02),SCNVector3(0,0.31,0.10),shell)
        _=box(SCNVector3(1.03,0.13,1.67),SCNVector3(0,0.14,0.05),rubber,radius:0.065)
        if family == .mxMaster3s {
            let rest=sphere(SCNVector3(0.45,0.07,0.69),SCNVector3(-0.58,0.12,0.18),rubber);rest.eulerAngles.z = -0.13
            for n in 0..<6 {let ridge=box(SCNVector3(0.045,0.035,0.55),SCNVector3(-0.59,0.24+Float(n)*0.042,0.43),shell,radius:0.017);ridge.eulerAngles.z = -0.4}
        } else {
            _=sphere(SCNVector3(0.21,0.13,0.67),SCNVector3(0.57,0.22,0.16),rubber)
        }
        let clickMat=material(NSColor(calibratedWhite:0.21,alpha:1))
        for x:Float in [-0.29,0.29] {let click=box(SCNVector3(0.54,0.07,0.70),SCNVector3(x,0.57,-0.53),clickMat);click.eulerAngles.x = -0.18}
        let wheel=SCNCylinder(radius:0.15,height:0.16);wheel.materials=[material(NSColor(calibratedWhite:0.55,alpha:1),metal:0.8,rough:0.3)]
        let wheelNode=SCNNode(geometry:wheel);wheelNode.eulerAngles.z = .pi/2;wheelNode.position=SCNVector3(0,0.65,-0.65);root.addChildNode(wheelNode)
        for i in 0..<18 {
            let ring=SCNTorus(ringRadius:0.151,pipeRadius:0.006);ring.materials=[rubber]
            let node=SCNNode(geometry:ring);node.eulerAngles.z = .pi/2;node.position=SCNVector3(-0.075+Float(i)*0.009,0.65,-0.65);root.addChildNode(node)
        }
        var points=[Int:SCNVector3]()
        if family == .mxMaster3s {
            let thumbWheel=SCNCylinder(radius:0.12,height:0.27);thumbWheel.materials=[material(.lightGray,metal:0.8,rough:0.3)]
            let node=SCNNode(geometry:thumbWheel);node.eulerAngles.x = .pi/2;node.position=SCNVector3(-0.60,0.46,-0.27);root.addChildNode(node)
            points=[301:SCNVector3(-0.64,0.34,0.17),302:SCNVector3(-0.64,0.34,-0.10),303:SCNVector3(0,0.83,-0.65),304:SCNVector3(-0.83,0.20,0.28),305:SCNVector3(0,0.68,-0.29)]
        } else {
            let ids=plate.buttonIDs
            let columns=plate == .two ? 2:3
            for (offset,id) in ids.enumerated(){
                let row=offset/columns,col=offset%columns
                points[id]=SCNVector3(-0.64,0.51-Float(row)*0.105,Float(col)*0.28-0.36)
                if !hotspots{_=box(SCNVector3(0.08,0.085,0.22),points[id]!,rubber,radius:0.02)}
            }
            points[13]=SCNVector3(-0.49,0.65,-0.73);points[14]=SCNVector3(-0.49,0.68,-0.48)
            points[15]=SCNVector3(0,0.70,-0.23);points[16]=SCNVector3(0,0.71,0.02);points[17]=SCNVector3(0.67,0.42,-0.10)
        }
        for (id,point) in points {
            let mesh=SCNSphere(radius:hotspots ? 0.066:0.045);mesh.materials=[material(NSColor(calibratedWhite:0.27,alpha:1))]
            let node=SCNNode(geometry:mesh);node.position=point;node.name="button-\(id)";root.addChildNode(node);buttons[id]=node
            if hotspots {
                let text=SCNText(string:family == .naga ? "\(MouseControls.number(id))":"\(id-300)",extrusionDepth:0.1)
                text.font=NSFont.systemFont(ofSize:1,weight:.bold);text.flatness=0.1;text.materials=[material(.white)]
                let label=SCNNode(geometry:text);let bounds=text.boundingBox
                label.pivot=SCNMatrix4MakeTranslation((bounds.max.x+bounds.min.x)/2,(bounds.max.y+bounds.min.y)/2,0)
                label.scale=SCNVector3(0.075,0.075,0.075);label.position=SCNVector3(-0.035,0.035,-0.07)
                label.constraints=[SCNBillboardConstraint()];label.renderingOrder=10;text.firstMaterial?.readsFromDepthBuffer=false
                node.addChildNode(label)
            }
        }
        let camera=SCNNode();camera.camera=SCNCamera();camera.camera?.usesOrthographicProjection=true;camera.camera?.orthographicScale=1.15
        camera.position=SCNVector3(-3.2,2.6,-3.8);camera.look(at:SCNVector3(-0.08,0.28,0));root.addChildNode(camera)
        let key=SCNNode();key.light=SCNLight();key.light?.type = .omni;key.light?.intensity=650;key.position=SCNVector3(-3,5,-4);root.addChildNode(key)
        let fill=SCNNode();fill.light=SCNLight();fill.light?.type = .omni;fill.light?.intensity=300;fill.position=SCNVector3(3,2,2);root.addChildNode(fill)
        let ambient=SCNNode();ambient.light=SCNLight();ambient.light?.type = .ambient;ambient.light?.intensity=100;root.addChildNode(ambient)
        return (scene,camera,buttons)
    }
}
