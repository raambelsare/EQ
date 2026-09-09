import Foundation
import AVFoundation

public final class AudioDeviceManager: ObservableObject {
    @Published public var inputSampleRate: Double = 0.0
    @Published public var outputSampleRate: Double = 0.0
    @Published public var inputName: String = "Default Input"
    @Published public var outputName: String = "Default Output"
    @Published public var engineError: String? = nil
    @Published public var engine: AudioEngine?
    
    public var isMismatched: Bool {
        inputSampleRate > 0 && outputSampleRate > 0 && abs(inputSampleRate - outputSampleRate) > 0.1
    }
    
    public init() {}
    
    public func update(from engine: AudioEngine) {
        let outputFormat = engine.engine.outputNode.outputFormat(forBus: 0)
        let rate = outputFormat.sampleRate > 0 ? outputFormat.sampleRate : 48000.0
        
        DispatchQueue.main.async {
            self.outputSampleRate = rate
            if engine.isGeneratorMode {
                self.inputSampleRate = rate
                self.inputName = "Test Tone Generator"
            } else if AudioEngine.hasUsableInputDevice() {
                let inputHWFormat = engine.engine.inputNode.inputFormat(forBus: 0)
                self.inputSampleRate = inputHWFormat.sampleRate > 0 ? inputHWFormat.sampleRate : rate
                self.inputName = "Hardware Input"
            }
        }
    }
}
