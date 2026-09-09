import Foundation
import Accelerate

/// Thread-safe stereo audio meter tracking true peak, RMS, and clip flags.
/// Calculation happens lock-free on the audio thread; decay and reading happen on the UI/display thread.
public final class AudioMeter {
    public struct MeterValues {
        public let peakLeft: Float      // dBFS (-60 to 0+)
        public let peakRight: Float     // dBFS (-60 to 0+)
        public let rmsLeft: Float       // dBFS (-60 to 0+)
        public let rmsRight: Float      // dBFS (-60 to 0+)
        public let peakHoldLeft: Float  // dBFS
        public let peakHoldRight: Float // dBFS
        public let isClippingLeft: Bool
        public let isClippingRight: Bool
    }
    
    // Audio thread atomic/direct registers
    private var rawPeakLeft: Float = 0.0
    private var rawPeakRight: Float = 0.0
    private var rawRMSLeft: Float = 0.0
    private var rawRMSRight: Float = 0.0
    private var rawClipLeft: Bool = false
    private var rawClipRight: Bool = false
    
    // UI thread smoothed & ballistic states
    private var smoothPeakLeft: Float = 0.0
    private var smoothPeakRight: Float = 0.0
    private var smoothRMSLeft: Float = 0.0
    private var smoothRMSRight: Float = 0.0
    
    private var holdPeakLeft: Float = 0.0
    private var holdPeakRight: Float = 0.0
    private var holdTimerLeft: TimeInterval = 0.0
    private var holdTimerRight: TimeInterval = 0.0
    
    private var clipStickyLeft: Bool = false
    private var clipStickyRight: Bool = false
    private var clipHoldTimerLeft: TimeInterval = 0.0
    private var clipHoldTimerRight: TimeInterval = 0.0
    
    private let peakDecayPerSec: Float = 20.0  // dB per second release
    private let rmsDecayPerSec: Float = 14.0   // dB per second release
    private let peakHoldDuration: TimeInterval = 1.5 // seconds
    private let clipHoldDuration: TimeInterval = 2.0 // seconds
    
    private let lock = NSLock()
    
    public init() {}
    
    /// Audio thread call: Non-allocating peak & RMS calculation via Accelerate vDSP
    public func process(left: UnsafePointer<Float>, right: UnsafePointer<Float>, count: Int) {
        guard count > 0 else { return }
        
        var maxL: Float = 0.0
        var maxR: Float = 0.0
        var rmsL: Float = 0.0
        var rmsR: Float = 0.0
        
        // Fast SIMD vector max absolute value
        vDSP_maxmgv(left, 1, &maxL, vDSP_Length(count))
        vDSP_maxmgv(right, 1, &maxR, vDSP_Length(count))
        
        // Fast SIMD root-mean-square
        vDSP_rmsqv(left, 1, &rmsL, vDSP_Length(count))
        vDSP_rmsqv(right, 1, &rmsR, vDSP_Length(count))
        
        // Interim safety threshold detection (or digital ceiling 1.0)
        let clipL = maxL >= 0.707
        let clipR = maxR >= 0.707
        
        // Try-lock or lightweight mutex lock to transfer to UI sampler without blocking audio
        if lock.try() {
            self.rawPeakLeft = max(self.rawPeakLeft, maxL)
            self.rawPeakRight = max(self.rawPeakRight, maxR)
            self.rawRMSLeft = max(self.rawRMSLeft, rmsL)
            self.rawRMSRight = max(self.rawRMSRight, rmsR)
            if clipL { self.rawClipLeft = true }
            if clipR { self.rawClipRight = true }
            lock.unlock()
        }
    }
    
    /// UI thread call: Applies ballistics, smooth decay, and returns current meter state in dBFS
    public func update(deltaTime: TimeInterval) -> MeterValues {
        var pL: Float = 0.0
        var pR: Float = 0.0
        var rL: Float = 0.0
        var rR: Float = 0.0
        var cL: Bool = false
        var cR: Bool = false
        
        lock.lock()
        pL = self.rawPeakLeft
        pR = self.rawPeakRight
        rL = self.rawRMSLeft
        rR = self.rawRMSRight
        cL = self.rawClipLeft
        cR = self.rawClipRight
        
        // Reset raw peak accumulators for next interval
        self.rawPeakLeft = 0.0
        self.rawPeakRight = 0.0
        self.rawRMSLeft = 0.0
        self.rawRMSRight = 0.0
        self.rawClipLeft = false
        self.rawClipRight = false
        lock.unlock()
        
        let dt = Float(deltaTime)
        
        // Convert to dBFS (-60 to 0+)
        let dbPL = amplitudeToDB(pL)
        let dbPR = amplitudeToDB(pR)
        let dbRL = amplitudeToDB(rL)
        let dbRR = amplitudeToDB(rR)
        
        // Instant attack, smooth exponential decay for Peak
        if dbPL > smoothPeakLeft {
            smoothPeakLeft = dbPL
        } else {
            smoothPeakLeft = max(-60.0, smoothPeakLeft - peakDecayPerSec * dt)
        }
        
        if dbPR > smoothPeakRight {
            smoothPeakRight = dbPR
        } else {
            smoothPeakRight = max(-60.0, smoothPeakRight - peakDecayPerSec * dt)
        }
        
        // RMS ballistics (slightly slower release)
        if dbRL > smoothRMSLeft {
            smoothRMSLeft = dbRL
        } else {
            smoothRMSLeft = max(-60.0, smoothRMSLeft - rmsDecayPerSec * dt)
        }
        
        if dbRR > smoothRMSRight {
            smoothRMSRight = dbRR
        } else {
            smoothRMSRight = max(-60.0, smoothRMSRight - rmsDecayPerSec * dt)
        }
        
        // Peak Hold logic Left
        if smoothPeakLeft >= holdPeakLeft {
            holdPeakLeft = smoothPeakLeft
            holdTimerLeft = peakHoldDuration
        } else {
            holdTimerLeft -= deltaTime
            if holdTimerLeft <= 0 {
                holdPeakLeft = max(-60.0, holdPeakLeft - (peakDecayPerSec * 2.0) * dt)
            }
        }
        
        // Peak Hold logic Right
        if smoothPeakRight >= holdPeakRight {
            holdPeakRight = smoothPeakRight
            holdTimerRight = peakHoldDuration
        } else {
            holdTimerRight -= deltaTime
            if holdTimerRight <= 0 {
                holdPeakRight = max(-60.0, holdPeakRight - (peakDecayPerSec * 2.0) * dt)
            }
        }
        
        // Sticky Clip logic
        if cL {
            clipStickyLeft = true
            clipHoldTimerLeft = clipHoldDuration
        } else if clipStickyLeft {
            clipHoldTimerLeft -= deltaTime
            if clipHoldTimerLeft <= 0 { clipStickyLeft = false }
        }
        
        if cR {
            clipStickyRight = true
            clipHoldTimerRight = clipHoldDuration
        } else if clipStickyRight {
            clipHoldTimerRight -= deltaTime
            if clipHoldTimerRight <= 0 { clipStickyRight = false }
        }
        
        return MeterValues(
            peakLeft: smoothPeakLeft,
            peakRight: smoothPeakRight,
            rmsLeft: smoothRMSLeft,
            rmsRight: smoothRMSRight,
            peakHoldLeft: holdPeakLeft,
            peakHoldRight: holdPeakRight,
            isClippingLeft: clipStickyLeft,
            isClippingRight: clipStickyRight
        )
    }
    
    public func resetClip() {
        clipStickyLeft = false
        clipStickyRight = false
        clipHoldTimerLeft = 0
        clipHoldTimerRight = 0
    }
    
    @inline(__always)
    private func amplitudeToDB(_ amp: Float) -> Float {
        if amp <= 0.000001 { return -60.0 }
        return max(-60.0, 20.0 * log10(amp))
    }
}
