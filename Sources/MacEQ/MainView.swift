import SwiftUI
import AVFoundation

struct MainView: View {
    @ObservedObject var deviceManager: AudioDeviceManager
    
    var body: some View {
        VStack(spacing: 0) {
            // Header Bar
            HStack {
                HStack(spacing: 8) {
                    Circle()
                        .fill(DesignSystem.Colors.amber)
                        .frame(width: 8, height: 8)
                        .shadow(color: DesignSystem.Colors.amberGlow, radius: 4)
                    Text("MacEQ")
                        .font(DesignSystem.Typography.titleFont)
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                    Text("DSP HI-FI")
                        .font(DesignSystem.Typography.labelFont)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 2)
                        .background(DesignSystem.Colors.bgElement)
                        .foregroundColor(DesignSystem.Colors.copper)
                        .cornerRadius(3)
                }
                
                Spacer()
                
                // Hardware Status & Sample Rate Telemetry
                // Music File Player & Source Selection
                HStack(spacing: 8) {
                    if let engine = deviceManager.engine {
                        // Open File Button
                        Button(action: {
                            let panel = NSOpenPanel()
                            panel.allowsMultipleSelection = false
                            panel.canChooseDirectories = false
                            panel.allowedContentTypes = [.audio, .mp3]
                            if panel.runModal() == .OK, let url = panel.url {
                                try? engine.loadAudioFile(url: url)
                            }
                        }) {
                            HStack(spacing: 5) {
                                Image(systemName: "music.note.list")
                                    .font(.system(size: 10))
                                Text("OPEN AUDIO FILE")
                                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(DesignSystem.Colors.amber)
                            .cornerRadius(4)
                        }
                        .buttonStyle(.plain)
                        
                        // Demo Sound Button (Loads built-in macOS audio sample to test EQ immediately)
                        Button(action: {
                            let demoURL = URL(fileURLWithPath: "/System/Library/Sounds/Funk.aiff")
                            try? engine.loadAudioFile(url: demoURL)
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "sparkles")
                                    .font(.system(size: 9))
                                Text("DEMO TRACK")
                                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                            }
                            .foregroundColor(DesignSystem.Colors.textPrimary)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 4)
                            .background(DesignSystem.Colors.bgElement)
                            .cornerRadius(4)
                        }
                        .buttonStyle(.plain)
                        
                        // Play/Pause Button
                        Button(action: {
                            if engine.isPlayingFile {
                                engine.pause()
                            } else {
                                engine.play()
                            }
                        }) {
                            Image(systemName: engine.isPlayingFile ? "pause.fill" : "play.fill")
                                .font(.system(size: 10))
                                .foregroundColor(DesignSystem.Colors.textPrimary)
                                .frame(width: 24, height: 22)
                                .background(DesignSystem.Colors.bgElement)
                                .cornerRadius(4)
                        }
                        .buttonStyle(.plain)
                        
                        // Currently Playing Track Label
                        if !engine.currentTrackName.isEmpty {
                            HStack(spacing: 4) {
                                Image(systemName: "waveform")
                                    .font(.system(size: 9))
                                    .foregroundColor(DesignSystem.Colors.amber)
                                Text(engine.currentTrackName)
                                    .font(.system(size: 9, weight: .semibold, design: .monospaced))
                                    .foregroundColor(DesignSystem.Colors.textPrimary)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                                    .frame(maxWidth: 140)
                            }
                            .padding(.horizontal, 6)
                            .padding(.vertical, 4)
                            .background(DesignSystem.Colors.bgElement)
                            .cornerRadius(4)
                        }
                    }
                }
                
                // Output Sample Rate Telemetry
                HStack(spacing: 6) {
                    Image(systemName: "speaker.wave.2.fill")
                        .font(.system(size: 9))
                        .foregroundColor(DesignSystem.Colors.meterGreen)
                    Text("OUT: \(deviceManager.outputSampleRate, specifier: "%.0f") Hz")
                        .font(DesignSystem.Typography.readoutFont)
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(DesignSystem.Colors.bgElement)
                .cornerRadius(4)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(DesignSystem.Colors.bgPanel)
            .overlay(
                Rectangle()
                    .frame(height: 1)
                    .foregroundColor(DesignSystem.Colors.borderSubtle),
                alignment: .bottom
            )
            
            // Main Audio Dashboard
            if let error = deviceManager.engineError {
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.octagon.fill")
                        .font(.system(size: 32))
                        .foregroundColor(DesignSystem.Colors.meterClip)
                    Text("Audio Initialization Error")
                        .font(DesignSystem.Typography.titleFont)
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                    Text(error)
                        .font(DesignSystem.Typography.readoutFont)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let engine = deviceManager.engine {
                DashboardView(engine: engine)
            } else {
                VStack(spacing: 12) {
                    ProgressView()
                    Text("Starting audio engine...")
                        .font(DesignSystem.Typography.readoutFont)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(minWidth: 720, minHeight: 460)
        .background(DesignSystem.Colors.bgDeep)
    }
}

private struct DashboardView: View {
    let engine: AudioEngine
    
    // UI State for Analyzer and Meters (driven by 60Hz display timer)
    @State private var fftAnalyzer = FFTAnalyzer(fftSize: 2048, binCount: 128, sampleRate: 48000.0)
    @State private var spectrum: [Float] = [Float](repeating: -80.0, count: 128)
    @State private var meterValues = AudioMeter.MeterValues(
        peakLeft: -60, peakRight: -60,
        rmsLeft: -60, rmsRight: -60,
        peakHoldLeft: -60, peakHoldRight: -60,
        isClippingLeft: false, isClippingRight: false
    )
    
    // Presets
    @State private var activePresetName: String = "Flat / Reference"
    
    // 10-Band EQ Gains
    @State private var eqGains: [Float] = [Float](repeating: 0.0, count: MultiBandEQ.bandCount)
    
    // Tone Boosters
    @State private var bassBoost: Float = 0.0
    @State private var midsBoost: Float = 0.0
    @State private var trebleBoost: Float = 0.0
    
    // 3D Spatial Virtualizer
    @State private var spatialWidth: Float = 1.0
    @State private var crossfeed: Float = 0.0
    
    // Studio Reverb
    @State private var reverbRoomSize: Float = 0.5
    @State private var reverbWet: Float = 0.25
    @State private var reverbBypassed: Bool = true
    
    // Dynamics Telemetry States
    @State private var compGR: Float = 0.0
    @State private var limiterGR: Float = 0.0
    
    // 60 FPS UI polling timer
    let timer = Timer.publish(every: 1.0 / 60.0, on: .main, in: .common).autoconnect()
    
    var body: some View {
        ScrollView(.vertical, showsIndicators: true) {
            VStack(spacing: 12) {
                // Preset Bar
                PresetSelectorView(engine: engine, activePresetName: $activePresetName) { preset in
                    self.eqGains = preset.eqGains
                    self.bassBoost = preset.bassBoostDB
                    self.midsBoost = preset.midsBoostDB
                    self.trebleBoost = preset.trebleBoostDB
                    self.spatialWidth = preset.spatialWidth
                    self.crossfeed = preset.crossfeed
                    self.reverbRoomSize = preset.reverbRoomSize
                    self.reverbWet = preset.reverbWet
                    self.reverbBypassed = !preset.reverbEnabled
                }
                
                // Visualizer Section: Real-Time Spectrum Analyzer + Stereo Meter
                HStack(spacing: 12) {
                    SpectrumAnalyzerView(spectrum: spectrum)
                        .frame(height: 180)
                    
                    MeterView(values: meterValues) {
                        engine.audioMeter.resetClip()
                    }
                    .frame(width: 76, height: 180)
                }
                
                // 10-Band Multi-Band Equalizer Console
                MultiBandEQView(engine: engine, gains: $eqGains)
                
                // Tone Boosters (Bass, Mids, Treble) + 3D Spatial + Studio Reverb
                EffectsControlView(
                    engine: engine,
                    bassBoost: $bassBoost,
                    midsBoost: $midsBoost,
                    trebleBoost: $trebleBoost,
                    spatialWidth: $spatialWidth,
                    crossfeed: $crossfeed,
                    reverbRoomSize: $reverbRoomSize,
                    reverbWet: $reverbWet,
                    reverbBypassed: $reverbBypassed
                )
                
                // Dynamics Section: Compressor & Brickwall Limiter
                DynamicsControlView(engine: engine, compGR: compGR, limiterGR: limiterGR)
            }
            .padding(14)
        }
        .onAppear {
            for i in 0..<MultiBandEQ.bandCount {
                eqGains[i] = engine.getBandGain(index: i)
            }
            bassBoost = engine.getBassBoost()
            midsBoost = engine.getMidsBoost()
            trebleBoost = engine.getTrebleBoost()
            spatialWidth = engine.getSpatialWidth()
            crossfeed = engine.getCrossfeedAmount()
            reverbRoomSize = engine.getReverbRoomSize()
            reverbWet = engine.getReverbWet()
            reverbBypassed = engine.getReverbBypass()
        }
        .onReceive(timer) { _ in
            // Execute FFT analysis on available samples in the lock-free ring buffer
            fftAnalyzer.process(ringBuffer: engine.ringBuffer, smoothingFactor: 0.70)
            self.spectrum = fftAnalyzer.smoothedSpectrum
            
            // Poll and decay meters
            self.meterValues = engine.audioMeter.update(deltaTime: 1.0 / 60.0)
            
            // Poll gain reduction telemetry
            self.compGR = engine.getCompressorGainReduction()
            self.limiterGR = engine.getLimiterGainReduction()
        }
    }
}
