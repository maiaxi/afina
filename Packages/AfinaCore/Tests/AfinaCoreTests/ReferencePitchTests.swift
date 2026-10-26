import Foundation
import Testing
@testable import AfinaCore

struct ReferencePitchTests {
    @Test func a440IsA4WithZeroCents() throws {
        let reading = try #require(ReferencePitch.standard.reading(forFrequency: 440))
        #expect(reading.note == Note(.a, octave: 4))
        #expect(abs(reading.cents) < 1e-9)
    }

    @Test func lowEIsE2WithinATenthOfACent() throws {
        let reading = try #require(ReferencePitch.standard.reading(forFrequency: 82.41))
        #expect(reading.note == Note(.e, octave: 2))
        #expect(abs(reading.cents) <= 0.1)
    }

    @Test func customReferenceA432() throws {
        let reference = ReferencePitch(a4: 432)
        let reading = try #require(reference.reading(forFrequency: 432))
        #expect(reading.note == Note(.a, octave: 4))
        #expect(abs(reading.cents) < 1e-9)
        #expect(abs(reference.frequency(of: Note(.a, octave: 3)) - 216) < 1e-9)
    }

    @Test func referenceIsClampedToAllowedRange() {
        #expect(ReferencePitch(a4: 400).a4 == 415)
        #expect(ReferencePitch(a4: 500).a4 == 466)
        #expect(ReferencePitch(a4: 442).a4 == 442)
    }

    @Test func decodingClampsOutOfRangeValues() throws {
        let data = Data(#"{"a4":1000}"#.utf8)
        let reference = try JSONDecoder().decode(ReferencePitch.self, from: data)
        #expect(reference.a4 == 466)
    }

    @Test func centsAreSignedAndRounded() throws {
        let reference = ReferencePitch.standard
        // 25 cents acima de A4
        let sharp = try #require(reference.reading(forFrequency: 440 * pow(2, 25.0 / 1200)))
        #expect(sharp.note == Note(.a, octave: 4))
        #expect(abs(sharp.cents - 25) < 1e-9)
        // 30 cents abaixo de A4 continua a ser A4
        let flat = try #require(reference.reading(forFrequency: 440 * pow(2, -30.0 / 1200)))
        #expect(flat.note == Note(.a, octave: 4))
        #expect(abs(flat.cents + 30) < 1e-9)
        // 60 cents acima de A4 já é A♯4 com -40
        let next = try #require(reference.reading(forFrequency: 440 * pow(2, 60.0 / 1200)))
        #expect(next.note == Note(.aSharp, octave: 4))
        #expect(abs(next.cents + 40) < 1e-9)
    }

    @Test(arguments: 0...127)
    func frequencyToMIDIRoundTrip(midiNumber: Int) throws {
        let reference = ReferencePitch(a4: 441)
        let note = Note(midiNumber: midiNumber)
        let reading = try #require(reference.reading(forFrequency: reference.frequency(of: note)))
        #expect(reading.note == note)
        #expect(abs(reading.cents) < 1e-6)
    }

    @Test(arguments: [0.0, -10, .nan, .infinity])
    func invalidFrequenciesHaveNoReading(frequency: Double) {
        #expect(ReferencePitch.standard.reading(forFrequency: frequency) == nil)
    }

    @Test func centsBetweenFrequencies() {
        #expect(abs(Cents.between(880, and: 440) - 1200) < 1e-9)
        #expect(abs(Cents.between(440, and: 880) + 1200) < 1e-9)
    }
}
