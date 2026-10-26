import Testing
@testable import AfinaCore

@MainActor
struct MetronomeEngineTests {
    @Test func bpmIsClampedToRange() {
        let engine = MetronomeEngine()
        engine.bpm = 500
        #expect(engine.bpm == 300)
        engine.bpm = 5
        #expect(engine.bpm == 20)
        engine.bpm = 96
        #expect(engine.bpm == 96)
    }

    @Test func volumeIsClampedToRange() {
        let engine = MetronomeEngine()
        engine.volume = 2
        #expect(engine.volume == 1)
        engine.volume = -1
        #expect(engine.volume == 0)
    }

    @Test func cyclingAndSignatureChangeUpdatePattern() {
        let engine = MetronomeEngine()
        engine.cycleSound(atPulse: 1)
        #expect(engine.beatPattern.sounds == [.accent, .weakBeat, .beat, .beat])
        engine.cycleSound(atPulse: 9) // fora do compasso: ignorado
        engine.timeSignature = .sixEight
        #expect(engine.beatPattern == BeatPattern(defaultFor: .sixEight))
        // Cada compasso lembra o seu padrão
        engine.timeSignature = .fourFour
        #expect(engine.beatPattern.sounds == [.accent, .weakBeat, .beat, .beat])
        engine.resetBeatPattern()
        #expect(engine.beatPattern == BeatPattern(defaultFor: .fourFour))
    }

    @Test func preferencesRoundTrip() {
        let engine = MetronomeEngine()
        engine.bpm = 87
        engine.timeSignature = .sevenEight
        engine.subdivision = .three
        engine.volume = 0.4
        engine.clickSound = .wood
        engine.cycleSound(atPulse: 0)

        let restored = MetronomeEngine()
        restored.apply(engine.preferences)
        #expect(restored.preferences == engine.preferences)
        #expect(restored.beatPattern == engine.beatPattern)
    }

    @Test func notPlayingHasNoPosition() {
        let engine = MetronomeEngine()
        #expect(!engine.isPlaying)
        #expect(engine.position == nil)
    }
}
