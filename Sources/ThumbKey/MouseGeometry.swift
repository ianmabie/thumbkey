import AppKit
import SceneKit
import Metal
import simd
import ThumbKeyCore

enum MouseViewAngle:String,CaseIterable,Identifiable {
    case overview,left,top,right
    var id:String{rawValue}
    var title:String{switch self{case .overview:return "Overview";case .left:return "Thumb";case .top:return "Top";case .right:return "Right"}}
}

/// Original meshes modeled from multi-angle manufacturer photos; dimensions/locations are approximate.
/// Geometry is generated offline with no downloaded textures or third-party models.
enum MouseIllustration {
    static func make(family:MouseFamily,plate:SidePlate,hotspots:Bool)->(SCNScene,SCNNode,[Int:SCNNode]) {
        let builder=MouseMeshBuilder(family:family,hotspots:hotspots)
        builder.shell();builder.clicks();builder.wheels()
        if family == .naga{builder.nagaPlate(plate);builder.nagaExtras()}else{builder.mxThumbRest();builder.mxButtons()}
        builder.underside();builder.port();builder.brand()
        let camera=SCNNode();camera.camera=SCNCamera();camera.camera?.usesOrthographicProjection=true
        camera.camera?.zNear=0.1;camera.camera?.zFar=1500
        camera.camera?.screenSpaceAmbientOcclusionIntensity=0
        camera.camera?.screenSpaceAmbientOcclusionRadius=5
        position(camera,angle:.overview,thumbnail:!hotspots);builder.root.addChildNode(camera)
        for (position,power) in [(SCNVector3(-90,150,-130),CGFloat(900)),(SCNVector3(100,100,50),CGFloat(650))] {
            let light=SCNNode();light.light=SCNLight();light.light?.type = .omni;light.light?.intensity=power;light.position=position;builder.root.addChildNode(light)
        }
        let ambient=SCNNode();ambient.light=SCNLight();ambient.light?.type = .ambient;ambient.light?.intensity=260;builder.root.addChildNode(ambient)
        return(builder.scene,camera,builder.buttons)
    }
    static func position(_ camera:SCNNode,angle:MouseViewAngle,thumbnail:Bool){
        let target=SCNVector3(-4,20,0)
        switch angle {
        case .overview:camera.position=SCNVector3(-155,115,-165)
        case .left:camera.position=SCNVector3(-220,65,-25)
        case .right:camera.position=SCNVector3(220,85,-30)
        case .top:camera.position=SCNVector3(-4,270,-0.1)
        }
        if angle == .top{camera.look(at:target,up:SCNVector3(0,0,-1),localFront:SCNVector3(0,0,-1))}else{camera.look(at:target)}
        camera.camera?.orthographicScale=thumbnail ? 66:angle == .top ? 78:62
    }
    static func exportPreviews(to directory:URL)throws {
        try FileManager.default.createDirectory(at:directory,withIntermediateDirectories:true)
        for family in MouseFamily.allCases {
            let plates:[SidePlate]=family == .naga ? [.twelve,.six,.two]:[.twelve]
            for plate in plates {
            let angles:[MouseViewAngle]=plate == .twelve ? MouseViewAngle.allCases:[.overview,.left]
            for angle in angles {
                let (scene,camera,_)=make(family:family,plate:plate,hotspots:true)
                position(camera,angle:angle,thumbnail:false)
                let renderer=SCNRenderer(device:MTLCreateSystemDefaultDevice(),options:nil);renderer.scene=scene;renderer.pointOfView=camera
                scene.background.contents=NSColor(calibratedWhite:0.93,alpha:1)
                let image=renderer.snapshot(atTime:0,with:CGSize(width:1000,height:720),antialiasingMode:.multisampling4X)
                guard let tiff=image.tiffRepresentation,let bitmap=NSBitmapImageRep(data:tiff),let png=bitmap.representation(using:.png,properties:[:]) else{continue}
                try png.write(to:directory.appendingPathComponent("\(family.rawValue)-\(plate.rawValue)-\(angle.rawValue).png"))
            }
            }
        }
    }
}

private final class MouseMeshBuilder {
    let scene=SCNScene()
    var root:SCNNode{scene.rootNode}
    let family:MouseFamily,hotspots:Bool
    var buttons=[Int:SCNNode]()
    let shellMat=MouseMeshBuilder.mat(0.20),clickMat=MouseMeshBuilder.mat(0.23),rubber=MouseMeshBuilder.mat(0.105),seam=MouseMeshBuilder.mat(0.055)
    let metal=MouseMeshBuilder.mat(0.63,specular:0.85),green=MouseMeshBuilder.color(NSColor(red:0.3,green:0.92,blue:0.12,alpha:1),glow:0.3)
    init(family:MouseFamily,hotspots:Bool){self.family=family;self.hotspots=hotspots}
    static func mat(_ white:CGFloat,specular:CGFloat=0.25)->SCNMaterial {
        let m=SCNMaterial();m.lightingModel = .blinn;m.diffuse.contents=NSColor(calibratedWhite:white,alpha:1);m.specular.contents=NSColor(calibratedWhite:specular,alpha:1);m.shininess=0.35;return m
    }
    static func color(_ color:NSColor,glow:CGFloat=0)->SCNMaterial {
        let m=mat(0.2);m.diffuse.contents=color;m.emission.contents=color.withAlphaComponent(glow);return m
    }
    // z, half-width, crown height. Interpolated sections create the broad rear hump and low nose.
    var sections:[SIMD3<Float>] {
        family == .naga ? [SIMD3(-63,21,16),SIMD3(-59,27,23),SIMD3(-43,29,31),SIMD3(-22,31,39),SIMD3(0,33,44),SIMD3(23,32,42),SIMD3(44,28,32),SIMD3(58,18,17),SIMD3(63,1,5)] : [SIMD3(-63,22,21),SIMD3(-58,26,29),SIMD3(-40,28,35),SIMD3(-20,30,45),SIMD3(3,31,51),SIMD3(27,32,46),SIMD3(47,28,33),SIMD3(59,16,18),SIMD3(63,1,5)]
    }
    func section(_ z:Float)->SIMD3<Float>{
        let points=sections
        let index=min(points.count-2,max(0,(0..<points.count-1).first{z<=points[$0+1].x} ?? points.count-2))
        let a=points[max(0,index-1)],b=points[index],c=points[index+1],d=points[min(points.count-1,index+2)]
        let t=max(0,min(1,(z-b.x)/(c.x-b.x)))
        return 0.5*((2*b)+(-a+c)*t+(2*a-5*b+4*c-d)*t*t+(-a+3*b-3*c+d)*t*t*t)
    }
    func top(_ x:Float,_ z:Float)->Float {
        let s=section(z),fraction=min(0.999,abs(x)/max(1,s.y))
        return 8+(s.z-8)*pow(max(0,1-pow(fraction,3.4)),0.46)+(family == .mxMaster3s ? -x/max(1,s.y)*3:0)
    }
    @discardableResult func node(_ geometry:SCNGeometry,_ position:SCNVector3 = SCNVector3Zero,_ material:SCNMaterial)->SCNNode {
        geometry.materials=[material];let node=SCNNode(geometry:geometry);node.position=position;root.addChildNode(node);return node
    }
    @discardableResult func box(_ x:CGFloat,_ y:CGFloat,_ z:CGFloat,_ p:SCNVector3,_ material:SCNMaterial,radius:CGFloat=1)->SCNNode {
        node(SCNBox(width:x,height:y,length:z,chamferRadius:radius),p,material)
    }
    func mesh(rows:Int,columns:Int,_ point:(Float,Float)->SIMD3<Float>)->SCNGeometry {
        var positions=[SIMD3<Float>](),indices=[UInt32]()
        for r in 0...rows {for c in 0...columns{positions.append(point(Float(r)/Float(rows),Float(c)/Float(columns)))}}
        for r in 0..<rows{for c in 0..<columns{
            let a=UInt32(r*(columns+1)+c),b=a+1,d=a+UInt32(columns+1),e=d+1;indices += [a,b,d,d,b,e]
        }}
        var normals=[SIMD3<Float>](repeating:.zero,count:positions.count)
        for i in stride(from:0,to:indices.count,by:3){let a=Int(indices[i]),b=Int(indices[i+1]),c=Int(indices[i+2]);let n=simd_cross(positions[b]-positions[a],positions[c]-positions[a]);normals[a]+=n;normals[b]+=n;normals[c]+=n}
        let vertices=positions.map{SCNVector3($0.x,$0.y,$0.z)},normalSource=normals.map{n -> SCNVector3 in let v=simd_length_squared(n)>0.000001 ? simd_normalize(n):SIMD3<Float>(0,1,0);return SCNVector3(v.x,v.y,v.z)}
        return SCNGeometry(sources:[SCNGeometrySource(vertices:vertices),SCNGeometrySource(normals:normalSource)],elements:[SCNGeometryElement(indices:indices,primitiveType:.triangles)])
    }
    func shell(){
        let body=mesh(rows:100,columns:80){u,v in
            let z = -63+126*u,s=self.section(z),angle=v*2*Float.pi,c=cos(angle),sinus=sin(angle)
            let x=s.y*(c<0 ? -1:1)*pow(abs(c),0.6)
            let y:Float=sinus>=0 ? 8+(s.z-8)*pow(sinus,0.92):2+6*pow(1+sinus,0.4)
            return SIMD3(x,y+(sinus>0 && self.family == .mxMaster3s ? -x/max(1,s.y)*3*sinus:0),z)
        }
        _=node(body,SCNVector3Zero,shellMat)
        for z:Float in [-63,63] {
            let s=section(z);var vertices=[SCNVector3(0,8,z)],indices=[UInt32]()
            for i in 0...80 {
                let a=Float(i)*2*Float.pi/80,c=cos(a),sn=sin(a)
                let x=s.y*(c<0 ? -1:1)*pow(abs(c),0.6),y:Float=sn>=0 ? 8+(s.z-8)*pow(sn,0.92):2+6*pow(1+sn,0.4)
                vertices.append(SCNVector3(x,y+(sn>0 && family == .mxMaster3s ? -x/max(1,s.y)*3*sn:0),z))
                if i>0 {indices += z<0 ? [0,UInt32(i+1),UInt32(i)]:[0,UInt32(i),UInt32(i+1)]}
            }
            let normal=SCNVector3(0,0,z<0 ? -1:1)
            let cap=SCNGeometry(sources:[SCNGeometrySource(vertices:vertices),SCNGeometrySource(normals:Array(repeating:normal,count:vertices.count))],elements:[SCNGeometryElement(indices:indices,primitiveType:.triangles)])
            _=node(cap,SCNVector3Zero,shellMat)
        }
        // Narrow lower chassis and parting line follow the same planform.
        let base=mesh(rows:70,columns:48){u,v in
            let z = -62+124*u,s=self.section(z),a=v*2*Float.pi
            return SIMD3(s.y*0.96*cos(a),2.6+1.2*sin(a),z)
        };_=node(base,SCNVector3Zero,seam)
    }
    func surface(x0:Float,x1:Float,z0:Float,z1:Float,lift:Float,material:SCNMaterial)->SCNNode {
        let geometry=mesh(rows:28,columns:14){u,v in
            let z=z0+(z1-z0)*u,w=self.section(z).y
            let x=(x1+(x0-x1)*v)*w
            return SIMD3(x,self.top(x,z)+lift,z)
        }
        // Surface winding follows x then z; point normals upward.
        geometry.firstMaterial=material;geometry.firstMaterial?.isDoubleSided=true
        return node(geometry,SCNVector3Zero,material)
    }
    func clicks(){
        let end:Float=family == .naga ? -8:-16
        _=surface(x0:family == .naga ? -0.75:-0.97,x1:-0.085,z0:-60,z1:end,lift:0.8,material:clickMat)
        _=surface(x0:0.085,x1:0.97,z0:-60,z1:end,lift:0.8,material:clickMat)
        _=surface(x0:-0.075,x1:0.075,z0:-61,z1:family == .naga ? 2:-5,lift:0.45,material:seam)
    }
    func wheels(){
        let z:Float=family == .naga ? -41:-42,y=top(0,z)-3
        let wheel=node(SCNCylinder(radius:8.4,height:8.5),SCNVector3(0,y,z),family == .naga ? rubber:metal);wheel.eulerAngles.z = .pi/2
        for i in 0..<42 {
            let a=Float(i)*2*Float.pi/42
            let ridge=box(8.8,0.7,0.8,SCNVector3(0,y+8.4*cos(a),z+8.4*sin(a)),family == .naga ? shellMat:matSilver(),radius:0.2);ridge.eulerAngles.x=CGFloat(a)
        }
        if family == .naga {
            for x:Float in [-3.9,3.9] {let ring=node(SCNTorus(ringRadius:8.1,pipeRadius:0.55),SCNVector3(x,y,z),green);ring.eulerAngles.z = .pi/2}
        }
        if family == .mxMaster3s {
            let insetPath=NSBezierPath(roundedRect:NSRect(x:-22.5,y:25,width:31,height:14),xRadius:6,yRadius:6)
            let inset=SCNShape(path:insetPath,extrusionDepth:3);inset.chamferRadius=0.8
            let housing=node(inset,SCNVector3(-28,0,0),rubber);housing.eulerAngles.y = -.pi/2
            let wheel=node(SCNCylinder(radius:5.3,height:18),SCNVector3(-30,32,-12),metal);wheel.eulerAngles.x = .pi/2
            let center=node(SCNCylinder(radius:5.4,height:1.5),SCNVector3(-30,32,-12),rubber);center.eulerAngles.x = .pi/2
            for n in 0..<30{let a=Float(n)*2*Float.pi/30;let rib=box(0.5,0.5,18,SCNVector3(-30+5.3*cos(a),32+5.3*sin(a),-12),matSilver(),radius:0.2);rib.eulerAngles.z=CGFloat(a)}
        }
    }
    func matSilver()->SCNMaterial{Self.mat(0.45,specular:0.9)}
    func sidePanel(_ material:SCNMaterial)->SCNNode {
        let p=NSBezierPath();p.move(to:NSPoint(x:-34,y:6));p.line(to:NSPoint(x:46,y:6));p.curve(to:NSPoint(x:38,y:29),controlPoint1:NSPoint(x:50,y:9),controlPoint2:NSPoint(x:45,y:23));p.curve(to:NSPoint(x:-15,y:35),controlPoint1:NSPoint(x:25,y:40),controlPoint2:NSPoint(x:-4,y:39));p.curve(to:NSPoint(x:-34,y:6),controlPoint1:NSPoint(x:-28,y:33),controlPoint2:NSPoint(x:-33,y:16));p.close()
        let shape=SCNShape(path:p,extrusionDepth:1.2);shape.chamferRadius=0.7
        let panel=node(shape,SCNVector3(-30,0,0),material);panel.eulerAngles.y = -.pi/2;return panel
    }
    func nagaPlate(_ plate:SidePlate){
        _=sidePanel(rubber)
        if plate == .twelve {
            for col in 0..<4 {for row in 0..<3 {
                let id=col*3+row+1,z:Float = -13+Float(col)*10.8,y:Float=10+Float(row)*8.7
                let cap=box(2.8,7.6,8.9,SCNVector3(-32.8,y,z),Self.mat(0.22),radius:1.1);cap.eulerAngles.x = -0.10
                register(id,cap,normal:SCNVector3(-1,0,0),number:"\(id)")
            }}
        } else {
            // Both alternative plates have a rubber thumb grip below their buttons.
            for n in 0..<20 {
                let y:Float=7+Float(n)*0.65,width:Float=40-abs(Float(n)-10)*1.6
                _=box(0.7,0.28,CGFloat(width),SCNVector3(-32, y,12),shellMat,radius:0.13)
            }
            if plate == .six {
                let points:[(Int,Float,Float)]=[(101,-12,31),(102,0,33),(103,12,31),(104,14,23),(105,2,22),(106,-10,23)]
                for (id,z,y) in points{let cap=box(2.8,6.4,10,SCNVector3(-32.4,y,z),Self.mat(0.22),radius:1.2);register(id,cap,normal:SCNVector3(-1,0,0),number:"\(MouseControls.number(id))")}
            } else {
                for (id,z) in [(201,Float(-8)),(202,Float(8))]{let cap=box(2.8,8,14,SCNVector3(-32.5,29,z),Self.mat(0.22),radius:1.6);register(id,cap,normal:SCNVector3(-1,0,0),number:"\(MouseControls.number(id))")}
            }
        }
    }
    func nagaExtras(){
        for (id,z) in [(13,Float(-53)),(14,Float(-37))]{
            let x:Float = -25.5,cap=box(7.5,2.8,12,SCNVector3(x,top(x,z)+1.6,z),Self.mat(0.22),radius:1.1);cap.eulerAngles.x = -0.25;register(id,cap,normal:SCNVector3(0,1,0),number:hotspots ? "\(id)":nil)
        }
        for (id,z) in [(15,Float(-19)),(16,Float(-7))]{let cap=box(7,2.7,8.8,SCNVector3(0,top(0,z)+1.6,z),Self.mat(0.22),radius:1.2);register(id,cap,normal:SCNVector3(0,1,0),number:hotspots ? "\(id)":nil)}
        let cap=box(3.2,12,23,SCNVector3(31.5,24,-16),Self.mat(0.22),radius:2);cap.eulerAngles.z = -0.35;register(17,cap,normal:SCNVector3(1,0,0),number:hotspots ? "17":nil)
        for n in 0..<12{_=box(0.8,0.35,15,SCNVector3(33,20+Float(n)*0.6,-13),rubber,radius:0.16)}
    }
    func wing(_ u:Float,_ v:Float)->SIMD3<Float>{
        let z = -30+89*u,taper=pow(max(0,sin(u*Float.pi)),0.6),inner = -section(z).y+3
        let x=inner-(19*taper+2)*v,y=5+(25*taper)*pow(1-v,2)+3*sin(v*Float.pi)*taper
        return SIMD3(x,y,z)
    }
    func mxThumbRest(){
        let geometry=mesh(rows:65,columns:35){self.wing($0,$1)};geometry.firstMaterial=shellMat;geometry.firstMaterial?.isDoubleSided=true
        _=node(geometry,SCNVector3Zero,shellMat)
        for n in 0..<7 {
            var path=[SCNVector3]()
            for step in 0...35 {
                let v=Float(step)/35,u=0.15+Float(n)*0.09+v*0.11
                var p=wing(min(0.97,u),0.12+v*0.8);p.y+=0.18;path.append(SCNVector3(p.x,p.y,p.z))
            };tube(path,radius:0.35,material:rubber)
        }
        // Indicator inset immediately behind the horizontal wheel.
        let led=box(0.7,1.4,3.6,SCNVector3(-31,34,2),green,radius:0.3);led.eulerAngles.z = -0.2
    }
    func mxButtons(){
        for (id,z) in [(301,Float(2)),(302,Float(-12))]{let cap=box(3.1,4.2,12,SCNVector3(-32,23,z),Self.mat(0.22),radius:1.5);register(id,cap,normal:SCNVector3(-1,0,0),number:hotspots ? "\(id-300)":nil)}
        let mode=box(6.4,2,8.6,SCNVector3(0,top(0,-18)+1.5,-18),Self.mat(0.22),radius:1.5);register(305,mode,normal:SCNVector3(0,1,0),number:hotspots ? "5":nil)
        let rest=box(5,1.1,10,SCNVector3(-43,9,27),Self.mat(0.22),radius:1);rest.eulerAngles.z = -0.17;register(304,rest,normal:SCNVector3(0,1,0),number:hotspots ? "4":nil)
        // Click target covers the real scroll wheel, with the marker above its crown.
        let click=box(8.6,0.7,8.6,SCNVector3(0,top(0,-42)+5.8,-42),Self.mat(0.22),radius:0.3);click.opacity=hotspots ? 0.8:0;register(303,click,normal:SCNVector3(0,1,0),number:hotspots ? "3":nil)
    }
    func register(_ id:Int,_ cap:SCNNode,normal:SCNVector3,number:String?){
        cap.name="button-\(id)";buttons[id]=cap
        guard let number else{return}
        let text=SCNText(string:number,extrusionDepth:0.01);text.font=NSFont.systemFont(ofSize:1,weight:.medium);text.flatness=0.05
        let labelMat=SCNMaterial();labelMat.lightingModel = .constant;labelMat.diffuse.contents=family == .naga && id<300 ? NSColor(red:0.55,green:0.95,blue:0.4,alpha:1):NSColor.white;text.materials=[labelMat]
        let label=SCNNode(geometry:text),bounds=text.boundingBox
        label.pivot=SCNMatrix4MakeTranslation((bounds.max.x+bounds.min.x)/2,(bounds.max.y+bounds.min.y)/2,0)
        let size:Float=4.0;label.scale=SCNVector3(size,size,size)
        label.position=SCNVector3(normal.x*2,normal.y*2,normal.z*2)
        if normal.x<0{label.eulerAngles.y = -.pi/2}
        else if normal.x>0{label.eulerAngles.y = .pi/2}
        else{label.eulerAngles.x = -.pi/2}
        cap.addChildNode(label)
    }
    func tube(_ points:[SCNVector3],radius:CGFloat,material:SCNMaterial){
        for i in 1..<points.count {
            let a=points[i-1],b=points[i],dx=b.x-a.x,dy=b.y-a.y,dz=b.z-a.z,length=sqrt(dx*dx+dy*dy+dz*dz)
            let segment=node(SCNCylinder(radius:radius,height:CGFloat(length)),SCNVector3((a.x+b.x)/2,(a.y+b.y)/2,(a.z+b.z)/2),material)
            segment.look(at:b,up:SCNVector3(0,1,0),localFront:SCNVector3(0,1,0))
        }
    }
    func port(){
        _=box(10,4,1.1,SCNVector3(0,10,-63),metal,radius:1.5)
        _=box(8.7,2.8,1.3,SCNVector3(0,10,-63.2),seam,radius:1.2)
    }
    func underside(){
        for x:Float in [-22,22]{_=box(5.8,0.8,58,SCNVector3(x,1.7,5),rubber,radius:2)}
        let sensor=node(SCNCylinder(radius:3.4,height:0.7),SCNVector3(0,1.5,0),seam);sensor.eulerAngles.x = .pi
        _=box(2.4,0.8,3.2,SCNVector3(0,1.05,0),Self.mat(0.45),radius:0.4)
    }
    func brand(){
        let text=SCNText(string:family == .mxMaster3s ? "MX":"NAGA",extrusionDepth:0.02);text.font=NSFont.systemFont(ofSize:1,weight:.semibold);text.materials=[Self.mat(family == .mxMaster3s ? 0.43:0.28)]
        let label=node(text,SCNVector3(-4,top(-4,21)+0.45,21),text.materials[0]);label.scale=SCNVector3(3.5,3.5,3.5);label.eulerAngles.x = -.pi/2
    }
}
