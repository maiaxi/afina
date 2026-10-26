import Foundation
import Testing
@testable import AfinaCore

enum DetectorKind: String, CaseIterable, CustomTestStringConvertible {
    case mpm, yin

    func make() -> any PitchDetector {
        switch self {
        case .mpm: MPMPitchDetector()
        case .yin: YINPitchDetector()
        }
    }

    var testDescription: String { rawValue.uppercased() }
}

/// Frequências de teste: extremos da gama e notas de guitarra, baixo e ukulele.
private let sineFrequencies: [Double] = [
    40, 41.2, 55, 61.74, 73.42, 82.41, 98, 110, 146.83, 196, 246.94,
    329.63, 392, 440, 523.25, 659.26, 880, 1046.5, 1318.51, 1500,
]

struct PitchDetectorTests {
    @Test(arguments: DetectorKind.allCases, [44_100.0, 48_000])
    func pureSinesAreWithinOneCent(kind: DetectorKind, sampleRate: Double) throws {
        let detector = kind.make()
        for frequency in sineFrequencies {
            let signal = Signals.sine(
                frequency: frequency, amplitude: 0.5, sampleRate: sampleRate,
                count: detector.windowSize, phase: 0.7
            )
            let estimate = try #require(detect(signal, with: detector, sampleRate: sampleRate), "\(frequency) Hz")
            let error = Cents.between(estimate.frequency, and: frequency)
            #expect(abs(error) < 1, "\(frequency) Hz → \(estimate.frequency) Hz (\(error)¢)")
            #expect(estimate.clarity > 0.9)
        }
    }

    /// Espetro tipo corda: fundamental fraca, 2.º harmónico dominante.
    @Test(arguments: DetectorKind.allCases)
    func weakFundamentalHasNoOctaveError(kind: DetectorKind) throws {
        let detector = kind.make()
        let amplitudes: [Float] = [0.15, 1, 0.6, 0.45, 0.3, 0.25, 0.15, 0.1]
        for fundamental in [41.2, 55, 82.41, 110, 146.83, 196, 246.94, 329.63, 440] {
            let signal = Signals.harmonic(
                fundamental: fundamental, amplitudes: amplitudes,
                sampleRate: 48_000, count: detector.windowSize
            )
            let estimate = try #require(detect(signal, with: detector, sampleRate: 48_000), "\(fundamental) Hz")
            let error = Cents.between(estimate.frequency, and: fundamental)
            #expect(abs(error) < 5, "\(fundamental) Hz → \(estimate.frequency) Hz (\(error)¢)")
        }
    }

    /// Sem fundamental nenhuma: o período continua a ser o da fundamental.
    @Test(arguments: DetectorKind.allCases)
    func missingFundamentalIsStillDetected(kind: DetectorKind) throws {
        let detector = kind.make()
        let signal = Signals.harmonic(
            fundamental: 110, amplitudes: [0, 1, 0.8, 0.5],
            sampleRate: 48_000, count: detector.windowSize
        )
        let estimate = try #require(detect(signal, with: detector, sampleRate: 48_000))
        #expect(abs(Cents.between(estimate.frequency, and: 110)) < 5)
    }

    /// Seno com ruído branco a ~22 dB de SNR.
    @Test(arguments: DetectorKind.allCases, [82.41, 196, 659.26])
    func noisySineIsStillAccurate(kind: DetectorKind, frequency: Double) throws {
        let detector = kind.make()
        let sine = Signals.sine(frequency: frequency, amplitude: 0.5, sampleRate: 48_000, count: detector.windowSize)
        for seed: UInt64 in 1...10 {
            let noise = Signals.whiteNoise(amplitude: 0.05, count: detector.windowSize, seed: seed)
            let estimate = try #require(detect(Signals.mix(sine, noise), with: detector, sampleRate: 48_000))
            let error = Cents.between(estimate.frequency, and: frequency)
            #expect(abs(error) < 2, "semente \(seed): \(error)¢")
        }
    }

    @Test(arguments: DetectorKind.allCases, [1, 2, 3, 4, 5] as [UInt64])
    func whiteNoiseHasNoPitch(kind: DetectorKind, seed: UInt64) {
        let detector = kind.make()
        let noise = Signals.whiteNoise(amplitude: 0.5, count: detector.windowSize, seed: seed)
        #expect(detect(noise, with: detector, sampleRate: 48_000) == nil)
    }

    @Test(arguments: DetectorKind.allCases)
    func silenceHasNoPitch(kind: DetectorKind) {
        let detector = kind.make()
        let silence = [Float](repeating: 0, count: detector.windowSize)
        #expect(detect(silence, with: detector, sampleRate: 48_000) == nil)
    }

    @Test(arguments: DetectorKind.allCases)
    func dcOffsetIsIgnored(kind: DetectorKind) throws {
        let detector = kind.make()
        let signal = Signals.sine(frequency: 220, amplitude: 0.3, sampleRate: 48_000, count: detector.windowSize)
            .map { $0 + 0.4 }
        let estimate = try #require(detect(signal, with: detector, sampleRate: 48_000))
        #expect(abs(Cents.between(estimate.frequency, and: 220)) < 1)
    }

    @Test func largerWindowReachesLowBInAt96kHz() throws {
        // B0 (30,87 Hz) a 96 kHz precisa de mais de 4096 amostras: é o "modo baixo" de 8192.
        let detector = MPMPitchDetector(windowSize: 8192)
        let signal = Signals.sine(frequency: 30.87, amplitude: 0.5, sampleRate: 96_000, count: 8192)
        let estimate = try #require(detect(signal, with: detector, sampleRate: 96_000))
        #expect(abs(Cents.between(estimate.frequency, and: 30.87)) < 1)
    }

    @Test func mpmAnalysisIsFastEnough() {
        let detector = MPMPitchDetector()
        let signal = Signals.harmonic(
            fundamental: 82.41, amplitudes: [0.3, 1, 0.5, 0.3], sampleRate: 48_000, count: detector.windowSize
        )
        let runs = 200
        let elapsed = ContinuousClock().measure {
            for _ in 0..<runs { _ = detect(signal, with: detector, sampleRate: 48_000) }
        }
        let perWindow = elapsed / runs
        #expect(perWindow < .milliseconds(2), "\(perWindow) por janela")
    }

    private func detect(_ signal: [Float], with detector: any PitchDetector, sampleRate: Double) -> PitchEstimate? {
        signal.withUnsafeBufferPointer { detector.detect($0, sampleRate: sampleRate) }
    }
}
