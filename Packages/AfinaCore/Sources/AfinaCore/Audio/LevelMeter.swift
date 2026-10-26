import Accelerate
import Foundation

/// Nível de um bloco de amostras, em amplitude linear (1 = escala completa).
public struct InputLevel: Hashable, Sendable {
    public static let silence = InputLevel(rms: 0, peak: 0)

    public let rms: Float
    public let peak: Float

    public init(rms: Float, peak: Float) {
        self.rms = rms
        self.peak = peak
    }

    public var rmsDecibels: Float { LevelMeter.decibelsFullScale(rms) }
    public var peakDecibels: Float { LevelMeter.decibelsFullScale(peak) }
}

/// Medição de nível com `vDSP`. Não aloca memória: pode ser usado no thread de áudio.
public enum LevelMeter {
    /// Valor usado para silêncio absoluto, em vez de -∞.
    public static let silenceDecibels: Float = -120

    public static func rms(of samples: UnsafeBufferPointer<Float>) -> Float {
        guard let base = samples.baseAddress, !samples.isEmpty else { return 0 }
        var result: Float = 0
        vDSP_rmsqv(base, 1, &result, vDSP_Length(samples.count))
        return result
    }

    public static func peak(of samples: UnsafeBufferPointer<Float>) -> Float {
        guard let base = samples.baseAddress, !samples.isEmpty else { return 0 }
        var result: Float = 0
        vDSP_maxmgv(base, 1, &result, vDSP_Length(samples.count))
        return result
    }

    public static func decibelsFullScale(_ amplitude: Float) -> Float {
        guard amplitude > 0 else { return silenceDecibels }
        return max(20 * log10(amplitude), silenceDecibels)
    }
}
