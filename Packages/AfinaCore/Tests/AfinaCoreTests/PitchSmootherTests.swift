import Foundation
import Testing
@testable import AfinaCore

struct PitchSmootherTests {
    private let reference = ReferencePitch.standard

    private func estimate(note: Note, cents: Double) -> PitchEstimate {
        let frequency = reference.frequency(of: note) * pow(2, cents / 1200)
        return PitchEstimate(frequency: frequency, clarity: 1)
    }

    @Test func steadyInputConverges() throws {
        let smoother = PitchSmoother()
        var reading: PitchReading?
        for _ in 0..<30 { reading = smoother.process(estimate(note: Note(.a, octave: 4), cents: 7)) }
        let result = try #require(reading)
        #expect(result.note == Note(.a, octave: 4))
        #expect(abs(result.cents - 7) < 0.01)
    }

    @Test func singleOctaveSpikeIsRejectedByMedian() throws {
        let smoother = PitchSmoother()
        let e2 = Note(.e, octave: 2)
        for _ in 0..<5 { _ = smoother.process(estimate(note: e2, cents: 0)) }
        let spike = try #require(smoother.process(estimate(note: e2.transposed(bySemitones: 12), cents: 0)))
        #expect(spike.note == e2)
        #expect(abs(spike.cents) < 0.01)
    }

    @Test func jitterIsReduced() throws {
        let smoother = PitchSmoother()
        let pattern = [-3.0, 3, -2, 2, -3, 3, -1, 1]
        var outputs: [Double] = []
        for index in 0..<80 {
            let reading = smoother.process(estimate(note: Note(.g, octave: 3), cents: pattern[index % pattern.count]))
            if index >= 20, let reading { outputs.append(reading.cents) }
        }
        let spread = (outputs.max() ?? 0) - (outputs.min() ?? 0)
        #expect(spread < 2, "variação de \(spread)¢ com entrada a ±3¢")
    }

    @Test func newNoteSnapsQuickly() throws {
        let smoother = PitchSmoother()
        for _ in 0..<10 { _ = smoother.process(estimate(note: Note(.e, octave: 2), cents: 0)) }
        var reading: PitchReading?
        for _ in 0..<3 { reading = smoother.process(estimate(note: Note(.a, octave: 2), cents: -4)) }
        let result = try #require(reading)
        #expect(result.note == Note(.a, octave: 2))
        #expect(abs(result.cents + 4) < 0.01)
    }

    @Test func hysteresisKeepsNoteNearTheBoundary() throws {
        let smoother = PitchSmoother()
        let a4 = Note(.a, octave: 4)
        for _ in 0..<10 { _ = smoother.process(estimate(note: a4, cents: 40)) }
        // 55¢ acima de A4 seria A♯4 -45¢, mas ainda está dentro da margem de histerese
        var reading: PitchReading?
        for _ in 0..<30 { reading = smoother.process(estimate(note: a4, cents: 55)) }
        let held = try #require(reading)
        #expect(held.note == a4)
        #expect(abs(held.cents - 55) < 0.5)
        // 65¢ já ultrapassa a margem
        for _ in 0..<30 { reading = smoother.process(estimate(note: a4, cents: 65)) }
        let switched = try #require(reading)
        #expect(switched.note == Note(.aSharp, octave: 4))
    }

    @Test func briefDropoutsHoldTheLastReading() {
        let smoother = PitchSmoother()
        for _ in 0..<5 { _ = smoother.process(estimate(note: Note(.d, octave: 3), cents: 0)) }
        for _ in 0..<smoother.configuration.holdCount {
            #expect(smoother.process(nil)?.note == Note(.d, octave: 3))
        }
        #expect(smoother.process(nil) == nil)
    }
}
