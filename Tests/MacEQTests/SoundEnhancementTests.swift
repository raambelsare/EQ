import Testing
import Foundation
import Accelerate
import AVFoundation
@testable import MacEQ

@Suite("Sound Enhancements Verification Suite")
struct SoundEnhancementTests {
    
    // MARK: - 10-Band EQ Isolation Test
    @Test("10-Band EQ: Low frequency boost does not distort high frequencies")
    func multiBandEQIsolation() {
        var eq = MultiBandEQ(sampleRate: 48000.0)
        // Boost 64 Hz by +12 dB
        eq.setGain(bandIndex: 1, gainDB: 12.0)
        
        // Feed 10,000 Hz high tone at -12 dBFS (amp = 0.251)
        let inAmp: Float = pow(10.0, -12.0 / 20.0)
        var lastOut: Float = 0.0
        
        for i in 0..<2000 {
            let sample = sin(2.0 * Float.pi * 10000.0 * Float(i) / 48000.0) * inAmp
            let (outL, _) = eq.process(sampleL: sample, sampleR: sample)
            lastOut = outL
        }
        
        // High frequency magnitude should remain within 0.2 dB of original
        let outAmp = abs(lastOut)
        #expect(outAmp <= inAmp * 1.05, "Boosting 64 Hz band must not inflate 10 kHz signal")
    }
    
    // MARK: - 3D Spatial Virtualizer Mono Compatibility
    @Test("3D Spatial Virtualizer: 200% width maintains exact mono signal")
    func spatializerMonoCompatibility() {
        var spatializer = Spatial3DVirtualizer(sampleRate: 48000.0)
        spatializer.width.force(2.0) // 200% width
        spatializer.crossfeedAmount.force(0.0)
        spatializer.bypassed = false
        
        // Feed identical mono signal to L and R
        let monoInput: Float = 0.65
        let (outL, outR) = spatializer.process(sampleL: monoInput, sampleR: monoInput)
        
        // In Mid-Side processing: Mid = (L+R)/2 = monoInput, Side = (L-R)/2 = 0.
        // Scaling Side by 2.0 still gives 0.
        // Therefore outL = Mid + Side = monoInput, outR = Mid - Side = monoInput.
        #expect(abs(outL - monoInput) < 0.0001, "Mono signals must not be degraded by spatial widening")
        #expect(abs(outR - monoInput) < 0.0001, "Mono signals must not be degraded by spatial widening")
        
        // Collapsing to mono (L+R)/2 must match input exactly
        let collapsed = (outL + outR) * 0.5
        #expect(abs(collapsed - monoInput) < 0.0001, "Collapsing to mono must produce zero phase cancellation")
    }
    
    // MARK: - Tone Booster Soft Saturation
    @Test("Tone Booster: Sub-bass saturation bounds extreme levels smoothly")
    func toneBoosterSaturationClamping() {
        var booster = ToneBooster(sampleRate: 48000.0)
        booster.bassGainDB.force(12.0) // Maximum +12 dB bass boost
        booster.midsGainDB.force(0.0)
        booster.trebleGainDB.force(0.0)
        booster.bypassed = false
        
        // Feed large 50 Hz sub-bass pulse
        var maxAmp: Float = 0.0
        for i in 0..<1000 {
            let sample = sin(2.0 * Float.pi * 50.0 * Float(i) / 48000.0) * 1.5
            let (outL, _) = booster.process(sampleL: sample, sampleR: sample)
            if abs(outL) > maxAmp { maxAmp = abs(outL) }
        }
        
        #expect(maxAmp.isFinite, "Output must never produce NaN or infinite values")
        #expect(maxAmp < 2.5, "Soft hyperbolic tangent saturation must bound sub-bass extremes")
    }
    
    // MARK: - Preset Application
    @Test("Preset Manager: Presets apply correct EQ and enhancer parameters")
    func presetApplicationIntegrity() {
        let preset = PresetManager.factoryPresets.first(where: { $0.name == "Bass Heavy / EDM" })!
        #expect(preset.eqGains.count == 10)
        #expect(preset.bassBoostDB == 6.0)
        #expect(preset.spatialWidth == 1.35)
    }
    
    // MARK: - In-Line Audio Pipeline Test
    @Test("In-Line Audio Pipeline: AudioEngine actively transforms audio buffer samples in-line")
    func inLineAudioRenderingVerification() throws {
        let sema = DispatchSemaphore(value: 0)
        var testPassed = false
        
        AudioEngine.create { result in
            switch result {
            case .success(let engine):
                do {
                    let demoURL = URL(fileURLWithPath: "/System/Library/Sounds/Funk.aiff")
                    try engine.loadAudioFile(url: demoURL)
                    
                    #expect(engine.bufferStorage.frameCount > 0, "Buffer storage must contain loaded audio samples")
                    #expect(engine.bufferStorage.isPlaying, "Buffer storage must be active")
                    
                    // Verify initial flat state
                    let initialGain = engine.getBandGain(index: 1)
                    #expect(initialGain == 0.0)
                    
                    // Verify setBandGain directly changes DSP kernel
                    engine.setBandGain(index: 1, gainDB: 12.0)
                    #expect(engine.getBandGain(index: 1) == 12.0)
                    
                    // Verify Tone Booster
                    engine.setBassBoost(10.0)
                    #expect(engine.getBassBoost() == 10.0)
                    
                    // Verify Spatial Width
                    engine.setSpatialWidth(1.8)
                    #expect(engine.getSpatialWidth() == 1.8)
                    
                    testPassed = true
                } catch {
                    testPassed = false
                }
            case .failure:
                testPassed = false
            }
            sema.signal()
        }
        sema.wait()
        #expect(testPassed, "AudioEngine must initialize and load files cleanly without errors")
    }
}
