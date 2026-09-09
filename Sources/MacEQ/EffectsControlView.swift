import SwiftUI

/// Audio Enhancers, 3D Spatial Virtualizer, and Studio Reverb Control Console
public struct EffectsControlView: View {
    let engine: AudioEngine
    
    // Tone Boosters
    @Binding var bassBoost: Float
    @Binding var midsBoost: Float
    @Binding var trebleBoost: Float
    @State private var boosterBypassed: Bool = false
    
    // 3D Spatial Virtualizer
    @Binding var spatialWidth: Float
    @Binding var crossfeed: Float
    @State private var spatialBypassed: Bool = false
    
    // Studio Reverb
    @Binding var reverbRoomSize: Float
    @Binding var reverbWet: Float
    @Binding var reverbBypassed: Bool
    
    public init(
        engine: AudioEngine,
        bassBoost: Binding<Float>,
        midsBoost: Binding<Float>,
        trebleBoost: Binding<Float>,
        spatialWidth: Binding<Float>,
        crossfeed: Binding<Float>,
        reverbRoomSize: Binding<Float>,
        reverbWet: Binding<Float>,
        reverbBypassed: Binding<Bool>
    ) {
        self.engine = engine
        self._bassBoost = bassBoost
        self._midsBoost = midsBoost
        self._trebleBoost = trebleBoost
        self._spatialWidth = spatialWidth
        self._crossfeed = crossfeed
        self._reverbRoomSize = reverbRoomSize
        self._reverbWet = reverbWet
        self._reverbBypassed = reverbBypassed
    }
    
    public var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Card 1: Tone Boosters (Bass, Mids, Treble)
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    HStack(spacing: 5) {
                        Image(systemName: "speaker.wave.3.fill")
                            .font(.system(size: 11))
                            .foregroundColor(DesignSystem.Colors.amber)
                        Text("TONE BOOSTERS")
                            .font(DesignSystem.Typography.headerFont)
                            .foregroundColor(boosterBypassed ? DesignSystem.Colors.textMuted : DesignSystem.Colors.copper)
                    }
                    
                    Spacer()
                    
                    Button(action: {
                        boosterBypassed.toggle()
                        engine.setBoosterBypass(boosterBypassed)
                    }) {
                        Text(boosterBypassed ? "BYPASS" : "ACTIVE")
                            .font(.system(size: 8.5, weight: .bold, design: .monospaced))
                            .foregroundColor(boosterBypassed ? DesignSystem.Colors.textMuted : .white)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(boosterBypassed ? DesignSystem.Colors.bgElement : DesignSystem.Colors.amber)
                            .cornerRadius(3)
                    }
                    .buttonStyle(.plain)
                }
                
                VStack(spacing: 8) {
                    EffectSlider(
                        icon: "waveform.badge.plus",
                        label: "BASS BOOST",
                        valueStr: String(format: "+%.1f dB", bassBoost),
                        value: $bassBoost,
                        range: 0...12
                    ) { engine.setBassBoost($0) }
                    
                    EffectSlider(
                        icon: "person.wave.2",
                        label: "MIDS CLARITY",
                        valueStr: String(format: "+%.1f dB", midsBoost),
                        value: $midsBoost,
                        range: 0...12
                    ) { engine.setMidsBoost($0) }
                    
                    EffectSlider(
                        icon: "sparkles",
                        label: "TREBLE AIR",
                        valueStr: String(format: "+%.1f dB", trebleBoost),
                        value: $trebleBoost,
                        range: 0...12
                    ) { engine.setTrebleBoost($0) }
                }
            }
            .padding(12)
            .background(DesignSystem.Colors.bgPanel)
            .cornerRadius(DesignSystem.Layout.cornerRadius)
            .overlay(
                RoundedRectangle(cornerRadius: DesignSystem.Layout.cornerRadius)
                    .stroke(boosterBypassed ? DesignSystem.Colors.borderSubtle : DesignSystem.Colors.borderActive, lineWidth: 1)
            )
            
            // Card 2: 3D Spatial Virtualizer
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    HStack(spacing: 5) {
                        Image(systemName: "headphones")
                            .font(.system(size: 11))
                            .foregroundColor(DesignSystem.Colors.cyan)
                        Text("3D SPATIAL")
                            .font(DesignSystem.Typography.headerFont)
                            .foregroundColor(spatialBypassed ? DesignSystem.Colors.textMuted : DesignSystem.Colors.cyan)
                    }
                    
                    Spacer()
                    
                    Button(action: {
                        spatialBypassed.toggle()
                        engine.setSpatialBypass(spatialBypassed)
                    }) {
                        Text(spatialBypassed ? "BYPASS" : "3D WIDE")
                            .font(.system(size: 8.5, weight: .bold, design: .monospaced))
                            .foregroundColor(spatialBypassed ? DesignSystem.Colors.textMuted : .black)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(spatialBypassed ? DesignSystem.Colors.bgElement : DesignSystem.Colors.cyan)
                            .cornerRadius(3)
                    }
                    .buttonStyle(.plain)
                }
                
                VStack(spacing: 8) {
                    EffectSlider(
                        icon: "arrow.left.and.right",
                        label: "STEREO WIDTH",
                        valueStr: String(format: "%.0f%%", spatialWidth * 100),
                        value: $spatialWidth,
                        range: 0.5...2.0
                    ) { engine.setSpatialWidth($0) }
                    
                    EffectSlider(
                        icon: "ear",
                        label: "CROSS-FEED",
                        valueStr: String(format: "%.0f%%", crossfeed * 100),
                        value: $crossfeed,
                        range: 0.0...1.0
                    ) { engine.setCrossfeedAmount($0) }
                }
                
                HStack {
                    Text("MODE")
                        .font(DesignSystem.Typography.labelFont)
                        .foregroundColor(DesignSystem.Colors.textMuted)
                    Spacer()
                    Text("MID-SIDE (PHASE-SAFE)")
                        .font(DesignSystem.Typography.readoutFont)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                }
                .padding(.top, 4)
            }
            .frame(maxWidth: .infinity)
            .padding(12)
            .background(DesignSystem.Colors.bgPanel)
            .cornerRadius(DesignSystem.Layout.cornerRadius)
            .overlay(
                RoundedRectangle(cornerRadius: DesignSystem.Layout.cornerRadius)
                    .stroke(spatialBypassed ? DesignSystem.Colors.borderSubtle : DesignSystem.Colors.borderActive, lineWidth: 1)
            )
            
            // Card 3: Studio Reverb
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    HStack(spacing: 5) {
                        Image(systemName: "dot.radiowaves.left.and.right")
                            .font(.system(size: 11))
                            .foregroundColor(DesignSystem.Colors.copper)
                        Text("STUDIO REVERB")
                            .font(DesignSystem.Typography.headerFont)
                            .foregroundColor(reverbBypassed ? DesignSystem.Colors.textMuted : DesignSystem.Colors.copper)
                    }
                    
                    Spacer()
                    
                    Button(action: {
                        reverbBypassed.toggle()
                        engine.setReverbBypass(reverbBypassed)
                    }) {
                        Text(reverbBypassed ? "BYPASS" : "ROOM")
                            .font(.system(size: 8.5, weight: .bold, design: .monospaced))
                            .foregroundColor(reverbBypassed ? DesignSystem.Colors.textMuted : .white)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(reverbBypassed ? DesignSystem.Colors.bgElement : DesignSystem.Colors.copper)
                            .cornerRadius(3)
                    }
                    .buttonStyle(.plain)
                }
                
                VStack(spacing: 8) {
                    EffectSlider(
                        icon: "square.split.diagonal.2x2",
                        label: "ROOM SIZE",
                        valueStr: String(format: "%.0f%%", reverbRoomSize * 100),
                        value: $reverbRoomSize,
                        range: 0.1...0.95
                    ) { engine.setReverbRoomSize($0) }
                    
                    EffectSlider(
                        icon: "drop.fill",
                        label: "WET MIX",
                        valueStr: String(format: "%.0f%%", reverbWet * 100),
                        value: $reverbWet,
                        range: 0.0...0.8
                    ) { engine.setReverbWet($0) }
                }
                
                HStack {
                    Text("ENGINE")
                        .font(DesignSystem.Typography.labelFont)
                        .foregroundColor(DesignSystem.Colors.textMuted)
                    Spacer()
                    Text("SCHROEDER 8-COMB")
                        .font(DesignSystem.Typography.readoutFont)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                }
                .padding(.top, 4)
            }
            .frame(maxWidth: .infinity)
            .padding(12)
            .background(DesignSystem.Colors.bgPanel)
            .cornerRadius(DesignSystem.Layout.cornerRadius)
            .overlay(
                RoundedRectangle(cornerRadius: DesignSystem.Layout.cornerRadius)
                    .stroke(reverbBypassed ? DesignSystem.Colors.borderSubtle : DesignSystem.Colors.borderActive, lineWidth: 1)
            )
        }
        .onAppear {
            boosterBypassed = engine.getBoosterBypass()
            spatialBypassed = engine.getSpatialBypass()
        }
    }
}

private struct EffectSlider: View {
    let icon: String
    let label: String
    let valueStr: String
    @Binding var value: Float
    let range: ClosedRange<Float>
    let onChange: (Float) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 9))
                    .foregroundColor(DesignSystem.Colors.textMuted)
                Text(label)
                    .font(DesignSystem.Typography.labelFont)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
                Spacer()
                Text(valueStr)
                    .font(DesignSystem.Typography.readoutFont)
                    .foregroundColor(DesignSystem.Colors.textPrimary)
            }
            Slider(value: $value, in: range)
                .accentColor(DesignSystem.Colors.amber)
                .onChange(of: value) { onChange($0) }
        }
    }
}
