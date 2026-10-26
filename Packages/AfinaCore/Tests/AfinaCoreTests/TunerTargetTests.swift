import Foundation
import Testing
@testable import AfinaCore

struct TunerTargetTests {
    private let reference = ReferencePitch.standard
    private let standard = Instrument.guitar.tunings[0]

    private func reading(_ frequency: Double) throws -> PitchReading {
        try #require(reference.reading(forFrequency: frequency))
    }

    @Test func chromaticModeUsesNearestNote() throws {
        let target = try #require(TunerTarget(
            reading: try reading(445), mode: .chromatic, tuning: standard, reference: reference
        ))
        #expect(target.note == Note(.a, octave: 4))
        #expect(target.stringIndex == nil)
        #expect(abs(target.cents - Cents.between(445, and: 440)) < 1e-9)
    }

    @Test func instrumentModeUsesNearestStringEvenWhenFarOff() throws {
        // Lá2 (110 Hz) muito baixo, já mais perto de G♯2 cromaticamente
        let frequency = 110 * pow(2, -70.0 / 1200)
        let target = try #require(TunerTarget(
            reading: try reading(frequency), mode: .instrument, tuning: standard, reference: reference
        ))
        #expect(target.note == Note(.a, octave: 2))
        #expect(target.stringIndex == 1)
        #expect(abs(target.cents + 70) < 1e-6)
    }

    @Test func capoIsRespected() throws {
        let capo2 = standard.withCapo(atFret: 2)
        let fSharp2 = reference.frequency(of: Note(.fSharp, octave: 2))
        let target = try #require(TunerTarget(
            reading: try reading(fSharp2), mode: .instrument, tuning: capo2, reference: reference
        ))
        #expect(target.stringIndex == 0)
        #expect(abs(target.cents) < 1e-6)
    }

    @Test func noReadingMeansNoTarget() {
        #expect(TunerTarget(reading: nil, mode: .chromatic, tuning: standard, reference: reference) == nil)
    }

    @Test func toleranceIsInclusive() {
        let target = TunerTarget(note: Note(.e, octave: 2), cents: -3, stringIndex: 0)
        #expect(target.isInTune(tolerance: 3))
        #expect(!target.isInTune(tolerance: 2.9))
    }
}

struct TuningProgressTests {
    private func target(string: Int, cents: Double) -> TunerTarget {
        TunerTarget(note: Note(midiNumber: 40 + string * 5), cents: cents, stringIndex: string)
    }

    @Test func stringIsMarkedAfterSustainedInTuneReadings() {
        var progress = TuningProgress(requiredCount: 5)
        for _ in 0..<4 { progress.update(with: target(string: 2, cents: 1), tolerance: 3) }
        #expect(progress.tunedStrings.isEmpty)
        progress.update(with: target(string: 2, cents: -2), tolerance: 3)
        #expect(progress.tunedStrings == [2])
    }

    @Test func interruptionsRestartTheCount() {
        var progress = TuningProgress(requiredCount: 5)
        for _ in 0..<4 { progress.update(with: target(string: 0, cents: 0), tolerance: 3) }
        progress.update(with: nil, tolerance: 3)
        for _ in 0..<4 { progress.update(with: target(string: 0, cents: 0), tolerance: 3) }
        #expect(progress.tunedStrings.isEmpty)
    }

    @Test func clearlyDetunedStringIsUnmarked() {
        var progress = TuningProgress(requiredCount: 3)
        for _ in 0..<3 { progress.update(with: target(string: 1, cents: 0), tolerance: 3) }
        // Entre 1× e 2× a tolerância não desmarca
        for _ in 0..<10 { progress.update(with: target(string: 1, cents: 5), tolerance: 3) }
        #expect(progress.tunedStrings == [1])
        for _ in 0..<3 { progress.update(with: target(string: 1, cents: 12), tolerance: 3) }
        #expect(progress.tunedStrings.isEmpty)
    }

    @Test func chromaticTargetsAreIgnoredAndResetClears() {
        var progress = TuningProgress(requiredCount: 2)
        for _ in 0..<5 {
            progress.update(with: TunerTarget(note: Note(.a, octave: 4), cents: 0, stringIndex: nil), tolerance: 3)
        }
        #expect(progress.tunedStrings.isEmpty)
        for _ in 0..<2 { progress.update(with: target(string: 3, cents: 0), tolerance: 3) }
        progress.reset()
        #expect(progress.tunedStrings.isEmpty)
    }
}
