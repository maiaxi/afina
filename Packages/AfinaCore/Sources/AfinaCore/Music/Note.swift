/// Uma nota concreta (classe de altura + oitava), em notação científica: C4 = Dó central = MIDI 60.
public struct Note: Hashable, Codable, Sendable {
    public let midiNumber: Int

    public init(midiNumber: Int) {
        self.midiNumber = midiNumber
    }

    public init(_ pitchClass: PitchClass, octave: Int) {
        midiNumber = (octave + 1) * 12 + pitchClass.rawValue
    }

    public var pitchClass: PitchClass {
        // Sem força: o resultado de uma divisão euclidiana por 12 está sempre em 0..<12.
        PitchClass(rawValue: midiNumber.euclideanRemainder(12)) ?? .c
    }

    public var octave: Int {
        midiNumber.euclideanQuotient(12) - 1
    }

    public func transposed(bySemitones semitones: Int) -> Note {
        Note(midiNumber: midiNumber + semitones)
    }

    /// Nome com oitava, por exemplo "E2" ou "Mi2".
    public func name(in notation: NoteNotation) -> String {
        "\(pitchClass.name(in: notation))\(octave)"
    }
}

private extension Int {
    func euclideanQuotient(_ divisor: Int) -> Int {
        let quotient = self / divisor
        return self % divisor < 0 ? quotient - 1 : quotient
    }

    func euclideanRemainder(_ divisor: Int) -> Int {
        let remainder = self % divisor
        return remainder < 0 ? remainder + divisor : remainder
    }
}
