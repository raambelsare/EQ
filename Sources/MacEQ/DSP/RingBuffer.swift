import Foundation
import os.lock

/// High-performance Single-Producer Single-Consumer (SPSC) lock-free circular buffer
/// using Darwin's `OSAtomic` / `os_unfair_lock` or atomic memory primitives.
/// Safe for reading on a UI/worker thread while being written directly from the real-time audio thread.
/// Zero heap allocations and deterministic execution.
public final class RingBuffer {
    private let capacity: Int
    private let mask: Int
    private let buffer: UnsafeMutablePointer<Float>
    
    // 64-bit atomic indices using UnsafeMutablePointer<Int64> with OSAtomic / atomic operations
    private let writeHeadPtr: UnsafeMutablePointer<Int64>
    private let readHeadPtr: UnsafeMutablePointer<Int64>
    
    public init(capacity: Int = 16384) {
        var cap = 1
        while cap < capacity {
            cap <<= 1
        }
        self.capacity = cap
        self.mask = cap - 1
        
        self.buffer = UnsafeMutablePointer<Float>.allocate(capacity: cap)
        self.buffer.initialize(repeating: 0.0, count: cap)
        
        self.writeHeadPtr = UnsafeMutablePointer<Int64>.allocate(capacity: 1)
        self.writeHeadPtr.initialize(to: 0)
        
        self.readHeadPtr = UnsafeMutablePointer<Int64>.allocate(capacity: 1)
        self.readHeadPtr.initialize(to: 0)
    }
    
    deinit {
        buffer.deinitialize(count: capacity)
        buffer.deallocate()
        
        writeHeadPtr.deinitialize(count: 1)
        writeHeadPtr.deallocate()
        
        readHeadPtr.deinitialize(count: 1)
        readHeadPtr.deallocate()
    }
    
    /// Real-time audio thread write method.
    /// Non-blocking, zero locks, zero dynamic allocations.
    @discardableResult
    public func write(from source: UnsafePointer<Float>, count: Int) -> Int {
        guard count > 0 else { return 0 }
        
        let currentWrite = OSAtomicAdd64(0, writeHeadPtr)
        let currentRead = OSAtomicAdd64(0, readHeadPtr)
        
        let available = capacity - Int(currentWrite - currentRead)
        if count > available {
            // Drop oldest unread frames on overflow to maintain fresh real-time stream
            let overflow = Int64(count - available)
            OSAtomicAdd64(overflow, readHeadPtr)
        }
        
        let writeOffset = Int(currentWrite) & mask
        let firstChunk = min(count, capacity - writeOffset)
        
        buffer.advanced(by: writeOffset).initialize(from: source, count: firstChunk)
        
        let secondChunk = count - firstChunk
        if secondChunk > 0 {
            buffer.initialize(from: source.advanced(by: firstChunk), count: secondChunk)
        }
        
        OSAtomicAdd64(Int64(count), writeHeadPtr)
        return count
    }
    
    /// Consumer UI / worker thread read method.
    public func read(into destination: UnsafeMutablePointer<Float>, count: Int) -> Int {
        guard count > 0 else { return 0 }
        
        let currentRead = OSAtomicAdd64(0, readHeadPtr)
        let currentWrite = OSAtomicAdd64(0, writeHeadPtr)
        
        let available = Int(currentWrite - currentRead)
        guard available > 0 else { return 0 }
        
        let toRead = min(count, available)
        let readOffset = Int(currentRead) & mask
        let firstChunk = min(toRead, capacity - readOffset)
        
        destination.initialize(from: buffer.advanced(by: readOffset), count: firstChunk)
        
        let secondChunk = toRead - firstChunk
        if secondChunk > 0 {
            destination.advanced(by: firstChunk).initialize(from: buffer, count: secondChunk)
        }
        
        OSAtomicAdd64(Int64(toRead), readHeadPtr)
        return toRead
    }
    
    /// Number of samples currently available to read
    public var availableRead: Int {
        let currentWrite = OSAtomicAdd64(0, writeHeadPtr)
        let currentRead = OSAtomicAdd64(0, readHeadPtr)
        return max(0, Int(currentWrite - currentRead))
    }
}
