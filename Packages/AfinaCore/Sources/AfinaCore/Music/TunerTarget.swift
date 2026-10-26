public enum TunerMode: String, CaseIterable, Codable, Sendable {
    /// Mostra a nota temperada mais próxima.
    case chromatic
    /// Mostra a corda mais próxima da afinação escolhida.
    case instrument
}

/// O que o afinador mostra: a nota alvo e o desvio em relação a ela.
public struct TunerTarget: Hashable, Sendable {
    public let note: Note
    /// No modo cromático fica em ±(50 + histerese); no modo instrumento pode ser maior
    /// (corda muito desafinada).
    public let cents: Double
    /// Índice da corda em `Tuning.notes` no modo instrumento.
    public let stringIndex: Int?

    public init(note: Note, cents: Double, stringIndex: Int?) {
        self.note = note
        self.cents = cents
        self.stringIndex = stringIndex
    }

    /// `tuning` já deve incluir o capotraste.
    public init?(reading: PitchReading?, mode: TunerMode, tuning: Tuning, reference: ReferencePitch) {
        guard let reading else { return nil }
        switch mode {
        case .chromatic:
            self.init(note: reading.note, cents: reading.cents, stringIndex: nil)
        case .instrument:
            guard let match = tuning.nearestString(to: reading.frequency, reference: reference) else { return nil }
            self.init(note: match.note, cents: match.cents, stringIndex: match.index)
        }
    }

    public func isInTune(tolerance: Double) -> Bool {
        abs(cents) <= tolerance
    }
}

/// Cordas já afinadas numa sessão do modo instrumento. Uma corda fica marcada depois de
/// `requiredCount` leituras seguidas dentro da tolerância, e desmarcada depois de outras tantas
/// a mais do dobro da tolerância (entre os dois limites não muda nada).
public struct TuningProgress: Hashable, Sendable {
    private enum Zone {
        case inTune, between, outOfTune
    }

    public let requiredCount: Int
    public private(set) var tunedStrings: Set<Int> = []

    private var streakString: Int?
    private var streakZone = Zone.between
    private var streakLength = 0

    public init(requiredCount: Int = 10) {
        self.requiredCount = requiredCount
    }

    public mutating func update(with target: TunerTarget?, tolerance: Double) {
        guard let target, let index = target.stringIndex else {
            streakString = nil
            streakLength = 0
            return
        }

        let zone: Zone = if target.isInTune(tolerance: tolerance) {
            .inTune
        } else if abs(target.cents) > 2 * tolerance {
            .outOfTune
        } else {
            .between
        }

        if streakString == index, streakZone == zone {
            streakLength += 1
        } else {
            streakString = index
            streakZone = zone
            streakLength = 1
        }

        guard streakLength >= requiredCount else { return }
        switch zone {
        case .inTune: tunedStrings.insert(index)
        case .outOfTune: tunedStrings.remove(index)
        case .between: break
        }
    }

    public mutating func reset() {
        self = TuningProgress(requiredCount: requiredCount)
    }
}
