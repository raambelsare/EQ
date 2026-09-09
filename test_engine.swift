import AVFoundation

let desc = AudioComponentDescription(
    componentType: kAudioUnitType_Effect,
    componentSubType: 0x45513031, // 'EQ01'
    componentManufacturer: 0x4D616345, // 'MacE'
    componentFlags: 0,
    componentFlagsMask: 0
)

class EQAudioUnit: AUAudioUnit {
    public override init(componentDescription: AudioComponentDescription, options: AudioComponentInstantiationOptions = []) throws {
        try super.init(componentDescription: componentDescription, options: options)
    }
}

AUAudioUnit.registerSubclass(EQAudioUnit.self, as: desc, name: "MacEQ", version: 1)
let au = AVAudioUnitEffect(audioComponentDescription: desc)

let engine = AVAudioEngine()
let mixerNode = AVAudioMixerNode()

engine.attach(au)
engine.attach(mixerNode)

let input = engine.inputNode
let output = engine.outputNode

let inputFormat = input.outputFormat(forBus: 0)
let outputFormat = output.outputFormat(forBus: 0)

engine.connect(input, to: au, format: inputFormat)
engine.connect(au, to: mixerNode, format: inputFormat)
engine.connect(mixerNode, to: output, format: outputFormat)

do {
    try engine.start()
    print("Engine started successfully.")
} catch {
    print("Failed to start engine: \(error)")
}
