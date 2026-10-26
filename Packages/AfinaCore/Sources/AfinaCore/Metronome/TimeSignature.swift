/// Compasso. O metrónomo dá um clique por pulso (a unidade do denominador) e o BPM conta pulsos:
/// em 6/8, 180 BPM são 180 colcheias por minuto. `grouping` agrupa os pulsos em tempos
/// (6/8 = 3+3, 7/8 = 2+2+3), o que define onde caem os acentos secundários.
public struct TimeSignature: Hashable, Codable, Sendable, Identifiable {
    public let beats: Int
    public let noteValue: Int
    public let grouping: [Int]

    public init(beats: Int, noteValue: Int, grouping: [Int]? = nil) {
        let grouping = grouping ?? Array(repeating: 1, count: beats)
        precondition(grouping.reduce(0, +) == beats, "O agrupamento tem de somar o número de tempos")
        self.beats = beats
        self.noteValue = noteValue
        self.grouping = grouping
    }

    public var id: String { "\(beats)/\(noteValue)" }

    /// Se o pulso abre um grupo (recebe o som de tempo e não o de pulso fraco).
    public func isGroupStart(_ pulse: Int) -> Bool {
        var start = 0
        for size in grouping {
            if pulse == start { return true }
            start += size
        }
        return false
    }

    public static let twoFour = TimeSignature(beats: 2, noteValue: 4)
    public static let threeFour = TimeSignature(beats: 3, noteValue: 4)
    public static let fourFour = TimeSignature(beats: 4, noteValue: 4)
    public static let fiveFour = TimeSignature(beats: 5, noteValue: 4)
    public static let sixEight = TimeSignature(beats: 6, noteValue: 8, grouping: [3, 3])
    public static let sevenEight = TimeSignature(beats: 7, noteValue: 8, grouping: [2, 2, 3])
    public static let twelveEight = TimeSignature(beats: 12, noteValue: 8, grouping: [3, 3, 3, 3])

    public static let all: [TimeSignature] = [
        .twoFour, .threeFour, .fourFour, .fiveFour, .sixEight, .sevenEight, .twelveEight,
    ]
}

/// Cliques por pulso.
public enum Subdivision: Int, CaseIterable, Codable, Sendable {
    case none = 1
    case two = 2
    case three = 3
    case four = 4
}
