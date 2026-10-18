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
    private static var thumbnails=[String:NSImage]()
    static func thumbnail(family:MouseFamily,plate:SidePlate)->NSImage {
        let key="\(family.rawValue)-\(plate.rawValue)"
        if let image=thumbnails[key]{return image}
        let (scene,camera,_)=make(family:family,plate:plate,hotspots:false)
        scene.background.contents=NSColor.clear
        let renderer=SCNRenderer(device:MTLCreateSystemDefaultDevice(),options:nil)
        renderer.scene=scene;renderer.pointOfView=camera
        let image=renderer.snapshot(atTime:0,with:CGSize(width:228,height:234),antialiasingMode:.multisampling4X)
        thumbnails[key]=image;return image
    }
    static func make(family:MouseFamily,plate:SidePlate,hotspots:Bool)->(SCNScene,SCNNode,[Int:SCNNode]) {
        let builder=MouseMeshBuilder(family:family,hotspots:hotspots)
        builder.shell();builder.clicks();builder.wheels()
        if family == .naga{builder.nagaPlate(plate);builder.nagaExtras()}else{builder.mxThumbRest();builder.mxButtons()}
        builder.underside();builder.port();builder.finishSilhouette();builder.contactShadow()
        let camera=SCNNode();camera.camera=SCNCamera();camera.camera?.usesOrthographicProjection=true
        camera.camera?.zNear=0.1;camera.camera?.zFar=1500
        camera.camera?.screenSpaceAmbientOcclusionIntensity=0
        camera.camera?.screenSpaceAmbientOcclusionRadius=3
        position(camera,angle:.overview,thumbnail:!hotspots);builder.root.addChildNode(camera)
        builder.scene.lightingEnvironment.contents=studioEnvironment
        builder.scene.lightingEnvironment.intensity=1.1
        for (position,power) in [(SCNVector3(-90,180,-100),CGFloat(850)),(SCNVector3(100,100,70),CGFloat(450))] {
            let light=SCNNode();light.light=SCNLight();light.light?.type = .omni;light.light?.intensity=power;light.position=position;builder.root.addChildNode(light)
        }
        let ambient=SCNNode();ambient.light=SCNLight();ambient.light?.type = .ambient;ambient.light?.intensity=100;builder.root.addChildNode(ambient)
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
        if angle == .top{camera.look(at:target,up:SCNVector3(0,0,-1),localFront:SCNVector3(0,0,-1))}else{camera.look(at:target,up:SCNVector3(0,1,0),localFront:SCNVector3(0,0,-1))}
        camera.camera?.orthographicScale=thumbnail ? 65:angle == .top ? 73:57
    }
    /// Original studio illumination, shared by the cards and the interactive model.
    /// Broad highlights reveal curvature without importing photographs or texture assets.
    private static let studioEnvironment:NSImage = {
        let image=NSImage(size:NSSize(width:512,height:256))
        image.lockFocus()
        NSGradient(starting:NSColor(white:0.18,alpha:1),ending:NSColor(white:0.78,alpha:1))!.draw(in:NSRect(x:0,y:0,width:512,height:256),angle:90)
        NSColor(white:1,alpha:1).setFill()
        NSBezierPath(roundedRect:NSRect(x:45,y:115,width:130,height:82),xRadius:22,yRadius:22).fill()
        NSColor(white:0.92,alpha:1).setFill()
        NSBezierPath(roundedRect:NSRect(x:300,y:100,width:75,height:125),xRadius:20,yRadius:20).fill()
        image.unlockFocus();return image
    }()
    static func exportPreviews(to directory:URL)throws {
        try FileManager.default.createDirectory(at:directory,withIntermediateDirectories:true)
        var report=[[String:Any]]()
        for family in MouseFamily.allCases {
            let plates:[SidePlate]=family == .naga ? [.twelve,.six,.two]:[.twelve]
            for plate in plates {
                let started=Date()
                let (scene,camera,buttons)=make(family:family,plate:plate,hotspots:true)
                let expected=Set(family == .naga ? plate.buttonIDs+MouseControls.extraIDs:MouseControls.mxIDs)
                precondition(Set(buttons.keys)==expected,"Rendered controls must match the active plate")
                var visible=Set<Int>()
                for angle in MouseViewAngle.allCases {
                    position(camera,angle:angle,thumbnail:false)
                    let direction=simd_normalize(camera.simdPosition-SIMD3<Float>(-4,20,0))
                    for (id,button) in buttons {
                        let target=button.simdWorldPosition+(id==303 ? SIMD3<Float>(0,9,0):SIMD3<Float>.zero)
                        let hits=scene.rootNode.hitTestWithSegment(from:SCNVector3(target+direction*300),to:SCNVector3(target-direction*4),options:[SCNHitTestOption.searchMode.rawValue:SCNHitTestSearchMode.closest.rawValue,SCNHitTestOption.backFaceCulling.rawValue:false])
                        var node=hits.first?.node
                        while let hit=node {
                            if hit.name=="button-\(id)" {visible.insert(id);break}
                            node=hit.parent
                        }
                    }
                    let renderer=SCNRenderer(device:MTLCreateSystemDefaultDevice(),options:nil);renderer.scene=scene;renderer.pointOfView=camera
                    scene.background.contents=NSColor(calibratedWhite:0.93,alpha:1)
                    let image=renderer.snapshot(atTime:0,with:CGSize(width:1000,height:720),antialiasingMode:.multisampling4X)
                    guard let tiff=image.tiffRepresentation,let bitmap=NSBitmapImageRep(data:tiff),let png=bitmap.representation(using:.png,properties:[:]) else{continue}
                    try png.write(to:directory.appendingPathComponent("\(family.rawValue)-\(plate.rawValue)-\(angle.rawValue).png"))
                }
                let missing=expected.subtracting(visible).sorted()
                print("\(family.rawValue) plate \(plate.rawValue): \(buttons.count) controls, missing visible hit targets: \(missing); \(String(format:"%.2f",Date().timeIntervalSince(started)))s")
                report.append(["mouse":family.rawValue,"plate":plate.rawValue,"controlIDs":expected.sorted(),"visibleHitTargets":visible.sorted(),"missingHitTargets":missing])
            }
        }
        try JSONSerialization.data(withJSONObject:report,options:[.prettyPrinted,.sortedKeys]).write(to:directory.appendingPathComponent("model-validation.json"))
    }

}

private final class MouseMeshBuilder {
    let scene = SCNScene()
    var root: SCNNode { scene.rootNode }
    let family: MouseFamily
    let hotspots: Bool
    var buttons = [Int: SCNNode]()
    let shellMat = material(0.23, gloss: 0.48)
    let clickMat = material(0.24, gloss: 0.46)
    let rubber = material(0.085, gloss: 0.08)
    let seam = material(0.025, gloss: 0.12)
    let metal = material(0.78, gloss: 0.85)
    let green = luminous(NSColor(red: 0.28, green: 0.93, blue: 0.06, alpha: 1))

    init(family: MouseFamily, hotspots: Bool) { self.family = family; self.hotspots = hotspots }
    static func material(_ white: CGFloat, gloss: CGFloat = 0.3) -> SCNMaterial {
        let m = SCNMaterial()
        m.lightingModel = .physicallyBased
        m.diffuse.contents = NSColor(calibratedWhite: white, alpha: 1)
        m.metalness.contents = gloss > 0.6 ? 0.85:0.0
        m.roughness.contents = gloss > 0.6 ? 0.25:0.82-gloss*0.65
        return m
    }
    static func luminous(_ color: NSColor) -> SCNMaterial {
        let m = material(0.1); m.diffuse.contents = color
        m.emission.contents = color.blended(withFraction: 0.78, of: .black)
        return m
    }
    // Millimetre-scale control sections: z (nose -> heel), half width, crown height.
    // The Naga has a broad low nose and right finger shelf. MX has a taller, tilted crown.
    var sections: [SIMD3<Float>] {
        if family == .naga {
            return [.init(-63,24,15), .init(-60,28,21), .init(-45,29,28),
                    .init(-25,30,36), .init(-3,32,42), .init(20,33,43),
                    .init(41,29,35), .init(56,20,21), .init(63,0.5,6.1)]
        }
        // The user's scan places the MX crown farther forward than our first illustration.
        return [.init(-63,23,18), .init(-59,26,24), .init(-44,27,32),
                .init(-24,28,41), .init(-3,30,49), .init(12,32,51), .init(20,32,49),
                .init(42,29,34), .init(56,20,18), .init(63,0.5,6.1)]
    }
    func section(_ z: Float) -> SIMD3<Float> {
        let points = sections
        let i = min(points.count-2, max(0, (0..<points.count-1).first { z <= points[$0+1].x } ?? points.count-2))
        let b=points[i], c=points[i+1], span=c.x-b.x
        let t=max(0,min(1,(z-b.x)/span))
        // These stations are unevenly spaced. Uniform Catmull–Rom gave each join a
        // different physical slope, producing bands and kinks in the highlights.
        func slope(_ j:Int,_ axis:Int)->Float {
            if j==0{return (points[1][axis]-points[0][axis])/(points[1].x-points[0].x)}
            if j==points.count-1{return (points[j][axis]-points[j-1][axis])/(points[j].x-points[j-1].x)}
            let left=(points[j][axis]-points[j-1][axis])/(points[j].x-points[j-1].x)
            let right=(points[j+1][axis]-points[j][axis])/(points[j+1].x-points[j].x)
            guard left*right>0 else{return 0}
            let h0=points[j].x-points[j-1].x,h1=points[j+1].x-points[j].x
            return 3*(h0+h1)/((2*h1+h0)/left+(h1+2*h0)/right)
        }
        var result=SIMD3<Float>(z,0,0)
        for axis in 1...2 {
            result[axis]=(2*t*t*t-3*t*t+1)*b[axis]+(t*t*t-2*t*t+t)*span*slope(i,axis)
                + (-2*t*t*t+3*t*t)*c[axis]+(t*t*t-t*t)*span*slope(i+1,axis)
        }
        if z>20 {result.y=(family == .naga ? 33:32)*sqrt(max(0.0001,1-pow((z-20)/43,2)))}
        return result
    }
    func width(_ z: Float, right: Bool) -> Float {
        let w=section(z).y
        if family == .naga && right { return w + 5.5*exp(-pow((z+13)/27,2)) }
        return w
    }
    func top(_ x: Float, _ z: Float) -> Float {
        let s=section(z), w=width(z,right:x>0), f=min(0.9999,abs(x)/max(0.5,w))
        let h: Float = 6+(s.z-6)*pow(max(0,1-pow(f,4.2)),0.52)
        if family == .mxMaster3s { return h - 4*x/max(1,w)*pow(max(0,1-f),0.28) }
        // A soft depression lets the ring finger sit alongside right-click.
        return h - (x>0 ? 3*exp(-pow((z+20)/25,2))*pow(f,2):0)
    }
    func sideX(_ y: Float, _ z: Float, right: Bool = false) -> Float {
        let section=self.section(z), w=width(z,right:right), sign:Float=right ? 1:-1
        if family == .naga && !right {
            let fraction=max(0,min(0.9999,(y-6)/max(0.1,section.z-6)))
            return -w*pow(max(0,1-pow(fraction,1/0.52)),1/4.2)
        }
        var lo:Float=0,hi:Float=0.9999
        for _ in 0..<18 {
            let f=(lo+hi)/2
            var h:Float=6+(section.z-6)*pow(max(0,1-pow(f,4.2)),0.52)
            if family == .mxMaster3s {h -= 4*sign*f*pow(max(0,1-f),0.28)}
            else if right {h -= 3*exp(-pow((z+20)/25,2))*f*f}
            if h>y {lo=f}else{hi=f}
        }
        return sign*w*(lo+hi)/2
    }
    func sidePoint(_ y: Float, _ z: Float, lift: Float=0.3) -> SIMD3<Float> {
        SIMD3(sideX(y,z)-lift,y,z)
    }
    func sideNormal(_ y: Float, _ z: Float) -> SIMD3<Float> {
        simd_normalize(SIMD3(-1,(sideX(y+0.1,z)-sideX(y-0.1,z))/0.2,(sideX(y,z+0.1)-sideX(y,z-0.1))/0.2))
    }
    func topNormal(_ x: Float, _ z: Float) -> SIMD3<Float> {
        simd_normalize(SIMD3(-(top(x+0.1,z)-top(x-0.1,z))/0.2,1,-(top(x,z+0.1)-top(x,z-0.1))/0.2))
    }
    @discardableResult func node(_ geometry: SCNGeometry, _ p: SIMD3<Float> = .zero, _ material: SCNMaterial) -> SCNNode {
        geometry.materials=[material]; let n=SCNNode(geometry:geometry); n.simdPosition=p; root.addChildNode(n); return n
    }
    @discardableResult func box(_ w: CGFloat,_ h: CGFloat,_ d: CGFloat,_ p: SIMD3<Float>,_ m: SCNMaterial,r: CGFloat=0.6) -> SCNNode {
        let g=SCNBox(width:w,height:h,length:d,chamferRadius:r); g.chamferSegmentCount=4
        return node(g,p,m)
    }
    func orient(_ n: SCNNode, normal: SIMD3<Float>, tangent: SIMD3<Float>) {
        let x=simd_normalize(tangent-normal*simd_dot(tangent,normal)), y=simd_cross(normal,x)
        n.simdOrientation=simd_quatf(simd_float3x3(columns:(x,y,normal)))
    }
    func mesh(rows: Int, columns: Int, _ point: (Float,Float)->SIMD3<Float>) -> SCNGeometry {
        var p=[SIMD3<Float>](), indices=[UInt32]()
        for r in 0...rows {for c in 0...columns {p.append(point(Float(r)/Float(rows),Float(c)/Float(columns)))}}
        for r in 0..<rows {for c in 0..<columns {
            let a=UInt32(r*(columns+1)+c), b=a+1, d=a+UInt32(columns+1), e=d+1
            indices += [a,b,d,d,b,e]
        }}
        return geometry(p,indices)
    }
    func geometry(_ p: [SIMD3<Float>], _ indices: [UInt32]) -> SCNGeometry {
        var normals=[SIMD3<Float>](repeating:.zero,count:p.count)
        for i in stride(from:0,to:indices.count,by:3) {
            let a=Int(indices[i]),b=Int(indices[i+1]),c=Int(indices[i+2]), n=simd_cross(p[b]-p[a],p[c]-p[a])
            normals[a]+=n; normals[b]+=n; normals[c]+=n
        }
        let n=normals.map { simd_length_squared($0)>0.000001 ? simd_normalize($0):SIMD3<Float>(0,1,0) }
        return SCNGeometry(sources:[SCNGeometrySource(vertices:p.map{SCNVector3($0)}),SCNGeometrySource(normals:n.map{SCNVector3($0)})],elements:[SCNGeometryElement(indices:indices,primitiveType:.triangles)])
    }
    func shell() {
        let body=mesh(rows:220,columns:192) { u,v in
            let z:Float = -63+126*u, a=v*2*Float.pi, c=cos(a), sn=sin(a)
            let x=self.width(z,right:c>0)*(c<0 ? -1:1)*pow(abs(c),0.47619)
            let y:Float = sn>=0 ? self.top(x,z):1.8+4.2*pow(max(0,1+sn),0.45)
            return SIMD3(x,y,z)
        }
        node(body,.zero,shellMat)
        // Close both end faces; the low nose sits beneath separately sculpted click paddles.
        for z: Float in [-63,63] {
            var p=[SIMD3<Float>(0,6,z)], indices=[UInt32]()
            for i in 0...120 {
                let a=Float(i)*2*Float.pi/120, c=cos(a), sn=sin(a)
                let x=width(z,right:c>0)*(c<0 ? -1:1)*pow(abs(c),0.47619)
                let y:Float=sn>=0 ? top(x,z):1.8+4.2*pow(max(0,1+sn),0.45)
                p.append(SIMD3(x,y,z)); if i>0 {indices += z<0 ? [0,UInt32(i+1),UInt32(i)]:[0,UInt32(i),UInt32(i+1)]}
            }
            node(geometry(p,indices),.zero,z<0 ? rubber:shellMat)
        }
        for side: Float in [-1,1] {
            let points=(0...100).map { i -> SIMD3<Float> in
                let z:Float = -61+122*Float(i)/100
                return SIMD3(self.sideX(6.6,z,right:side>0)*1.003,6.6,z)
            }
            tube(points,radius:0.35,material:seam)
        }
    }
    /// A rounded, closed contour projected onto the shell; useful for real panel seams.
    @discardableResult func patch(_ outline:[SIMD2<Float>], lift:Float, material:SCNMaterial,
                                  map:((SIMD2<Float>,Float)->SIMD3<Float>)?=nil) -> SCNNode {
        let project=map ?? {p,offset in SIMD3(p.x,self.top(p.x,p.y)+offset,p.y)}
        func cross(_ a:SIMD2<Float>,_ b:SIMD2<Float>)->Float {a.x*b.y-a.y*b.x}
        let area=outline.indices.reduce(Float(0)) { $0+cross(outline[$1],outline[($1+1)%outline.count]) }
        let winding:Float=area>0 ? 1:-1
        var remaining=Array(outline.indices), triangles=[(SIMD2<Float>,SIMD2<Float>,SIMD2<Float>)]()
        while remaining.count>2 {
            var clipped=false
            for k in remaining.indices {
                let ia=remaining[(k+remaining.count-1)%remaining.count],ib=remaining[k],ic=remaining[(k+1)%remaining.count]
                let a=outline[ia],b=outline[ib],c=outline[ic]
                guard winding*cross(b-a,c-b)>0.000001 else{continue}
                let occupied=remaining.contains { i in
                    if i==ia || i==ib || i==ic{return false}
                    let p=outline[i]
                    return winding*cross(b-a,p-a)>0.000001 && winding*cross(c-b,p-b)>0.000001 && winding*cross(a-c,p-c)>0.000001
                }
                if !occupied {triangles.append((a,b,c));remaining.remove(at:k);clipped=true;break}
            }
            guard clipped else{break}
        }
        var vertices=[SCNVector3](),normals=[SCNVector3](),indices=[UInt32]()
        func add(_ a:SIMD2<Float>,_ b:SIMD2<Float>,_ c:SIMD2<Float>,_ depth:Int) {
            if depth<9 && max(simd_length(a-b),max(simd_length(b-c),simd_length(c-a)))>0.85 {
                let ab=(a+b)/2,bc=(b+c)/2,ca=(c+a)/2
                add(a,ab,ca,depth+1);add(ab,b,bc,depth+1);add(ca,bc,c,depth+1);add(ab,bc,ca,depth+1);return
            }
            let start=UInt32(vertices.count)
            var surfaceNormal=SIMD3<Float>.zero
            for p in [a,b,c] {
                let dx=project(p+SIMD2(0.02,0),lift)-project(p-SIMD2(0.02,0),lift)
                let dy=project(p+SIMD2(0,0.02),lift)-project(p-SIMD2(0,0.02),lift)
                let n=simd_normalize(map == nil ? simd_cross(dy,dx):simd_cross(dx,dy))
                surfaceNormal+=n;vertices.append(SCNVector3(project(p,lift)));normals.append(SCNVector3(n))
            }
            let face=simd_cross(project(b,lift)-project(a,lift),project(c,lift)-project(a,lift))
            indices += simd_dot(face,surfaceNormal)>0 ? [start,start+1,start+2]:[start,start+2,start+1]
        }
        for (a,b,c) in triangles {add(a,b,c,0)}
        let g=SCNGeometry(sources:[SCNGeometrySource(vertices:vertices),SCNGeometrySource(normals:normals)],elements:[SCNGeometryElement(indices:indices,primitiveType:.triangles)])
        return node(g,.zero,material.copy() as! SCNMaterial)
    }
    func roundedContour(_ vertices:[SIMD2<Float>], radius:Float=0.12) -> [SIMD2<Float>] {
        var result=[SIMD2<Float>]()
        for i in vertices.indices {
            let prev=vertices[(i+vertices.count-1)%vertices.count], p=vertices[i], next=vertices[(i+1)%vertices.count]
            let a=p+(prev-p)*radius, b=p+(next-p)*radius
            for step in 0..<8 {let t=Float(step)/8;result.append((1-t)*(1-t)*a+2*(1-t)*t*p+t*t*b)}
        }
        return result
    }
    /// Sample in the panel's two-dimensional domain before projecting onto the body.
    /// Connecting only contour corners drew straight chords through the curved shell,
    /// which made seams disappear and reappear as disconnected black scratches.
    func seamContour(_ outline:[SIMD2<Float>])->[SIMD2<Float>] {
        var points=[SIMD2<Float>]()
        for i in outline.indices {
            let a=outline[i],b=outline[(i+1)%outline.count]
            let steps=max(1,Int(ceil(simd_length(b-a)/0.4)))
            for step in 0..<steps {points.append(a+(b-a)*Float(step)/Float(steps))}
        }
        points.append(outline[0]);return points
    }
    func clicks() {
        for side: Float in [-1,1] {
            let outline: [SIMD2<Float>]
            if family == .mxMaster3s {
                // Long angular paddles flank a wide, integral wheel bridge (as in the top reference).
                outline=[SIMD2(side*0.55,-62.7),SIMD2(side*23,-62.0),SIMD2(side*26,-41),
                         SIMD2(side*27,-14),SIMD2(side*10,-19),SIMD2(side*8,-47),SIMD2(side*0.55,-48)]
            } else {
                let outer: Float=side<0 ? 20.5:28
                outline=[SIMD2(side*5.9,-62.7),SIMD2(side*23.3,-62.0),SIMD2(side*outer,-41),
                         SIMD2(side*(outer+1),-9),SIMD2(side*5.2,-6),SIMD2(side*5.2,-45)]
            }
            let contour=roundedContour(outline,radius:0.07)
            patch(contour,lift:0.42,material:clickMat)
            let line=seamContour(contour).map{SIMD3($0.x,top($0.x,$0.y)+0.30,$0.y)}
            tube(line,radius:0.16,material:seam)
        }
        // Naga's recessed bridge continues behind the wheel to the two narrow controls.
        if family == .naga {
            let outline=roundedContour([SIMD2(-5.1,-60),SIMD2(5.1,-60),SIMD2(5.1,0),SIMD2(-5.1,0)],radius:0.06)
            patch(outline,lift:0.3,material:seam)
        } else {
            // The small wordmark is projected onto the curved paddle, not a flat
            // text object that can float above the silhouette from the opposite side.
            let image=NSImage(size:NSSize(width:256,height:120))
            image.lockFocus()
            ("logi" as NSString).draw(in:NSRect(x:3,y:2,width:250,height:118),withAttributes:[.font:NSFont.systemFont(ofSize:100,weight:.semibold),.foregroundColor:NSColor(white:0.43,alpha:1)])
            image.unlockFocus()
            let g=mesh(rows:12,columns:24){u,v in
                let x:Float = -20+13*v,z:Float = -20-6*u
                return SIMD3(x,self.top(x,z)+0.65,z)
            }
            var uv=[CGPoint]()
            for r in 0...12 {for c in 0...24 {uv.append(CGPoint(x:Double(c)/24,y:1-Double(r)/12))}}
            let decal=SCNGeometry(sources:g.sources+[SCNGeometrySource(textureCoordinates:uv)],elements:g.elements)
            let m=SCNMaterial();m.lightingModel = .constant;m.diffuse.contents=image;m.writesToDepthBuffer=false
            node(decal,.zero,m)
        }
    }
    @discardableResult func wheel(center:SIMD3<Float>,radius:CGFloat,length:CGFloat,axis:SIMD3<Float>,steel:Bool) -> SCNNode {
        // A single beveled lathe, with actual cut grooves rather than 64 cylinders.
        // Keeping the center band and end rings smooth avoids the old spiky silhouette.
        let r=Float(radius), half=Float(length)/2
        let profile:[SIMD3<Float>]=[
            .init(-half,r-0.7,0),.init(-half+0.28,r-0.18,0),
            .init(-half+0.65,r,steel ? 0.16:0.32),
            .init(-0.85,r,steel ? 0.16:0.32),.init(-0.6,r+0.06,0),
            .init(0.6,r+0.06,0),.init(0.85,r,steel ? 0.16:0.32),
            .init(half-0.65,r,steel ? 0.16:0.32),.init(half-0.28,r-0.18,0),.init(half,r-0.7,0)]
        let g=mesh(rows:profile.count-1,columns:512){u,v in
            let q=profile[min(profile.count-1,Int((u*Float(profile.count-1)).rounded()))]
            let a = -v*2*Float.pi
            let radial=q.y-q.z*(0.5+0.5*cos(a*64))
            return SIMD3(radial*cos(a),q.x,radial*sin(a))
        }
        let n=node(g,center,steel ? metal:rubber)
        n.simdOrientation=simd_quatf(from:SIMD3(0,1,0),to:axis)
        for edge:Float in [-1,1] {
            let end=SCNNode(geometry:SCNCylinder(radius:radius-0.65,height:0.10))
            (end.geometry as? SCNCylinder)?.radialSegmentCount=96
            end.geometry?.materials=[steel ? Self.material(0.42,gloss:0.82):rubber]
            end.simdPosition.y=edge*(half-0.04);n.addChildNode(end)
            if !steel {
                let ring=SCNNode(geometry:SCNTorus(ringRadius:radius-0.08,pipeRadius:0.24))
                (ring.geometry as? SCNTorus)?.ringSegmentCount=128
                ring.geometry?.materials=[green];ring.simdPosition.y=edge*(half-0.30);n.addChildNode(ring)
            }
        }
        return n
    }
    func wheels() {
        let z:Float=family == .naga ? -40:-39, r:Float=family == .naga ? 9.6:9.0
        let y=top(0,z)-3.8
        let outline=roundedContour([SIMD2(-5.9,z-11),SIMD2(5.9,z-11),SIMD2(5.9,z+11),SIMD2(-5.9,z+11)],radius:0.13)
        patch(outline,lift:0.67,material:seam)
        let main=wheel(center:SIMD3(0,y,z),radius:CGFloat(r),length:8.5,axis:SIMD3(1,0,0),steel:family == .mxMaster3s)
        if family == .mxMaster3s {
            // Register the real wheel mesh. No block covering the metal wheel as a hit target.
            register(303,main,number:nil)
            let outline=roundedContour([SIMD2(-27,27),SIMD2(5,28),SIMD2(9,38),SIMD2(-25,39)],radius:0.27)
            let project:(SIMD2<Float>,Float)->SIMD3<Float>={p,lift in self.sidePoint(p.y,p.x,lift:lift)}
            patch(outline,lift:0.5,material:rubber,map:project)
            let center=sidePoint(32,-12,lift:0.8)
            _=wheel(center:center,radius:4.6,length:17.5,axis:SIMD3(0,0,1),steel:true)
        }
    }
    func nagaPlate(_ plate: SidePlate) {
        // A conforming removable panel: its edge is a seam on the shell, not an extruded slab.
        let contour=roundedContour([SIMD2(-43,7),SIMD2(46,7),SIMD2(49,17),SIMD2(38,30),
                                   SIMD2(21,37),SIMD2(-5,34),SIMD2(-25,24)],radius:0.13)
        let project:(SIMD2<Float>,Float)->SIMD3<Float>={p,lift in self.sidePoint(p.y,p.x,lift:lift)}
        patch(contour,lift:0.33,material:Self.material(0.125,gloss:0.20),map:project)
        let edge=seamContour(contour).map{sidePoint($0.y,$0.x,lift:0.40)};tube(edge,radius:0.18,material:seam)
        if plate != .twelve { thumbGrip() }
        for (row,ids) in plate.visualRows.enumerated() {
            for (col,id) in ids.enumerated() {
                let z:Float, y:Float, w:CGFloat, h:CGFloat
                switch plate {
                case .twelve:
                    z = -10+Float(col)*11.6 + Float(row)*0.8
                    y = 29-Float(row)*9.0 + (col==1 || col==2 ? 1.1:0)
                    w=10.0;h=7.8
                case .six:
                    z = -10+Float(col)*13.4 + (row==1 ? 0.7:0)
                    y = 29.5-Float(row)*8.0 + (col==1 ? 1.8:0)
                    w=11.8;h=6.8
                case .two:
                    z = -4+Float(col)*21
                    y = 29.8
                    w=19.4;h=8.6
                }
                let normal=sideNormal(y,z), center=sidePoint(y,z,lift:0.5)+normal*1.15
                let well=box(w+0.8,h+0.8,1.5,center-normal*0.6,seam,r:1.1)
                orient(well,normal:normal,tangent:SIMD3(0,0,1))
                let cap=box(w,h,2.8,center,Self.material(0.16,gloss:0.35),r:1.0)
                orient(cap,normal:normal,tangent:SIMD3(0,0,1))
                register(id,cap,number:plate == .twelve ? "\(MouseControls.number(id))":nil,depth:1.5,size:3.1)
                // The six-button plate has subtle legends; two-button plate is unnumbered hardware.
                if plate == .six {legend("\(MouseControls.number(id))",on:cap,depth:1.5,size:2.4,lit:false)}
            }
        }
    }
    func thumbGrip() {
        let outline=roundedContour([SIMD2(-23,6),SIMD2(36,6),SIMD2(31,17),SIMD2(6,19),SIMD2(-16,16)],radius:0.20)
        let project:(SIMD2<Float>,Float)->SIMD3<Float>={p,lift in self.sidePoint(p.y,p.x,lift:lift)}
        patch(outline,lift:0.6,material:rubber,map:project)
        // Fine diamond grip, built as one mesh instead of hundreds of SceneKit nodes.
        var p=[SIMD3<Float>](), idx=[UInt32]()
        for row in 0..<13 { for col in 0..<48 {
            let z:Float = -19+Float(col)*1.05+(row%2==0 ? 0:0.52), y:Float=7+Float(row)*0.7
            if z>30 || (y>14 && (z < -12 || z>25)){continue}
            let start=UInt32(p.count)
            for q in [SIMD2<Float>(-0.25,0),SIMD2<Float>(0,0.22),SIMD2<Float>(0.25,0),SIMD2<Float>(0,-0.22)] {p.append(sidePoint(y+q.y,z+q.x,lift:0.69))}
            idx += [start,start+1,start+2,start,start+2,start+3]
        }}
        let m=Self.material(0.13,gloss:0.1);m.isDoubleSided=true;node(geometry(p,idx),.zero,m)
    }
    func topButton(_ id:Int,x:Float,z:Float,w:CGFloat,h:CGFloat) {
        let normal=topNormal(x,z),center=SIMD3(x,top(x,z),z)+normal*1.05
        let well=box(w+1.0,h+0.8,1.3,center-normal*0.45,seam,r:1.0)
        orient(well,normal:normal,tangent:SIMD3(1,0,0))
        let cap=box(w,h,2.0,center,Self.material(0.155,gloss:0.35),r:0.9)
        orient(cap,normal:normal,tangent:SIMD3(1,0,0));register(id,cap,number:nil)
    }
    func nagaExtras() {
        topButton(13,x:-25,z:-50,w:6.3,h:12.0)
        topButton(14,x:-26,z:-35,w:6.3,h:12.0)
        topButton(15,x:0,z:-18,w:6.8,h:7.2)
        topButton(16,x:0,z:-6,w:6.8,h:7.5)
        // Ring-finger paddle is a long, low shelf beside the right paddle, not a vertical side key.
        let x:Float=32,z:Float = -21, normal=topNormal(x,z)
        let cap=box(7.0,24.5,2.5,SIMD3(x,top(x,z),z)+normal*1.0,Self.material(0.125,gloss:0.25),r:2.0)
        orient(cap,normal:normal,tangent:SIMD3(1,0,0));register(17,cap,number:nil)
    }
    func wing(_ u:Float,_ v:Float)->SIMD3<Float> {
        let z:Float = -30+86*u, taper=pow(max(0,sin(u*Float.pi)),0.7)
        let inner=sideX(min(section(z).z-0.5,20+12*taper),z)+0.2, outer:Float = -width(z,right:false)-21*taper
        let x=inner+(outer-inner)*v
        // Concave wall flows into a broad, nearly level thumb ledge.
        let y=4.0+(min(section(z).z-0.5,20+12*taper)-4)*pow(1-v,3.4)+0.8*sin(v*Float.pi)
        return SIMD3(x,y,z)
    }
    func mxThumbRest() {
        let mat=Self.material(0.23,gloss:0.35);mat.isDoubleSided=true
        let wingNode=node(mesh(rows:110,columns:70){u,v in self.wing(u,v)},.zero,mat)
        wingNode.name="button-304"
        var rim=[SIMD3<Float>]()
        for i in 0...100 {var p=wing(Float(i)/100,1);p.y-=0.2;rim.append(p)}
        tube(rim,radius:0.8,material:Self.material(0.10,gloss:0.28))
        // Shallow sweeping ribs follow the concavity, rather than straight black stripes.
        for n in 0..<9 {
            let g=mesh(rows:70,columns:5){u,v in
                let along=0.10+Float(n)*0.078+u*0.17+(v-0.5)*0.008
                var p=self.wing(min(0.985,along),0.12+u*0.82)
                p.y+=0.12*sin(v*Float.pi);return p
            }
            let ribMaterial=Self.material(0.185,gloss:0.28);ribMaterial.isDoubleSided=true
            node(g,.zero,ribMaterial)
        }
        let led=box(3.3,1.1,0.6,sidePoint(33.4,2,lift:0.9),green,r:0.45)
        orient(led,normal:sideNormal(33.4,2),tangent:SIMD3(0,0,1))
    }
    func mxButtons() {
        for (id,z) in [(301,Float(1)),(302,Float(-13))] {
            let y:Float=23.5, normal=sideNormal(y,z),center=sidePoint(y,z,lift:0.5)+normal*0.6
            let well=box(13.0,4.5,1.5,center-normal*0.4,seam,r:1.5);orient(well,normal:normal,tangent:SIMD3(0,0,1))
            let cap=box(12.1,3.5,2.1,center,Self.material(0.15,gloss:0.35),r:1.1)
            orient(cap,normal:normal,tangent:SIMD3(0,0,1));register(id,cap,number:nil)
        }
        topButton(305,x:0,z:-13,w:5.9,h:9.5)
        // Entire thumb rest is the gesture press target; highlight its small embossed dash.
        let u:Float=0.61,v:Float=0.82, p=wing(u,v)
        let du=wing(u+0.001,v)-wing(u-0.001,v), dv=wing(u,v+0.001)-wing(u,v-0.001)
        var normal=simd_normalize(simd_cross(du,dv));if normal.y<0{normal = -normal}
        let cap=box(1.2,5.7,0.55,p+normal*0.35,Self.material(0.19,gloss:0.18),r:0.45)
        orient(cap,normal:normal,tangent:SIMD3(1,0,0));register(304,cap,number:nil)
    }
    func register(_ id:Int,_ cap:SCNNode,number:String?,depth:Float=1.5,size:Float=3.1) {
        // Selection must never recolor another control that shares a base material.
        if let geometry=cap.geometry {geometry.materials=geometry.materials.map{$0.copy() as! SCNMaterial}}
        cap.name="button-\(id)";buttons[id]=cap
        if let number {legend(number,on:cap,depth:depth,size:size,lit:true)}
    }
    func legend(_ text:String,on cap:SCNNode,depth:Float,size:Float,lit:Bool) {
        let g=SCNText(string:text,extrusionDepth:0.005);g.font=NSFont.systemFont(ofSize:1,weight:.medium);g.flatness=0.025
        let m=SCNMaterial();m.lightingModel = .constant
        m.diffuse.contents=lit ? NSColor(red:0.42,green:0.95,blue:0.16,alpha:1):NSColor(calibratedWhite:0.43,alpha:1)
        g.materials=[m];let n=SCNNode(geometry:g),bounds=g.boundingBox
        n.pivot=SCNMatrix4MakeTranslation((bounds.max.x+bounds.min.x)/2,(bounds.max.y+bounds.min.y)/2,0)
        n.scale=SCNVector3(size,size,size);n.position=SCNVector3(0,0,depth);cap.addChildNode(n)
    }
    func tube(_ points:[SIMD3<Float>],radius:Float,material:SCNMaterial) {
        guard points.count>1 else{return}
        // One indexed mesh per seam; prevents thousands of draw calls in header cards.
        let g=mesh(rows:points.count-1,columns:8){u,v in
            let i=min(points.count-1,Int((u*Float(points.count-1)).rounded()))
            let tangent=simd_normalize(points[min(i+1,points.count-1)]-points[max(0,i-1)])
            let helper:SIMD3<Float>=abs(tangent.y)>0.95 ? SIMD3(1,0,0):SIMD3(0,1,0)
            let a=simd_normalize(simd_cross(tangent,helper)), b=simd_cross(tangent,a), angle=v*2*Float.pi
            return points[i]+radius*(a*cos(angle)+b*sin(angle))
        }
        node(g,.zero,material)
    }
    func port() {
        box(10,3.7,0.6,SIMD3(0,9.2,-63.1),seam,r:1.6)
        box(7.1,0.8,0.8,SIMD3(0,9.2,-63.5),Self.material(0.29,gloss:0.6),r:0.3)
    }
    func underside() {
        for z:Float in [-44,40] {box(28,1.2,9,SIMD3(0,2.4,z),rubber,r:0.55)}
        let g=SCNCylinder(radius:3.7,height:0.5);g.radialSegmentCount=40
        node(g,SIMD3(0,1.3,0),seam)
    }
    func contactShadow() {
        let bitmap=NSBitmapImageRep(bitmapDataPlanes:nil,pixelsWide:128,pixelsHigh:128,bitsPerSample:8,samplesPerPixel:4,hasAlpha:true,isPlanar:false,colorSpaceName:.deviceRGB,bytesPerRow:512,bitsPerPixel:32)!
        for y in 0..<128 {for x in 0..<128 {
            let u=Float(x-64)/64,v=Float(y-64)/64,r=u*u+v*v
            let alpha=UInt8(max(0,(exp(-r*3.5)-exp(-3.5)))*65)
            let i=y*512+x*4
            bitmap.bitmapData![i]=0;bitmap.bitmapData![i+1]=0;bitmap.bitmapData![i+2]=0;bitmap.bitmapData![i+3]=alpha
        }}
        let image=NSImage(size:NSSize(width:128,height:128));image.addRepresentation(bitmap)
        let material=SCNMaterial();material.lightingModel = .constant;material.diffuse.contents=image
        material.writesToDepthBuffer=false
        let shadow=node(SCNPlane(width:family == .naga ? 94:114,height:154),SIMD3(family == .naga ? 0:-6,0,3),material)
        shadow.eulerAngles.x = -.pi/2;shadow.name="contact-shadow"
    }
    func finishSilhouette() {
        // The front edge is rounded in plan and the MX right paddle ends behind the left.
        func warp(_ p:SIMD3<Float>)->SIMD3<Float> {
            let blend=pow(max(0,min(1,(-p.z-40)/23)),3),f=p.x/30
            let shift=blend*(4*f*f+(family == .mxMaster3s ? 3.8*f:0))
            return SIMD3(p.x,p.y,p.z+shift)
        }
        // Shell, patches and seams are baked in mouse space; primitives retain their native normals.
        for node in root.childNodes {
            guard let g=node.geometry else{continue}
            if node.simdPosition == .zero, !(g is SCNText), let source=g.sources(for:.vertex).first {
                let data=source.data
                var vertices=[SCNVector3](),original=[SIMD3<Float>]()
                data.withUnsafeBytes { bytes in
                    for i in 0..<source.vectorCount {
                        let offset=source.dataOffset+i*source.dataStride
                        let x=bytes.loadUnaligned(fromByteOffset:offset,as:Float.self)
                        let y=bytes.loadUnaligned(fromByteOffset:offset+4,as:Float.self)
                        let z=bytes.loadUnaligned(fromByteOffset:offset+8,as:Float.self)
                        let p=SIMD3(x,y,z);original.append(p);vertices.append(SCNVector3(warp(p)))
                    }
                }
                // Deforming only vertices left the old normals behind, creating false
                // creases near the nose. Transform normals by the inverse transpose.
                var sources=[SCNGeometrySource(vertices:vertices)]
                if let normals=g.sources(for:.normal).first, normals.vectorCount==original.count {
                    var transformed=[SCNVector3]()
                    normals.data.withUnsafeBytes { bytes in
                        for i in original.indices {
                            let offset=normals.dataOffset+i*normals.dataStride
                            let n=SIMD3(bytes.loadUnaligned(fromByteOffset:offset,as:Float.self),bytes.loadUnaligned(fromByteOffset:offset+4,as:Float.self),bytes.loadUnaligned(fromByteOffset:offset+8,as:Float.self))
                            let p=original[i],e:Float=0.01
                            let dx=(warp(p+SIMD3(e,0,0))-warp(p-SIMD3(e,0,0)))/(2*e)
                            let dy=(warp(p+SIMD3(0,e,0))-warp(p-SIMD3(0,e,0)))/(2*e)
                            let dz=(warp(p+SIMD3(0,0,e))-warp(p-SIMD3(0,0,e)))/(2*e)
                            let jacobian=simd_float3x3(columns:(dx,dy,dz))
                            transformed.append(SCNVector3(simd_normalize(jacobian.inverse.transpose*n)))
                        }
                    }
                    sources.append(SCNGeometrySource(normals:transformed))
                }
                sources += g.sources.filter{$0.semantic != .vertex && $0.semantic != .normal}
                let replacement=SCNGeometry(sources:sources,elements:g.elements);replacement.materials=g.materials;node.geometry=replacement
            } else {node.simdPosition=warp(node.simdPosition)}
        }
    }
}
