import Foundation
import Testing
@testable import AfinaCore

struct TuningTests {
    @Test func guitarStandardIsEADGBE() throws {
        let standard = try #require(Instrument.guitar.tunings.first)
        #expect(standard.notes == [
            Note(.e, octave: 2), Note(.a, octave: 2), Note(.d, octave: 3),
            Note(.g, octave: 3), Note(.b, octave: 3), Note(.e, octave: 4),
        ])
    }

    @Test func builtInTuningsHaveExpectedStringCounts() {
        let expected = ["guitar": 6, "bass4": 4, "bass5": 5, "ukulele": 4, "cavaquinho": 4, "portugueseGuitar": 6]
        for instrument in Instrument.builtIn {
            for tuning in instrument.tunings {
                #expect(tuning.notes.count == expected[instrument.id], "\(tuning.id)")
            }
        }
    }

    @Test func identifiersAreUnique() {
        let instrumentIDs = Instrument.builtIn.map(\.id)
        #expect(Set(instrumentIDs).count == instrumentIDs.count)
        let tuningIDs = Instrument.builtIn.flatMap(\.tunings).map(\.id)
        #expect(Set(tuningIDs).count == tuningIDs.count)
    }

    @Test func builtInNotesStayWithinTunerRange() {
        let reference = ReferencePitch.standard
        for tuning in Instrument.builtIn.flatMap(\.tunings) {
            for note in tuning.notes {
                let frequency = reference.frequency(of: note)
                #expect((30...1500).contains(frequency), "\(tuning.id) \(note.name(in: .english))")
            }
        }
    }

    @Test func instrumentsRoundTripThroughJSON() throws {
        let data = try JSONEncoder().encode(Instrument.builtIn)
        let decoded = try JSONDecoder().decode([Instrument].self, from: data)
        #expect(decoded == Instrument.builtIn)
    }

    @Test func capoTransposesEveryString() throws {
        let standard = try #require(Instrument.guitar.tunings.first)
        let capo2 = standard.withCapo(atFret: 2)
        #expect(capo2.notes == standard.notes.map { $0.transposed(bySemitones: 2) })
        #expect(capo2.notes.first == Note(.fSharp, octave: 2))
        #expect(standard.withCapo(atFret: 0) == standard)
    }

    @Test func nearestStringPicksClosestTarget() throws {
        let standard = try #require(Instrument.guitar.tunings.first)
        let reference = ReferencePitch.standard

        let lowE = try #require(standard.nearestString(to: 83, reference: reference))
        #expect(lowE.index == 0)
        #expect(lowE.note == Note(.e, octave: 2))
        #expect(lowE.cents > 0)

        // Sol ligeiramente abaixo de G3 (196 Hz)
        let gString = try #require(standard.nearestString(to: 194, reference: reference))
        #expect(gString.index == 3)
        #expect(gString.cents < 0)

        // Um A4 está mais perto do Mi agudo (E4) do que do Si (B3)
        let a4 = try #require(standard.nearestString(to: 440, reference: reference))
        #expect(a4.index == 5)
        #expect(abs(a4.cents - 500) < 1e-9)
    }

    @Test func nearestStringIsNilForInvalidInput() {
        let empty = Tuning(id: "empty", name: "Vazia", notes: [])
        #expect(empty.nearestString(to: 440, reference: .standard) == nil)
        #expect(Instrument.guitar.tunings[0].nearestString(to: 0, reference: .standard) == nil)
    }
}
