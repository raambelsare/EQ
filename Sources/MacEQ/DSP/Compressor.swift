import Foundation
import Accelerate

/// Studio-grade downward compressor with quadratic soft knee and single shared-detector stereo linking.
/// Fully real-time safe: zero allocations, zero locks, zero system calls.
/// Giannoulis et al. soft-knee digital dynamic range compressor formulation.
public struct Compressor {
    // Smoothed audio-thread parameters
    public var thresholdDB: SmoothedParameter
    public var ratio: SmoothedParameter
    public var attackMs: SmoothedParameter
    public var releaseMs: SmoothedParameter
    public var kneeDB: SmoothedParameter
    public var makeupGainDB: SmoothedParameter
    
    public var bypassed: Bool = false
    
    // Internal state
    private var sampleRate: Float
    private var detectorEnvelopeDB: Float = 0.0
    
    // UI Telemetry: current gain reduction in dB (positive or negative convention: reported as attenuation dB <= 0)
    public private(set) var currentGainReductionDB: Float = 0.0
    
    #if DEBUG
    // Debug counter to explicitly prove envelope follower does NOT run when bypassed
    public var debugEnvelopeRunCount: Int = 0
    #endif
    
    public init(sampleRate: Float = 48000.0) {
        self.sampleRate = sampleRate
        
        // Parameter smoothing time ~20ms to prevent zipper noise on live slider dragging
        self.thresholdDB = SmoothedParameter(initialValue: -12.0, smoothingTimeMs: 20.0, sampleRate: sampleRate)
        self.ratio = SmoothedParameter(initialValue: 3.0, smoothingTimeMs: 20.0, sampleRate: sampleRate)
        self.attackMs = SmoothedParameter(initialValue: 10.0, smoothingTimeMs: 20.0, sampleRate: sampleRate)
        self.releaseMs = SmoothedParameter(initialValue: 100.0, smoothingTimeMs: 20.0, sampleRate: sampleRate)
        self.kneeDB = SmoothedParameter(initialValue: 4.0, smoothingTimeMs: 20.0, sampleRate: sampleRate)
        self.makeupGainDB = SmoothedParameter(initialValue: 0.0, smoothingTimeMs: 20.0, sampleRate: sampleRate)
    }
    
    public mutating func setSampleRate(_ rate: Float) {
        self.sampleRate = rate
        thresholdDB.setSampleRate(rate)
        ratio.setSampleRate(rate)
        attackMs.setSampleRate(rate)
        releaseMs.setSampleRate(rate)
        kneeDB.setSampleRate(rate)
        makeupGainDB.setSampleRate(rate)
    }
    
    public mutating func reset() {
        detectorEnvelopeDB = -120.0
        currentGainReductionDB = 0.0
    }
    
    /// Compute Giannoulis et al. quadratic soft-knee gain computer.
    /// Input: xG (signal level in dB)
    /// Output: yG (target compressed level in dB)
    @inline(__always)
    public static func computeSoftKnee(xG: Float, threshold: Float, ratio: Float, knee: Float) -> Float {
        let halfKnee = knee * 0.5
        let invRatio = 1.0 / max(1.0, ratio)
        
        if xG <= (threshold - halfKnee) {
            // Below knee: linear 1:1, no compression
            return xG
        } else if knee > 0.001 && abs(xG - threshold) <= halfKnee {
            // Within knee: quadratic transition
            let delta = xG - threshold + halfKnee
            return xG + ((invRatio - 1.0) * delta * delta) / (2.0 * knee)
        } else {
            // Above knee: full compression ratio
            return threshold + (xG - threshold) * invRatio
        }
    }
    
    /// Real-time sample-by-sample stereo processing.
    /// Stereo linking requirement: Single shared level detector driven by max(|L|, |R|),
    /// producing ONE identical gain reduction factor applied to both left and right channels.
    @inline(__always)
    public mutating func process(sampleL: Float, sampleR: Float) -> (Float, Float) {
        // Parameter smoothing step
        let thresh = thresholdDB.advance()
        let rat = ratio.advance()
        let att = attackMs.advance()
        let rel = releaseMs.advance()
        let kn = kneeDB.advance()
        let makeup = makeupGainDB.advance()
        
        // True Bypass: When bypassed == true, envelope follower MUST NOT RUN at all.
        if bypassed {
            currentGainReductionDB = 0.0
            return (sampleL, sampleR)
        }
        
        #if DEBUG
        debugEnvelopeRunCount += 1
        #endif
        
        // 1. Stereo-linked Level Detection: max(|L|, |R|)
        let absL = abs(sampleL)
        let absR = abs(sampleR)
        let maxAbs = max(absL, absR)
        
        // Convert to dB (log floor at -120 dBFS)
        let xG: Float = maxAbs > 0.000001 ? 20.0 * log10(maxAbs) : -120.0
        
        // 2. Gain Computer (Static characteristic in dB)
        let yG = Compressor.computeSoftKnee(xG: xG, threshold: thresh, ratio: rat, knee: kn)
        
        // Target gain reduction in dB (always <= 0)
        let deltaDB = yG - xG
        
        // 3. Attack/Release Ballistics (One-pole smoothing in dB domain)
        let alphaAttack = exp(-1.0 / max(1.0, (att * 0.001 * sampleRate)))
        let alphaRelease = exp(-1.0 / max(1.0, (rel * 0.001 * sampleRate)))
        
        if deltaDB < detectorEnvelopeDB {
            // Compressing more (Attack phase: deltaDB is dropping)
            detectorEnvelopeDB = (alphaAttack * detectorEnvelopeDB) + ((1.0 - alphaAttack) * deltaDB)
        } else {
            // Recovering (Release phase: deltaDB is returning toward 0)
            detectorEnvelopeDB = (alphaRelease * detectorEnvelopeDB) + ((1.0 - alphaRelease) * deltaDB)
        }
        
        // Bound envelope to prevent subnormal decay
        if detectorEnvelopeDB > -0.0001 {
            detectorEnvelopeDB = 0.0
        }
        
        currentGainReductionDB = detectorEnvelopeDB
        
        // 4. Convert Gain Reduction from dB to Linear Scale + Makeup Gain
        let totalGainDB = detectorEnvelopeDB + makeup
        let linearGain = pow(10.0, totalGainDB / 20.0)
        
        // 5. Apply identical gain reduction to both channels (preserves stereo image)
        return (sampleL * linearGain, sampleR * linearGain)
    }
}
