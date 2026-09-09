import SwiftUI

/// 10-Band Graphic/Parametric EQ Console with interactive vertical faders, dB readouts, and zero-reset buttons
public struct MultiBandEQView: View {
    let engine: AudioEngine
    @Binding var gains: [Float]
    
    // Labels for the 10 ISO bands
    private let bandLabels = ["32Hz", "64Hz", "125Hz", "250Hz", "500Hz", "1kHz", "2kHz", "4kHz", "8kHz", "16kHz"]
    
    public init(engine: AudioEngine, gains: Binding<[Float]>) {
        self.engine = engine
        self._gains = gains
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "slider.vertical.3")
                        .foregroundColor(DesignSystem.Colors.amber)
                    Text("10-BAND EQUALIZER")
                        .font(DesignSystem.Typography.headerFont)
                        .foregroundColor(DesignSystem.Colors.copper)
                }
                
                Spacer()
                
                Button(action: {
                    for i in 0..<gains.count {
                        gains[i] = 0.0
                        engine.setBandGain(index: i, gainDB: 0.0)
                    }
                }) {
                    Text("FLAT RESET")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundColor(DesignSystem.Colors.textMuted)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(DesignSystem.Colors.bgElement)
                        .cornerRadius(3)
                }
                .buttonStyle(.plain)
            }
            
            // 10 Vertical Faders Grid
            HStack(spacing: 8) {
                ForEach(0..<min(gains.count, bandLabels.count), id: \.self) { i in
                    VStack(spacing: 4) {
                        // Value label (+/- dB)
                        Text(String(format: "%+.1f", gains[i]))
                            .font(.system(size: 8.5, weight: .medium, design: .monospaced))
                            .foregroundColor(abs(gains[i]) > 0.1 ? DesignSystem.Colors.amber : DesignSystem.Colors.textMuted)
                            .frame(height: 12)
                        
                        // Vertical Slider Track
                        VerticalSlider(value: $gains[i], range: -12.0...12.0) { newVal in
                            engine.setBandGain(index: i, gainDB: newVal)
                        }
                        .frame(height: 110)
                        
                        // Frequency Label
                        Text(bandLabels[i])
                            .font(.system(size: 8.5, weight: .semibold, design: .monospaced))
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .padding(.vertical, 6)
        }
        .padding(12)
        .background(DesignSystem.Colors.bgPanel)
        .cornerRadius(DesignSystem.Layout.cornerRadius)
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.Layout.cornerRadius)
                .stroke(DesignSystem.Colors.borderSubtle, lineWidth: 1)
        )
    }
}

/// Custom Vertical Slider for tactile, hardware-style faders
private struct VerticalSlider: View {
    @Binding var value: Float
    let range: ClosedRange<Float>
    let onChange: (Float) -> Void
    
    var body: some View {
        GeometryReader { geo in
            let height = geo.size.height
            let width = geo.size.width
            let norm = CGFloat((value - range.lowerBound) / (range.upperBound - range.lowerBound))
            let thumbY = height * (1.0 - norm)
            
            ZStack(alignment: .top) {
                // Background Track
                RoundedRectangle(cornerRadius: 2)
                    .fill(DesignSystem.Colors.bgElement)
                    .frame(width: 4, height: height)
                    .position(x: width / 2, y: height / 2)
                
                // Center Zero Marker Tick
                Rectangle()
                    .fill(DesignSystem.Colors.borderActive)
                    .frame(width: 10, height: 1)
                    .position(x: width / 2, y: height / 2)
                
                // Active Fill
                let midY = height / 2
                let fillHeight = abs(thumbY - midY)
                let fillTop = min(thumbY, midY)
                
                RoundedRectangle(cornerRadius: 2)
                    .fill(abs(value) > 0.1 ? DesignSystem.Colors.amber.opacity(0.8) : Color.clear)
                    .frame(width: 4, height: fillHeight)
                    .position(x: width / 2, y: fillTop + fillHeight / 2)
                
                // Fader Cap / Thumb
                RoundedRectangle(cornerRadius: 3)
                    .fill(
                        LinearGradient(
                            colors: [Color(white: 0.35), Color(white: 0.20)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: 20, height: 10)
                    .overlay(
                        RoundedRectangle(cornerRadius: 3)
                            .stroke(DesignSystem.Colors.borderActive, lineWidth: 0.8)
                    )
                    .overlay(
                        Rectangle()
                            .fill(abs(value) > 0.1 ? DesignSystem.Colors.amber : DesignSystem.Colors.textMuted)
                            .frame(width: 14, height: 1.5)
                    )
                    .position(x: width / 2, y: thumbY)
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { gesture in
                        let locationY = max(0, min(height, gesture.location.y))
                        let invertedNorm = Float(1.0 - (locationY / height))
                        let newVal = range.lowerBound + (invertedNorm * (range.upperBound - range.lowerBound))
                        
                        // Snap to 0 dB near center
                        let finalVal = abs(newVal) < 0.4 ? 0.0 : newVal
                        value = finalVal
                        onChange(finalVal)
                    }
            )
        }
    }
}
