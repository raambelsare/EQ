import AVFoundation

class EQAudioUnit: AUAudioUnit {
    private var _inputBusArray: AUAudioUnitBusArray!
    private var _outputBusArray: AUAudioUnitBusArray!
    
    public override init(componentDescription: AudioComponentDescription, options: AudioComponentInstantiationOptions = []) throws {
        try super.init(componentDescription: componentDescription, options: options)
        let format = AVAudioFormat(standardFormatWithSampleRate: 44100.0, channels: 2)!
        let inBus = try AUAudioUnitBus(format: format)
        let outBus = try AUAudioUnitBus(format: format)
        _inputBusArray = AUAudioUnitBusArray(audioUnit: self, busType: .input, busses: [inBus])
        _outputBusArray = AUAudioUnitBusArray(audioUnit: self, busType: .output, busses: [outBus])
    }
    public override var inputBusses: AUAudioUnitBusArray { return _inputBusArray }
    public override var outputBusses: AUAudioUnitBusArray { return _outputBusArray }
    public override var internalRenderBlock: AUInternalRenderBlock { return { _,_,_,_,_,_,_ in noErr } }
}

let desc = AudioComponentDescription(componentType: kAudioUnitType_Effect, componentSubType: 0x45513031, componentManufacturer: 0x4D616345, componentFlags: 0, componentFlagsMask: 0)
AUAudioUnit.registerSubclass(EQAudioUnit.self, as: desc, name: "MacEQ", version: 1)
let au = AVAudioUnitEffect(audioComponentDescription: desc)

let engine = AVAudioEngine()
let inputFormat = AVAudioFormat(standardFormatWithSampleRate: 48000.0, channels: 1)!

do {
    engine.attach(au)
    engine.connect(engine.inputNode, to: au, format: inputFormat)
    print("Connected successfully!")
} catch {
    print("Connect failed: \(error)")
}
do {
    try engine.start()
    print("Engine started successfully!")
} catch {
    print("Engine start failed: \(error)")
}
