import Foundation

/// Stale background work must never reconnect a mouse after a newer selection or pause.
public final class RequestGeneration: @unchecked Sendable {
    private let lock=NSLock()
    private var value=UUID()
    public init(){}
    @discardableResult public func next()->UUID {lock.lock();defer{lock.unlock()};value=UUID();return value}
    public func current()->UUID {lock.lock();defer{lock.unlock()};return value}
    public func matches(_ request:UUID)->Bool {lock.lock();defer{lock.unlock()};return value==request}
}
