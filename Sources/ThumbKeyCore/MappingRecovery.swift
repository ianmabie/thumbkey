import Foundation

/// User intent survives temporary capture loss; manual pause always cancels recovery.
public struct MappingRecovery {
    public private(set) var requested: Bool
    public private(set) var sleeping = false
    public private(set) var secureInputBlocked = false
    private var attempts = 0
    public init(requested: Bool = false) { self.requested = requested }
    public mutating func enable() { requested = true; attempts = 0 }
    public mutating func pause() { requested = false; attempts = 0 }
    public mutating func sleep() { sleeping = true; attempts = 0 }
    public mutating func wake() { sleeping = false; attempts = 0 }
    public mutating func resetAttempts() { attempts = 0 }
    public mutating func setSecureInput(_ blocked:Bool) {
        if secureInputBlocked != blocked { secureInputBlocked=blocked;attempts=0 }
    }
    public mutating func nextDelay() -> Double? {
        guard requested, !sleeping, !secureInputBlocked, attempts < 3 else { return nil }
        let delay = [0.5, 1.0, 2.0][attempts]; attempts += 1; return delay
    }
}
