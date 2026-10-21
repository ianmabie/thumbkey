import Foundation
import ThumbKeyCore

/// All blocking feature-report traffic stays on this serial queue, including restoration.
/// Serializing telemetry and mapping requests also prevents their replies from colliding.
final class MouseHardware {
    private let queue=DispatchQueue(label:"personal.thumbkey.hardware",qos:.userInitiated)
    private let session=RequestGeneration(),statusRequest=RequestGeneration()
    private let logitech=LogitechController(),naga=NagaDriverMode()
    private var restorationFailure:String?
    var onInput:((UInt32,Bool,ButtonBinding?,Bool)->Void)? {
        didSet{logitech.onInput=onInput}
    }
    func prepare(family:MouseFamily,extraButtons:Bool,buttons:[ButtonBinding],completion:@escaping(Result<(Bool,String?),Error>)->Void){
        let request=session.next()
        queue.async{[self] in
            guard session.matches(request) else{return}
            let result:Result<(Bool,String?),Error>
            do{
                if let restorationFailure{throw HardwareError(restorationFailure)}
                if family == .mxMaster3s {
                    try logitech.connect();try logitech.configure(buttons,learning:false)
                    result = .success((false,nil))
                }else if extraButtons {
                    do{try naga.activate();result = .success((true,nil))}
                    catch{result = .success((false,"Side-panel mappings are on. Extra buttons are unavailable: \(error.localizedDescription)"))}
                }else{result = .success((false,nil))}
            }catch{result = .failure(error)}
            DispatchQueue.main.async{[self] in guard session.matches(request) else{return};completion(result)}
        }
    }
    func stop(completion:@escaping(String?)->Void){
        let request=session.next()
        queue.async{[self] in
            let failure=restore()
            DispatchQueue.main.async{[self] in guard session.matches(request) else{return};completion(failure)}
        }
    }
    private func restore()->String? {
        var failures=[String]()
        do{try naga.restore()}catch{failures.append(error.localizedDescription)}
        do{try logitech.stop()}catch{failures.append(error.localizedDescription)}
        restorationFailure=failures.isEmpty ? nil:failures.joined(separator:" ")
        return restorationFailure
    }
    func finishStopping(){queue.sync{}}
    func configure(_ buttons:[ButtonBinding],learning:Bool,onError:@escaping(String)->Void){
        let request=session.current()
        queue.async{[self] in
            guard session.matches(request),logitech.isConnected else{return}
            do{try logitech.configure(buttons,learning:learning)}catch{
                let message=error.localizedDescription
                DispatchQueue.main.async{[self] in guard session.matches(request) else{return};onError(message)}
            }
        }
    }
    func checkExtraButtons(completion:@escaping(Result<Bool,Error>)->Void){
        let request=session.current()
        queue.async{[self] in
            guard session.matches(request) else{return}
            let result:Result<Bool,Error>
            do{
                if naga.active{result = .success(try naga.ensure())}
                else{try naga.activate();result = .success(true)}
            }catch{try? naga.restore();result = .failure(error)}
            DispatchQueue.main.async{[self] in guard session.matches(request) else{return};completion(result)}
        }
    }
    func refreshStatus(_ connections:[MouseFamily:MouseConnection],completion:@escaping([MouseFamily:MouseStatus])->Void){
        let request=statusRequest.next()
        queue.async{[self] in
            guard statusRequest.matches(request) else{return}
            var statuses=[MouseFamily:MouseStatus]()
            for family in MouseFamily.allCases {
                guard let connection=connections[family] else{statuses[family]=MouseStatus();continue}
                var status=MouseStatus(presence:connection == .wireless ? .receiver:.connected,connection:connection)
                if family == .naga {
                    // Receiver battery reports are not reliable on this hardware. Do not
                    // block selection trying them or present an invented battery value.
                    if connection == .wired{status.power=MouseTelemetry.nagaPower()}
                }else {
                    let temporary = !logitech.isConnected
                    do{
                        try logitech.connect();status.connection=logitech.connection
                        status.power=logitech.power()
                        if status.power.percent != nil{status.presence = .connected}
                    }catch{}
                    if temporary{try? logitech.stop()}
                }
                statuses[family]=status
            }
            DispatchQueue.main.async{[self] in guard statusRequest.matches(request) else{return};completion(statuses)}
        }
    }
}
private struct HardwareError:LocalizedError {
    let message:String
    init(_ message:String){self.message=message}
    var errorDescription:String?{message}
}
