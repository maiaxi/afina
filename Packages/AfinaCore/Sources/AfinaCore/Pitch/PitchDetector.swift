import Accelerate

/// Frequência fundamental estimada numa janela de áudio.
public struct PitchEstimate: Hashable, Sendable {
    public let frequency: Double
    /// Confiança da estimativa em [0, 1] (periodicidade do sinal).
    public let clarity: Float

    public init(frequency: Double, clarity: Float) {
        self.frequency = frequency
        self.clarity = clarity
    }
}

/// Detetor de pitch sobre uma janela de amostras mono.
///
/// As implementações pré-alocam os buffers na inicialização, por isso não são thread-safe:
/// cada instância deve ser usada por um só thread de análise.
public protocol PitchDetector: AnyObject {
    /// Número de amostras analisadas; amostras a mais são ignoradas.
    var windowSize: Int { get }

    /// Devolve `nil` se o sinal não for periódico o suficiente (ruído, silêncio, fora da gama).
    func detect(_ samples: UnsafeBufferPointer<Float>, sampleRate: Double) -> PitchEstimate?
}

/// Peças comuns aos detetores.
enum PitchDetection {
    /// Gama de lags (períodos em amostras) correspondente à gama de frequências pedida.
    /// `nil` se a janela for curta demais para a frequência mínima.
    static func lagRange(
        sampleRate: Double,
        minimumFrequency: Double,
        maximumFrequency: Double,
        largestLag: Int
    ) -> ClosedRange<Int>? {
        guard sampleRate > 0 else { return nil }
        let minimumLag = max(2, Int((sampleRate / maximumFrequency).rounded(.down)))
        let maximumLag = min(largestLag, Int((sampleRate / minimumFrequency).rounded(.up)) + 1)
        guard maximumLag > minimumLag + 2 else { return nil }
        return minimumLag...maximumLag
    }

    /// Copia `count` amostras para `destination` sem a componente DC. Devolve a energia (soma dos quadrados).
    static func copyRemovingDC(
        _ samples: UnsafeBufferPointer<Float>,
        count: Int,
        to destination: UnsafeMutablePointer<Float>
    ) -> Float {
        guard let source = samples.baseAddress, count > 0 else { return 0 }
        var mean: Float = 0
        vDSP_meanv(source, 1, &mean, vDSP_Length(count))
        var negativeMean = -mean
        vDSP_vsadd(source, 1, &negativeMean, destination, 1, vDSP_Length(count))
        var energy: Float = 0
        vDSP_svesq(destination, 1, &energy, vDSP_Length(count))
        return energy
    }

    /// Refina `period` com o extremo de `score` no maior múltiplo do período que cabe até `largestLag`.
    ///
    /// O erro da interpolação parabólica fica dividido pelo número de períodos, o que torna a
    /// estimativa bem menos sensível ao ruído. `score` tem de ser maior onde a periodicidade é maior;
    /// se o extremo encontrado não for um máximo local ou `accept` o recusar, devolve `period`.
    static func refinedPeriod(
        _ period: Double,
        largestLag: Int,
        score: (Int) -> Float,
        accept: (Int) -> Bool
    ) -> Double {
        let multiple = Int(Double(largestLag - 1) / period)
        guard multiple >= 2 else { return period }

        let expected = Int((period * Double(multiple)).rounded())
        let radius = max(2, min(Int(period / 4), Int(Double(expected) * 0.01)))
        let searchRange = max(1, expected - radius)...min(largestLag - 1, expected + radius)
        guard let best = searchRange.max(by: { score($0) < score($1) }),
              best != searchRange.lowerBound, best != searchRange.upperBound,
              accept(best)
        else { return period }

        let peak = parabolicPeak(score(best - 1), score(best), score(best + 1))
        return (Double(best) + Double(peak.offset)) / Double(multiple)
    }

    /// Deslocamento (em [-0,5, 0,5]) do vértice da parábola que passa por (-1, a), (0, b), (1, c),
    /// e o valor nesse vértice.
    static func parabolicPeak(_ a: Float, _ b: Float, _ c: Float) -> (offset: Float, value: Float) {
        let denominator = a - 2 * b + c
        guard denominator != 0 else { return (0, b) }
        let offset = max(-0.5, min(0.5, 0.5 * (a - c) / denominator))
        return (offset, b - 0.25 * (a - c) * offset)
    }
}
