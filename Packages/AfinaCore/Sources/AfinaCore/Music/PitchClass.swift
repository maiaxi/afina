/// Notação usada para mostrar os nomes das notas.
public enum NoteNotation: String, CaseIterable, Codable, Sendable {
    /// Dó, Ré, Mi, Fá, Sol, Lá, Si
    case latin
    /// C, D, E, F, G, A, B
    case english
}

/// Uma das 12 classes de altura do sistema temperado, independente da oitava.
///
/// As alterações escrevem-se sempre com sustenido.
public enum PitchClass: Int, CaseIterable, Codable, Sendable {
    case c, cSharp, d, dSharp, e, f, fSharp, g, gSharp, a, aSharp, b

    public func name(in notation: NoteNotation) -> String {
        let names = switch notation {
        case .latin: Self.latinNames
        case .english: Self.englishNames
        }
        return names[rawValue]
    }

    private static let latinNames = ["Dó", "Dó♯", "Ré", "Ré♯", "Mi", "Fá", "Fá♯", "Sol", "Sol♯", "Lá", "Lá♯", "Si"]
    private static let englishNames = ["C", "C♯", "D", "D♯", "E", "F", "F♯", "G", "G♯", "A", "A♯", "B"]
}
