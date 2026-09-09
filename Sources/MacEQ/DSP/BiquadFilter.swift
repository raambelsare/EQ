import Foundation

public enum FilterType: Int {
    case bell = 0, lowShelf, highShelf, lowPass, highPass, notch
}

public struct BiquadCoefficients {
    var b0: Float = 1.0
    var b1: Float = 0.0
    var b2: Float = 0.0
    var a1: Float = 0.0
    var a2: Float = 0.0
    
    public init() {}
    
    /// Calculate RBJ Audio EQ Cookbook coefficients.
    public mutating func calculate(type: FilterType, sampleRate: Float, frequency: Float, q: Float, gainDB: Float) {
        // Clamping to prevent NaNs/Infs and hardware damage
        let clampedFreq = max(20.0, min(frequency, sampleRate * 0.45))
        let clampedQ = max(0.1, min(q, 100.0))
        let clampedGain = max(-24.0, min(gainDB, 24.0))
        
        let A = pow(10.0, clampedGain / 40.0)
        let w0 = 2.0 * Float.pi * clampedFreq / sampleRate
        let cos_w0 = cos(w0)
        let sin_w0 = sin(w0)
        let alpha = sin_w0 / (2.0 * clampedQ)
        
        let a0: Float
        let b0Temp: Float, b1Temp: Float, b2Temp: Float, a1Temp: Float, a2Temp: Float
        
        switch type {
        case .bell:
            b0Temp = 1.0 + alpha * A
            b1Temp = -2.0 * cos_w0
            b2Temp = 1.0 - alpha * A
            a0 = 1.0 + alpha / A
            a1Temp = -2.0 * cos_w0
            a2Temp = 1.0 - alpha / A
        case .lowShelf:
            let sqA = sqrt(A)
            b0Temp = A * ((A + 1.0) - (A - 1.0) * cos_w0 + 2.0 * sqA * alpha)
            b1Temp = 2.0 * A * ((A - 1.0) - (A + 1.0) * cos_w0)
            b2Temp = A * ((A + 1.0) - (A - 1.0) * cos_w0 - 2.0 * sqA * alpha)
            a0 = (A + 1.0) + (A - 1.0) * cos_w0 + 2.0 * sqA * alpha
            a1Temp = -2.0 * ((A - 1.0) + (A + 1.0) * cos_w0)
            a2Temp = (A + 1.0) + (A - 1.0) * cos_w0 - 2.0 * sqA * alpha
        case .highShelf:
            let sqA = sqrt(A)
            b0Temp = A * ((A + 1.0) + (A - 1.0) * cos_w0 + 2.0 * sqA * alpha)
            b1Temp = -2.0 * A * ((A - 1.0) + (A + 1.0) * cos_w0)
            b2Temp = A * ((A + 1.0) + (A - 1.0) * cos_w0 - 2.0 * sqA * alpha)
            a0 = (A + 1.0) - (A - 1.0) * cos_w0 + 2.0 * sqA * alpha
            a1Temp = 2.0 * ((A - 1.0) - (A + 1.0) * cos_w0)
            a2Temp = (A + 1.0) - (A - 1.0) * cos_w0 - 2.0 * sqA * alpha
        case .lowPass:
            b0Temp = (1.0 - cos_w0) / 2.0
            b1Temp = 1.0 - cos_w0
            b2Temp = (1.0 - cos_w0) / 2.0
            a0 = 1.0 + alpha
            a1Temp = -2.0 * cos_w0
            a2Temp = 1.0 - alpha
        case .highPass:
            b0Temp = (1.0 + cos_w0) / 2.0
            b1Temp = -(1.0 + cos_w0)
            b2Temp = (1.0 + cos_w0) / 2.0
            a0 = 1.0 + alpha
            a1Temp = -2.0 * cos_w0
            a2Temp = 1.0 - alpha
        case .notch:
            b0Temp = 1.0
            b1Temp = -2.0 * cos_w0
            b2Temp = 1.0
            a0 = 1.0 + alpha
            a1Temp = -2.0 * cos_w0
            a2Temp = 1.0 - alpha
        }
        
        // Normalize by a0
        let invA0 = 1.0 / a0
        self.b0 = b0Temp * invA0
        self.b1 = b1Temp * invA0
        self.b2 = b2Temp * invA0
        self.a1 = a1Temp * invA0
        self.a2 = a2Temp * invA0
    }
}

public struct BiquadState {
    var z1: Float = 0.0
    var z2: Float = 0.0
    
    public init() {}
    
    public mutating func clear() {
        z1 = 0.0
        z2 = 0.0
    }
    
    @inline(__always)
    public mutating func process(_ input: Float, coeffs: BiquadCoefficients) -> Float {
        // Direct Form II Transposed
        let out = (coeffs.b0 * input) + z1
        z1 = (coeffs.b1 * input) - (coeffs.a1 * out) + z2
        z2 = (coeffs.b2 * input) - (coeffs.a2 * out)
        
        // Defend against denormals/NaNs entering state
        if !z1.isFinite { z1 = 0 }
        if !z2.isFinite { z2 = 0 }
        return out
    }
}

public struct SmoothedParameter {
    public var current: Float
    public var target: Float
    private var smoothingCoefficient: Float
    
    public init(initialValue: Float, smoothingTimeMs: Float, sampleRate: Float) {
        self.current = initialValue
        self.target = initialValue
        
        let samples = smoothingTimeMs * 0.001 * sampleRate
        self.smoothingCoefficient = exp(-1.0 / max(1.0, samples))
    }
    
    public mutating func setTarget(_ value: Float) {
        target = value
    }
    
    public mutating func force(_ value: Float) {
        target = value
        current = value
    }
    
    public mutating func setSampleRate(_ sampleRate: Float, smoothingTimeMs: Float = 20.0) {
        let samples = smoothingTimeMs * 0.001 * sampleRate
        self.smoothingCoefficient = exp(-1.0 / max(1.0, samples))
    }
    
    @inline(__always)
    public mutating func advance() -> Float {
        current = (current * smoothingCoefficient) + (target * (1.0 - smoothingCoefficient))
        if abs(current - target) < 1e-6 {
            current = target
        }
        return current
    }
}

public struct EQBand {
    public var type: FilterType
    public var freq: SmoothedParameter
    public var gain: SmoothedParameter
    public var q: SmoothedParameter
    public var bypassed: Bool
    
    public var coeffs = BiquadCoefficients()
    public var stateL = BiquadState()
    public var stateR = BiquadState()
    
    public init(type: FilterType, sampleRate: Float) {
        self.type = type
        self.freq = SmoothedParameter(initialValue: 1000.0, smoothingTimeMs: 20.0, sampleRate: sampleRate)
        self.gain = SmoothedParameter(initialValue: 0.0, smoothingTimeMs: 20.0, sampleRate: sampleRate)
        self.q = SmoothedParameter(initialValue: 0.707, smoothingTimeMs: 20.0, sampleRate: sampleRate)
        self.bypassed = false
        recalculate(sampleRate: sampleRate)
    }
    
    public mutating func setType(_ newType: FilterType, sampleRate: Float) {
        if self.type != newType {
            self.type = newType
            // Hard switch - clear state to prevent artifacts
            stateL.clear()
            stateR.clear()
            recalculate(sampleRate: sampleRate)
        }
    }
    
    @inline(__always)
    public mutating func update(sampleRate: Float) {
        if bypassed { return }
        
        let targetF = freq.target
        let targetG = gain.target
        let targetQ = q.target
        
        let fChanging = freq.current != targetF
        let gChanging = gain.current != targetG
        let qChanging = q.current != targetQ
        
        let f = freq.advance()
        let g = gain.advance()
        let _q = q.advance()
        
        // Only recompute trigonometric RBJ coefficients if parameters are actively moving
        if fChanging || gChanging || qChanging {
            coeffs.calculate(type: type, sampleRate: sampleRate, frequency: f, q: _q, gainDB: g)
        }
    }
    
    public mutating func recalculate(sampleRate: Float) {
        coeffs.calculate(type: type, sampleRate: sampleRate, frequency: freq.current, q: q.current, gainDB: gain.current)
    }
    
    @inline(__always)
    public mutating func process(sampleL: Float, sampleR: Float) -> (Float, Float) {
        if bypassed {
            return (sampleL, sampleR)
        }
        let outL = stateL.process(sampleL, coeffs: coeffs)
        let outR = stateR.process(sampleR, coeffs: coeffs)
        return (outL, outR)
    }
}
