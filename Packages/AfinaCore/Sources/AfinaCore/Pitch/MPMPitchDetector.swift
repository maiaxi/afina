import Accelerate

/// McLeod Pitch Method (McLeod & Wyvill, 2005).
///
/// Calcula a NSDF (normalized square difference function) com autocorrelação via FFT, escolhe o
/// primeiro máximo-chave acima de `peakThreshold` × o maior, e refina-o com interpolação parabólica
/// e com o pico no maior múltiplo do período (ver `PitchDetection.refinedPeriod`).
/// Não aplica janela: a normalização da NSDF já compensa a sobreposição decrescente nas pontas.
public final class MPMPitchDetector: PitchDetector {
    public let windowSize: Int
    public var minimumFrequency: Double
    public var maximumFrequency: Double
    /// Valor mínimo do pico escolhido da NSDF para aceitar a estimativa.
    public var clarityThreshold: Float
    /// Fração do maior máximo-chave que um máximo anterior tem de atingir para ser escolhido.
    /// Mais baixo favorece períodos curtos (erros de oitava para cima); mais alto, o contrário.
    public var peakThreshold: Float

    private let fftSize: Int
    private let log2FFTSize: vDSP_Length
    private let fftSetup: FFTSetup
    private let input: UnsafeMutablePointer<Float>
    private let padded: UnsafeMutablePointer<Float>
    private let real: UnsafeMutablePointer<Float>
    private let imaginary: UnsafeMutablePointer<Float>
    private let nsdf: UnsafeMutablePointer<Float>

    public init(
        windowSize: Int = 4096,
        minimumFrequency: Double = 30,
        maximumFrequency: Double = 1500,
        clarityThreshold: Float = 0.9,
        peakThreshold: Float = 0.9
    ) {
        precondition(windowSize >= 64, "Janela demasiado pequena")
        self.windowSize = windowSize
        self.minimumFrequency = minimumFrequency
        self.maximumFrequency = maximumFrequency
        self.clarityThreshold = clarityThreshold
        self.peakThreshold = peakThreshold

        // Zero padding até 2× a janela para a autocorrelação não ser circular.
        var log2Size: vDSP_Length = 0
        while (1 << log2Size) < 2 * windowSize { log2Size += 1 }
        log2FFTSize = log2Size
        fftSize = 1 << log2Size
        // Só falha sem memória ou com tamanhos absurdos; não há forma razoável de continuar.
        guard let setup = vDSP_create_fftsetup(log2Size, FFTRadix(kFFTRadix2)) else {
            fatalError("Não foi possível criar o FFT setup do vDSP")
        }
        fftSetup = setup

        input = .allocate(capacity: windowSize)
        padded = .allocate(capacity: fftSize)
        real = .allocate(capacity: fftSize / 2)
        imaginary = .allocate(capacity: fftSize / 2)
        nsdf = .allocate(capacity: windowSize)
    }

    deinit {
        vDSP_destroy_fftsetup(fftSetup)
        for buffer in [input, padded, real, imaginary, nsdf] { buffer.deallocate() }
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

        computeAutocorrelation(count: count)
        let largestLag = count / 2
        computeNSDF(count: count, energy: energy, maximumLag: largestLag)

        guard let lag = selectPeakLag(in: lags) else { return nil }
        let peak = PitchDetection.parabolicPeak(nsdf[lag - 1], nsdf[lag], nsdf[lag + 1])
        let clarity = min(peak.value, 1)
        guard clarity >= clarityThreshold else { return nil }

        let period = PitchDetection.refinedPeriod(
            Double(lag) + Double(peak.offset),
            largestLag: largestLag,
            score: { nsdf[$0] },
            accept: { nsdf[$0] >= 0.5 * peak.value }
        )
        return PitchEstimate(frequency: sampleRate / period, clarity: clarity)
    }

    // MARK: NSDF

    /// Autocorrelação r(τ) de `input` em `padded[0...]`, via FFT → |X|² → IFFT.
    private func computeAutocorrelation(count: Int) {
        padded.update(from: input, count: count)
        (padded + count).update(repeating: 0, count: fftSize - count)

        let halfSize = vDSP_Length(fftSize / 2)
        var split = DSPSplitComplex(realp: real, imagp: imaginary)
        padded.withMemoryRebound(to: DSPComplex.self, capacity: fftSize / 2) {
            vDSP_ctoz($0, 2, &split, 1, halfSize)
        }
        vDSP_fft_zrip(fftSetup, &split, 1, log2FFTSize, FFTDirection(kFFTDirection_Forward))

        // No formato "packed" do vDSP, realp[0] é a componente DC e imagp[0] a de Nyquist.
        let dc = real[0]
        let nyquist = imaginary[0]
        vDSP_zvmags(&split, 1, real, 1, halfSize)
        vDSP_vclr(imaginary, 1, halfSize)
        real[0] = dc * dc
        imaginary[0] = nyquist * nyquist

        vDSP_fft_zrip(fftSetup, &split, 1, log2FFTSize, FFTDirection(kFFTDirection_Inverse))
        padded.withMemoryRebound(to: DSPComplex.self, capacity: fftSize / 2) {
            vDSP_ztoc(&split, 1, $0, 2, halfSize)
        }
        // A FFT real do vDSP escala por 2 em cada sentido e a inversa por n: o total é 4n.
        var scale = 1 / Float(4 * fftSize)
        vDSP_vsmul(padded, 1, &scale, padded, 1, vDSP_Length(count))
    }

    /// n'(τ) = 2·r(τ) / m(τ), com m(τ) = Σ x[j]² + x[j+τ]² atualizado incrementalmente.
    private func computeNSDF(count: Int, energy: Float, maximumLag: Int) {
        var squareSum = Double(2 * energy)
        nsdf[0] = 1
        for lag in 1...maximumLag {
            let leaving = input[lag - 1]
            let leavingEnd = input[count - lag]
            squareSum -= Double(leaving * leaving + leavingEnd * leavingEnd)
            nsdf[lag] = squareSum > 1e-12 ? Float(2 * Double(padded[lag]) / squareSum) : 0
        }
    }

    // MARK: Escolha do pico

    private func selectPeakLag(in lags: ClosedRange<Int>) -> Int? {
        var highest: Float = 0
        forEachKeyMaximum(in: lags) { lag in
            highest = max(highest, nsdf[lag])
            return true
        }
        guard highest > 0 else { return nil }

        let threshold = peakThreshold * highest
        var chosen: Int?
        forEachKeyMaximum(in: lags) { lag in
            guard nsdf[lag] >= threshold else { return true }
            chosen = lag
            return false
        }
        return chosen
    }

    /// Visita o maior valor de cada região positiva da NSDF (depois do lóbulo inicial em τ = 0),
    /// por ordem crescente de lag, enquanto `visit` devolver `true`.
    private func forEachKeyMaximum(in lags: ClosedRange<Int>, _ visit: (Int) -> Bool) {
        let end = lags.upperBound // nsdf[end] existe; os máximos ficam em < end para interpolar
        var lag = 1
        while lag < end, nsdf[lag] > 0 { lag += 1 }

        while lag < end {
            while lag < end, nsdf[lag] <= 0 { lag += 1 }
            var best = -1
            while lag < end, nsdf[lag] > 0 {
                if best < 0 || nsdf[lag] > nsdf[best] { best = lag }
                lag += 1
            }
            guard best >= 0 else { return }
            let isTrueMaximum = nsdf[best] >= nsdf[best + 1]
            if best >= lags.lowerBound, isTrueMaximum, !visit(best) { return }
        }
    }
}
