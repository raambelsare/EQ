import SwiftUI

/// Stereo Peak & RMS Meter with sticky clip indicators and precision dBFS calibration.
public struct MeterView: View {
    let values: AudioMeter.MeterValues
    let onResetClip: () -> Void
    
    // Scale: -60 dBFS to 0 dBFS
    private let minDB: Float = -60.0
    private let maxDB: Float = 0.0
    
    public init(values: AudioMeter.MeterValues, onResetClip: @escaping () -> Void = {}) {
        self.values = values
        self.onResetClip = onResetClip
    }
    
    public var body: some View {
        VStack(spacing: 6) {
            // Clip indicators
            HStack(spacing: 8) {
                ClipBadge(channel: "L", isClipping: values.isClippingLeft, onTap: onResetClip)
                ClipBadge(channel: "R", isClipping: values.isClippingRight, onTap: onResetClip)
            }
            
            // Dual vertical bars
            HStack(spacing: 6) {
                MeterBar(peakDB: values.peakLeft, rmsDB: values.rmsLeft, peakHoldDB: values.peakHoldLeft)
                MeterBar(peakDB: values.peakRight, rmsDB: values.rmsRight, peakHoldDB: values.peakHoldRight)
            }
            .frame(width: 32)
            
            // Numerical readouts
            VStack(spacing: 2) {
                Text(formatDB(values.peakLeft))
                    .font(DesignSystem.Typography.readoutFont)
                    .foregroundColor(values.isClippingLeft ? DesignSystem.Colors.meterClip : DesignSystem.Colors.textSecondary)
                Text(formatDB(values.peakRight))
                    .font(DesignSystem.Typography.readoutFont)
                    .foregroundColor(values.isClippingRight ? DesignSystem.Colors.meterClip : DesignSystem.Colors.textSecondary)
            }
        }
        .padding(8)
        .background(DesignSystem.Colors.bgPanel)
        .cornerRadius(DesignSystem.Layout.cornerRadius)
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.Layout.cornerRadius)
                .stroke(DesignSystem.Colors.borderSubtle, lineWidth: 1)
        )
    }
    
    private func formatDB(_ db: Float) -> String {
        if db <= -59.5 { return "-∞ dB" }
        return String(format: "%+.1f", db)
    }
}

private struct ClipBadge: View {
    let channel: String
    let isClipping: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            Text(channel)
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundColor(isClipping ? .white : DesignSystem.Colors.textMuted)
                .frame(width: 14, height: 14)
                .background(isClipping ? DesignSystem.Colors.meterClip : DesignSystem.Colors.bgElement)
                .cornerRadius(2)
        }
        .buttonStyle(.plain)
    }
}

private struct MeterBar: View {
    let peakDB: Float
    let rmsDB: Float
    let peakHoldDB: Float
    
    private let minDB: Float = -60.0
    private let maxDB: Float = 0.0
    
    var body: some View {
        GeometryReader { geo in
            let height = geo.size.height
            let width = geo.size.width
            
            let peakY = normalize(peakDB) * height
            let rmsY = normalize(rmsDB) * height
            let holdY = normalize(peakHoldDB) * height
            
            ZStack(alignment: .bottom) {
                // Background track
                Rectangle()
                    .fill(DesignSystem.Colors.bgElement)
                    .frame(width: width)
                
                // Peak fill with multi-stop precision gradient
                Rectangle()
                    .fill(
                        LinearGradient(
                            stops: [
                                .init(color: DesignSystem.Colors.meterGreen, location: 0.0),
                                .init(color: DesignSystem.Colors.meterGreen, location: 0.70),  // up to -18 dBFS
                                .init(color: DesignSystem.Colors.meterYellow, location: 0.85), // -6 dBFS
                                .init(color: DesignSystem.Colors.meterAmber, location: 0.95),  // -3 dBFS
                                .init(color: DesignSystem.Colors.meterClip, location: 1.0)     // 0 dBFS
                            ],
                            startPoint: .bottom,
                            endPoint: .top
                        )
                    )
                    .frame(width: width, height: max(0, peakY))
                
                // RMS inner bar (narrower, slightly dimmer/solid for visual depth)
                Rectangle()
                    .fill(Color.white.opacity(0.45))
                    .frame(width: width * 0.45, height: max(0, rmsY))
                
                // Peak Hold Line
                if holdY > 2 {
                    Rectangle()
                        .fill(Color.white)
                        .frame(width: width, height: 1.5)
                        .offset(y: -holdY)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 2))
        }
    }
    
    private func normalize(_ db: Float) -> CGFloat {
        let clamped = max(minDB, min(maxDB, db))
        return CGFloat((clamped - minDB) / (maxDB - minDB))
    }
}
