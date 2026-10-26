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

    @Test func notPlayingHasNoPosition() {
        let engine = MetronomeEngine()
        #expect(!engine.isPlaying)
        #expect(engine.position == nil)
    }
}
