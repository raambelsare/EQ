import Foundation

/// Tone Booster Module: Bass Boost, Mids Clarity, and Treble Presence
/// Features clean soft saturation on the sub-bass channel for rich low-end punch without digital clipping.
public struct ToneBooster {
    // Independent smoothed gain parameters (0 dB to +12 dB)
    public var bassGainDB: SmoothedParameter
    public var midsGainDB: SmoothedParameter
    public var trebleGainDB: SmoothedParameter
    
    public var bypassed: Bool = false
    
    // Internal biquad filter bands
    private var bassFilter: EQBand
    private var midsFilter: EQBand
    private var trebleFilter: EQBand
    private var sampleRate: Float
    
    public init(sampleRate: Float = 48000.0) {
        self.sampleRate = sampleRate
        
        self.bassGainDB = SmoothedParameter(initialValue: 0.0, smoothingTimeMs: 20.0, sampleRate: sampleRate)
        self.midsGainDB = SmoothedParameter(initialValue: 0.0, smoothingTimeMs: 20.0, sampleRate: sampleRate)
        self.trebleGainDB = SmoothedParameter(initialValue: 0.0, smoothingTimeMs: 20.0, sampleRate: sampleRate)
        
        // Bass: Low shelf at 80 Hz with gentle Q
        var bBand = EQBand(type: .lowShelf, sampleRate: sampleRate)
        bBand.freq.force(80.0)
        bBand.q.force(0.707)
        bBand.gain.force(0.0)
        bBand.recalculate(sampleRate: sampleRate)
        self.bassFilter = bBand
        
        // Mids: Peaking bell at 1200 Hz with Q=1.2 for vocal presence
        var mBand = EQBand(type: .bell, sampleRate: sampleRate)
        mBand.freq.force(1200.0)
        mBand.q.force(1.2)
        mBand.gain.force(0.0)
        mBand.recalculate(sampleRate: sampleRate)
        self.midsFilter = mBand
        
        // Treble: High shelf at 10 kHz with Q=0.707 for air and sheen
        var tBand = EQBand(type: .highShelf, sampleRate: sampleRate)
        tBand.freq.force(10000.0)
        tBand.q.force(0.707)
        tBand.gain.force(0.0)
        tBand.recalculate(sampleRate: sampleRate)
        self.trebleFilter = tBand
    }
    
    public mutating func setSampleRate(_ rate: Float) {
        self.sampleRate = rate
        bassGainDB.setSampleRate(rate)
        midsGainDB.setSampleRate(rate)
        trebleGainDB.setSampleRate(rate)
        
        bassFilter.recalculate(sampleRate: rate)
        midsFilter.recalculate(sampleRate: rate)
        trebleFilter.recalculate(sampleRate: rate)
    }
    
    @inline(__always)
    public mutating func process(sampleL: Float, sampleR: Float) -> (Float, Float) {
        if bypassed { return (sampleL, sampleR) }
        
        let bGain = bassGainDB.advance()
        let mGain = midsGainDB.advance()
        let tGain = trebleGainDB.advance()
        
        // Update filter targets
        bassFilter.gain.setTarget(bGain)
        midsFilter.gain.setTarget(mGain)
        trebleFilter.gain.setTarget(tGain)
        
        bassFilter.update(sampleRate: sampleRate)
        midsFilter.update(sampleRate: sampleRate)
        trebleFilter.update(sampleRate: sampleRate)
        
        // 1. Process through Bass Filter
        var (bL, bR) = bassFilter.process(sampleL: sampleL, sampleR: sampleR)
        
        // If bass is heavily boosted (> 3 dB), apply soft hyperbolic-tangent harmonic saturation
        if bGain > 3.0 {
            let drive: Float = 1.0 + (bGain - 3.0) * 0.05
            bL = tanh(bL * drive) / drive
            bR = tanh(bR * drive) / drive
        }
        
        // 2. Process through Mids Filter
        let (mL, mR) = midsFilter.process(sampleL: bL, sampleR: bR)
        
        // 3. Process through Treble Filter
        let (tL, tR) = trebleFilter.process(sampleL: mL, sampleR: mR)
        
        return (tL, tR)
    }
}
