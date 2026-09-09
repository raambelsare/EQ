import Foundation
import AVFoundation

// Audio DSP Kernel executing the complete real-time chain:
// Input -> 10-Band MultiBandEQ -> ToneBooster -> Spatial 3D Virtualizer -> Reverb -> Compressor -> Limiter -> Safety Ceiling (-0.1 dBFS) -> Output
public struct EQKernel {
    public var multiBandEQ: MultiBandEQ
    public var toneBooster: ToneBooster
    public var spatializer: Spatial3DVirtualizer
    public var reverb: ReverbEngine
    public var compressor: Compressor
    public var limiter: Limiter
    public var sampleRate: Float = 44100.0
    
    // Safety ceiling: -0.1 dBFS (10^(-0.1/20) = 0.98855)
    public static let safetyCeilingLinear: Float = 0.988553
    
    public init(sampleRate: Float) {
        self.sampleRate = sampleRate
        self.multiBandEQ = MultiBandEQ(sampleRate: sampleRate)
        self.toneBooster = ToneBooster(sampleRate: sampleRate)
        self.spatializer = Spatial3DVirtualizer(sampleRate: sampleRate)
        self.reverb = ReverbEngine(sampleRate: sampleRate)
        self.compressor = Compressor(sampleRate: sampleRate)
        self.limiter = Limiter(sampleRate: sampleRate)
    }
    
    public mutating func setSampleRate(_ rate: Float) {
        self.sampleRate = rate
        multiBandEQ.setSampleRate(rate)
        toneBooster.setSampleRate(rate)
        spatializer.setSampleRate(rate)
        reverb.setSampleRate(rate)
        compressor.setSampleRate(rate)
        limiter.setSampleRate(rate)
    }
    
    public mutating func setParameter(address: AUParameterAddress, value: AUValue) {
        // Multi-Band EQ Gains: 100...109
        if address >= 100 && address < 110 {
            multiBandEQ.setGain(bandIndex: Int(address - 100), gainDB: value)
            return
        }
        
        switch address {
        // Tone Booster: 30...33
        case 30: toneBooster.bassGainDB.setTarget(value)
        case 31: toneBooster.midsGainDB.setTarget(value)
        case 32: toneBooster.trebleGainDB.setTarget(value)
        case 33: toneBooster.bypassed = (value > 0.5)
            
        // 3D Spatial Virtualizer: 40...42
        case 40: spatializer.width.setTarget(value)
        case 41: spatializer.crossfeedAmount.setTarget(value)
        case 42: spatializer.bypassed = (value > 0.5)
            
        // Reverb Engine: 50...54
        case 50: reverb.roomSize.setTarget(value)
        case 51: reverb.damping.setTarget(value)
        case 52: reverb.wetLevel.setTarget(value)
        case 53: reverb.dryLevel.setTarget(value)
        case 54: reverb.bypassed = (value > 0.5)
            
        // Compressor: 10...16
        case 10: compressor.thresholdDB.setTarget(value)
        case 11: compressor.ratio.setTarget(value)
        case 12: compressor.attackMs.setTarget(value)
        case 13: compressor.releaseMs.setTarget(value)
        case 14: compressor.kneeDB.setTarget(value)
        case 15: compressor.makeupGainDB.setTarget(value)
        case 16: compressor.bypassed = (value > 0.5)
            
        // Limiter: 20...22
        case 20: limiter.ceilingDB.setTarget(value)
        case 21: limiter.releaseMs.setTarget(value)
        case 22: limiter.bypassed = (value > 0.5)
        default: break
        }
    }
    
    public func getParameter(address: AUParameterAddress) -> AUValue {
        if address >= 100 && address < 110 {
            return multiBandEQ.getGain(bandIndex: Int(address - 100))
        }
        
        switch address {
        case 30: return toneBooster.bassGainDB.target
        case 31: return toneBooster.midsGainDB.target
        case 32: return toneBooster.trebleGainDB.target
        case 33: return toneBooster.bypassed ? 1.0 : 0.0
            
        case 40: return spatializer.width.target
        case 41: return spatializer.crossfeedAmount.target
        case 42: return spatializer.bypassed ? 1.0 : 0.0
            
        case 50: return reverb.roomSize.target
        case 51: return reverb.damping.target
        case 52: return reverb.wetLevel.target
        case 53: return reverb.dryLevel.target
        case 54: return reverb.bypassed ? 1.0 : 0.0
            
        case 10: return compressor.thresholdDB.target
        case 11: return compressor.ratio.target
        case 12: return compressor.attackMs.target
        case 13: return compressor.releaseMs.target
        case 14: return compressor.kneeDB.target
        case 15: return compressor.makeupGainDB.target
        case 16: return compressor.bypassed ? 1.0 : 0.0
            
        case 20: return limiter.ceilingDB.target
        case 21: return limiter.releaseMs.target
        case 22: return limiter.bypassed ? 1.0 : 0.0
        default: return 0.0
        }
    }
    
    /// Real-time audio rendering loop.
    /// Strict real-time constraints: zero heap allocations, zero locks, zero system calls.
    public mutating func process(bufferList: UnsafeMutablePointer<AudioBufferList>, frameCount: AVAudioFrameCount) {
        let buffers = UnsafeMutableAudioBufferListPointer(bufferList)
        guard buffers.count >= 2 else { return }
        
        let left = buffers[0].mData!.assumingMemoryBound(to: Float.self)
        let right = buffers[1].mData!.assumingMemoryBound(to: Float.self)
        let ceiling = EQKernel.safetyCeilingLinear
        
        for i in 0..<Int(frameCount) {
            // 1. 10-Band Graphic & Parametric EQ stage
            let (eqL, eqR) = multiBandEQ.process(sampleL: left[i], sampleR: right[i])
            
            // 2. Tone Booster stage (Sub-Bass Saturation, Mids, Treble Air)
            let (tbL, tbR) = toneBooster.process(sampleL: eqL, sampleR: eqR)
            
            // 3. 3D Spatial Virtualizer (Mid-Side Stereo Widening + Headphone Crossfeed)
            let (spL, spR) = spatializer.process(sampleL: tbL, sampleR: tbR)
            
            // 4. Studio Algorithmic Reverb (Freeverb Comb & All-Pass Diffusers)
            let (revL, revR) = reverb.process(sampleL: spL, sampleR: spR)
            
            // 5. Dynamic Compressor stage (Stereo-linked shared detector)
            let (compL, compR) = compressor.process(sampleL: revL, sampleR: revR)
            
            // 6. Brickwall Lookahead Limiter stage (Stereo-linked shared detector)
            var (limL, limR) = limiter.process(sampleL: compL, sampleR: compR)
            
            // 7. Final Safety Ceiling (-0.1 dBFS hard clamp)
            limL = max(-ceiling, min(limL, ceiling))
            limR = max(-ceiling, min(limR, ceiling))
            
            left[i] = limL
            right[i] = limR
        }
    }
}

public class EQAudioUnit: AUAudioUnit {
    public static let componentDescription = AudioComponentDescription(
        componentType: kAudioUnitType_Effect,
        componentSubType: 0x6d657175, // "mequ"
        componentManufacturer: 0x64656d6f, // "demo"
        componentFlags: 0,
        componentFlagsMask: 0
    )
    
    private static var isRegistered = false
    public static func register() {
        guard !isRegistered else { return }
        AUAudioUnit.registerSubclass(
            EQAudioUnit.self,
            as: componentDescription,
            name: "MacEQ: Audio DSP Unit",
            version: 1
        )
        isRegistered = true
    }
    
    private var _parameterTree: AUParameterTree!
    public var kernelPtr: UnsafeMutablePointer<EQKernel>
    private var ownsKernel: Bool = true
    
    public var onProcessedBuffer: ((UnsafeMutablePointer<AudioBufferList>, AVAudioFrameCount) -> Void)?
    
    private var _outputBus: AUAudioUnitBus!
    private var _inputBus: AUAudioUnitBus!
    private var _outputBusArray: AUAudioUnitBusArray!
    private var _inputBusArray: AUAudioUnitBusArray!
    
    public override init(componentDescription: AudioComponentDescription, options: AudioComponentInstantiationOptions = []) throws {
        self.kernelPtr = UnsafeMutablePointer<EQKernel>.allocate(capacity: 1)
        self.kernelPtr.initialize(to: EQKernel(sampleRate: 44100.0))
        self.ownsKernel = true
        
        try super.init(componentDescription: componentDescription, options: options)
        
        let format = AVAudioFormat(standardFormatWithSampleRate: 44100.0, channels: 2)!
        _inputBus = try AUAudioUnitBus(format: format)
        _outputBus = try AUAudioUnitBus(format: format)
        _inputBusArray = AUAudioUnitBusArray(audioUnit: self, busType: .input, busses: [_inputBus])
        _outputBusArray = AUAudioUnitBusArray(audioUnit: self, busType: .output, busses: [_outputBus])
    }
    
    public func setExternalKernel(_ ptr: UnsafeMutablePointer<EQKernel>) {
        if ownsKernel {
            kernelPtr.deinitialize(count: 1)
            kernelPtr.deallocate()
            ownsKernel = false
        }
        self.kernelPtr = ptr
    }
    
    deinit {
        if ownsKernel {
            kernelPtr.deinitialize(count: 1)
            kernelPtr.deallocate()
        }
    }
    
    public override var inputBusses: AUAudioUnitBusArray {
        return _inputBusArray
    }
    
    public override var outputBusses: AUAudioUnitBusArray {
        return _outputBusArray
    }
    
    public override func allocateRenderResources() throws {
        try super.allocateRenderResources()
        let format = _outputBusArray[0].format
        kernelPtr.pointee.setSampleRate(Float(format.sampleRate))
    }
    
    public override var internalRenderBlock: AUInternalRenderBlock {
        let ptr = self.kernelPtr
        let callback = self.onProcessedBuffer
        
        return { actionFlags, timestamp, frameCount, outputBusNumber, outputData, renderEvent, pullInputBlock in
            guard let pullInputBlock = pullInputBlock else { return kAudioUnitErr_NoConnection }
            
            let err = pullInputBlock(actionFlags, timestamp, frameCount, 0, outputData)
            if err != noErr { return err }
            
            // In-line audio DSP execution: 100% real-time directly modifying outputData
            ptr.pointee.process(bufferList: outputData, frameCount: frameCount)
            
            // Send to visualizer/meter if callback provided
            callback?(outputData, frameCount)
            
            return noErr
        }
    }
}
