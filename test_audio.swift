import AVFoundation

let engine = AVAudioEngine()
let input = engine.inputNode
let output = engine.outputNode

print("Input node inputFormat(0): \(input.inputFormat(forBus: 0).sampleRate)")
print("Input node outputFormat(0): \(input.outputFormat(forBus: 0).sampleRate)")
print("Output node inputFormat(0): \(output.inputFormat(forBus: 0).sampleRate)")
print("Output node outputFormat(0): \(output.outputFormat(forBus: 0).sampleRate)")
