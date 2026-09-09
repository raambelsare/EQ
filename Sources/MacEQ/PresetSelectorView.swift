import SwiftUI

/// Preset selection bar with instant switching and genre categorization
public struct PresetSelectorView: View {
    let engine: AudioEngine
    let onPresetSelected: (AudioPreset) -> Void
    @Binding var activePresetName: String
    
    private let presets = PresetManager.factoryPresets
    
    public init(engine: AudioEngine, activePresetName: Binding<String>, onPresetSelected: @escaping (AudioPreset) -> Void) {
        self.engine = engine
        self._activePresetName = activePresetName
        self.onPresetSelected = onPresetSelected
    }
    
    public var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(presets) { preset in
                    let isSelected = preset.name == activePresetName
                    Button(action: {
                        activePresetName = preset.name
                        engine.applyPreset(preset)
                        onPresetSelected(preset)
                    }) {
                        HStack(spacing: 6) {
                            Circle()
                                .fill(isSelected ? DesignSystem.Colors.amber : DesignSystem.Colors.borderActive)
                                .frame(width: 6, height: 6)
                            
                            VStack(alignment: .leading, spacing: 1) {
                                Text(preset.name)
                                    .font(.system(size: 11, weight: isSelected ? .bold : .medium))
                                    .foregroundColor(isSelected ? .white : DesignSystem.Colors.textSecondary)
                                Text(preset.category.uppercased())
                                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                                    .foregroundColor(isSelected ? DesignSystem.Colors.amber : DesignSystem.Colors.textMuted)
                            }
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(isSelected ? DesignSystem.Colors.bgElement : DesignSystem.Colors.bgPanel)
                        .cornerRadius(6)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(isSelected ? DesignSystem.Colors.amber.opacity(0.6) : DesignSystem.Colors.borderSubtle, lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 2)
        }
    }
}
