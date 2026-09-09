import SwiftUI

/// Dynamics section displaying Compressor & Limiter controls, bypass toggles, and wide-scale Gain Reduction meters.
public struct DynamicsControlView: View {
    let engine: AudioEngine
    let compGR: Float    // in dB (<= 0)
    let limiterGR: Float // in dB (<= 0)
    
    // Compressor states
    @State private var threshold: Float = -12.0
    @State private var ratio: Float = 3.0
    @State private var attack: Float = 10.0
    @State private var release: Float = 100.0
    @State private var knee: Float = 4.0
    @State private var makeupGain: Float = 0.0
    @State private var compBypassed: Bool = false
    
    // Limiter states
    @State private var ceiling: Float = -0.3
    @State private var limiterRelease: Float = 50.0
    @State private var limiterBypassed: Bool = false
    
    public init(engine: AudioEngine, compGR: Float, limiterGR: Float) {
        self.engine = engine
        self.compGR = compGR
        self.limiterGR = limiterGR
    }
    
    public var body: some View {
        HStack(alignment: .top, spacing: 14) {
            // Compressor Strip
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("DYNAMIC COMPRESSOR")
                        .font(DesignSystem.Typography.headerFont)
                        .foregroundColor(compBypassed ? DesignSystem.Colors.textMuted : DesignSystem.Colors.copper)
                    
                    Spacer()
                    
                    Button(action: {
                        compBypassed.toggle()
                        engine.setCompressorBypass(compBypassed)
                    }) {
                        Text(compBypassed ? "BYPASS" : "ACTIVE")
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .foregroundColor(compBypassed ? DesignSystem.Colors.textMuted : .white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(compBypassed ? DesignSystem.Colors.bgElement : DesignSystem.Colors.amber)
                            .cornerRadius(3)
                    }
                    .buttonStyle(.plain)
                }
                
                // Gain Reduction Meter (Scale: 0 to -30 dBFS with Over-range Flag)
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("COMP GR")
                            .font(DesignSystem.Typography.labelFont)
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                        Spacer()
                        if compGR < -30.0 {
                            Text("OVER \(String(format: "%.1f", compGR)) dB")
                                .font(DesignSystem.Typography.readoutFont)
                                .foregroundColor(DesignSystem.Colors.meterClip)
                        } else {
                            Text(String(format: "%.1f dB", compGR))
                                .font(DesignSystem.Typography.readoutFont)
                                .foregroundColor(compGR < -0.1 ? DesignSystem.Colors.amber : DesignSystem.Colors.textMuted)
                        }
                    }
                    
                    GainReductionBar(grDB: compGR, maxReductionDB: 30.0)
                        .frame(height: 6)
                }
                
                // Sliders Grid
                VStack(spacing: 8) {
                    HStack(spacing: 12) {
                        // Threshold
                        ParameterSlider(
                            label: "THRESH",
                            valueString: String(format: "%.0f dB", threshold),
                            value: $threshold,
                            range: -60...0,
                            onChange: { engine.setCompressorThreshold($0) }
                        )
                        
                        // Ratio
                        ParameterSlider(
                            label: "RATIO",
                            valueString: String(format: "%.1f:1", ratio),
                            value: $ratio,
                            range: 1...20,
                            onChange: { engine.setCompressorRatio($0) }
                        )
                    }
                    
                    HStack(spacing: 12) {
                        // Attack
                        ParameterSlider(
                            label: "ATTACK",
                            valueString: String(format: "%.1f ms", attack),
                            value: $attack,
                            range: 0.1...100,
                            onChange: { engine.setCompressorAttack($0) }
                        )
                        
                        // Release
                        ParameterSlider(
                            label: "RELEASE",
                            valueString: String(format: "%.0f ms", release),
                            value: $release,
                            range: 10...1000,
                            onChange: { engine.setCompressorRelease($0) }
                        )
                    }
                    
                    HStack(spacing: 12) {
                        // Knee
                        ParameterSlider(
                            label: "KNEE",
                            valueString: String(format: "%.1f dB", knee),
                            value: $knee,
                            range: 0...12,
                            onChange: { engine.setCompressorKnee($0) }
                        )
                        
                        // Makeup
                        ParameterSlider(
                            label: "MAKEUP",
                            valueString: String(format: "%+.1f dB", makeupGain),
                            value: $makeupGain,
                            range: 0...24,
                            onChange: { engine.setCompressorMakeupGain($0) }
                        )
                    }
                }
            }
            .padding(12)
            .background(DesignSystem.Colors.bgPanel)
            .cornerRadius(DesignSystem.Layout.cornerRadius)
            .overlay(
                RoundedRectangle(cornerRadius: DesignSystem.Layout.cornerRadius)
                    .stroke(compBypassed ? DesignSystem.Colors.borderSubtle : DesignSystem.Colors.borderActive, lineWidth: 1)
            )
            
            // Limiter Strip
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("LOOKAHEAD LIMITER")
                        .font(DesignSystem.Typography.headerFont)
                        .foregroundColor(limiterBypassed ? DesignSystem.Colors.textMuted : DesignSystem.Colors.amber)
                    
                    Spacer()
                    
                    Button(action: {
                        limiterBypassed.toggle()
                        engine.setLimiterBypass(limiterBypassed)
                    }) {
                        Text(limiterBypassed ? "BYPASS" : "BRICKWALL")
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .foregroundColor(limiterBypassed ? DesignSystem.Colors.textMuted : .white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(limiterBypassed ? DesignSystem.Colors.bgElement : DesignSystem.Colors.amber)
                            .cornerRadius(3)
                    }
                    .buttonStyle(.plain)
                }
                
                // Limiter GR Meter
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("LIM GR")
                            .font(DesignSystem.Typography.labelFont)
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                        Spacer()
                        if limiterGR < -20.0 {
                            Text("OVER \(String(format: "%.1f", limiterGR)) dB")
                                .font(DesignSystem.Typography.readoutFont)
                                .foregroundColor(DesignSystem.Colors.meterClip)
                        } else {
                            Text(String(format: "%.1f dB", limiterGR))
                                .font(DesignSystem.Typography.readoutFont)
                                .foregroundColor(limiterGR < -0.1 ? DesignSystem.Colors.meterAmber : DesignSystem.Colors.textMuted)
                        }
                    }
                    
                    GainReductionBar(grDB: limiterGR, maxReductionDB: 20.0)
                        .frame(height: 6)
                }
                
                // Limiter Parameters
                VStack(spacing: 8) {
                    ParameterSlider(
                        label: "CEILING",
                        valueString: String(format: "%.1f dBFS", ceiling),
                        value: $ceiling,
                        range: -6.0...(-0.1),
                        onChange: { engine.setLimiterCeiling($0) }
                    )
                    
                    ParameterSlider(
                        label: "RELEASE",
                        valueString: String(format: "%.0f ms", limiterRelease),
                        value: $limiterRelease,
                        range: 1...500,
                        onChange: { engine.setLimiterRelease($0) }
                    )
                }
                
                // Hardware/DSP specs readout
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("LOOKAHEAD")
                            .font(DesignSystem.Typography.labelFont)
                            .foregroundColor(DesignSystem.Colors.textMuted)
                        Spacer()
                        Text("3.0 ms (144 smp)")
                            .font(DesignSystem.Typography.readoutFont)
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                    }
                    HStack {
                        Text("DETECTOR")
                            .font(DesignSystem.Typography.labelFont)
                            .foregroundColor(DesignSystem.Colors.textMuted)
                        Spacer()
                        Text("SHARED STEREO")
                            .font(DesignSystem.Typography.readoutFont)
                            .foregroundColor(DesignSystem.Colors.meterGreen)
                    }
                }
                .padding(.top, 4)
            }
            .frame(width: 240)
            .padding(12)
            .background(DesignSystem.Colors.bgPanel)
            .cornerRadius(DesignSystem.Layout.cornerRadius)
            .overlay(
                RoundedRectangle(cornerRadius: DesignSystem.Layout.cornerRadius)
                    .stroke(limiterBypassed ? DesignSystem.Colors.borderSubtle : DesignSystem.Colors.borderActive, lineWidth: 1)
            )
        }
        .onAppear {
            threshold = engine.getCompressorThreshold()
            ratio = engine.getCompressorRatio()
            attack = engine.getCompressorAttack()
            release = engine.getCompressorRelease()
            knee = engine.getCompressorKnee()
            makeupGain = engine.getCompressorMakeupGain()
            compBypassed = engine.getCompressorBypass()
            
            ceiling = engine.getLimiterCeiling()
            limiterRelease = engine.getLimiterRelease()
            limiterBypassed = engine.getLimiterBypass()
        }
    }
}

private struct ParameterSlider: View {
    let label: String
    let valueString: String
    @Binding var value: Float
    let range: ClosedRange<Float>
    let onChange: (Float) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(label)
                    .font(DesignSystem.Typography.labelFont)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
                Spacer()
                Text(valueString)
                    .font(DesignSystem.Typography.readoutFont)
                    .foregroundColor(DesignSystem.Colors.textPrimary)
            }
            Slider(value: $value, in: range)
                .accentColor(DesignSystem.Colors.amber)
                .onChange(of: value) { newValue in
                    onChange(newValue)
                }
        }
    }
}

/// Horizontal gain reduction LED meter with right-to-left reduction and over-range indication
private struct GainReductionBar: View {
    let grDB: Float             // <= 0
    let maxReductionDB: Float   // e.g. 30 dB
    
    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let reduction = max(0, -grDB)
            let norm = min(1.0, CGFloat(reduction / maxReductionDB))
            let barWidth = norm * width
            let isOverRange = reduction > maxReductionDB
            
            ZStack(alignment: .trailing) {
                // Background Track
                Rectangle()
                    .fill(DesignSystem.Colors.bgElement)
                    .frame(width: width)
                
                // Gain reduction active fill (grows from right to left)
                Rectangle()
                    .fill(
                        LinearGradient(
                            stops: [
                                .init(color: isOverRange ? DesignSystem.Colors.meterClip : DesignSystem.Colors.amber, location: 0.0),
                                .init(color: isOverRange ? DesignSystem.Colors.meterClip : DesignSystem.Colors.copper, location: 1.0)
                            ],
                            startPoint: .trailing,
                            endPoint: .leading
                        )
                    )
                    .frame(width: barWidth)
            }
            .clipShape(RoundedRectangle(cornerRadius: 2))
        }
    }
}
