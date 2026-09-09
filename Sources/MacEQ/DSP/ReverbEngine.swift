import Foundation

/// Low-Pass Feedback Comb Filter (LBCF) component for algorithmic reverb
private struct CombFilter {
    private var buffer: [Float]
    private var bufferSize: Int
    private var bufferIndex: Int = 0
    private var filterStore: Float = 0.0
    
    public init(size: Int) {
        self.bufferSize = max(1, size)
        self.buffer = [Float](repeating: 0.0, count: self.bufferSize)
    }
    
    @inline(__always)
    public mutating func process(_ input: Float, feedback: Float, damp: Float) -> Float {
        let output = buffer[bufferIndex]
        filterStore = (output * (1.0 - damp)) + (filterStore * damp)
        buffer[bufferIndex] = input + (filterStore * feedback)
        
        bufferIndex += 1
        if bufferIndex >= bufferSize { bufferIndex = 0 }
        return output
    }
}

/// All-Pass Filter (APF) diffuser component for algorithmic reverb
private struct AllPassFilter {
    private var buffer: [Float]
    private var bufferSize: Int
    private var bufferIndex: Int = 0
    private let feedback: Float = 0.5
    
    public init(size: Int) {
        self.bufferSize = max(1, size)
        self.buffer = [Float](repeating: 0.0, count: self.bufferSize)
    }
    
    @inline(__always)
    public mutating func process(_ input: Float) -> Float {
        let bufOut = buffer[bufferIndex]
        let output = -input + bufOut
        buffer[bufferIndex] = input + (bufOut * feedback)
        
        bufferIndex += 1
        if bufferIndex >= bufferSize { bufferIndex = 0 }
        return output
    }
}

/// Studio-grade algorithmic reverberator (Schroeder / Freeverb architecture)
/// Fully pre-allocated static buffers, zero dynamic heap allocations on audio thread.
public struct ReverbEngine {
    // Tuning parameters
    public var roomSize: SmoothedParameter   // 0.0 to 1.0 (reverberation decay time)
    public var damping: SmoothedParameter    // 0.0 to 1.0 (high frequency absorption)
    public var wetLevel: SmoothedParameter   // 0.0 to 1.0 (reverb volume)
    public var dryLevel: SmoothedParameter   // 0.0 to 1.0 (direct signal volume)
    public var bypassed: Bool = true
    
    // Comb filter bank (8 parallel comb filters per channel with prime delay lengths)
    private var combL: [CombFilter]
    private var combR: [CombFilter]
    
    // All-pass filter diffuser bank (4 series all-pass filters per channel)
    private var allPassL: [AllPassFilter]
    private var allPassR: [AllPassFilter]
    
    private var sampleRate: Float
    
    public init(sampleRate: Float = 48000.0) {
        self.sampleRate = sampleRate
        
        self.roomSize = SmoothedParameter(initialValue: 0.5, smoothingTimeMs: 20.0, sampleRate: sampleRate)
        self.damping = SmoothedParameter(initialValue: 0.2, smoothingTimeMs: 20.0, sampleRate: sampleRate)
        self.wetLevel = SmoothedParameter(initialValue: 0.25, smoothingTimeMs: 20.0, sampleRate: sampleRate)
        self.dryLevel = SmoothedParameter(initialValue: 1.0, smoothingTimeMs: 20.0, sampleRate: sampleRate)
        
        // Tuned prime delay lengths at 44.1kHz / 48kHz
        let scale: Float = sampleRate / 44100.0
        let baseComb: [Int] = [1116, 1188, 1277, 1356, 1422, 1491, 1557, 1617]
        let baseAllPass: [Int] = [556, 441, 341, 225]
        
        let combDelaysL: [Int] = baseComb.map { Int(Float($0) * scale) }
        let combDelaysR: [Int] = baseComb.map { Int(Float($0 + 23) * scale) }
        
        let allPassDelaysL: [Int] = baseAllPass.map { Int(Float($0) * scale) }
        let allPassDelaysR: [Int] = baseAllPass.map { Int(Float($0 + 23) * scale) }
        
        self.combL = combDelaysL.map { CombFilter(size: $0) }
        self.combR = combDelaysR.map { CombFilter(size: $0) }
        self.allPassL = allPassDelaysL.map { AllPassFilter(size: $0) }
        self.allPassR = allPassDelaysR.map { AllPassFilter(size: $0) }
    }
    
    public mutating func setSampleRate(_ rate: Float) {
        self.sampleRate = rate
        roomSize.setSampleRate(rate)
        damping.setSampleRate(rate)
        wetLevel.setSampleRate(rate)
        dryLevel.setSampleRate(rate)
    }
    
    @inline(__always)
    public mutating func process(sampleL: Float, sampleR: Float) -> (Float, Float) {
        if bypassed { return (sampleL, sampleR) }
        
        let rSize = roomSize.advance()
        let damp = damping.advance()
        let wet = wetLevel.advance()
        let dry = dryLevel.advance()
        
        let feedback = 0.7 + (rSize * 0.28) // Stable feedback range [0.70 ... 0.98]
        let inputMix = (sampleL + sampleR) * 0.015 // Attenuate input to prevent comb clipping
        
        var outL: Float = 0.0
        var outR: Float = 0.0
        
        // Parallel Comb filters
        for i in 0..<combL.count {
            outL += combL[i].process(inputMix, feedback: feedback, damp: damp)
            outR += combR[i].process(inputMix, feedback: feedback, damp: damp)
        }
        
        // Series All-Pass diffusion
        for i in 0..<allPassL.count {
            outL = allPassL[i].process(outL)
            outR = allPassR[i].process(outR)
        }
        
        // Final Dry / Wet blending
        let finalL = (sampleL * dry) + (outL * wet)
        let finalR = (sampleR * dry) + (outR * wet)
        return (finalL, finalR)
    }
}
