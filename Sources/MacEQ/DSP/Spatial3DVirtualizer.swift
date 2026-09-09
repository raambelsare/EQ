import Foundation

/// 3D Spatial Virtualizer with Mid-Side Stereo Expansion & Headphone Cross-feed
/// Increases soundstage width and depth with zero mono phase cancellation.
public struct Spatial3DVirtualizer {
    // Width: 0.0 (mono) to 1.0 (normal) to 2.0 (super-wide 3D)
    public var width: SmoothedParameter
    public var crossfeedAmount: SmoothedParameter
    public var bypassed: Bool = false
    
    // Headphone crossfeed delay buffer (~0.3ms inter-aural time difference delay)
    private static let crossfeedDelayFrames = 16
    private var delayBufferL = [Float](repeating: 0.0, count: crossfeedDelayFrames)
    private var delayBufferR = [Float](repeating: 0.0, count: crossfeedDelayFrames)
    private var delayIndex: Int = 0
    private var sampleRate: Float
    
    // Crossfeed lowpass filter state (cross-ear head shadow acoustic damping)
    private var crossfeedLpL: Float = 0.0
    private var crossfeedLpR: Float = 0.0
    
    public init(sampleRate: Float = 48000.0) {
        self.sampleRate = sampleRate
        self.width = SmoothedParameter(initialValue: 1.0, smoothingTimeMs: 20.0, sampleRate: sampleRate)
        self.crossfeedAmount = SmoothedParameter(initialValue: 0.0, smoothingTimeMs: 20.0, sampleRate: sampleRate)
    }
    
    public mutating func setSampleRate(_ rate: Float) {
        self.sampleRate = rate
        width.setSampleRate(rate)
        crossfeedAmount.setSampleRate(rate)
    }
    
    @inline(__always)
    public mutating func process(sampleL: Float, sampleR: Float) -> (Float, Float) {
        if bypassed { return (sampleL, sampleR) }
        
        let w = width.advance()
        let xfeed = crossfeedAmount.advance()
        
        // 1. Mid-Side decomposition
        // Mid (center channel: vocals, bass, snare)
        // Side (stereo difference: ambient cues, wide synths, cymbals)
        let mid = (sampleL + sampleR) * 0.5
        let side = (sampleL - sampleR) * 0.5
        
        // Scale side component by spatial width multiplier
        let scaledSide = side * w
        
        // Reconstruct stereo channels from Mid & Scaled Side
        var outL = mid + scaledSide
        var outR = mid - scaledSide
        
        // 2. Headphone Cross-feed (Natural acoustic ear cross-talk)
        if xfeed > 0.01 {
            let writeIdx = delayIndex
            delayBufferL[writeIdx] = outL
            delayBufferR[writeIdx] = outR
            
            let readIdx = (writeIdx + 1) % Spatial3DVirtualizer.crossfeedDelayFrames
            delayIndex = readIdx
            
            // 1-pole lowpass at ~2 kHz for head shadow acoustic simulation
            let alpha: Float = 0.25
            crossfeedLpL = (alpha * delayBufferL[readIdx]) + ((1.0 - alpha) * crossfeedLpL)
            crossfeedLpR = (alpha * delayBufferR[readIdx]) + ((1.0 - alpha) * crossfeedLpR)
            
            outL = outL + (crossfeedLpR * xfeed * 0.3)
            outR = outR + (crossfeedLpL * xfeed * 0.3)
        }
        
        return (outL, outR)
    }
}
