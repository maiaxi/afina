import Foundation
import Testing
@testable import AfinaCore

struct TuningLibraryTests {
    @Test func customTuningsAppearAfterBuiltIns() throws {
        var library = TuningLibrary()
        let custom = Tuning.custom(name: "Open C", notes: [Note(.c, octave: 2), Note(.g, octave: 2)])
        library.add(custom, to: Instrument.guitar.id)

        let guitar = try #require(library.instruments.first { $0.id == Instrument.guitar.id })
        #expect(guitar.tunings.count == Instrument.guitar.tunings.count + 1)
        #expect(guitar.tunings.last == custom)
        #expect(custom.isCustom)
        #expect(!Instrument.guitar.tunings[0].isCustom)
    }

    @Test func updateAndRemove() {
        var library = TuningLibrary()
        var custom = Tuning.custom(name: "A minha", notes: [Note(.d, octave: 3)])
        library.add(custom, to: Instrument.ukulele.id)

        custom.name = "Renomeada"
        library.update(custom)
        #expect(library.tunings(for: Instrument.ukulele.id).first?.name == "Renomeada")

        library.remove(tuningID: custom.id)
        #expect(library.tunings(for: Instrument.ukulele.id).isEmpty)
        #expect(library == TuningLibrary())
    }
}

struct PreferencesTests {
    @Test func tunerPreferencesRoundTrip() throws {
        var preferences = TunerPreferences()
        preferences.mode = .chromatic
        preferences.capo = 3
        preferences.referenceA4 = 442
        preferences.notation = .latin
        preferences.inputDeviceUID = "AppleUSBAudioEngine:XYZ"
        preferences.library.add(.custom(name: "Teste", notes: [Note(.e, octave: 2)]), to: "guitar")

        let data = try JSONEncoder().encode(preferences)
        #expect(try JSONDecoder().decode(TunerPreferences.self, from: data) == preferences)
    }

    @Test func missingFieldsUseDefaults() throws {
        let tuner = try JSONDecoder().decode(TunerPreferences.self, from: Data(#"{"capo": 2}"#.utf8))
        var expectedTuner = TunerPreferences()
        expectedTuner.capo = 2
        #expect(tuner == expectedTuner)

        let metronome = try JSONDecoder().decode(MetronomePreferences.self, from: Data(#"{"bpm": 90}"#.utf8))
        var expectedMetronome = MetronomePreferences()
        expectedMetronome.bpm = 90
        #expect(metronome == expectedMetronome)
    }
}
