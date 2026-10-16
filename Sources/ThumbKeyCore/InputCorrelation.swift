import Foundation

/// Transient, one-use hardware evidence. Never infer the mouse from a key code alone.
public struct InputCorrelation {
    public enum Match: Equatable { case naga(UInt32), otherKeyboard, ambiguous, missing }
    public struct Transition {
        public let usage:UInt32, down:Bool, timestamp:UInt64, naga:Bool
        public let device:UInt64
        public init(usage:UInt32,down:Bool,timestamp:UInt64,naga:Bool,device:UInt64){self.usage=usage;self.down=down;self.timestamp=timestamp;self.naga=naga;self.device=device}
    }
    private var pending:[Transition]=[]
    private var states:[UInt64:Set<UInt32>]=[:]
    private var nagaDevices=Set<UInt64>()
    public var tolerance:UInt64=2_000_000 // Hardware timestamps, not callback arrival times.
    public init(){}
    public mutating func record(_ t:Transition){
        guard t.timestamp>0,KeyboardMap.usageToKey[t.usage] != nil else{return}
        if t.naga {nagaDevices.insert(t.device)}
        if t.down {states[t.device,default:[]].insert(t.usage)} else {states[t.device]?.remove(t.usage)}
        pending.append(t)
        if pending.count>256 {pending.removeFirst(pending.count-256)}
        pending.removeAll { $0.timestamp<t.timestamp && t.timestamp-$0.timestamp>150_000_000 }
    }
    private func distance(_ a:UInt64,_ b:UInt64)->UInt64 {a>b ? a-b:b-a}
    private func matchingIndices(keyCode:UInt16,down:Bool,timestamp:UInt64)->[Int]{
        guard timestamp>0 else{return []}
        return pending.indices.filter{let t=pending[$0];return t.down==down && KeyboardMap.usageToKey[t.usage]==keyCode && distance(t.timestamp,timestamp)<=tolerance}
    }
    public func peek(keyCode:UInt16,down:Bool,timestamp:UInt64)->Match {
        let matches=matchingIndices(keyCode:keyCode,down:down,timestamp:timestamp)
        guard !matches.isEmpty else{return .missing}
        let candidates=matches.map{pending[$0]}
        let hasNaga=candidates.contains{$0.naga},hasOther=candidates.contains{!$0.naga}
        let nagaUsages=Set(candidates.filter{$0.naga}.map(\.usage))
        if hasNaga && hasOther || nagaUsages.count>1{return .ambiguous}
        if let usage=nagaUsages.first{return .naga(usage)}
        return .otherKeyboard
    }
    public mutating func consume(keyCode:UInt16,down:Bool,timestamp:UInt64)->Match {
        let result=peek(keyCode:keyCode,down:down,timestamp:timestamp)
        let consumed=Set(matchingIndices(keyCode:keyCode,down:down,timestamp:timestamp))
        pending=pending.enumerated().filter{!consumed.contains($0.offset)}.map(\.element)
        return result
    }
    public func nagaHeld(keyCode:UInt16)->Bool{states.contains{nagaDevices.contains($0.key) && $0.value.contains{KeyboardMap.usageToKey[$0]==keyCode}}}
    public func otherHeld(keyCode:UInt16)->Bool{states.contains{!nagaDevices.contains($0.key) && $0.value.contains{KeyboardMap.usageToKey[$0]==keyCode}}}
    public mutating func reset(){pending=[];states=[:];nagaDevices=[]}
}
