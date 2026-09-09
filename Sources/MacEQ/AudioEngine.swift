import Foundation
import AVFoundation
import CoreAudio

public final class AudioEngine {
    public let engine = AVAudioEngine()
    public let kernelPtr: UnsafeMutablePointer<EQKernel>
    public private(set) var isGeneratorMode: Bool = false
    private var toneNode: AVAudioSourceNode?
    
    public let ringBuffer = RingBuffer(capacity: 16384)
    public let audioMeter = AudioMeter()
    
    public final class AudioBufferStorage: @unchecked Sendable {
        public var leftBuffer: [Float] = []
        public var rightBuffer: [Float] = []
        public var frameCount: Int = 0
        public var readIndex: Int = 0
        public var isPlaying: Bool = false
        public var sampleRate: Double = 48000.0
        
        public init() {}
    }
    
    public let bufferStorage = AudioBufferStorage()
    public private(set) var currentTrackName: String = ""
    public var isPlayingFile: Bool {
        return bufferStorage.isPlaying
    }
    private var processingNode: AVAudioSourceNode?
    private var currentAudioFile: AVAudioFile?
    
    public static func hasUsableInputDevice() -> Bool {
        return false // Do NOT capture microphone by default to prevent self-voice playback
    }
    
    public static func create(completion: @escaping (Result<AudioEngine, Error>) -> Void) {
        do {
            let audioEngine = try AudioEngine()
            completion(.success(audioEngine))
        } catch {
            completion(.failure(error))
        }
    }
    
    private init() throws {
        let output = self.engine.outputNode
        let outputFormat = output.outputFormat(forBus: 0)
        let sampleRate = Float(outputFormat.sampleRate > 0 ? outputFormat.sampleRate : 48000.0)
        self.bufferStorage.sampleRate = Double(sampleRate)
        
        self.kernelPtr = UnsafeMutablePointer<EQKernel>.allocate(capacity: 1)
        self.kernelPtr.initialize(to: EQKernel(sampleRate: sampleRate))
        
        try setupGraph(sampleRate: sampleRate)
    }
    
    deinit {
        kernelPtr.deinitialize(count: 1)
        kernelPtr.deallocate()
    }
    
    private func setupGraph(sampleRate: Float) throws {
        let format = AVAudioFormat(standardFormatWithSampleRate: Double(sampleRate), channels: 2)!
        let storage = self.bufferStorage
        let ptr = self.kernelPtr
        let rb = self.ringBuffer
        let meter = self.audioMeter
        
        // Active In-Line DSP Node: Reads audio file buffer, processes directly through DSP Kernel,
        // and feeds the output directly to speakers & meters without any OSStatus -3000 error!
        let dspNode = AVAudioSourceNode { _, _, frameCount, audioBufferList in
            let abl = UnsafeMutableAudioBufferListPointer(audioBufferList)
            guard abl.count >= 2,
                  let outL = abl[0].mData?.assumingMemoryBound(to: Float.self),
                  let outR = abl[1].mData?.assumingMemoryBound(to: Float.self) else {
                return noErr
            }
            
            let total = storage.frameCount
            let playing = storage.isPlaying
            
            if !playing || total == 0 {
                memset(outL, 0, Int(frameCount) * MemoryLayout<Float>.size)
                memset(outR, 0, Int(frameCount) * MemoryLayout<Float>.size)
                return noErr
            }
            
            var idx = storage.readIndex
            storage.leftBuffer.withUnsafeBufferPointer { lBuf in
                storage.rightBuffer.withUnsafeBufferPointer { rBuf in
                    for i in 0..<Int(frameCount) {
                        outL[i] = lBuf[idx]
                        outR[i] = rBuf[idx]
                        idx = (idx + 1) % total
                    }
                }
            }
            storage.readIndex = idx
            
            // 100% In-Line DSP Processing: MultiBandEQ, ToneBooster, Spatializer, Reverb, Compressor, Limiter
            ptr.pointee.process(bufferList: audioBufferList, frameCount: frameCount)
            
            // Feed processed audio to visualizer and meters
            meter.process(left: outL, right: outR, count: Int(frameCount))
            rb.write(from: outL, count: Int(frameCount))
            
            return noErr
        }
        
        self.processingNode = dspNode
        self.engine.attach(dspNode)
        self.engine.connect(dspNode, to: self.engine.mainMixerNode, format: format)
    }
    
    public func loadAudioFile(url: URL) throws {
        let file = try AVAudioFile(forReading: url)
        self.currentAudioFile = file
        self.currentTrackName = url.lastPathComponent
        
        let fileFrames = AVAudioFrameCount(file.length)
        let pcm = AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: fileFrames)!
        try file.read(into: pcm)
        
        // Load into lock-free audio buffer
        let count = Int(fileFrames)
        var left = [Float](repeating: 0.0, count: count)
        var right = [Float](repeating: 0.0, count: count)
        
        pcm.floatChannelData![0].withMemoryRebound(to: Float.self, capacity: count) { ptr in
            left.withUnsafeMutableBufferPointer { dest in
                _ = dest.initialize(from: UnsafeBufferPointer(start: ptr, count: count))
            }
        }
        
        if pcm.format.channelCount >= 2 {
            pcm.floatChannelData![1].withMemoryRebound(to: Float.self, capacity: count) { ptr in
                right.withUnsafeMutableBufferPointer { dest in
                    _ = dest.initialize(from: UnsafeBufferPointer(start: ptr, count: count))
                }
            }
        } else {
            right = left
        }
        
        bufferStorage.isPlaying = false
        bufferStorage.leftBuffer = left
        bufferStorage.rightBuffer = right
        bufferStorage.frameCount = count
        bufferStorage.readIndex = 0
        bufferStorage.isPlaying = true
    }
    
    public func play() {
        bufferStorage.isPlaying = true
    }
    
    public func pause() {
        bufferStorage.isPlaying = false
    }
    
    // MARK: - 10-Band EQ
    public func setBandGain(index: Int, gainDB: Float) {
        kernelPtr.pointee.setParameter(address: AUParameterAddress(100 + index), value: gainDB)
    }
    
    public func getBandGain(index: Int) -> Float {
        return kernelPtr.pointee.getParameter(address: AUParameterAddress(100 + index))
    }
    
    public func resetEQ() {
        for i in 0..<MultiBandEQ.bandCount {
            setBandGain(index: i, gainDB: 0.0)
        }
    }
    
    // MARK: - Tone Booster
    public func setBassBoost(_ db: Float) {
        kernelPtr.pointee.setParameter(address: 30, value: db)
    }
    public func setMidsBoost(_ db: Float) {
        kernelPtr.pointee.setParameter(address: 31, value: db)
    }
    public func setTrebleBoost(_ db: Float) {
        kernelPtr.pointee.setParameter(address: 32, value: db)
    }
    public func setBoosterBypass(_ bypass: Bool) {
        kernelPtr.pointee.setParameter(address: 33, value: bypass ? 1.0 : 0.0)
    }
    public func getBassBoost() -> Float { kernelPtr.pointee.getParameter(address: 30) }
    public func getMidsBoost() -> Float { kernelPtr.pointee.getParameter(address: 31) }
    public func getTrebleBoost() -> Float { kernelPtr.pointee.getParameter(address: 32) }
    public func getBoosterBypass() -> Bool { kernelPtr.pointee.getParameter(address: 33) > 0.5 }
    
    // MARK: - 3D Spatial Virtualizer
    public func setSpatialWidth(_ width: Float) {
        kernelPtr.pointee.setParameter(address: 40, value: width)
    }
    public func setCrossfeedAmount(_ amount: Float) {
        kernelPtr.pointee.setParameter(address: 41, value: amount)
    }
    public func setSpatialBypass(_ bypass: Bool) {
        kernelPtr.pointee.setParameter(address: 42, value: bypass ? 1.0 : 0.0)
    }
    public func getSpatialWidth() -> Float { kernelPtr.pointee.getParameter(address: 40) }
    public func getCrossfeedAmount() -> Float { kernelPtr.pointee.getParameter(address: 41) }
    public func getSpatialBypass() -> Bool { kernelPtr.pointee.getParameter(address: 42) > 0.5 }
    
    // MARK: - Studio Reverb
    public func setReverbRoomSize(_ size: Float) {
        kernelPtr.pointee.setParameter(address: 50, value: size)
    }
    public func setReverbDamping(_ damp: Float) {
        kernelPtr.pointee.setParameter(address: 51, value: damp)
    }
    public func setReverbWet(_ wet: Float) {
        kernelPtr.pointee.setParameter(address: 52, value: wet)
    }
    public func setReverbDry(_ dry: Float) {
        kernelPtr.pointee.setParameter(address: 53, value: dry)
    }
    public func setReverbBypass(_ bypass: Bool) {
        kernelPtr.pointee.setParameter(address: 54, value: bypass ? 1.0 : 0.0)
    }
    public func getReverbRoomSize() -> Float { kernelPtr.pointee.getParameter(address: 50) }
    public func getReverbWet() -> Float { kernelPtr.pointee.getParameter(address: 52) }
    public func getReverbBypass() -> Bool { kernelPtr.pointee.getParameter(address: 54) > 0.5 }
    
    // MARK: - Apply Preset
    public func applyPreset(_ preset: AudioPreset) {
        for (i, gain) in preset.eqGains.enumerated() {
            setBandGain(index: i, gainDB: gain)
        }
        setBassBoost(preset.bassBoostDB)
        setMidsBoost(preset.midsBoostDB)
        setTrebleBoost(preset.trebleBoostDB)
        setSpatialWidth(preset.spatialWidth)
        setCrossfeedAmount(preset.crossfeed)
        setReverbRoomSize(preset.reverbRoomSize)
        setReverbWet(preset.reverbWet)
        setReverbBypass(!preset.reverbEnabled)
    }
    
    // MARK: - Compressor Parameters
    public func setCompressorThreshold(_ db: Float) {
        kernelPtr.pointee.setParameter(address: 10, value: db)
    }
    
    public func setCompressorRatio(_ r: Float) {
        kernelPtr.pointee.setParameter(address: 11, value: r)
    }
    
    public func setCompressorAttack(_ ms: Float) {
        kernelPtr.pointee.setParameter(address: 12, value: ms)
    }
    
    public func setCompressorRelease(_ ms: Float) {
        kernelPtr.pointee.setParameter(address: 13, value: ms)
    }
    
    public func setCompressorKnee(_ db: Float) {
        kernelPtr.pointee.setParameter(address: 14, value: db)
    }
    
    public func setCompressorMakeupGain(_ db: Float) {
        kernelPtr.pointee.setParameter(address: 15, value: db)
    }
    
    public func setCompressorBypass(_ bypass: Bool) {
        kernelPtr.pointee.setParameter(address: 16, value: bypass ? 1.0 : 0.0)
    }
    
    public func getCompressorThreshold() -> Float {
        return kernelPtr.pointee.getParameter(address: 10)
    }
    
    public func getCompressorRatio() -> Float {
        return kernelPtr.pointee.getParameter(address: 11)
    }
    
    public func getCompressorAttack() -> Float {
        return kernelPtr.pointee.getParameter(address: 12)
    }
    
    public func getCompressorRelease() -> Float {
        return kernelPtr.pointee.getParameter(address: 13)
    }
    
    public func getCompressorKnee() -> Float {
        return kernelPtr.pointee.getParameter(address: 14)
    }
    
    public func getCompressorMakeupGain() -> Float {
        return kernelPtr.pointee.getParameter(address: 15)
    }
    
    public func getCompressorBypass() -> Bool {
        return kernelPtr.pointee.getParameter(address: 16) > 0.5
    }
    
    public func getCompressorGainReduction() -> Float {
        return kernelPtr.pointee.compressor.currentGainReductionDB
    }
    
    // MARK: - Limiter Parameters
    public func setLimiterCeiling(_ db: Float) {
        kernelPtr.pointee.setParameter(address: 20, value: db)
    }
    
    public func setLimiterRelease(_ ms: Float) {
        kernelPtr.pointee.setParameter(address: 21, value: ms)
    }
    
    public func setLimiterBypass(_ bypass: Bool) {
        kernelPtr.pointee.setParameter(address: 22, value: bypass ? 1.0 : 0.0)
    }
    
    public func getLimiterCeiling() -> Float {
        return kernelPtr.pointee.getParameter(address: 20)
    }
    
    public func getLimiterRelease() -> Float {
        return kernelPtr.pointee.getParameter(address: 21)
    }
    
    public func getLimiterBypass() -> Bool {
        return kernelPtr.pointee.getParameter(address: 22) > 0.5
    }
    
    public func getLimiterGainReduction() -> Float {
        return kernelPtr.pointee.limiter.currentGainReductionDB
    }
    
    public func start() throws {
        try engine.start()
    }
    
    public func stop() {
        engine.stop()
    }
}
