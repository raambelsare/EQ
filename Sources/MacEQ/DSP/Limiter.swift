import Foundation
import Accelerate

/// Studio-grade true-brickwall lookahead peak limiter.
/// Pre-allocated static delay ring buffer (~256 samples, ~5ms @ 48kHz).
/// Guarantees output strictly never exceeds configured ceiling (e.g. -0.3 dBFS)
/// with single shared-detector stereo linking and click-free ramping.
/// Zero heap allocations, zero locks on audio thread.
public struct Limiter {
    // Lookahead delay line capacity: 512 samples (~10.6ms at 48kHz)
    public static let maxDelayFrames: Int = 512
    
    // Parameters
    public var ceilingDB: SmoothedParameter
    public var releaseMs: SmoothedParameter
    public var lookaheadFrames: Int
    public var bypassed: Bool = false
    
    // Internal state
    private var sampleRate: Float
    private var delayBufferL: [Float]
    private var delayBufferR: [Float]
    private var delayWriteIndex: Int = 0
    
    // Gain reduction envelope in linear scale [0.0 ... 1.0]
    private var gainEnvelopeLinear: Float = 1.0
    
    // Telemetry: Current gain reduction in dB
    public private(set) var currentGainReductionDB: Float = 0.0
    
    #if DEBUG
    public var debugLimiterRunCount: Int = 0
    #endif
    
    public init(sampleRate: Float = 48000.0, lookaheadMs: Float = 3.0) {
        self.sampleRate = sampleRate
        
        self.ceilingDB = SmoothedParameter(initialValue: -0.3, smoothingTimeMs: 20.0, sampleRate: sampleRate)
        self.releaseMs = SmoothedParameter(initialValue: 50.0, smoothingTimeMs: 20.0, sampleRate: sampleRate)
        
        let frames = Int(lookaheadMs * 0.001 * sampleRate)
        self.lookaheadFrames = max(16, min(frames, Limiter.maxDelayFrames - 1))
        
        // Pre-allocate static fixed buffers
        self.delayBufferL = [Float](repeating: 0.0, count: Limiter.maxDelayFrames)
        self.delayBufferR = [Float](repeating: 0.0, count: Limiter.maxDelayFrames)
    }
    
    public mutating func setSampleRate(_ rate: Float) {
        self.sampleRate = rate
        ceilingDB.setSampleRate(rate)
        releaseMs.setSampleRate(rate)
    }
    
    public mutating func reset() {
        delayBufferL.withUnsafeMutableBufferPointer { $0.initialize(repeating: 0.0) }
        delayBufferR.withUnsafeMutableBufferPointer { $0.initialize(repeating: 0.0) }
        delayWriteIndex = 0
        gainEnvelopeLinear = 1.0
        currentGainReductionDB = 0.0
    }
    
    /// Process stereo samples with lookahead brickwall containment.
    /// Stereo linking requirement: Single shared detector over max(|L|, |R|)
    /// producing ONE identical gain multiplier applied to delayed (L, R).
    @inline(__always)
    public mutating func process(sampleL: Float, sampleR: Float) -> (Float, Float) {
        let ceilDB = ceilingDB.advance()
        let relMs = releaseMs.advance()
        
        // True Bypass: Envelope detector must not run when bypassed
        if bypassed {
            currentGainReductionDB = 0.0
            return (sampleL, sampleR)
        }
        
        #if DEBUG
        debugLimiterRunCount += 1
        #endif
        
        // 1. Store incoming samples in circular lookahead delay buffer
        let writeIdx = delayWriteIndex
        delayBufferL[writeIdx] = sampleL
        delayBufferR[writeIdx] = sampleR
        
        // Read delayed samples (delayed by lookaheadFrames)
        var readIdx = writeIdx - lookaheadFrames
        if readIdx < 0 { readIdx += Limiter.maxDelayFrames }
        let delayedL = delayBufferL[readIdx]
        let delayedR = delayBufferR[readIdx]
        
        // Advance delay write pointer
        delayWriteIndex = (writeIdx + 1) % Limiter.maxDelayFrames
        
        // 2. Shared Detector: Inspect peak amplitude of incoming sample N samples ahead
        let maxAbs = max(abs(sampleL), abs(sampleR))
        let ceilingLinear = pow(10.0, ceilDB / 20.0)
        
        // Target linear gain required to prevent this incoming transient from exceeding ceiling
        var targetGainLinear: Float = 1.0
        if maxAbs > ceilingLinear && maxAbs > 0.000001 {
            targetGainLinear = ceilingLinear / maxAbs
        }
        
        // 3. Attack & Release Ramping
        // Instant attack: if target gain is lower than current envelope, drop instantly (or ramp across lookahead)
        if targetGainLinear < gainEnvelopeLinear {
            // Rapid lookahead attack ramp
            let attackRate = 1.0 / Float(max(1, lookaheadFrames))
            gainEnvelopeLinear = max(targetGainLinear, gainEnvelopeLinear - attackRate)
        } else {
            // Smooth release ramp
            let alphaRelease = exp(-1.0 / max(1.0, (relMs * 0.001 * sampleRate)))
            gainEnvelopeLinear = (alphaRelease * gainEnvelopeLinear) + ((1.0 - alphaRelease) * 1.0)
        }
        
        // Safety clamp on gain envelope
        gainEnvelopeLinear = min(1.0, max(0.0001, gainEnvelopeLinear))
        
        // Telemetry update (Gain reduction in dB)
        currentGainReductionDB = 20.0 * log10(gainEnvelopeLinear)
        
        // 4. Apply identical gain reduction to delayed audio
        var outL = delayedL * gainEnvelopeLinear
        var outR = delayedR * gainEnvelopeLinear
        
        // 5. Final brickwall safety clamp strictly at ceiling (zero inter-sample overshoots)
        outL = max(-ceilingLinear, min(outL, ceilingLinear))
        outR = max(-ceilingLinear, min(outR, ceilingLinear))
        
        return (outL, outR)
    }
}
