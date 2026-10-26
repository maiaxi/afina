/// Som de um pulso do compasso.
public enum PulseSound: Int, CaseIterable, Codable, Sendable {
    case accent
    case beat
    case weakBeat
    case silent

    /// O som seguinte no ciclo usado pela UI (acento → tempo → fraco → silêncio → acento).
    public var next: PulseSound {
        PulseSound(rawValue: (rawValue + 1) % PulseSound.allCases.count) ?? .accent
    }

    var clickKind: ClickKind? {
        switch self {
        case .accent: .accent
        case .beat: .beat
        case .weakBeat: .weakBeat
        case .silent: nil
        }
    }
}

/// Som de cada pulso de um compasso.
///
/// Para chegar ao thread de áudio num só atómico, codifica-se em `UInt64` com 2 bits por pulso
/// (até 32 pulsos; o maior compasso suportado tem 12).
public struct BeatPattern: Hashable, Codable, Sendable {
    public private(set) var sounds: [PulseSound]

    public init(sounds: [PulseSound]) {
        precondition(sounds.count <= Self.maximumPulses, "Demasiados pulsos")
        self.sounds = sounds
    }

    /// Acento no primeiro pulso, tempo no início de cada grupo e fraco nos restantes.
    public init(defaultFor signature: TimeSignature) {
        self.init(sounds: (0..<signature.beats).map { pulse in
            pulse == 0 ? .accent : signature.isGroupStart(pulse) ? .beat : .weakBeat
        })
    }

    public subscript(pulse: Int) -> PulseSound {
        get { sounds[pulse] }
        set { sounds[pulse] = newValue }
    }

    // MARK: Codificação para o thread de áudio

    static let maximumPulses = 32

    var packed: UInt64 {
        sounds.enumerated().reduce(0) { result, element in
            result | UInt64(element.element.rawValue) << (2 * UInt64(element.offset))
        }
    }

    /// Som do pulso `pulse` num padrão codificado. Não aloca: seguro no thread de áudio.
    static func sound(atPulse pulse: Int, in packed: UInt64) -> PulseSound {
        PulseSound(rawValue: Int((packed >> (2 * UInt64(pulse))) & 0b11)) ?? .silent
    }
}
