import Foundation

/// 10-Band ISO Standard Parametric & Graphic Equalizer
/// Frequencies: 32Hz, 64Hz, 125Hz, 250Hz, 500Hz, 1kHz, 2kHz, 4kHz, 8kHz, 16kHz
/// Strictly real-time safe: Zero heap allocation, zero locks, smoothed parameters.
public struct MultiBandEQ {
    public static let standardFrequencies: [Float] = [
        32.0, 64.0, 125.0, 250.0, 500.0, 1000.0, 2000.0, 4000.0, 8000.0, 16000.0
    ]
    public static let bandCount = 10
    
    public var bands: [EQBand]
    public var bypassed: Bool = false
    private var sampleRate: Float
    
    public init(sampleRate: Float = 48000.0) {
        self.sampleRate = sampleRate
        var list: [EQBand] = []
        list.reserveCapacity(MultiBandEQ.bandCount)
        
        for i in 0..<MultiBandEQ.bandCount {
            let freq = MultiBandEQ.standardFrequencies[i]
            let type: FilterType
            if i == 0 {
                type = .lowShelf
            } else if i == MultiBandEQ.bandCount - 1 {
                type = .highShelf
            } else {
                type = .bell
            }
            
            var band = EQBand(type: type, sampleRate: sampleRate)
            band.freq.force(freq)
            band.gain.force(0.0)
            band.q.force(1.0)
            band.recalculate(sampleRate: sampleRate)
            list.append(band)
        }
        self.bands = list
    }
    
    public mutating func setSampleRate(_ rate: Float) {
        self.sampleRate = rate
        for i in 0..<bands.count {
            bands[i].freq.setSampleRate(rate)
            bands[i].gain.setSampleRate(rate)
            bands[i].q.setSampleRate(rate)
            bands[i].recalculate(sampleRate: rate)
        }
    }
    
    public mutating func setGain(bandIndex: Int, gainDB: Float) {
        guard bandIndex >= 0 && bandIndex < bands.count else { return }
        bands[bandIndex].gain.setTarget(max(-24.0, min(gainDB, 24.0)))
    }
    
    public func getGain(bandIndex: Int) -> Float {
        guard bandIndex >= 0 && bandIndex < bands.count else { return 0.0 }
        return bands[bandIndex].gain.target
    }
    
    public mutating func resetGains() {
        for i in 0..<bands.count {
            bands[i].gain.setTarget(0.0)
        }
    }
    
    @inline(__always)
    public mutating func process(sampleL: Float, sampleR: Float) -> (Float, Float) {
        if bypassed { return (sampleL, sampleR) }
        
        var curL = sampleL
        var curR = sampleR
        
        for i in 0..<bands.count {
            bands[i].update(sampleRate: sampleRate)
            let (outL, outR) = bands[i].process(sampleL: curL, sampleR: curR)
            curL = outL
            curR = outR
        }
        
        return (curL, curR)
    }
}
