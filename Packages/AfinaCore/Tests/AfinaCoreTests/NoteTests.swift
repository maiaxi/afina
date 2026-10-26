import Testing
@testable import AfinaCore

struct NoteTests {
    @Test func middleCIsMIDI60() {
        let note = Note(.c, octave: 4)
        #expect(note.midiNumber == 60)
        #expect(note.pitchClass == .c)
        #expect(note.octave == 4)
    }

    @Test(arguments: [
        (21, PitchClass.a, 0),
        (40, PitchClass.e, 2),
        (69, PitchClass.a, 4),
        (71, PitchClass.b, 4),
        (72, PitchClass.c, 5),
        (12, PitchClass.c, 0),
        (11, PitchClass.b, -1),
    ])
    func midiNumberMapsToPitchClassAndOctave(midiNumber: Int, pitchClass: PitchClass, octave: Int) {
        let note = Note(midiNumber: midiNumber)
        #expect(note.pitchClass == pitchClass)
        #expect(note.octave == octave)
        #expect(Note(pitchClass, octave: octave) == note)
    }

    @Test func namesInBothNotations() {
        let note = Note(.fSharp, octave: 3)
        #expect(note.name(in: .english) == "F♯3")
        #expect(note.name(in: .latin) == "Fá♯3")
        #expect(PitchClass.c.name(in: .latin) == "Dó")
        #expect(PitchClass.d.name(in: .latin) == "Ré")
        #expect(PitchClass.a.name(in: .latin) == "Lá")
        #expect(PitchClass.b.name(in: .english) == "B")
    }

    @Test func transposition() {
        #expect(Note(.e, octave: 2).transposed(bySemitones: 2) == Note(.fSharp, octave: 2))
        #expect(Note(.b, octave: 3).transposed(bySemitones: 1) == Note(.c, octave: 4))
        #expect(Note(.c, octave: 4).transposed(bySemitones: -1) == Note(.b, octave: 3))
    }
}
