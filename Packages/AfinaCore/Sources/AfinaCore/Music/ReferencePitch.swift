import Foundation

/// Distâncias em cents (1/100 de meio-tom temperado).
public enum Cents {
    /// Cents de `frequency` em relação a `reference`. Positivo se `frequency` for mais aguda.
    public static func between(_ frequency: Double, and reference: Double) -> Double {
        1200 * log2(frequency / reference)
    }
}

/// Resultado de mapear uma frequência para a nota temperada mais próxima.
public struct PitchReading: Hashable, Sendable {
    public let frequency: Double
    public let note: Note
    /// Desvio em relação à nota, em [-50, 50].
    public let cents: Double
}

/// Lá de referência (A4) usado nas conversões entre frequência e nota.
public struct ReferencePitch: Hashable, Codable, Sendable {
    public static let allowedRange: ClosedRange<Double> = 415...466
    public static let standard = ReferencePitch(a4: 440)

    private static let a4MIDINumber = 69.0

    public let a4: Double

    /// Valores fora de `allowedRange` são limitados ao extremo mais próximo.
    public init(a4: Double) {
        self.a4 = a4.clamped(to: Self.allowedRange)
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(a4: try container.decode(Double.self, forKey: .a4))
    }

    public func frequency(ofMIDINumber midiNumber: Double) -> Double {
        a4 * pow(2, (midiNumber - Self.a4MIDINumber) / 12)
    }

    public func frequency(of note: Note) -> Double {
        frequency(ofMIDINumber: Double(note.midiNumber))
    }

    /// Número MIDI fracionário da frequência, ou `nil` se a frequência não for positiva e finita.
    public func midiNumber(forFrequency frequency: Double) -> Double? {
        guard frequency.isFinite, frequency > 0 else { return nil }
        return Self.a4MIDINumber + 12 * log2(frequency / a4)
    }

    public func reading(forFrequency frequency: Double) -> PitchReading? {
        guard let midiNumber = midiNumber(forFrequency: frequency) else { return nil }
        let nearest = midiNumber.rounded()
        return PitchReading(
            frequency: frequency,
            note: Note(midiNumber: Int(nearest)),
            cents: (midiNumber - nearest) * 100
        )
    }
}

private extension Double {
    func clamped(to range: ClosedRange<Double>) -> Double {
        Swift.min(Swift.max(self, range.lowerBound), range.upperBound)
    }
}
