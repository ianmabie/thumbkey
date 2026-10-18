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
                Image(nsImage:MouseIllustration.thumbnail(family:family,plate:family == .naga ? model.sidePlate:.twelve))
                    .renderingMode(.original).resizable().interpolation(.high).frame(width:76,height:78).accessibilityHidden(true)
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
    @State private var angle=MouseViewAngle.overview
    var body:some View {
        VStack(spacing:8){
            HStack{Text(model.selectedMouse == .naga ? "BUTTON MAP · \(model.sidePlate.rawValue)-BUTTON PLATE":"BUTTON MAP").font(.caption.weight(.semibold)).foregroundStyle(.secondary);Spacer();Button{resetID=UUID()}label:{Image(systemName:"arrow.counterclockwise")}.buttonStyle(.plain).help("Reset 3D view")}
            Picker("View angle",selection:$angle){ForEach(MouseViewAngle.allCases){angle in Text(angle.title).tag(angle)}}.pickerStyle(.segmented)
            MouseSceneView(family:model.selectedMouse,plate:model.sidePlate,selected:model.selectedButton,interactive:true,angle:angle,onSelect:model.select).id(resetID)
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
    let onSelect:(Int)->Void
    final class Coordinator {
        var family:MouseFamily?;var plate:SidePlate?;var angle:MouseViewAngle?
        var buttons=[Int:SCNNode]()
        var baseColors=[Int:NSColor]()
        var baseLegendColors=[Int:NSColor]()
    }
    func makeCoordinator()->Coordinator{Coordinator()}
    func makeNSView(context:Context)->SCNView {
        let view=MouseSCNView()
        view.backgroundColor = .clear;view.antialiasingMode = .multisampling4X
        view.allowsCameraControl=interactive;view.autoenablesDefaultLighting=false
        view.defaultCameraController.interactionMode = .orbitTurntable
        view.defaultCameraController.inertiaEnabled=true
        view.defaultCameraController.automaticTarget=false
        view.defaultCameraController.target=SCNVector3(-4,20,0)
        view.defaultCameraController.minimumVerticalAngle=8
        view.defaultCameraController.maximumVerticalAngle=85
        view.choose=onSelect
        updateNSView(view,context:context);return view
    }
    func updateNSView(_ view:SCNView,context:Context){
        if context.coordinator.family != family || context.coordinator.plate != plate {
            let result=MouseIllustration.make(family:family,plate:plate,hotspots:interactive)
            view.scene=result.0;view.pointOfView=result.1;context.coordinator.buttons=result.2
            context.coordinator.baseColors=result.2.mapValues{$0.geometry?.firstMaterial?.diffuse.contents as? NSColor ?? .darkGray}
            context.coordinator.baseLegendColors=result.2.mapValues{$0.childNodes.first(where:{$0.geometry is SCNText})?.geometry?.firstMaterial?.diffuse.contents as? NSColor ?? .white}
            context.coordinator.family=family;context.coordinator.plate=plate;context.coordinator.angle=nil
        }
        if context.coordinator.angle != angle {
            if let camera=view.pointOfView {MouseIllustration.position(camera,angle:angle,thumbnail:!interactive)}
            context.coordinator.angle=angle
        }
        (view as? MouseSCNView)?.choose=onSelect
        for (id,node) in context.coordinator.buttons {
            node.geometry?.firstMaterial?.diffuse.contents=id==selected ? NSColor(red:0.07,green:0.46,blue:0.49,alpha:1):(context.coordinator.baseColors[id] ?? .darkGray)
            node.geometry?.firstMaterial?.emission.contents=id==selected ? NSColor(red:0.01,green:0.06,blue:0.065,alpha:1):NSColor.black
            for child in node.childNodes where child.geometry is SCNText {
                child.geometry?.firstMaterial?.diffuse.contents=id==selected ? NSColor.white:(context.coordinator.baseLegendColors[id] ?? .white)
            }
        }
    }
}
