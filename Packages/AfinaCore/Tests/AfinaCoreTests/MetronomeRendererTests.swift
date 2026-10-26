import Foundation
import Testing
@testable import AfinaCore

/// Renderiza o metrónomo offline e recolhe o início e o tipo de cada clique.
private final class OfflineMetronome {
    let parameters = MetronomeParameters()
    let renderer: MetronomeRenderer
    let sampleRate: Double
    private(set) var output: [Float] = []

    init(sampleRate: Double = 48_000, bpm: Double = 120, signature: TimeSignature = .fourFour, subdivision: Subdivision = .none) {
        self.sampleRate = sampleRate
        renderer = MetronomeRenderer(parameters: parameters, sampleRate: sampleRate)
        parameters.bpm = bpm
        parameters.timeSignatureIndex.store(TimeSignature.all.firstIndex(of: signature) ?? 0, ordering: .relaxed)
        parameters.subdivision.store(subdivision.rawValue, ordering: .relaxed)
        parameters.beatPattern.store(BeatPattern(defaultFor: signature).packed, ordering: .relaxed)
        parameters.volume.store(1)
        parameters.isPlaying.store(true, ordering: .relaxed)
        parameters.startGeneration.add(1, ordering: .relaxed)
    }

    /// Renderiza `seconds` em buffers de tamanho variável (como um dispositivo real).
    func render(seconds: Double, bufferSizes: [Int] = [512]) {
        render(frames: Int(seconds * sampleRate), bufferSizes: bufferSizes)
    }

    func render(frames total: Int, bufferSizes: [Int] = [512]) {
        var rendered = 0
        var sizeIndex = 0
        var buffer = [Float](repeating: 0, count: bufferSizes.max() ?? 512)
        while rendered < total {
            let size = min(bufferSizes[sizeIndex % bufferSizes.count], total - rendered)
            buffer.withUnsafeMutableBufferPointer { renderer.render(into: $0.baseAddress!, frameCount: size) }
            output.append(contentsOf: buffer.prefix(size))
            rendered += size
            sizeIndex += 1
        }
    }

    /// Início de cada clique: primeira amostra não nula depois de uma pausa (a 1.ª amostra de um clique nunca é 0).
    var onsets: [Int] {
        let clickLength = ClickSynth.length(sampleRate: sampleRate)
        var result: [Int] = []
        var index = 0
        while index < output.count {
            if output[index] != 0 {
                result.append(index)
                index += clickLength
            } else {
                index += 1
            }
        }
        return result
    }

    func kind(at onset: Int) -> ClickKind? {
        let clickLength = ClickSynth.length(sampleRate: sampleRate)
        let peak = output[onset..<min(onset + clickLength, output.count)].map(abs).max() ?? 0
        return ClickKind.allCases.min { abs($0.amplitude - peak) < abs($1.amplitude - peak) }
    }
}

struct MetronomeRendererTests {
    @Test func sixtySecondsAt120BPMHaveZeroDrift() {
        let metronome = OfflineMetronome(bpm: 120)
        metronome.render(seconds: 60, bufferSizes: [512, 128, 1024, 471, 256, 333])
        let onsets = metronome.onsets
        #expect(onsets.count == 120)
        #expect(onsets == (0..<120).map { $0 * 24_000 })
    }

    /// Intervalo não inteiro (44 100 × 60 / 113 = 23 415,93… amostras): cada clique cai no
    /// arredondamento do instante exato, sem acumular erro.
    @Test func nonIntegerIntervalDoesNotAccumulateError() {
        let metronome = OfflineMetronome(sampleRate: 44_100, bpm: 113)
        metronome.render(seconds: 600, bufferSizes: [512, 77, 1024, 300])
        let interval = 44_100.0 * 60 / 113
        let onsets = metronome.onsets
        #expect(onsets.count == Int((600 / (60 / 113.0)).rounded(.up)))
        let expected = (0..<onsets.count).map { Int((Double($0) * interval).rounded()) }
        #expect(onsets == expected)
    }

    @Test func accentsFollowTheBar() {
        let metronome = OfflineMetronome(bpm: 120, signature: .threeFour)
        metronome.render(seconds: 3)
        let kinds = metronome.onsets.map { metronome.kind(at: $0) }
        #expect(kinds == [.accent, .beat, .beat, .accent, .beat, .beat])
    }

    @Test func compoundMetersGroupPulses() {
        let metronome = OfflineMetronome(bpm: 240, signature: .sixEight)
        metronome.render(seconds: 3)
        let kinds = metronome.onsets.prefix(12).map { metronome.kind(at: $0) }
        #expect(kinds == [.accent, .weakBeat, .weakBeat, .beat, .weakBeat, .weakBeat,
                          .accent, .weakBeat, .weakBeat, .beat, .weakBeat, .weakBeat])

        let sevenEight = OfflineMetronome(bpm: 240, signature: .sevenEight)
        sevenEight.render(seconds: 2)
        let sevenKinds = sevenEight.onsets.prefix(7).map { sevenEight.kind(at: $0) }
        #expect(sevenKinds == [.accent, .weakBeat, .beat, .weakBeat, .beat, .weakBeat, .weakBeat])
    }

    @Test func customPatternChangesSoundsAndSilencesPulses() {
        let metronome = OfflineMetronome(bpm: 120, signature: .fourFour)
        let pattern = BeatPattern(sounds: [.accent, .silent, .weakBeat, .accent])
        metronome.parameters.beatPattern.store(pattern.packed, ordering: .relaxed)
        metronome.render(seconds: 2)
        // O 2.º pulso (24 000) fica em silêncio, mas o tempo continua a contar
        #expect(metronome.onsets == [0, 48_000, 72_000])
        #expect(metronome.onsets.map { metronome.kind(at: $0) } == [.accent, .weakBeat, .accent])
    }

    @Test func tripletsSplitEachPulse() {
        let metronome = OfflineMetronome(bpm: 60, subdivision: .three)
        metronome.render(seconds: 2)
        #expect(metronome.onsets == [0, 16_000, 32_000, 48_000, 64_000, 80_000])
        let kinds = metronome.onsets.map { metronome.kind(at: $0) }
        #expect(kinds == [.accent, .subdivision, .subdivision, .beat, .subdivision, .subdivision])
    }

    @Test func bpmChangeTakesEffectOnTheNextPulse() {
        let metronome = OfflineMetronome(bpm: 60)
        metronome.render(frames: 10_000)          // a meio do 1.º pulso
        metronome.parameters.bpm = 120
        metronome.render(frames: 110_000)
        // O 2.º pulso ainda cai no tempo antigo (48 000); a partir daí, de 24 000 em 24 000
        #expect(metronome.onsets == [0, 48_000, 72_000, 96_000])
    }

    @Test func bpmChangeWaitsForThePulseWhenSubdividing() {
        let metronome = OfflineMetronome(bpm: 60, subdivision: .two)
        metronome.render(frames: 30_000)          // depois da colcheia do meio (24 000)
        metronome.parameters.bpm = 120
        metronome.render(frames: 70_000)
        #expect(metronome.onsets == [0, 24_000, 48_000, 60_000, 72_000, 84_000, 96_000])
    }

    @Test func stoppingSilencesAndRestartBeginsTheBar() {
        let metronome = OfflineMetronome(bpm: 120, signature: .fourFour)
        metronome.render(frames: 30_000)          // 2 cliques: 0 e 24 000
        metronome.parameters.isPlaying.store(false, ordering: .relaxed)
        metronome.render(frames: 50_000)
        metronome.parameters.startGeneration.add(1, ordering: .relaxed)
        metronome.parameters.isPlaying.store(true, ordering: .relaxed)
        metronome.render(frames: 30_000)

        let onsets = metronome.onsets
        // O clique de 24 000 é cortado na paragem (30 000); o novo arranque é em 80 000
        #expect(onsets == [0, 24_000, 80_000, 104_000])
        #expect(metronome.kind(at: 80_000) == .accent)
    }

    @Test func volumeScalesOutput() {
        let metronome = OfflineMetronome(bpm: 120)
        metronome.parameters.volume.store(0.5)
        metronome.render(frames: 2000)
        let peak = metronome.output.map(abs).max() ?? 0
        #expect(abs(peak - 0.5) < 0.01)
    }

    @Test func currentPulseIsPublished() {
        let metronome = OfflineMetronome(bpm: 120, signature: .threeFour)
        metronome.render(frames: 50_000)          // pulsos 0 (0) e 1 (24 000), e 2 em 48 000
        #expect(metronome.parameters.currentPulse.load(ordering: .relaxed) == 2)
        #expect(metronome.parameters.pulseCount.load(ordering: .relaxed) == 3)
    }
}

struct TapTempoTests {
    @Test func averagesTheIntervals() throws {
        var tap = TapTempo()
        #expect(tap.tap(at: 10) == nil)
        let bpm = tap.tap(at: 10.5)
        #expect(abs(try #require(bpm) - 120) < 1e-9)
        _ = tap.tap(at: 11.02)
        let averaged = tap.tap(at: 11.5)
        #expect(abs(try #require(averaged) - 120) < 1e-9)
    }

    @Test func keepsOnlyTheLastTaps() throws {
        var tap = TapTempo(maximumTaps: 4)
        // Toques lentos (1 s) seguidos de rápidos (0,5 s): só contam os 4 últimos
        for time in [0.0, 1, 2] { _ = tap.tap(at: time) }
        var bpm: Double?
        for time in [2.5, 3, 3.5] { bpm = tap.tap(at: time) }
        #expect(abs(try #require(bpm) - 120) < 1e-9)
    }

    @Test func resetsAfterAPause() {
        var tap = TapTempo(resetInterval: 2)
        _ = tap.tap(at: 0)
        _ = tap.tap(at: 0.5)
        #expect(tap.tap(at: 3) == nil)
    }
}

struct BeatPatternTests {
    @Test func defaultFollowsGrouping() {
        #expect(BeatPattern(defaultFor: .threeFour).sounds == [.accent, .beat, .beat])
        #expect(BeatPattern(defaultFor: .sevenEight).sounds == [.accent, .weakBeat, .beat, .weakBeat, .beat, .weakBeat, .weakBeat])
    }

    @Test func packingRoundTrips() {
        let pattern = BeatPattern(sounds: [.silent, .accent, .weakBeat, .beat, .silent, .silent, .accent, .beat, .weakBeat, .accent, .silent, .beat])
        for pulse in pattern.sounds.indices {
            #expect(BeatPattern.sound(atPulse: pulse, in: pattern.packed) == pattern[pulse])
        }
    }

    @Test func soundsCycle() {
        #expect(PulseSound.accent.next == .beat)
        #expect(PulseSound.weakBeat.next == .silent)
        #expect(PulseSound.silent.next == .accent)
    }
}

struct TimeSignatureTests {
    @Test func groupStarts() {
        #expect((0..<7).filter(TimeSignature.sevenEight.isGroupStart) == [0, 2, 4])
        #expect((0..<4).allSatisfy(TimeSignature.fourFour.isGroupStart))
        #expect(TimeSignature.twelveEight.id == "12/8")
    }
}
