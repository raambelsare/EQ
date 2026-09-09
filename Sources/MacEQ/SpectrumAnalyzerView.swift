import SwiftUI

/// 60 FPS Canvas-based Real-Time Spectrum Analyzer with Logarithmic Frequency Scale & dB Grids.
public struct SpectrumAnalyzerView: View {
    let spectrum: [Float] // Array of dBFS values (-90 to +12)
    
    // Frequency grid markers (Hz)
    private let gridFrequencies: [Float] = [50, 100, 250, 500, 1000, 2000, 5000, 10000, 20000]
    private let minFreq: Float = 20.0
    private let maxFreq: Float = 20000.0
    
    // dB grid markers
    private let dbMarkers: [Float] = [6, 0, -6, -12, -24, -48, -72]
    private let minDB: Float = -80.0
    private let maxDB: Float = 12.0
    
    public init(spectrum: [Float]) {
        self.spectrum = spectrum
    }
    
    public var body: some View {
        Canvas { context, size in
            let width = size.width
            let height = size.height
            
            // 1. Draw Background Grid (Logarithmic Frequency Lines)
            for freq in gridFrequencies {
                let x = xForFreq(freq, width: width)
                var path = Path()
                path.move(to: CGPoint(x: x, y: 0))
                path.addLine(to: CGPoint(x: x, y: height))
                context.stroke(path, with: .color(DesignSystem.Colors.gridLine), lineWidth: 1)
                
                // Frequency label
                let text = Text(freqLabel(freq))
                    .font(DesignSystem.Typography.labelFont)
                    .foregroundColor(DesignSystem.Colors.textMuted)
                context.draw(text, at: CGPoint(x: x + 2, y: height - 10), anchor: .bottomLeading)
            }
            
            // 2. Draw dB Amplitude Horizontal Lines
            for db in dbMarkers {
                let y = yForDB(db, height: height)
                var path = Path()
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: width, y: y))
                let isZero = abs(db) < 0.1
                context.stroke(
                    path,
                    with: .color(isZero ? DesignSystem.Colors.borderActive : DesignSystem.Colors.gridLine),
                    lineWidth: isZero ? 1.5 : 1
                )
                
                // dB label
                let text = Text(String(format: "%+.0f dB", db))
                    .font(DesignSystem.Typography.labelFont)
                    .foregroundColor(DesignSystem.Colors.textMuted)
                context.draw(text, at: CGPoint(x: 6, y: y - 2), anchor: .bottomLeading)
            }
            
            // 3. Draw FFT Spectrum Curve & Gradient Fill
            guard spectrum.count > 1 else { return }
            
            var curvePath = Path()
            var fillPath = Path()
            
            let count = spectrum.count
            let firstX: CGFloat = 0
            let firstY = yForDB(spectrum[0], height: height)
            
            curvePath.move(to: CGPoint(x: firstX, y: firstY))
            fillPath.move(to: CGPoint(x: firstX, y: height))
            fillPath.addLine(to: CGPoint(x: firstX, y: firstY))
            
            for i in 1..<count {
                let x = CGFloat(i) / CGFloat(count - 1) * width
                let y = yForDB(spectrum[i], height: height)
                
                // Smooth cubic bezier or line segment
                curvePath.addLine(to: CGPoint(x: x, y: y))
                fillPath.addLine(to: CGPoint(x: x, y: y))
            }
            
            fillPath.addLine(to: CGPoint(x: width, y: height))
            fillPath.closeSubpath()
            
            // Subtle amber glow fill beneath spectrum
            context.fill(
                fillPath,
                with: .linearGradient(
                    Gradient(colors: [
                        DesignSystem.Colors.amber.opacity(0.35),
                        DesignSystem.Colors.amber.opacity(0.08),
                        Color.clear
                    ]),
                    startPoint: CGPoint(x: 0, y: 0),
                    endPoint: CGPoint(x: 0, y: height)
                )
            )
            
            // Spectrum Neon Trace
            context.stroke(
                curvePath,
                with: .color(DesignSystem.Colors.amber),
                style: StrokeStyle(lineWidth: 2.0, lineCap: .round, lineJoin: .round)
            )
        }
        .background(DesignSystem.Colors.bgDeep)
        .cornerRadius(DesignSystem.Layout.cornerRadius)
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.Layout.cornerRadius)
                .stroke(DesignSystem.Colors.borderSubtle, lineWidth: 1)
        )
    }
    
    private func xForFreq(_ freq: Float, width: CGFloat) -> CGFloat {
        let logMin = log10(minFreq)
        let logMax = log10(maxFreq)
        let logVal = log10(max(minFreq, min(maxFreq, freq)))
        let norm = (logVal - logMin) / (logMax - logMin)
        return CGFloat(norm) * width
    }
    
    private func yForDB(_ db: Float, height: CGFloat) -> CGFloat {
        let clamped = max(minDB, min(maxDB, db))
        let norm = (clamped - minDB) / (maxDB - minDB)
        return height * (1.0 - CGFloat(norm))
    }
    
    private func freqLabel(_ freq: Float) -> String {
        if freq >= 1000 {
            return String(format: "%.0fk", freq / 1000.0)
        }
        return String(format: "%.0f", freq)
    }
}
