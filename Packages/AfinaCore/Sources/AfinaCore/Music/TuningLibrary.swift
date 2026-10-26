/// Afinações personalizadas, agrupadas por instrumento (`Instrument.id`).
public struct TuningLibrary: Hashable, Codable, Sendable {
    public private(set) var customTunings: [String: [Tuning]] = [:]

    public init() {}

    /// Instrumentos pré-definidos com as afinações personalizadas no fim de cada um.
    public var instruments: [Instrument] {
        Instrument.builtIn.map { instrument in
            var merged = instrument
            merged.tunings += customTunings[instrument.id] ?? []
            return merged
        }
    }

    public func tunings(for instrumentID: String) -> [Tuning] {
        customTunings[instrumentID] ?? []
    }

    public mutating func add(_ tuning: Tuning, to instrumentID: String) {
        precondition(tuning.isCustom, "Só se guardam afinações personalizadas")
        customTunings[instrumentID, default: []].append(tuning)
    }

    /// Substitui a afinação com o mesmo `id` (nome e notas).
    public mutating func update(_ tuning: Tuning) {
        for (instrumentID, tunings) in customTunings {
            if let index = tunings.firstIndex(where: { $0.id == tuning.id }) {
                customTunings[instrumentID]?[index] = tuning
                return
            }
        }
    }

    public mutating func remove(tuningID: String) {
        for instrumentID in customTunings.keys {
            customTunings[instrumentID]?.removeAll { $0.id == tuningID }
            if customTunings[instrumentID]?.isEmpty == true { customTunings[instrumentID] = nil }
        }
    }
}
