import Foundation

/// Sinais sintéticos para os testes (nada de ficheiros de áudio no repositório).
enum Signals {
    static func sine(
        frequency: Double,
        amplitude: Float,
        sampleRate: Double,
        count: Int,
        phase: Double = 0
    ) -> [Float] {
        (0..<count).map { index in
            amplitude * Float(sin(2 * .pi * frequency * Double(index) / sampleRate + phase))
        }
    }

    /// Soma de harmónicos: `amplitudes[0]` é a fundamental, `amplitudes[1]` o 2.º harmónico, etc.
    /// Cada harmónico tem uma fase diferente, como numa corda real.
    static func harmonic(
        fundamental: Double,
        amplitudes: [Float],
        sampleRate: Double,
        count: Int
    ) -> [Float] {
        var output = [Float](repeating: 0, count: count)
        for (offset, amplitude) in amplitudes.enumerated() where amplitude != 0 {
            let harmonic = sine(
                frequency: fundamental * Double(offset + 1),
                amplitude: amplitude,
                sampleRate: sampleRate,
                count: count,
                phase: Double(offset) * 1.3
            )
            for index in 0..<count { output[index] += harmonic[index] }
        }
        return output
    }

    /// Ruído branco uniforme em [-amplitude, amplitude], determinístico para uma dada semente.
    static func whiteNoise(amplitude: Float, count: Int, seed: UInt64) -> [Float] {
        var generator = SplitMix64(state: seed)
        return (0..<count).map { _ in amplitude * Float.random(in: -1...1, using: &generator) }
    }

    static func mix(_ first: [Float], _ second: [Float]) -> [Float] {
        zip(first, second).map(+)
    }
}

/// Gerador pseudoaleatório pequeno e reprodutível.
struct SplitMix64: RandomNumberGenerator {
    var state: UInt64

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var value = state
        value = (value ^ (value >> 30)) &* 0xBF58_476D_1CE4_E5B9
        value = (value ^ (value >> 27)) &* 0x94D0_49BB_1331_11EB
        return value ^ (value >> 31)
    }
}
