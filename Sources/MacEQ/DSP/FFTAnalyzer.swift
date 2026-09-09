import Foundation
import Accelerate

/// High-performance Accelerate/vDSP based Real-Time FFT Spectrum Analyzer.
/// Processes time-domain samples from a ring buffer into calibrated log-frequency magnitude bins (20 Hz - 20 kHz).
public final class FFTAnalyzer {
    public let fftSize: Int
    private let log2n: vDSP_Length
    private let halfSize: Int
    private let sampleRate: Float
    
    // vDSP setup
    private let fftSetup: FFTSetup
    private var window: [Float]
    private var inputBuffer: [Float]
    private var realParts: [Float]
    private var imagParts: [Float]
    private var magnitudes: [Float]
    
    // Output smoothed frequency response bins (e.g. 128 log-spaced bins for rendering)
    public let binCount: Int
    public private(set) var smoothedSpectrum: [Float]
    private var binFrequencies: [Float]
    private var binFFTIndices: [Float]
    
    public init(fftSize: Int = 2048, binCount: Int = 128, sampleRate: Float = 48000.0) {
        self.fftSize = fftSize
        self.log2n = vDSP_Length(log2(Double(fftSize)))
        self.halfSize = fftSize / 2
        self.binCount = binCount
        self.sampleRate = sampleRate
        
        guard let setup = vDSP_create_fftsetup(self.log2n, FFTRadix(kFFTRadix2)) else {
            fatalError("Failed to create Accelerate FFT setup")
        }
        self.fftSetup = setup
        
        // Hann window to prevent spectral leakage
        self.window = [Float](repeating: 0, count: fftSize)
        vDSP_hann_window(&window, vDSP_Length(fftSize), Int32(vDSP_HANN_NORM))
        
        self.inputBuffer = [Float](repeating: 0, count: fftSize)
        self.realParts = [Float](repeating: 0, count: halfSize)
        self.imagParts = [Float](repeating: 0, count: halfSize)
        self.magnitudes = [Float](repeating: 0, count: halfSize)
        self.smoothedSpectrum = [Float](repeating: -80.0, count: binCount)
        
        // Precalculate logarithmic frequency scale mapping from 20 Hz to 20,000 Hz
        self.binFrequencies = [Float](repeating: 0, count: binCount)
        self.binFFTIndices = [Float](repeating: 0, count: binCount)
        
        let minFreq: Float = 20.0
        let maxFreq: Float = min(20000.0, sampleRate / 2.0)
        let logMin = log10(minFreq)
        let logMax = log10(maxFreq)
        
        for i in 0..<binCount {
            let t = Float(i) / Float(binCount - 1)
            let freq = pow(10.0, logMin + t * (logMax - logMin))
            binFrequencies[i] = freq
            
            // Map freq to linear FFT bin index
            let binIdx = (freq / (sampleRate / 2.0)) * Float(halfSize)
            binFFTIndices[i] = min(Float(halfSize - 1), max(0.0, binIdx))
        }
    }
    
    deinit {
        vDSP_destroy_fftsetup(fftSetup)
    }
    
    /// Pulls latest samples from ring buffer and executes FFT
    public func process(ringBuffer: RingBuffer, smoothingFactor: Float = 0.75) {
        // Read up to fftSize samples
        let available = ringBuffer.availableRead
        guard available >= fftSize / 2 else { return }
        
        let readCount = min(available, fftSize)
        // Temporary scratch read
        var temp = [Float](repeating: 0, count: readCount)
        _ = ringBuffer.read(into: &temp, count: readCount)
        
        // Shift inputBuffer and append new samples
        let shift = readCount
        if shift < fftSize {
            let keep = fftSize - shift
            for i in 0..<keep {
                inputBuffer[i] = inputBuffer[i + shift]
            }
            for i in 0..<shift {
                inputBuffer[keep + i] = temp[i]
            }
        } else {
            for i in 0..<fftSize {
                inputBuffer[i] = temp[readCount - fftSize + i]
            }
        }
        
        // 1. Apply Hann Window
        var windowed = [Float](repeating: 0, count: fftSize)
        vDSP_vmul(inputBuffer, 1, window, 1, &windowed, 1, vDSP_Length(fftSize))
        
        // 2. Pack into split complex format
        windowed.withUnsafeBufferPointer { winPtr in
            winPtr.baseAddress!.withMemoryRebound(to: DSPComplex.self, capacity: halfSize) { complexPtr in
                realParts.withUnsafeMutableBufferPointer { rPtr in
                    imagParts.withUnsafeMutableBufferPointer { iPtr in
                        var splitComplex = DSPSplitComplex(
                            realp: rPtr.baseAddress!,
                            imagp: iPtr.baseAddress!
                        )
                        vDSP_ctoz(complexPtr, 2, &splitComplex, 1, vDSP_Length(halfSize))
                        
                        // 3. In-place forward FFT
                        vDSP_fft_zrip(fftSetup, &splitComplex, 1, log2n, FFTDirection(FFT_FORWARD))
                        
                        // 4. Calculate magnitudes: sqrt(real^2 + imag^2)
                        magnitudes.withUnsafeMutableBufferPointer { magPtr in
                            vDSP_zvabs(&splitComplex, 1, magPtr.baseAddress!, 1, vDSP_Length(halfSize))
                        }
                    }
                }
            }
        }
        
        // 5. Normalization scale factor for FFT and Hann window
        var scale = 2.0 / Float(fftSize)
        vDSP_vsmul(magnitudes, 1, &scale, &magnitudes, 1, vDSP_Length(halfSize))
        
        // 6. Interpolate into log bins and smooth over time
        for i in 0..<binCount {
            let targetIdx = binFFTIndices[i]
            let low = Int(floor(targetIdx))
            let high = min(halfSize - 1, low + 1)
            let frac = targetIdx - Float(low)
            
            let amp = magnitudes[low] * (1.0 - frac) + magnitudes[high] * frac
            let db: Float
            if amp > 0.000001 {
                db = max(-90.0, min(12.0, 20.0 * log10(amp)))
            } else {
                db = -90.0
            }
            
            // Temporal smoothing (attack fast, release smooth)
            if db > smoothedSpectrum[i] {
                smoothedSpectrum[i] = db * 0.7 + smoothedSpectrum[i] * 0.3
            } else {
                smoothedSpectrum[i] = db * (1.0 - smoothingFactor) + smoothedSpectrum[i] * smoothingFactor
            }
        }
    }
}
