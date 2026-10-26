/// Corda de uma afinação escolhida como a mais próxima de uma frequência.
public struct StringMatch: Hashable, Sendable {
    /// Índice em `Tuning.notes`.
    public let index: Int
    public let note: Note
    /// Desvio da frequência em relação à nota da corda (sem limite a ±50).
    public let cents: Double
}

/// Afinação de um instrumento: a nota alvo de cada corda.
///
/// `notes` segue a ordem convencional de escrita da afinação (normalmente da corda mais grave
/// para a mais aguda; nas afinações reentrantes, como o ukulele, pela ordem física das cordas).
/// Para as afinações pré-definidas, `name` é a chave de localização em pt-PT.
public struct Tuning: Identifiable, Hashable, Codable, Sendable {
    public let id: String
    public var name: String
    public var notes: [Note]

    public init(id: String, name: String, notes: [Note]) {
        self.id = id
        self.name = name
        self.notes = notes
    }

    /// A mesma afinação com um capotraste na casa `fret` (0 = sem capotraste).
    public func withCapo(atFret fret: Int) -> Tuning {
        precondition(fret >= 0, "A casa do capotraste não pode ser negativa")
        var transposed = self
        transposed.notes = notes.map { $0.transposed(bySemitones: fret) }
        return transposed
    }

    /// Corda cuja nota alvo está mais perto (em cents) de `frequency`.
    public func nearestString(to frequency: Double, reference: ReferencePitch) -> StringMatch? {
        guard frequency.isFinite, frequency > 0 else { return nil }
        let matches = notes.enumerated().map { index, note in
            StringMatch(
                index: index,
                note: note,
                cents: Cents.between(frequency, and: reference.frequency(of: note))
            )
        }
        return matches.min { abs($0.cents) < abs($1.cents) }
    }
}
