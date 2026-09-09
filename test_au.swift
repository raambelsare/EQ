import AVFoundation

public class EQAudioUnit: AUAudioUnit {
    public override init(componentDescription: AudioComponentDescription, options: AudioComponentInstantiationOptions = []) throws {
        try super.init(componentDescription: componentDescription, options: options)
    }
}

let desc = AudioComponentDescription(
    componentType: kAudioUnitType_Effect,
    componentSubType: 0x45513031, // 'EQ01'
    componentManufacturer: 0x4D616345, // 'MacE'
    componentFlags: 0,
    componentFlagsMask: 0
)
AUAudioUnit.registerSubclass(EQAudioUnit.self, as: desc, name: "MacEQ", version: 1)
let au = AVAudioUnitEffect(audioComponentDescription: desc)
print(au.auAudioUnit)
print(au.auAudioUnit is EQAudioUnit)
