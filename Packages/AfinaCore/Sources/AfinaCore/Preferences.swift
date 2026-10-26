// Escolhas do utilizador que persistem entre arranques. A descodificação tolera campos em falta
// (versões antigas) usando os valores por defeito, para nunca se perder tudo por um campo novo.

public struct TunerPreferences: Hashable, Codable, Sendable {
    public var mode = TunerMode.instrument
    public var instrumentID = Instrument.guitar.id
    public var tuningID = Instrument.guitar.tunings[0].id
    public var capo = 0
    public var referenceA4 = 440.0
    /// Desvio máximo, em cents, para considerar a nota afinada.
    public var tolerance = 3.0
    public var notation = NoteNotation.english
    /// `nil` segue a entrada por defeito do sistema.
    public var inputDeviceUID: String?
    public var gateThresholdDecibels: Float = -55
    public var library = TuningLibrary()

    public static let toleranceRange: ClosedRange<Double> = 1...10
    public static let gateThresholdRange: ClosedRange<Float> = -80 ... -30

    public init() {}

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let defaults = TunerPreferences()
        mode = try container.decodeIfPresent(TunerMode.self, forKey: .mode) ?? defaults.mode
        instrumentID = try container.decodeIfPresent(String.self, forKey: .instrumentID) ?? defaults.instrumentID
        tuningID = try container.decodeIfPresent(String.self, forKey: .tuningID) ?? defaults.tuningID
        capo = try container.decodeIfPresent(Int.self, forKey: .capo) ?? defaults.capo
        referenceA4 = try container.decodeIfPresent(Double.self, forKey: .referenceA4) ?? defaults.referenceA4
        tolerance = try container.decodeIfPresent(Double.self, forKey: .tolerance) ?? defaults.tolerance
        notation = try container.decodeIfPresent(NoteNotation.self, forKey: .notation) ?? defaults.notation
        inputDeviceUID = try container.decodeIfPresent(String.self, forKey: .inputDeviceUID)
        gateThresholdDecibels = try container.decodeIfPresent(Float.self, forKey: .gateThresholdDecibels)
            ?? defaults.gateThresholdDecibels
        library = try container.decodeIfPresent(TuningLibrary.self, forKey: .library) ?? defaults.library
    }
}

public struct MetronomePreferences: Hashable, Codable, Sendable {
    public var bpm = 120.0
    public var timeSignatureID = TimeSignature.fourFour.id
    public var subdivision = Subdivision.none
    public var volume: Float = 0.8
    public var clickSound = ClickSound.beep
    public var beatPatterns: [String: BeatPattern] = [:]

    public init() {}

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let defaults = MetronomePreferences()
        bpm = try container.decodeIfPresent(Double.self, forKey: .bpm) ?? defaults.bpm
        timeSignatureID = try container.decodeIfPresent(String.self, forKey: .timeSignatureID) ?? defaults.timeSignatureID
        subdivision = try container.decodeIfPresent(Subdivision.self, forKey: .subdivision) ?? defaults.subdivision
        volume = try container.decodeIfPresent(Float.self, forKey: .volume) ?? defaults.volume
        clickSound = try container.decodeIfPresent(ClickSound.self, forKey: .clickSound) ?? defaults.clickSound
        beatPatterns = try container.decodeIfPresent([String: BeatPattern].self, forKey: .beatPatterns)
            ?? defaults.beatPatterns
    }
}

extension MetronomeEngine {
    public var preferences: MetronomePreferences {
        var preferences = MetronomePreferences()
        preferences.bpm = bpm
        preferences.timeSignatureID = timeSignature.id
        preferences.subdivision = subdivision
        preferences.volume = volume
        preferences.clickSound = clickSound
        preferences.beatPatterns = customBeatPatterns
        return preferences
    }

    public func apply(_ preferences: MetronomePreferences) {
        bpm = preferences.bpm
        timeSignature = TimeSignature.all.first { $0.id == preferences.timeSignatureID } ?? .fourFour
        subdivision = preferences.subdivision
        volume = preferences.volume
        clickSound = preferences.clickSound
        customBeatPatterns = preferences.beatPatterns
    }
}
