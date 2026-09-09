import AVFoundation

class EQAudioUnit: AUAudioUnit {
    public override init(componentDescription: AudioComponentDescription, options: AudioComponentInstantiationOptions = []) throws {
        try super.init(componentDescription: componentDescription, options: options)
    }
    public override var internalRenderBlock: AUInternalRenderBlock {
        return { actionFlags, timestamp, frameCount, outputBusNumber, outputData, renderEvent, pullInputBlock in return noErr }
    }
}

let desc = AudioComponentDescription(componentType: kAudioUnitType_Effect, componentSubType: 0x45513031, componentManufacturer: 0x4D616345, componentFlags: 0, componentFlagsMask: 0)
AUAudioUnit.registerSubclass(EQAudioUnit.self, as: desc, name: "MacEQ", version: 1)
let au = AVAudioUnitEffect(audioComponentDescription: desc)

print("Type: \(type(of: au.auAudioUnit))")
print("Is EQAudioUnit: \(au.auAudioUnit is EQAudioUnit)")
