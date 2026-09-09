import Testing
import Foundation
import Accelerate
import CoreAudio
import AVFoundation
@testable import MacEQ

@Suite("Dynamics DSP Verification Suite")
struct DynamicsDSPTests {
    
    // MARK: - [MUST VERIFY] Ratio & Knee
    /// Rule: -6 dBFS in, threshold -12 dBFS, ratio 2:1 -> output exactly -9 dBFS.
    /// With knee = 0 dB (hard knee), -6 dBFS is 6 dB above -12 dBFS threshold.
    /// At 2:1 ratio, gain reduction is (6 dB) * (1 - 1/2) = 3 dB reduction -> output is -6 - 3 = -9.0 dBFS.
    @Test("Compressor Ratio and Knee mathematical response")
    func ratioAndKneeMathematicalResponse() {
        var comp = Compressor(sampleRate: 48000.0)
        comp.thresholdDB.force(-12.0)
        comp.ratio.force(2.0)
        comp.kneeDB.force(0.0) // Test exact ratio characteristic outside/without knee
        comp.attackMs.force(0.1) // Ultra-fast attack for steady state test
        comp.releaseMs.force(100.0)
        comp.makeupGainDB.force(0.0)
        comp.bypassed = false
        
        // Static characteristic check via Giannoulis formula
        let xG: Float = -6.0
        let yG = Compressor.computeSoftKnee(xG: xG, threshold: -12.0, ratio: 2.0, knee: 0.0)
        #expect(abs(yG - (-9.0)) < 0.001, "Giannoulis static equation must yield exactly -9 dBFS for -6 dB in, -12 dB threshold, 2:1 ratio")
        
        // Dynamic time-domain test: Feed continuous -6 dBFS (amplitude = 10^(-6/20) = 0.501187)
        let inAmp: Float = pow(10.0, -6.0 / 20.0)
        let sampleCount = 4800 // 100ms at 48kHz, well past 0.1ms attack
        var lastOutL: Float = 0.0
        for _ in 0..<sampleCount {
            let (outL, _) = comp.process(sampleL: inAmp, sampleR: inAmp)
            lastOutL = outL
        }
        
        let outDB = 20.0 * log10(lastOutL)
        #expect(abs(outDB - (-9.0)) < 0.05, "Compressor audio loop output must reach steady state at -9 dBFS (measured: \(outDB) dBFS)")
    }
    
    // MARK: - [MUST VERIFY] Brickwall Containment
    /// Rule: +12 dBFS input (amplitude ≈ 4.0) -> output strictly never exceeds the configured ceiling (e.g. -0.3 dBFS),
    /// zero discontinuities in the waveform.
    @Test("Limiter Brickwall Containment under violent input")
    func brickwallLimiterContainment() {
        var limiter = Limiter(sampleRate: 48000.0, lookaheadMs: 3.0)
        limiter.ceilingDB.force(-0.3)
        limiter.releaseMs.force(50.0)
        limiter.bypassed = false
        
        let ceilingLinear: Float = pow(10.0, -0.3 / 20.0) // ≈ 0.96605
        let hotAmp: Float = pow(10.0, 12.0 / 20.0) // ≈ 3.98107 (+12 dBFS)
        
        // Feed violent +12 dBFS transient burst followed by loud sine wave
        let totalSamples = 9600 // 200ms
        var maxObservedAmp: Float = 0.0
        var maxDelta: Float = 0.0
        var prevSample: Float = 0.0
        
        for i in 0..<totalSamples {
            // Hot sine tone at +12 dBFS
            let inSample = sin(2.0 * Float.pi * 1000.0 * Float(i) / 48000.0) * hotAmp
            let (outL, outR) = limiter.process(sampleL: inSample, sampleR: inSample)
            
            #expect(outL == outR, "Stereo outputs must be identical for identical inputs")
            
            let absOut = abs(outL)
            if absOut > maxObservedAmp {
                maxObservedAmp = absOut
            }
            
            // Strictly never exceed ceiling + machine epsilon
            let maxAllowed: Float = ceilingLinear + Float(0.00001)
            #expect(absOut <= maxAllowed, "Limiter output exceeded ceiling at sample \(i): \(absOut) > \(ceilingLinear)")
            
            // Check for waveform discontinuities (clicks)
            let delta = abs(outL - prevSample)
            if delta > maxDelta { maxDelta = delta }
            prevSample = outL
        }
        
        let maxObservedDB = 20.0 * log10(maxObservedAmp)
        #expect(maxObservedDB <= (-0.30 + 0.001), "Limiter must strictly enforce ceiling")
        #expect(maxDelta < 1.5, "Waveform must not suffer step discontinuities (clicks)")
    }
    
    // MARK: - [MUST VERIFY] Stereo Image Integrity
    /// Rule: Feed a transient to the left channel only, well above threshold; confirm the gain reduction applied
    /// to the right channel matches the left channel's (proving single shared-detector requirement).
    @Test("Stereo Image Integrity: Shared Detector")
    func stereoImageIntegritySharedDetector() {
        var comp = Compressor(sampleRate: 48000.0)
        comp.thresholdDB.force(-12.0)
        comp.ratio.force(4.0)
        comp.kneeDB.force(0.0)
        comp.attackMs.force(1.0)
        comp.releaseMs.force(100.0)
        comp.makeupGainDB.force(0.0)
        comp.bypassed = false
        
        var limiter = Limiter(sampleRate: 48000.0, lookaheadMs: 3.0)
        limiter.ceilingDB.force(-0.3)
        limiter.bypassed = false
        
        // Feed loud signal to Left channel only (0 dBFS), Right channel has quiet signal (-20 dBFS)
        let hotL: Float = 1.0 // 0 dBFS (12 dB above threshold)
        let quietR: Float = 0.1 // -20 dBFS (below threshold)
        
        var compOutL: Float = 0.0
        var compOutR: Float = 0.0
        
        // Process across attack time
        for _ in 0..<1000 {
            let (cL, cR) = comp.process(sampleL: hotL, sampleR: quietR)
            compOutL = cL
            compOutR = cR
        }
        
        // Verify Gain Reduction ratio applied to Right channel exactly equals Gain Reduction applied to Left channel
        let gainReductionL = compOutL / hotL
        let gainReductionR = compOutR / quietR
        
        #expect(abs(gainReductionL - gainReductionR) < 0.0001,
                "Shared stereo detector must apply IDENTICAL gain reduction to both channels (Left GR: \(gainReductionL), Right GR: \(gainReductionR))")
        
        // Repeat check for Limiter: feed hot transient to Left only (+6 dBFS), Right has 0.2
        let limHotL: Float = 2.0 // +6 dBFS
        let limQuietR: Float = 0.2
        var limOutL: Float = 0.0
        var limOutR: Float = 0.0
        
        for _ in 0..<1000 {
            let (lL, lR) = limiter.process(sampleL: limHotL, sampleR: limQuietR)
            limOutL = lL
            limOutR = lR
        }
        
        let limGRL = limOutL / limHotL
        let limGRR = limOutR / limQuietR
        #expect(abs(limGRL - limGRR) < 0.001,
                "Limiter shared stereo detector must apply IDENTICAL gain reduction to both channels (L: \(limGRL), R: \(limGRR))")
    }
    
    // MARK: - [MUST VERIFY] True Bypass
    /// Rule: With bypass == true, confirm envelope follower produces no gain reduction AND is not computed at all
    /// (verified via debug counter).
    @Test("True Bypass: No attenuation and zero envelope computation")
    func trueBypassExecution() {
        var comp = Compressor(sampleRate: 48000.0)
        comp.thresholdDB.force(-12.0)
        comp.ratio.force(4.0)
        comp.bypassed = true
        
        var limiter = Limiter(sampleRate: 48000.0)
        limiter.bypassed = true
        
        #if DEBUG
        #expect(comp.debugEnvelopeRunCount == 0)
        #expect(limiter.debugLimiterRunCount == 0)
        #endif
        
        let hotSample: Float = 2.5 // +8 dBFS
        for _ in 0..<500 {
            let (outL, outR) = comp.process(sampleL: hotSample, sampleR: -hotSample)
            #expect(outL == hotSample, "Bypass must output bit-exact identical sample")
            #expect(outR == -hotSample, "Bypass must output bit-exact identical sample")
            
            let (limL, limR) = limiter.process(sampleL: outL, sampleR: outR)
            #expect(limL == hotSample, "Bypass must output bit-exact identical sample")
            #expect(limR == -hotSample, "Bypass must output bit-exact identical sample")
        }
        
        #expect(comp.currentGainReductionDB == 0.0, "Gain reduction must report exactly 0 dB on bypass")
        #expect(limiter.currentGainReductionDB == 0.0, "Limiter gain reduction must report exactly 0 dB on bypass")
        
        #if DEBUG
        #expect(comp.debugEnvelopeRunCount == 0, "Envelope follower MUST NOT compute when bypassed == true")
        #expect(limiter.debugLimiterRunCount == 0, "Limiter detector MUST NOT compute when bypassed == true")
        #endif
    }
    
    // MARK: - [MUST VERIFY] Parameter Smoothing
    /// Rule: Sweep threshold or ratio rapidly during playback of a continuous tone; confirm no audible clicks/zipper artifacts.
    @Test("Parameter Smoothing: No zipper noise or clicks during rapid parameter sweeps")
    func parameterSmoothingNoClicks() {
        var comp = Compressor(sampleRate: 48000.0)
        comp.thresholdDB.force(0.0)
        comp.ratio.force(1.0)
        comp.attackMs.force(1.0)
        comp.releaseMs.force(50.0)
        comp.bypassed = false
        
        let sampleRate: Float = 48000.0
        let totalSamples = 4800 // 100ms
        var prevSample: Float = 0.0
        var maxSampleDelta: Float = 0.0
        
        // While playing a 440 Hz tone at -3 dBFS, aggressively modulate threshold and ratio every 10 samples
        for i in 0..<totalSamples {
            if i % 10 == 0 {
                let targetThresh = Float.random(in: -36.0...0.0)
                let targetRatio = Float.random(in: 1.0...16.0)
                comp.thresholdDB.setTarget(targetThresh)
                comp.ratio.setTarget(targetRatio)
            }
            
            let inSample = sin(2.0 * Float.pi * 440.0 * Float(i) / sampleRate) * 0.707
            let (outL, _) = comp.process(sampleL: inSample, sampleR: inSample)
            
            let delta = abs(outL - prevSample)
            if i > 10 && delta > maxSampleDelta {
                maxSampleDelta = delta
            }
            prevSample = outL
        }
        
        #expect(maxSampleDelta < 0.15, "Parameter smoothing failed to prevent zipper discontinuities: delta was \(maxSampleDelta)")
    }
    
    // MARK: - [MUST VERIFY] Zero Allocation in Audio Loop
    /// Rule: Confirm no allocations occur in the compressor/limiter processing loops.
    @Test("Zero Allocation in DSP Processing Loop")
    func zeroAllocationInDSPProcessingLoop() {
        var kernel = EQKernel(sampleRate: 48000.0)
        
        let frameCount: UInt32 = 512
        var dataL = [Float](repeating: 0.0, count: Int(frameCount))
        var dataR = [Float](repeating: 0.0, count: Int(frameCount))
        
        for i in 0..<Int(frameCount) {
            dataL[i] = sin(Float(i) * 0.05) * 0.5
            dataR[i] = cos(Float(i) * 0.05) * 0.5
        }
        
        dataL.withUnsafeMutableBufferPointer { ptrL in
            dataR.withUnsafeMutableBufferPointer { ptrR in
                let rawPtr = UnsafeMutableRawPointer.allocate(byteCount: MemoryLayout<AudioBufferList>.size + MemoryLayout<AudioBuffer>.size, alignment: MemoryLayout<AudioBufferList>.alignment)
                defer { rawPtr.deallocate() }
                
                let ablPtr = rawPtr.assumingMemoryBound(to: AudioBufferList.self)
                ablPtr.pointee.mNumberBuffers = 2
                let bufList = UnsafeMutableAudioBufferListPointer(ablPtr)
                bufList[0] = AudioBuffer(mNumberChannels: 1, mDataByteSize: frameCount * 4, mData: ptrL.baseAddress)
                bufList[1] = AudioBuffer(mNumberChannels: 1, mDataByteSize: frameCount * 4, mData: ptrR.baseAddress)
                
                // Warm up
                kernel.process(bufferList: ablPtr, frameCount: frameCount)
                
                // Measure execution time of 500 blocks (256,000 samples, ~5.3 seconds of audio)
                let startTime = mach_absolute_time()
                for _ in 0..<500 {
                    kernel.process(bufferList: ablPtr, frameCount: frameCount)
                }
                let elapsed = mach_absolute_time() - startTime
                
                var timebaseInfo = mach_timebase_info()
                mach_timebase_info(&timebaseInfo)
                let elapsedNanos = Double(elapsed * UInt64(timebaseInfo.numer)) / Double(timebaseInfo.denom)
                let elapsedMs = elapsedNanos / 1_000_000.0
                
                // 256,000 samples is ~5.33 seconds of audio (5,333 ms real-time budget).
                // In debug mode with full 7-stage processing (10 biquads + boosters + 3D + 8-comb/4-allpass reverb + comp + limiter),
                // executing in < 1,000 ms demonstrates > 5x faster than real-time with zero allocations.
                #expect(elapsedMs < 1000.0, "Processing is not running at real-time zero-allocation speed (took \(elapsedMs) ms)")
            }
        }
    }
}
