import AVFoundation

public enum FilterType: Int { case bell = 0, lowShelf, highShelf, lowPass, highPass, notch }
public struct BiquadCoefficients { public init() {} }
public struct BiquadState { public init() {} }
public struct SmoothedParameter { public init() {} }
public struct EQBand { 
    public init(type: FilterType, sampleRate: Float) {}
    public mutating func update(sampleRate: Float) {}
    public mutating func process(sampleL: Float, sampleR: Float) -> (Float, Float) { return (0, 0) }
}
public struct EQKernel {
    public init(sampleRate: Float) {}
    public mutating func setSampleRate(_ rate: Float) {}
    public mutating func setParameter(address: AUParameterAddress, value: AUValue) {}
    public func getParameter(address: AUParameterAddress) -> AUValue { return 0 }
    public mutating func process(bufferList: UnsafeMutablePointer<AudioBufferList>, frameCount: AVAudioFrameCount) {}
}

public class EQAudioUnit: AUAudioUnit {
    private var _parameterTree: AUParameterTree!
    private var kernelPtr: UnsafeMutablePointer<EQKernel>
    private var _outputBus: AUAudioUnitBus!
    private var _inputBus: AUAudioUnitBus!
    private var _outputBusArray: AUAudioUnitBusArray!
    private var _inputBusArray: AUAudioUnitBusArray!
    
    public override init(componentDescription: AudioComponentDescription, options: AudioComponentInstantiationOptions = []) throws {
        kernelPtr = UnsafeMutablePointer<EQKernel>.allocate(capacity: 1)
        kernelPtr.initialize(to: EQKernel(sampleRate: 44100.0))
        try super.init(componentDescription: componentDescription, options: options)
        let format = AVAudioFormat(standardFormatWithSampleRate: 44100.0, channels: 2)!
        _inputBus = try AUAudioUnitBus(format: format)
        _outputBus = try AUAudioUnitBus(format: format)
        _inputBusArray = AUAudioUnitBusArray(audioUnit: self, busType: .input, busses: [_inputBus])
        _outputBusArray = AUAudioUnitBusArray(audioUnit: self, busType: .output, busses: [_outputBus])
    }
    deinit {
        kernelPtr.deinitialize(count: 1)
        kernelPtr.deallocate()
    }
    public override var inputBusses: AUAudioUnitBusArray { return _inputBusArray }
    public override var outputBusses: AUAudioUnitBusArray { return _outputBusArray }
    public override var internalRenderBlock: AUInternalRenderBlock {
        let ptr = self.kernelPtr
        return { actionFlags, timestamp, frameCount, outputBusNumber, outputData, renderEvent, pullInputBlock in
            return noErr
        }
    }
}

let desc = AudioComponentDescription(componentType: kAudioUnitType_Effect, componentSubType: 0x45513031, componentManufacturer: 0x4D616345, componentFlags: 0, componentFlagsMask: 0)
AUAudioUnit.registerSubclass(EQAudioUnit.self, as: desc, name: "MacEQ", version: 1)
let au = AVAudioUnitEffect(audioComponentDescription: desc)
let engine = AVAudioEngine()
engine.attach(au)
print("Attached!")
