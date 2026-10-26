import Foundation
import Testing
@testable import AfinaCore

struct PitchAnalyzerTests {
    private let sampleRate = 48_000.0

    private func feed(_ signal: [Float], to analyzer: PitchAnalyzer) -> [PitchAnalyzer.Output] {
        let ring = SPSCRingBuffer(minimumCapacity: 8192)
        var outputs: [PitchAnalyzer.Output] = []
        var offset = 0
        // Blocos de 512 como um tap de áudio, consumidos à medida que chegam
        while offset < signal.count {
            let end = min(offset + 512, signal.count)
            _ = signal[offset..<end].withUnsafeBufferPointer { ring.write($0) }
            offset = end
            if let output = analyzer.process(from: ring) { outputs.append(output) }
        }
        return outputs
    }

    @Test func detectsStringThroughTheWholeChain() throws {
        let analyzer = PitchAnalyzer(sampleRate: sampleRate)
        let a2 = ReferencePitch.standard.frequency(of: Note(.a, octave: 2)) * pow(2, -12.0 / 1200)
        let signal = Signals.harmonic(
            fundamental: a2, amplitudes: [0.1, 0.3, 0.15, 0.1], sampleRate: sampleRate, count: 48_000
        )
        let last = try #require(feed(signal, to: analyzer).last)
        #expect(last.isSignalPresent)
        let reading = try #require(last.reading)
        #expect(reading.note == Note(.a, octave: 2))
        #expect(abs(reading.cents + 12) < 0.5)
    }

    @Test func quietSignalKeepsTheGateClosed() throws {
        let analyzer = PitchAnalyzer(sampleRate: sampleRate)
        // -70 dBFS: abaixo do limiar de -55
        let signal = Signals.sine(frequency: 440, amplitude: 0.0004, sampleRate: sampleRate, count: 24_000)
        let outputs = feed(signal, to: analyzer)
        #expect(!outputs.isEmpty)
        #expect(outputs.allSatisfy { !$0.isSignalPresent && $0.reading == nil })
    }

    @Test func referencePitchChangeIsApplied() throws {
        let analyzer = PitchAnalyzer(sampleRate: sampleRate, reference: ReferencePitch(a4: 432))
        let signal = Signals.sine(frequency: 432, amplitude: 0.3, sampleRate: sampleRate, count: 24_000)
        let reading = try #require(feed(signal, to: analyzer).last?.reading)
        #expect(reading.note == Note(.a, octave: 4))
        #expect(abs(reading.cents) < 0.5)
    }

    @Test func consumesEverySampleInHops() {
        let analyzer = PitchAnalyzer(sampleRate: sampleRate)
        let ring = SPSCRingBuffer(minimumCapacity: 8192)
        let signal = [Float](repeating: 0, count: 3000)
        _ = signal.withUnsafeBufferPointer { ring.write($0) }
        _ = analyzer.process(from: ring)
        // 3000 = 2 saltos de 1024 + 952 por consumir
        #expect(ring.availableToRead == 952)
    }
}
