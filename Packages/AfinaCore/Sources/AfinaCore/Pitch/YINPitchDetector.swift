import Accelerate

/// YIN (de Cheveigné & Kawahara, 2002): função de diferença com normalização cumulativa,
/// limiar absoluto e interpolação parabólica sobre a função de diferença, refinada com o mínimo
/// no maior múltiplo do período (ver `PitchDetection.refinedPeriod`).
public final class YINPitchDetector: PitchDetector {
    public let windowSize: Int
    public var minimumFrequency: Double
    public var maximumFrequency: Double
    /// Limiar absoluto sobre a diferença normalizada (0,1–0,15 é o habitual).
    public var threshold: Float

    private let input: UnsafeMutablePointer<Float>
    private let difference: UnsafeMutablePointer<Float>
    private let normalized: UnsafeMutablePointer<Float>

    public init(
        windowSize: Int = 4096,
        minimumFrequency: Double = 30,
        maximumFrequency: Double = 1500,
        threshold: Float = 0.12
    ) {
        precondition(windowSize >= 64, "Janela demasiado pequena")
        self.windowSize = windowSize
        self.minimumFrequency = minimumFrequency
        self.maximumFrequency = maximumFrequency
        self.threshold = threshold
        input = .allocate(capacity: windowSize)
        difference = .allocate(capacity: windowSize)
        normalized = .allocate(capacity: windowSize)
    }

    deinit {
        for buffer in [input, difference, normalized] { buffer.deallocate() }
    }

    public func detect(_ samples: UnsafeBufferPointer<Float>, sampleRate: Double) -> PitchEstimate? {
        let count = min(samples.count, windowSize)
        guard let lags = PitchDetection.lagRange(
            sampleRate: sampleRate,
            minimumFrequency: minimumFrequency,
            maximumFrequency: maximumFrequency,
            largestLag: count / 2
        ) else { return nil }

        let energy = PitchDetection.copyRemovingDC(samples, count: count, to: input)
        guard energy > .leastNormalMagnitude else { return nil }

        let largestLag = count / 2
        computeNormalizedDifference(count: count, maximumLag: largestLag)
        guard let lag = firstDip(in: lags) else { return nil }

        let dip = PitchDetection.parabolicPeak(difference[lag - 1], difference[lag], difference[lag + 1])
        let dipValue = normalized[lag]
        let period = PitchDetection.refinedPeriod(
            Double(lag) + Double(dip.offset),
            largestLag: largestLag,
            score: { -difference[$0] },
            accept: { normalized[$0] < max(threshold, 2 * dipValue) }
        )
        return PitchEstimate(frequency: sampleRate / period, clarity: max(0, 1 - dipValue))
    }

    /// d(τ) = Σ (x[j] − x[j+τ])² sobre uma janela de integração fixa, e d'(τ) = d(τ)·τ / Σ d(1...τ).
    private func computeNormalizedDifference(count: Int, maximumLag: Int) {
        let integrationLength = vDSP_Length(count - maximumLag)
        difference[0] = 0
        normalized[0] = 1
        var runningSum: Float = 0
        for lag in 1...maximumLag {
            var distance: Float = 0
            vDSP_distancesq(input, 1, input + lag, 1, &distance, integrationLength)
            difference[lag] = distance
            runningSum += distance
            normalized[lag] = runningSum > 0 ? distance * Float(lag) / runningSum : 1
        }
    }

    /// Primeiro lag abaixo do limiar, descendo depois até ao mínimo local.
    private func firstDip(in lags: ClosedRange<Int>) -> Int? {
        let end = lags.upperBound
        var lag = lags.lowerBound
        while lag < end, normalized[lag] >= threshold { lag += 1 }
        guard lag < end else { return nil }
        while lag + 1 < end, normalized[lag + 1] < normalized[lag] { lag += 1 }
        return lag
    }
}
