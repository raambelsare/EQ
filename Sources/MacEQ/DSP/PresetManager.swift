import Foundation

/// Audio Preset containing parameters across 10-Band EQ, Enhancers, 3D Spatializer, and Reverb
public struct AudioPreset: Identifiable, Codable, Equatable {
    public var id: String { name }
    public let name: String
    public let category: String
    
    // 10-Band EQ Gains in dB
    public var eqGains: [Float]
    
    // Enhancers
    public var bassBoostDB: Float
    public var midsBoostDB: Float
    public var trebleBoostDB: Float
    
    // Spatial 3D
    public var spatialWidth: Float      // 1.0 = normal, 1.5 = wide
    public var crossfeed: Float         // 0.0 = off, 1.0 = full
    
    // Reverb
    public var reverbEnabled: Bool
    public var reverbRoomSize: Float
    public var reverbWet: Float
    
    public init(
        name: String,
        category: String,
        eqGains: [Float],
        bassBoostDB: Float = 0.0,
        midsBoostDB: Float = 0.0,
        trebleBoostDB: Float = 0.0,
        spatialWidth: Float = 1.0,
        crossfeed: Float = 0.0,
        reverbEnabled: Bool = false,
        reverbRoomSize: Float = 0.5,
        reverbWet: Float = 0.25
    ) {
        self.name = name
        self.category = category
        self.eqGains = eqGains
        self.bassBoostDB = bassBoostDB
        self.midsBoostDB = midsBoostDB
        self.trebleBoostDB = trebleBoostDB
        self.spatialWidth = spatialWidth
        self.crossfeed = crossfeed
        self.reverbEnabled = reverbEnabled
        self.reverbRoomSize = reverbRoomSize
        self.reverbWet = reverbWet
    }
}

/// Factory Presets and Custom Preset Store
public final class PresetManager {
    public static let shared = PresetManager()
    
    public static let factoryPresets: [AudioPreset] = [
        AudioPreset(
            name: "Flat / Reference",
            category: "Standard",
            eqGains: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
        ),
        AudioPreset(
            name: "Bass Heavy / EDM",
            category: "Electronic",
            eqGains: [5.5, 4.5, 3.0, 1.0, 0.0, 0.5, 1.5, 2.5, 3.5, 4.0],
            bassBoostDB: 6.0,
            midsBoostDB: 1.0,
            trebleBoostDB: 3.0,
            spatialWidth: 1.35
        ),
        AudioPreset(
            name: "Vocal & Podcast",
            category: "Speech & Pop",
            eqGains: [-3.0, -2.0, -1.0, 1.0, 2.5, 4.0, 3.5, 2.0, 0.5, -1.0],
            bassBoostDB: 0.0,
            midsBoostDB: 4.5,
            trebleBoostDB: 2.0,
            spatialWidth: 1.05
        ),
        AudioPreset(
            name: "Rock & Metal",
            category: "Rock",
            eqGains: [4.0, 3.0, 1.5, -1.0, -2.0, 1.0, 3.0, 4.0, 4.5, 5.0],
            bassBoostDB: 3.5,
            midsBoostDB: 1.5,
            trebleBoostDB: 4.0,
            spatialWidth: 1.25
        ),
        AudioPreset(
            name: "Acoustic & Jazz",
            category: "Acoustic",
            eqGains: [2.0, 1.5, 1.0, 0.5, 1.0, 1.5, 2.0, 2.5, 3.0, 3.5],
            bassBoostDB: 1.5,
            midsBoostDB: 2.0,
            trebleBoostDB: 3.0,
            spatialWidth: 1.3,
            reverbEnabled: true,
            reverbRoomSize: 0.35,
            reverbWet: 0.15
        ),
        AudioPreset(
            name: "Immersive 3D Cinema",
            category: "Movies",
            eqGains: [4.5, 3.5, 1.0, 0.0, 0.5, 1.0, 2.0, 3.0, 4.0, 5.0],
            bassBoostDB: 5.0,
            midsBoostDB: 2.5,
            trebleBoostDB: 4.0,
            spatialWidth: 1.8,
            crossfeed: 0.4,
            reverbEnabled: true,
            reverbRoomSize: 0.7,
            reverbWet: 0.3
        ),
        AudioPreset(
            name: "Late Night Lounge",
            category: "Chill",
            eqGains: [-2.0, -1.0, 0.5, 1.5, 2.0, 1.5, 0.5, -1.0, -2.0, -3.0],
            bassBoostDB: 2.0,
            midsBoostDB: 1.0,
            trebleBoostDB: 0.0,
            spatialWidth: 1.2,
            reverbEnabled: true,
            reverbRoomSize: 0.55,
            reverbWet: 0.22
        )
    ]
}
