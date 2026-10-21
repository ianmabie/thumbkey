import Foundation
import IOKit.hid
import ThumbKeyCore

/// Temporary driver reporting, restricted to the V3 Pro USB control endpoint.
/// The previous mode is restored on pause/quit. This never writes onboard bindings.
final class NagaDriverMode {
    private var device:IOHIDDevice?
    private var previous:UInt8?
    private var transaction:UInt8=0x1f
    var active:Bool {device != nil}
    func activate() throws {
        if active{return}
        let manager=IOHIDManagerCreate(kCFAllocatorDefault,IOHIDManagerOptions.independentDevices.rawValue)
        IOHIDManagerSetDeviceMatching(manager,[kIOHIDVendorIDKey:0x1532] as CFDictionary);IOHIDManagerOpen(manager,0)
        defer{IOHIDManagerClose(manager,0)}
        let devices=(IOHIDManagerCopyDevices(manager) as? Set<IOHIDDevice> ?? []).filter {
            let id=HIDCapture.number($0,kIOHIDProductIDKey)
            return (id==0x00e7 || id==0x00e8) && HIDCapture.number($0,kIOHIDPrimaryUsagePageKey)==1 && HIDCapture.number($0,kIOHIDPrimaryUsageKey)==3 && HIDCapture.text($0,kIOHIDTransportKey)=="USB"
        }
        guard devices.count==1,let source=devices.first,let fresh=IOHIDDeviceCreate(kCFAllocatorDefault,IOHIDDeviceGetService(source)) else {
            throw ModeError.message("Extra-button mode needs one Naga V3 Pro connected by USB cable or its USB receiver. Bluetooth control is not supported yet.")
        }
        guard IOHIDDeviceOpen(fresh,0)==kIOReturnSuccess else{throw ModeError.message("Could not open the Naga control interface. Check Input Monitoring and reconnect the mouse.")}
        device=fresh
        do {
            // Negotiate with read-only queries before any mode write. Keep the
            // accepted transaction for activation, idle recovery and restoration.
            var failure:Error?
            for candidate in NagaProtocol.modeTransactions {
                transaction=candidate
                do{previous=try exchange();break}catch{failure=error}
            }
            guard previous != nil else{throw failure ?? ModeError.message("The Naga did not answer its reporting-mode query.")}

            if previous != 3 {_ = try exchange(set:3)}
            guard try exchange()==3 else{throw ModeError.message("The mouse did not enter extra-button mode.")}
        } catch {
            _ = try? restore();throw error
        }
    }
    /// Returns true if the mouse had dropped back to normal reporting after idle.
    func ensure() throws -> Bool {
        guard active else{return false}
        guard try exchange() != 3 else{return false}
        _ = try exchange(set:3)
        guard try exchange()==3 else{throw ModeError.message("Extra-button mode was lost. Pause and enable mappings to reconnect.")}
        return true
    }
    func restore() throws {
        guard let current=device else{return}
        defer{IOHIDDeviceClose(current,0);device=nil;previous=nil}
        if let previous { _ = try exchange(set:previous);guard try exchange()==previous else{throw ModeError.message("Could not verify restoration of the mouse's original mode. Reconnect the mouse.")} }
    }
    private func exchange(set mode:UInt8?=nil) throws -> UInt8 {
        guard let device else{throw ModeError.message("Mouse control interface is disconnected.")}
        let request=NagaProtocol.modeRequest(set:mode,transaction:transaction)
        let sent=IOHIDDeviceSetReport(device,kIOHIDReportTypeFeature,0,request,request.count)
        guard sent==kIOReturnSuccess else{throw ModeError.message("Mouse control request failed (\(String(format:"0x%08x",UInt32(bitPattern:sent)))).")}
        Thread.sleep(forTimeInterval:0.1)
        var response=[UInt8](repeating:0,count:90),length=90
        let status=IOHIDDeviceGetReport(device,kIOHIDReportTypeFeature,0,&response,&length)
        guard status==kIOReturnSuccess,length==90,let result=NagaProtocol.modeResponse(response,command:mode == nil ? 0x84:0x04,transaction:transaction) else {
            throw ModeError.message("The mouse did not acknowledge its reporting mode. No onboard profile was changed.")
        }
        return result
    }
    deinit{try? restore()}
}
private enum ModeError:LocalizedError {case message(String);var errorDescription:String?{if case .message(let text)=self{return text};return nil}}
