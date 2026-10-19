import AppKit
import SceneKit
import Metal
import simd
import ThumbKeyCore

enum MouseViewAngle:String,CaseIterable,Identifiable {
    case overview,left,top,right,bottom
    var id:String{rawValue}
    var title:String{switch self{case .overview:return "Overview";case .left:return "Thumb";case .top:return "Top";case .right:return "Right";case .bottom:return "Bottom"}}
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
        builder.scene.lightingEnvironment.intensity=1.65
        for (position,power) in [(SCNVector3(-90,180,-100),CGFloat(850)),(SCNVector3(100,100,70),CGFloat(260)),(SCNVector3(-65,-140,-70),CGFloat(550))] {
            let light=SCNNode();light.light=SCNLight();light.light?.type = .omni;light.light?.intensity=power;light.position=position;builder.root.addChildNode(light)
        }
        let ambient=SCNNode();ambient.light=SCNLight();ambient.light?.type = .ambient;ambient.light?.intensity=35;builder.root.addChildNode(ambient)
        let undersideLight=SCNNode();undersideLight.light=SCNLight();undersideLight.light?.type = .directional
        undersideLight.light?.intensity=650;undersideLight.eulerAngles=SCNVector3(Float.pi/2,0,0)
        builder.root.addChildNode(undersideLight)
        return(builder.scene,camera,builder.buttons)
    }
    static func position(_ camera:SCNNode,angle:MouseViewAngle,thumbnail:Bool){
        let target=SCNVector3(-4,20,0)
        switch angle {
        case .overview:camera.position=SCNVector3(-155,115,-165)
        case .left:camera.position=SCNVector3(-220,65,-25)
        case .right:camera.position=SCNVector3(220,85,-30)
        case .top:camera.position=SCNVector3(-4,270,-0.1)
        case .bottom:camera.position=SCNVector3(-4,-230,-0.1)
        }
        let vertical=angle == .top || angle == .bottom
        if vertical{camera.look(at:target,up:SCNVector3(0,0,-1),localFront:SCNVector3(0,0,-1))}else{camera.look(at:target,up:SCNVector3(0,1,0),localFront:SCNVector3(0,0,-1))}
        camera.camera?.orthographicScale=thumbnail ? 65:vertical ? 73:57
    }
    /// Original studio illumination, shared by the cards and the interactive model.
    /// Broad highlights reveal curvature without importing photographs or texture assets.
    private static let studioEnvironment:NSImage = {
        // Softboxes against a darker studio give metal a readable reflected band,
        // while leaving the graphite body matte instead of uniformly gray.
        let width=512,height=256
        let bitmap=NSBitmapImageRep(bitmapDataPlanes:nil,pixelsWide:width,pixelsHigh:height,bitsPerSample:8,samplesPerPixel:4,hasAlpha:true,isPlanar:false,colorSpaceName:.deviceRGB,bytesPerRow:width*4,bitsPerPixel:32)!
        for y in 0..<height {for x in 0..<width {
            let u=Float(x)/Float(width),v=Float(y)/Float(height)
            let key=exp(-pow(abs((u-0.22)/0.15),6)-pow(abs((v-0.31)/0.14),6))
            let strip=exp(-pow(abs((u-0.70)/0.065),6)-pow(abs((v-0.38)/0.25),6))
            let ceiling=0.09+0.12*max(0,1-v*2)
            let value=UInt8(min(1,ceiling+0.87*key+0.75*strip)*255)
            let i=(y*width+x)*4
            bitmap.bitmapData![i]=value;bitmap.bitmapData![i+1]=value;bitmap.bitmapData![i+2]=value;bitmap.bitmapData![i+3]=255
        }}
        let image=NSImage(size:NSSize(width:width,height:height));image.addRepresentation(bitmap);return image
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
                if plate == .twelve {
                    var inspectionViews:[(String,SCNVector3)]=[("rear-thumb",SCNVector3(-150,95,165)),("bottom-oblique",SCNVector3(145,-135,150)),("front-low",SCNVector3(-4,65,-230)),("thumb-low",SCNVector3(-230,38,-45)),("rear-low",SCNVector3(-100,55,220))]
                    if family == .naga {inspectionViews.append(("front-right",SCNVector3(150,145,-170)))}
                    for (name,position) in inspectionViews {
                        camera.position=position
                        camera.look(at:SCNVector3(-4,20,0),up:SCNVector3(0,1,0),localFront:SCNVector3(0,0,-1))
                        camera.camera?.orthographicScale=57
                        let renderer=SCNRenderer(device:MTLCreateSystemDefaultDevice(),options:nil);renderer.scene=scene;renderer.pointOfView=camera
                        let image=renderer.snapshot(atTime:0,with:CGSize(width:1000,height:720),antialiasingMode:.multisampling4X)
                        if let tiff=image.tiffRepresentation,let bitmap=NSBitmapImageRep(data:tiff),let png=bitmap.representation(using:.png,properties:[:]) {
                            try png.write(to:directory.appendingPathComponent("\(family.rawValue)-\(plate.rawValue)-\(name).png"))
                        }
                    }
                }
                let missing=expected.subtracting(visible).sorted()
                print("\(family.rawValue) plate \(plate.rawValue): \(buttons.count) controls, missing visible hit targets: \(missing); \(String(format:"%.2f",Date().timeIntervalSince(started)))s")
                report.append(["mouse":family.rawValue,"plate":plate.rawValue,"controlIDs":expected.sorted(),"visibleHitTargets":visible.sorted(),"missingHitTargets":missing])
            }
        }
        try JSONSerialization.data(withJSONObject:report,options:[.prettyPrinted,.sortedKeys]).write(to:directory.appendingPathComponent("model-validation.json"))
        if report.contains(where:{!($0["missingHitTargets"] as? [Int] ?? []).isEmpty}) {
            throw NSError(domain:"ThumbKey.ModelValidation",code:1,userInfo:[NSLocalizedDescriptionKey:"A mapped control is hidden from every preset; see model-validation.json."])
        }
    }

}

private final class MouseMeshBuilder {
    let scene = SCNScene()
    var root: SCNNode { scene.rootNode }
    let family: MouseFamily
    let hotspots: Bool
    var buttons = [Int: SCNNode]()
    private var conformingControls=Set<ObjectIdentifier>()
    let shellMat = material(0.19, gloss: 0.60)
    let clickMat = material(0.20, gloss: 0.58)
    let rubber = material(0.085, gloss: 0.08)
    let baseMat = material(0.12, gloss: 0.12)
    let seam = material(0.025, gloss: 0.12)
    let metal = material(0.90, gloss: 0.85)
    let green = luminous(NSColor(red: 0.28, green: 0.93, blue: 0.06, alpha: 1))

    init(family: MouseFamily, hotspots: Bool) {
        self.family = family; self.hotspots = hotspots
        if family == .mxMaster3s {
            shellMat.diffuse.contents=NSColor(calibratedWhite:0.235,alpha:1)
            shellMat.roughness.contents=0.53
            clickMat.diffuse.contents=NSColor(calibratedWhite:0.225,alpha:1)
            clickMat.roughness.contents=0.47
        }
    }
    static func material(_ white: CGFloat, gloss: CGFloat = 0.3) -> SCNMaterial {
        let m = SCNMaterial()
        m.lightingModel = .physicallyBased
        m.diffuse.contents = NSColor(calibratedWhite: white, alpha: 1)
        m.metalness.contents = gloss > 0.6 ? 0.85:0.0
        m.roughness.contents = gloss > 0.6 ? 0.18:0.84-gloss*0.80
        if white>=0.07 && white<=0.25 && gloss<=0.6 {
            m.normal.contents=plasticGrain;m.normal.intensity=0.07
            m.normal.wrapS = .repeat;m.normal.wrapT = .repeat
            m.normal.contentsTransform=SCNMatrix4MakeScale(6,10,1)
        }
        return m
    }
    // Fine molded-plastic grain, original and deterministic. Kept subtle enough
    // that silhouettes and button labels stay clean at the mapping-view size.
    private static let plasticGrain:NSImage = {
        let size=128
        let bitmap=NSBitmapImageRep(bitmapDataPlanes:nil,pixelsWide:size,pixelsHigh:size,bitsPerSample:8,samplesPerPixel:4,hasAlpha:true,isPlanar:false,colorSpaceName:.deviceRGB,bytesPerRow:size*4,bitsPerPixel:32)!
        func height(_ x:Int,_ y:Int)->Float {
            var n=UInt32((x+size)%size+((y+size)%size)*size)
            n=(n ^ 61) ^ (n >> 16);n=n &* 9;n=n ^ (n >> 4);n=n &* 0x27d4eb2d;n=n ^ (n >> 15)
            return Float(n & 1023)/1023
        }
        for y in 0..<size {for x in 0..<size {
            let n=simd_normalize(SIMD3<Float>((height(x-1,y)-height(x+1,y))*0.35,(height(x,y-1)-height(x,y+1))*0.35,1))
            let i=(y*size+x)*4
            bitmap.bitmapData![i]=UInt8((n.x*0.5+0.5)*255);bitmap.bitmapData![i+1]=UInt8((n.y*0.5+0.5)*255);bitmap.bitmapData![i+2]=UInt8((n.z*0.5+0.5)*255);bitmap.bitmapData![i+3]=255
        }}
        let image=NSImage(size:NSSize(width:size,height:size));image.addRepresentation(bitmap);return image
    }()
    static func luminous(_ color: NSColor) -> SCNMaterial {
        let m = material(0.1); m.diffuse.contents = color
        m.emission.contents = color.blended(withFraction: 0.78, of: .black)
        return m
    }
    // Millimetre-scale control sections: z (nose -> heel), half width, crown height.
    // The Naga has a broad low nose and right finger shelf. MX has a taller, tilted crown.
    lazy var sections: [SIMD3<Float>] = {
        if family == .naga {
            return [.init(-63,24,10), .init(-60,27,17), .init(-45,29,28),
                    .init(-25,30,36), .init(-3,32,42), .init(20,33,43),
                    .init(41,29,35), .init(56,20,21), .init(63,0.5,6.1)]
        }
        // The user's scan places the MX crown farther forward than our first illustration.
        // The front photographs show a continuous shallow ramp into the paddles,
        // not a short, steep dome above a vertical nose.
        return [.init(-63,25,11.8), .init(-56,26.5,16.5), .init(-44,27,27),
                .init(-24,28,40), .init(-3,30,49), .init(12,32,51), .init(20,32,49),
                .init(42,29,34), .init(56,20,18), .init(63,0.5,6.1)]
    }()
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
        if z>20 {
            let t=max(0,min(1,(z-20)/43)),p:Float=2.2
            // Match the crown's square-root approach to the rear pole so the
            // final millimetres close as a smooth dome, not a pointed ridge.
            result.y=(family == .naga ? 33:32)*sqrt(max(0.0000001,1-pow(t,p)))
        }
        let crownStart:Float=family == .naga ? 20:12
        if z>=crownStart {
            let t=max(0,min(1,(z-crownStart)/(63-crownStart)))
            let radius:Float=family == .naga ? 37:45
            // The ellipse meets the low chassis rim with a vertical tangent.
            // Raising its pole halfway up the body made the base curl upward.
            result.z=6+radius*sqrt(max(0,1-t*t))
        }
        return result
    }
    func heelRoundness(_ z:Float)->Float {
        let t=max(0,min(1,(z-44)/19))
        return sqrt(max(0,1-t*t))
    }
    func shoulderHeight(_ z:Float)->Float {6}
    /// Monotone cubic profile interpolation keeps the photo-fitted outline
    /// smooth without overshooting into a bulge between measured stations.
    func profile(_ z:Float,_ points:[SIMD2<Float>])->Float {
        let i=min(points.count-2,max(0,(0..<points.count-1).first{z<=points[$0+1].x} ?? points.count-2))
        let a=points[i],b=points[i+1],h=b.x-a.x,t=max(0,min(1,(z-a.x)/h))
        func slope(_ k:Int)->Float {
            if k==0{return (points[1].y-points[0].y)/(points[1].x-points[0].x)}
            if k==points.count-1{return (points[k].y-points[k-1].y)/(points[k].x-points[k-1].x)}
            let h0=points[k].x-points[k-1].x,h1=points[k+1].x-points[k].x
            let d0=(points[k].y-points[k-1].y)/h0,d1=(points[k+1].y-points[k].y)/h1
            guard d0*d1>0 else{return 0}
            return 3*(h0+h1)/((2*h1+h0)/d0+(h1+2*h0)/d1)
        }
        return (2*t*t*t-3*t*t+1)*a.y+(t*t*t-2*t*t+t)*h*slope(i)
            + (-2*t*t*t+3*t*t)*b.y+(t*t*t-t*t)*h*slope(i+1)
    }
    let nagaLeftOutline:[SIMD2<Float>]=[.init(-63,24),.init(-58,28),.init(-49,30),.init(-41,31),.init(-30,32),.init(-12,32.5),.init(10,33),.init(28,33)]
    let nagaRightOutline:[SIMD2<Float>]=[.init(-63,25),.init(-58,28),.init(-49,29),.init(-41,36),.init(-30,40),.init(-12,41),.init(10,40),.init(28,37.5)]
    func width(_ z: Float, right: Bool) -> Float {
        if family == .naga {
            if z>28 {
                let t=max(0,min(1,(z-28)/35))
                return (right ? 37.5:33)*sqrt(max(0.0000001,1-t*t))
            }
            return profile(z,right ? nagaRightOutline:nagaLeftOutline)
        }
        return section(z).y
    }
    var crownExponent:Float {family == .naga ? 3.2:2.8}
    func upperExponent(_ z:Float)->Float {
        // Broad click paddles across the front, blending into the rounded palm.
        let t=max(0,min(1,(-z-20)/35))
        return crownExponent+(family == .mxMaster3s ? 1.7:0.55)*t*t*(3-2*t)
    }
    func top(_ x: Float, _ z: Float) -> Float {
        let s=section(z), w=width(z,right:x>0), f=min(1,abs(x)/max(0.001,w))
        let base=shoulderHeight(z),rounding=heelRoundness(z)
        let h: Float = base+(s.z-base)*pow(max(0,1-pow(f,upperExponent(z))),0.52)
        if family == .mxMaster3s { return h - 4*x/max(1,w)*pow(max(0,1-f),0.28)*rounding }
        // A soft depression lets the ring finger sit alongside right-click.
        return h - (x>0 ? 3*exp(-pow((z+20)/25,2))*pow(f,2)*rounding:0)
    }
    func sideX(_ y: Float, _ z: Float, right: Bool = false) -> Float {
        let section=self.section(z), w=width(z,right:right), sign:Float=right ? 1:-1
        let base=shoulderHeight(z),rounding=heelRoundness(z)
        if y<base {
            // Let the MX ledge meet the rolled underside as well as the upper
            // shell; clamping to maximum width leaves a detached rear corner.
            let floor=undersideFloor(z)
            let fraction=max(0,min(1,(y-floor)/max(0.0001,base-floor)))
            let sine=0.35+0.65*pow(fraction,1/1.60)-1
            return sign*w*pow(sqrt(max(0,1-sine*sine)),2/crownExponent)
        }
        if family == .naga && !right {
            let fraction=max(0,min(0.9999,(y-base)/max(0.0001,section.z-base)))
            return -w*pow(max(0,1-pow(fraction,1/0.52)),1/upperExponent(z))
        }
        var lo:Float=0,hi:Float=0.9999
        let depression:Float=family == .naga && right ? 3*exp(-pow((z+20)/25,2))*rounding:0
        // Keep inverse evaluation precise enough for the finite-difference normals;
        // coarser rounding creates visible speckling on the side-wheel housing.
        for _ in 0..<18 {
            let f=(lo+hi)/2
            var h:Float=base+(section.z-base)*pow(max(0,1-pow(f,upperExponent(z))),0.52)
            if family == .mxMaster3s {h -= 4*sign*f*pow(max(0,1-f),0.28)*rounding}
            else if right {h -= depression*f*f}
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
        let g=geometry(p,indices)
        var uv=[CGPoint]()
        for r in 0...rows {for c in 0...columns {uv.append(CGPoint(x:Double(c)/Double(columns),y:Double(r)/Double(rows)))}}
        return SCNGeometry(sources:g.sources+[SCNGeometrySource(textureCoordinates:uv)],elements:g.elements)
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
    func gridMaterials(_ geometry:SCNGeometry,rows:Int,columns:Int,split:Int,upper:SCNMaterial,lower:SCNMaterial)->SCNGeometry {
        var top=[UInt32](),bottom=[UInt32]()
        for r in 0..<rows {for c in 0..<columns {
            let a=UInt32(r*(columns+1)+c),b=a+1,d=a+UInt32(columns+1),e=d+1
            if c<split {top += [a,b,d,d,b,e]}else{bottom += [a,b,d,d,b,e]}
        }}
        let result=SCNGeometry(sources:geometry.sources,elements:[SCNGeometryElement(indices:top,primitiveType:.triangles),SCNGeometryElement(indices:bottom,primitiveType:.triangles)])
        result.materials=[upper,lower];return result
    }
    func undersideFloor(_ z:Float)->Float {
        let t=max(0,min(1,(z-59)/4))
        return 1.8+4.2*(1-sqrt(max(0,1-t*t)))
    }
    func undersideHeight(_ z:Float,_ sine:Float)->Float {
        let floor=undersideFloor(z)
        // A flat contact surface with a rolled perimeter, as in the underside
        // photos. The old continuous bowl lifted the rear glide feet off-plane.
        let edge=pow(max(0,(1+sine-0.35)/0.65),1.60)
        return floor+(shoulderHeight(z)-floor)*edge
    }
    func shellTop(_ x:Float,_ z:Float)->Float {
        let t=max(0,min(1,(-z-43)/20))
        // Recess the chassis below the independent front click caps. This also
        // leaves a real shadow gap at the nose, visible from the low side angle.
        let height=top(x,z),base=shoulderHeight(z)
        let crownFraction=max(0,min(1,(height-base)/max(0.001,section(z).z-base)))
        return height-(family == .mxMaster3s ? 1.65:1.05)*t*t*(3-2*t)*crownFraction
    }
    func shell() {
        let body=mesh(rows:220,columns:192) { u,v in
            // Cosine spacing keeps the tight rear rollover smooth in profile.
            let z:Float = -63+63*(1-cos(u*Float.pi)), a=v*2*Float.pi, c=cos(a), sn=sin(a)
            let x=self.width(z,right:c>0)*(c<0 ? -1:1)*pow(abs(c),2/self.crownExponent)
            let y:Float = sn>=0 ? self.shellTop(x,z):self.undersideHeight(z,sn)
            return SIMD3(x,y,z)
        }
        let bodyNode=SCNNode(geometry:gridMaterials(body,rows:220,columns:192,split:96,upper:shellMat,lower:baseMat))
        root.addChildNode(bodyNode)
        // Close both end faces; the low nose sits beneath separately sculpted click paddles.
        for z: Float in [-63,63] {
            // Subdivide the closure before the nose warp. A single triangle fan
            // cannot follow its curved/recessed face and made long dark creases.
            let face=mesh(rows:32,columns:192){u,v in
                let a=(z<0 ? 1:-1)*v*2*Float.pi,c=cos(a),sn=sin(a)
                let x=self.width(z,right:c>0)*(c<0 ? -1:1)*pow(abs(c),2/self.crownExponent)
                let y:Float=sn>=0 ? self.shellTop(x,z):self.undersideHeight(z,sn)
                return SIMD3(x*u,self.shoulderHeight(z)+(y-self.shoulderHeight(z))*u,z)
            }
            let normal=SCNVector3(0,0,z<0 ? -1:1)
            let normals=SCNGeometrySource(normals:Array(repeating:normal,count:face.sources(for:.vertex)[0].vectorCount))
            node(SCNGeometry(sources:face.sources.filter{$0.semantic != .normal}+[normals],elements:face.elements),.zero,shellMat)
        }
        for side: Float in [-1,1] {
            // The MX ledge has its own continuous lower roll. A second shell
            // seam here created disconnected black stubs in front of and behind it.
            if family == .mxMaster3s {continue}
            let points=(0...100).map { i -> SIMD3<Float> in
                let z:Float = -61+62*(1-cos(Float(i)*Float.pi/100))
                let y=self.shoulderHeight(z)+0.6
                return SIMD3(self.sideX(y,z,right:side>0)*1.003,y,z)
            }
            tube(points,radius:0.35,material:seam)
        }
    }
    /// A rounded, closed contour projected onto the shell; useful for real panel seams.
    @discardableResult func patch(_ outline:[SIMD2<Float>], lift:Float, material:SCNMaterial,
                                  map:((SIMD2<Float>,Float)->SIMD3<Float>)?=nil,
                                  outward:SIMD3<Float>?=nil) -> SCNNode {
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
        var vertices=[SIMD3<Float>](),normals=[SIMD3<Float>](),uv=[CGPoint](),indices=[UInt32]()
        var vertexLookup=[SIMD2<Float>:UInt32]()
        func vertex(_ p:SIMD2<Float>)->UInt32 {
            if let index=vertexLookup[p] {return index}
            let dx=project(p+SIMD2(0.02,0),lift)-project(p-SIMD2(0.02,0),lift)
            let dy=project(p+SIMD2(0,0.02),lift)-project(p-SIMD2(0,0.02),lift)
            var normal=simd_normalize(map == nil ? simd_cross(dy,dx):simd_cross(dx,dy))
            if let outward,simd_dot(normal,outward)<0 {normal = -normal}
            let index=UInt32(vertices.count)
            vertices.append(project(p,lift));normals.append(normal)
            uv.append(CGPoint(x:Double(p.x)/64,y:Double(p.y)/126));vertexLookup[p]=index
            return index
        }
        func add(_ a:SIMD2<Float>,_ b:SIMD2<Float>,_ c:SIMD2<Float>,_ depth:Int) {
            if depth<9 && max(simd_length(a-b),max(simd_length(b-c),simd_length(c-a)))>0.85 {
                let ab=(a+b)/2,bc=(b+c)/2,ca=(c+a)/2
                add(a,ab,ca,depth+1);add(ab,b,bc,depth+1);add(ca,bc,c,depth+1);add(ab,bc,ca,depth+1);return
            }
            let ia=vertex(a),ib=vertex(b),ic=vertex(c)
            let face=simd_cross(vertices[Int(ib)]-vertices[Int(ia)],vertices[Int(ic)]-vertices[Int(ia)])
            let normal=normals[Int(ia)]+normals[Int(ib)]+normals[Int(ic)]
            indices += simd_dot(face,normal)>0 ? [ia,ib,ic]:[ia,ic,ib]
        }
        for (a,b,c) in triangles {add(a,b,c,0)}
        let g=SCNGeometry(sources:[SCNGeometrySource(vertices:vertices.map{SCNVector3($0)}),SCNGeometrySource(normals:normals.map{SCNVector3($0)}),SCNGeometrySource(textureCoordinates:uv)],elements:[SCNGeometryElement(indices:indices,primitiveType:.triangles)])
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
                outline=[SIMD2(side*0.45,-63.6),SIMD2(side*22.8,-63.0),
                         SIMD2(side*25.0,-58),SIMD2(side*26,-41),
                         SIMD2(side*26.3,-14),SIMD2(side*8.1,-19),
                         SIMD2(side*7.0,-49.6),SIMD2(side*0.45,-50.4)]
            } else {
                let outer: Float=side<0 ? 20.5:28
                outline=[SIMD2(side*5.9,-62.7),SIMD2(side*23.3,-62.0),SIMD2(side*outer,-41),
                         SIMD2(side*(outer+1),-9),SIMD2(side*5.2,-6),SIMD2(side*5.2,-45)]
            }
            let contour=roundedContour(outline,radius:0.07)
            patch(contour,lift:0.42,material:clickMat)
            let underside:(SIMD2<Float>,Float)->SIMD3<Float>={p,_ in
                let t=max(0,min(1,(-p.y-40)/20))
                return SIMD3(p.x,self.top(p.x,p.y)+0.26-0.95*t*t*(3-2*t),p.y)
            }
            patch(contour,lift:0,material:rubber,map:underside,outward:SIMD3(0,-1,0))
            // Give the front cap a rounded thickness instead of a paper-thin
            // decal on the chassis. The back edge settles flush into the shell.
            let edge=seamContour(contour)
            let edgeMaterial=clickMat.copy() as! SCNMaterial;edgeMaterial.isDoubleSided=true
            node(mesh(rows:edge.count-1,columns:8){u,v in
                let q=edge[min(edge.count-1,Int((u*Float(edge.count-1)).rounded()))]
                let nose=max(0,min(1,(-q.y-40)/20))
                let thickness:Float=0.16+0.95*nose*nose*(3-2*nose)
                let inset:Float=0.13*sin(v*Float.pi)
                return SIMD3(q.x*(1-inset/25),self.top(q.x,q.y)+0.42-thickness*v,q.y+inset)
            },.zero,edgeMaterial)
            let line=seamContour(contour).map{SIMD3($0.x,top($0.x,$0.y)+0.30,$0.y)}
            tube(line,radius:0.16,material:seam)
        }
        // Naga's recessed bridge continues behind the wheel to the two narrow controls.
        if family == .naga {
            let outline=roundedContour([SIMD2(-5.1,-60),SIMD2(5.1,-60),SIMD2(5.1,-29),
                                        SIMD2(4.6,-26),SIMD2(4.6,-4),SIMD2(-4.6,-4),
                                        SIMD2(-4.6,-26),SIMD2(-5.1,-29)],radius:0.10)
            patch(outline,lift:0.3,material:seam)
        } else {
            // The small wordmark is projected onto the curved paddle, not a flat
            // text object that can float above the silhouette from the opposite side.
            let image=NSImage(size:NSSize(width:256,height:120))
            image.lockFocus()
            ("logi" as NSString).draw(in:NSRect(x:3,y:2,width:250,height:118),withAttributes:[.font:NSFont.systemFont(ofSize:100,weight:.semibold),.foregroundColor:NSColor(white:0.43,alpha:1)])
            image.unlockFocus()
            let g=mesh(rows:12,columns:24){u,v in
                let x:Float = -18+10*v,z:Float = -21-4.7*u
                return SIMD3(x,self.top(x,z)+0.65,z)
            }
            var uv=[CGPoint]()
            for r in 0...12 {for c in 0...24 {uv.append(CGPoint(x:Double(c)/24,y:1-Double(r)/12))}}
            let decal=SCNGeometry(sources:g.sources.filter{$0.semantic != .texcoord}+[SCNGeometrySource(textureCoordinates:uv)],elements:g.elements)
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
            // The thumb-wheel axle rises toward the heel and is recessed into a
            // capsule housing. A horizontal floating cylinder exposed its end face.
            let project:(SIMD2<Float>,Float)->SIMD3<Float>={p,lift in
                self.sidePoint(p.y+0.20*(p.x+12),p.x,lift:lift)
            }
            let outline=roundedContour([SIMD2(-26,28.4),SIMD2(8,28.4),SIMD2(8,37.4),SIMD2(-26,37.4)],radius:0.43)
            patch(outline,lift:0.37,material:Self.material(0.12,gloss:0.40),map:project)
            let center=sidePoint(32.8,-13,lift:-0.65)
            let axis=simd_normalize(project(SIMD2(-4,32.8),0)-project(SIMD2(-22,32.8),0))
            _=wheel(center:center,radius:4.15,length:18.0,axis:axis,steel:true)
        }
    }
    func nagaPlate(_ plate: SidePlate) {
        // A conforming removable panel: its edge is a seam on the shell, not an extruded slab.
        // The removable plate occupies the whole left flank. Its upper seam
        // rises above the keypad and sweeps down around the heel in the photos.
        let contour=roundedContour([SIMD2(-60,6.7),SIMD2(40,6.7),SIMD2(54,6.7),
                                   SIMD2(59,7.2),SIMD2(55,13),SIMD2(43,24),
                                   SIMD2(28,34),SIMD2(13,39),SIMD2(-4,37),
                                   SIMD2(-27,30),SIMD2(-46,22.8),SIMD2(-60,14.5)],radius:0.25)
        let project:(SIMD2<Float>,Float)->SIMD3<Float>={p,lift in self.sidePoint(p.y,p.x,lift:lift)}
        patch(contour,lift:0.33,material:Self.material(0.165,gloss:0.32),map:project)
        let edge=seamContour(contour).map{sidePoint($0.y,$0.x,lift:0.40)};tube(edge,radius:0.18,material:seam)
        if plate != .twelve { thumbGrip() }
        for (row,ids) in plate.visualRows.enumerated() {
            for (col,id) in ids.enumerated() {
                let z:Float, y:Float, w:CGFloat, h:CGFloat
                switch plate {
                case .twelve:
                    z = -10+Float(col)*11.6 + Float(row)*0.8
                    y = 29-Float(row)*9.0 + (col==1 || col==2 ? 1.1:0)
                    w=9.5;h=8.35
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
                let cap=box(w,h,2.2,center,Self.material(0.16,gloss:0.48),r:1.0)
                orient(cap,normal:normal,tangent:SIMD3(0,0,1))
                register(id,cap,number:plate == .twelve ? "\(MouseControls.number(id))":nil,depth:1.15,size:3.1)
                // The six-button plate has subtle legends; two-button plate is unnumbered hardware.
                if plate == .six {legend("\(MouseControls.number(id))",on:cap,depth:1.15,size:2.4,lit:false)}
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
        let normal=topNormal(x,z),center=SIMD3(x,top(x,z),z)+normal*0.55
        let well=box(w+1.0,h+0.8,1.3,center-normal*0.45,seam,r:1.0)
        orient(well,normal:normal,tangent:SIMD3(1,0,0))
        let cap=box(w,h,1.25,center,Self.material(0.155,gloss:0.48),r:0.6)
        orient(cap,normal:normal,tangent:SIMD3(1,0,0));register(id,cap,number:nil)
    }
    /// A low cap whose whole surface follows the crown, including its bevel.
    /// The previous tangent-plane boxes pierced the curved shell at one end and
    /// floated above it at the other, especially on the ring-finger shoulder.
    func conformingButton(_ id:Int,_ vertices:[SIMD2<Float>],height:Float=1.2,
                          map:((SIMD2<Float>,Float)->SIMD3<Float>)?=nil,
                          outward:SIMD3<Float>=SIMD3(0,1,0),material:SCNMaterial?=nil) {
        let project=map ?? {p,offset in SIMD3(p.x,self.top(p.x,p.y)+offset,p.y)}
        let contour=roundedContour(vertices,radius:0.18)
        let center=vertices.reduce(SIMD2<Float>.zero,+)/Float(vertices.count)
        let area=contour.indices.reduce(Float(0)) { total,i in
            let a=contour[i],b=contour[(i+1)%contour.count]
            return total+a.x*b.y-a.y*b.x
        }
        // A constant-width gap avoids broad black blocks at the ends of long caps.
        let well=contour.indices.map { i -> SIMD2<Float> in
            let tangent=simd_normalize(contour[(i+1)%contour.count]-contour[(i+contour.count-1)%contour.count])
            let outward=area>0 ? SIMD2(tangent.y,-tangent.x):SIMD2(-tangent.y,tangent.x)
            return contour[i]+outward*0.22
        }
        patch(well,lift:0.46,material:seam,map:map,outward:outward)
        // Choose winding in the projected surface, including either mouse flank.
        let dx=project(center+SIMD2(0.02,0),0)-project(center-SIMD2(0.02,0),0)
        let dy=project(center+SIMD2(0,0.02),0)-project(center-SIMD2(0,0.02),0)
        let positive=simd_dot(simd_cross(dy,dx),outward)>0
        // Sample the long edges before projection. Corner-only caps cut straight
        // chords through a curved flank and exposed irregular islands of the well.
        let sampled=Array(seamContour(contour).dropLast())
        let edge=(area>0)==positive ? sampled:Array(sampled.reversed())
        let rings=max(24,Int(ceil(edge.map{simd_length($0-center)}.max()!/0.6)))
        let origin=project(center,height)
        let cap=node(mesh(rows:rings,columns:edge.count){u,v in
            let i=Int((v*Float(edge.count)).rounded())%edge.count
            let q=center+(edge[i]-center)*u
            let t=max(0,min(1,(u-0.80)/0.20)),bevel=t*t*(3-2*t)
            let lift=height-(height-0.53)*bevel+0.10*(1-u*u)
            return project(q,lift)-origin
        },origin,material ?? Self.material(0.155,gloss:0.48))
        conformingControls.insert(ObjectIdentifier(cap));register(id,cap,number:nil)
    }
    func nagaExtras() {
        // Tapered shoulder switches beside left-click, separated by a narrow gap.
        conformingButton(13,[SIMD2(-24.0,-57.2),SIMD2(-20.8,-58.3),SIMD2(-21.1,-44.3),SIMD2(-25.0,-43.0)])
        conformingButton(14,[SIMD2(-25.3,-41.4),SIMD2(-21.2,-42.7),SIMD2(-21.8,-30.0),SIMD2(-26.0,-29.0)])
        // Small, closely spaced controls in the recessed bridge behind the wheel.
        for (id,z) in [(15,Float(-21)),(16,Float(-10))] {
            conformingButton(id,[SIMD2(-3.3,z-3.6),SIMD2(3.3,z-3.6),SIMD2(3.3,z+3.6),SIMD2(-3.3,z+3.6)],height:1.0)
        }
        // The V3's ring-finger control is the long sculpted flank below M2,
        // extending almost to the nose, not a small switch on the crown.
        let right:(SIMD2<Float>,Float)->SIMD3<Float>={p,lift in
            SIMD3(self.sideX(p.y,p.x,right:true)+lift,p.y,p.x)
        }
        conformingButton(17,[SIMD2(-59,9),SIMD2(-56,16),SIMD2(-43,24),
                             SIMD2(-25,30),SIMD2(-6,31),SIMD2(2,27),
                             SIMD2(-9,20),SIMD2(-29,14),SIMD2(-51,9)],height:0.85,
                         map:right,outward:SIMD3(1,0,0),material:Self.material(0.16,gloss:0.35))
        let grip=roundedContour([SIMD2(-49,7),SIMD2(9,7),SIMD2(11,14),
                                 SIMD2(-4,18),SIMD2(-29,12),SIMD2(-48,10)],radius:0.32)
        patch(grip,lift:0.40,material:rubber,map:right,outward:SIMD3(1,0,0))
        let edge=seamContour(grip).map{right($0,0.44)}
        tube(edge,radius:0.14,material:Self.material(0.17,gloss:0.25))
        // Molded diamond grip below the paddle, integrated as one lightweight mesh.
        var points=[SIMD3<Float>](),indices=[UInt32]()
        for row in 0..<8 {for col in 0..<46 {
            let z:Float = -43+Float(col)*1.05+(row%2==0 ? 0:0.52)
            let y:Float=7.8+Float(row)*0.72
            let ceiling:Float=10.0+6.2*max(0,min(1,(z+37)/34))
            if y>ceiling || (z < -38 && y>9){continue}
            let start=UInt32(points.count)
            for q in [SIMD2<Float>(-0.23,0),SIMD2<Float>(0,0.21),SIMD2<Float>(0.23,0),SIMD2<Float>(0,-0.21)] {
                points.append(right(SIMD2(z,y)+q,0.48))
            }
            indices += [start,start+2,start+1,start,start+3,start+2]
        }}
        let grain=Self.material(0.13,gloss:0.14);grain.isDoubleSided=true
        node(geometry(points,indices),.zero,grain)
    }
    // The actual MX footprint has a concave neck and a broad rear ledge,
    // not the old sinusoidal wing which made the whole mouse pear-shaped.
    let wingExtensions:[SIMD2<Float>]=[.init(-39,0),.init(-28,0),.init(-22,0.4),.init(-16,3),.init(-8,13),.init(0,20),.init(15,25),.init(30,26),.init(42,24),.init(53,17),.init(60,6),.init(63,0)]
    func wingTaper(_ z:Float)->Float {max(0,min(1,profile(z,wingExtensions)/26))}
    func wingBottom(_ z:Float)->Float {
        let floor=undersideFloor(z),taper=wingTaper(z)
        // Collapse the roll into the side wall where the ledge disappears;
        // elsewhere its underside shares the chassis contact plane.
        return floor+(shoulderHeight(z)-floor)*pow(max(0,1-taper*3),3)-0.06*taper
    }
    func wing(_ u:Float,_ v:Float)->SIMD3<Float> {
        let z:Float = -39+102*u,taper=wingTaper(z)
        let height=min(section(z).z,shoulderHeight(z)+13+13*taper)
        let edgeHeight=shoulderHeight(z)-1.5*taper*heelRoundness(z)
        let y=edgeHeight+(height-edgeHeight)*pow(1-v,2.8)+0.5*sin(v*Float.pi)*taper
        let x=sideX(y,z)+0.20-profile(z,wingExtensions)*v*v
        let envelope=pow(max(0,sin(v*Float.pi)),2)*taper*taper
        let rib:Float=0.14*envelope*cos((u-0.18*v)*Float.pi*28)
        return SIMD3(x,y+rib,z)
    }
    func mxThumbRest() {
        let mat=Self.material(0.225,gloss:0.32)
        // Close the enlarged ledge around its rolled edge and onto the chassis.
        let wingNode=node(mesh(rows:180,columns:150){u,v in
            if v<=0.76 {return self.wing(u,v/0.76)}
            let outer=self.wing(u,1),taper=self.wingTaper(outer.z),bottom=self.wingBottom(outer.z)
            if v<=0.88 {
                let t=(v-0.76)/0.12
                return SIMD3(outer.x-0.45*taper*sin(t*Float.pi),outer.y-(outer.y-bottom)*(0.5-0.5*cos(t*Float.pi)),outer.z)
            }
            let t=(v-0.88)/0.12,inner=self.sideX(bottom,outer.z)+1.0
            return SIMD3(outer.x+(inner-outer.x)*t,bottom,outer.z)
        },.zero,mat)
        if let geometry=wingNode.geometry {wingNode.geometry=gridMaterials(geometry,rows:180,columns:150,split:132,upper:mat,lower:baseMat)}
        wingNode.name="button-304"
        let led=box(3.0,0.8,0.35,sidePoint(35.5,3,lift:0.6),green,r:0.17)
        orient(led,normal:sideNormal(35.5,3),tangent:SIMD3(0,0.20,1))
    }
    func mxButtons() {
        for (id,z) in [(301,Float(1)),(302,Float(-13))] {
            let project:(SIMD2<Float>,Float)->SIMD3<Float>={p,lift in
                self.sidePoint(p.y+0.20*(p.x+12),p.x,lift:lift)
            }
            conformingButton(id,[SIMD2(z-6,22.0),SIMD2(z+6,22.0),
                                 SIMD2(z+6,25.3),SIMD2(z-6,25.3)],height:0.85,
                             map:project,outward:SIMD3(-1,0,0),material:Self.material(0.18,gloss:0.42))
        }
        conformingButton(305,[SIMD2(-3,-17.7),SIMD2(3,-17.7),SIMD2(3,-8.3),SIMD2(-3,-8.3)],height:0.85)
        // Entire thumb rest is the gesture press target; highlight its small embossed dash.
        let u:Float=0.64,v:Float=0.82, p=wing(u,v)
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
        // A real rounded USB-C aperture; thin SCNBoxes clamp their corner radius
        // to the depth and previously read as square stickers on the nose.
        func capsule(_ width:Float,_ height:Float)->[SIMD2<Float>] {
            let radius=height/2,offset=(width-height)/2
            return (0..<64).map{i in
                let a=Float(i)*2*Float.pi/64
                return SIMD2((cos(a)>=0 ? offset:-offset)+radius*cos(a),6.8+radius*sin(a))
            }
        }
        let front:(SIMD2<Float>,Float)->SIMD3<Float>={p,lift in SIMD3(p.x,p.y,-63.12-lift)}
        patch(capsule(10.1,3.8),lift:0.03,material:Self.material(0.10,gloss:0.45),map:front,outward:SIMD3(0,0,-1))
        patch(capsule(9.5,3.2),lift:0.07,material:seam,map:front,outward:SIMD3(0,0,-1))
        patch(capsule(6.8,0.65),lift:0.10,material:Self.material(0.28,gloss:0.64),map:front,outward:SIMD3(0,0,-1))
    }
    /// Project every base detail onto the rolled body rather than floating a
    /// plane beneath it. Underside parts are descriptive, not remappable inputs.
    func bottomPoint(_ p:SIMD2<Float>,_ lift:Float)->SIMD3<Float> {
        let f=min(1,abs(p.x)/max(0.001,width(p.y,right:p.x>0)))
        let cosine=pow(f,crownExponent/2),sine = -sqrt(max(0,1-cosine*cosine))
        return SIMD3(p.x,undersideHeight(p.y,sine)-lift,p.y)
    }
    func underside() {
        let project:(SIMD2<Float>,Float)->SIMD3<Float>={self.bottomPoint($0,$1)}
        let down=SIMD3<Float>(0,-1,0)
        let foot=Self.material(family == .naga ? 0.80:0.065,gloss:0.40)
        let lens=Self.material(0.035,gloss:0.55)
        lens.metalness.contents=0.0;lens.roughness.contents=0.85
        func oval(_ x:Float,_ z:Float,_ rx:Float,_ rz:Float)->[SIMD2<Float>] {
            (0..<48).map { i in
                let a=Float(i)*2*Float.pi/48
                return SIMD2(x+rx*cos(a),z+rz*sin(a))
            }
        }
        func rect(_ x:Float,_ z:Float,_ w:Float,_ h:Float)->[SIMD2<Float>] {
            roundedContour([SIMD2(x-w/2,z-h/2),SIMD2(x+w/2,z-h/2),SIMD2(x+w/2,z+h/2),SIMD2(x-w/2,z+h/2)],radius:0.30)
        }
        func plate(_ contour:[SIMD2<Float>],_ lift:Float,_ mat:SCNMaterial) {
            patch(contour,lift:lift,material:mat,map:project,outward:down)
        }
        func label(_ text:String,_ x:Float,_ z:Float,_ size:Float) {
            let g=SCNText(string:text,extrusionDepth:0);g.font=NSFont.systemFont(ofSize:1,weight:.medium);g.flatness=0.04
            let m=SCNMaterial();m.lightingModel = .constant;m.diffuse.contents=NSColor(calibratedWhite:0.44,alpha:1)
            let n=node(g,bottomPoint(SIMD2(x,z),0.60),m),bounds=g.boundingBox
            n.pivot=SCNMatrix4MakeTranslation((bounds.max.x+bounds.min.x)/2,(bounds.max.y+bounds.min.y)/2,0)
            // Viewed from below, screen right is physical left; text up is noseward.
            n.simdOrientation=simd_quatf(simd_float3x3(columns:(SIMD3(-1,0,0),SIMD3(0,0,-1),down)))
            n.scale=SCNVector3(size,size,size)
        }
        if family == .naga {
            // Fit the broad asymmetric front foot and circular rear foot to
            // the user's underside photo, preserving the larger right shoulder.
            plate(roundedContour([SIMD2(-26,-53),SIMD2(-12,-56),SIMD2(12,-56),SIMD2(24,-52),SIMD2(26,-44),SIMD2(32,-33),SIMD2(-28,-33)],radius:0.18),0.32,foot)
            var rearFoot=[SIMD2<Float>]()
            for i in 0...48 {let a=Float(i)*Float.pi/48;rearFoot.append(SIMD2(28*cos(a),29+28*sin(a)))}
            for i in 1...16 {let a=Float.pi+Float(i)*Float.pi/16;rearFoot.append(SIMD2(-24+4*cos(a),29+4*sin(a)))}
            for i in 1...48 {let a=Float.pi-Float(i)*Float.pi/48;rearFoot.append(SIMD2(20*cos(a),29+20*sin(a)))}
            for i in 1..<16 {let a=Float.pi+Float(i)*Float.pi/16;rearFoot.append(SIMD2(24+4*cos(a),29+4*sin(a)))}
            plate(rearFoot,0.34,foot)
            plate(oval(0,29,19.2,19.2),0.22,seam)
            plate(oval(0,29,18.3,18.3),0.30,Self.material(0.16,gloss:0.25))
            for x:Float in [-14,14] {plate(oval(x,28,0.30,0.30),0.36,Self.material(0.32,gloss:0.20))}
            plate(oval(0,-3,7.7,7.7),0.35,foot)
            plate(oval(0,-3,4.6,4.6),0.40,seam)
            plate(oval(0,-3,2.6,3.1),0.46,lens)
            // Photo locations: vertical ring-finger lock at the outer shoulder,
            // wireless slider beside the sensor and elongated profile button.
            plate(rect(28,-25,6.6,9.4),0.27,seam)
            plate(oval(28,-26.8,2.3,2.3),0.44,Self.material(0.24,gloss:0.35))
            plate(rect(13,-3,6.3,10.5),0.27,seam)
            plate(oval(13,-5.3,2.2,2.2),0.44,Self.material(0.24,gloss:0.35))
            plate(rect(-13,-3,6.5,10.6),0.27,seam)
            plate(rect(-13,-3,4.8,8.0),0.43,Self.material(0.23,gloss:0.32))
            plate(oval(-13,-13,0.75,0.75),0.45,green)
            label("NAGA V3 PRO",0,-25,2.6)
            label("PROFILE",-13,4.8,1.45)
            label("BT",13,-11,1.3);label("2.4",13,5.5,1.3)
        } else {
            plate(rect(0,1,25,94),0.13,seam)
            plate(rect(0,1,23.5,92),0.20,Self.material(0.105,gloss:0.20))
            // Four low-friction pads: nose, heel, body flank and thumb ledge.
            plate(roundedContour([SIMD2(-11,-54),SIMD2(11,-54),SIMD2(12,-48),SIMD2(9,-43),SIMD2(-9,-43),SIMD2(-12,-48)],radius:0.30),0.33,foot)
            plate(roundedContour([SIMD2(-12,43),SIMD2(12,43),SIMD2(12,49),SIMD2(8,55),SIMD2(0,57),SIMD2(-8,55),SIMD2(-12,49)],radius:0.30),0.33,foot)
            plate(roundedContour([SIMD2(22,-10),SIMD2(27,-8),SIMD2(26,29),SIMD2(22,40),SIMD2(19,38),SIMD2(21,20)],radius:0.18),0.31,foot)
            // Map the fourth skate directly onto the thumb-rest underside.
            let wingMap:(SIMD2<Float>,Float)->SIMD3<Float>={p,lift in
                let u=(p.y+39)/102,outer=self.wing(u,1),bottom=self.wingBottom(p.y)
                let inner=self.sideX(bottom,p.y)+1
                return SIMD3(inner+(outer.x-inner)*p.x,bottom-lift,p.y)
            }
            patch(roundedContour([SIMD2(0.64,-5),SIMD2(0.90,-5),SIMD2(0.90,39),SIMD2(0.64,39)],radius:0.18),lift:0.32,material:foot,map:wingMap,outward:down)
            // Power slot, glass sensor and Easy-Switch button with three channels.
            plate(rect(0,-24,4.7,10),0.28,Self.material(0.24,gloss:0.35))
            plate(rect(0,-24,3.7,8.8),0.34,seam)
            plate(rect(0,-26.2,2.6,3.0),0.42,green)
            plate(rect(0,-22.7,3.2,4.7),0.48,Self.material(0.20,gloss:0.32))
            plate(oval(0,-2,5,7.1),0.31,Self.material(0.24,gloss:0.45))
            plate(oval(0,-2,3.8,5.8),0.36,seam)
            plate(rect(0,-2,3.2,6),0.43,lens)
            plate(oval(0,25,4.8,4.8),0.29,seam)
            plate(oval(0,25,3.9,3.9),0.43,Self.material(0.24,gloss:0.32))
            label("MX Master 3S",0,-32,2.0)
            label("1   2   3",0,15,2.3)
            label("Easy-Switch",0,32,1.5)
        }
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
        let noseHeight=section(-63).z
        func warp(_ p:SIMD3<Float>)->SIMD3<Float> {
            let blend=pow(max(0,min(1,(-p.z-40)/23)),3),f=p.x/30
            let planCurve=family == .mxMaster3s ? 3.6*f*f+2.4*f:5.5*f*f
            // The lower nose recedes beneath the click paddles. Keeping every
            // vertex on one vertical plane produced the blunt oval front face.
            let below=max(0,min(1,(noseHeight-p.y-0.6)/max(1,noseHeight-2)))
            let setback=(family == .mxMaster3s ? 4.4:2.0)*below
            let shift=blend*(planCurve+setback)
            let rear=max(0,min(1,(p.z-20)/43)),rearOffset:Float=family == .mxMaster3s ? -5*rear*rear*(3-2*rear):0
            return SIMD3(p.x+rearOffset,p.y,p.z+shift)
        }
        // Shell, patches and seams are baked in mouse space; primitives retain their native normals.
        for node in root.childNodes {
            guard let g=node.geometry else{continue}
            let isConforming=conformingControls.contains(ObjectIdentifier(node))
            if node.simdPosition == .zero || isConforming, !(g is SCNText), let source=g.sources(for:.vertex).first {
                let data=source.data,origin=isConforming ? node.simdPosition:SIMD3<Float>.zero
                var vertices=[SCNVector3](),original=[SIMD3<Float>]()
                data.withUnsafeBytes { bytes in
                    for i in 0..<source.vectorCount {
                        let offset=source.dataOffset+i*source.dataStride
                        let x=bytes.loadUnaligned(fromByteOffset:offset,as:Float.self)
                        let y=bytes.loadUnaligned(fromByteOffset:offset+4,as:Float.self)
                        let z=bytes.loadUnaligned(fromByteOffset:offset+8,as:Float.self)
                        let p=SIMD3(x,y,z)+origin;original.append(p);vertices.append(SCNVector3(warp(p)-warp(origin)))
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
                if isConforming {
                    node.simdPosition=warp(origin)
                }
            } else {node.simdPosition=warp(node.simdPosition)}
        }
    }
}
