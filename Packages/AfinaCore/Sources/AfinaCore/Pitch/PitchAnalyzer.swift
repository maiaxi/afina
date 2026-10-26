/// Cadeia de análise: lê o áudio do ring buffer em saltos (`hopSize`), mantém uma janela
/// deslizante, aplica o noise gate, deteta o pitch e suaviza o resultado.
///
/// Corre no thread de análise (não no de áudio). Não é thread-safe.
public final class PitchAnalyzer {
    public struct Configuration: Hashable, Sendable {
        /// Amostras novas entre análises (1024 ≈ 47 análises/s a 48 kHz).
        public var hopSize = 1024
        /// O gate abre quando o RMS da janela passa este nível.
        public var gateThresholdDecibels: Float = -55
        /// O gate só fecha quando o nível desce este tanto abaixo do limiar.
        public var gateHysteresisDecibels: Float = 6
        public var smoothing = PitchSmoother.Configuration()

        public init() {}
    }

    public struct Output: Hashable, Sendable {
        /// `false` enquanto o gate está fechado ("à espera de som").
        public let isSignalPresent: Bool
        public let level: InputLevel
        public let reading: PitchReading?
    }

    public let sampleRate: Double
    public var configuration: Configuration

    public var reference: ReferencePitch {
        get { smoother.reference }
        set { smoother.reference = newValue }
    }

    private let detector: any PitchDetector
    private let smoother: PitchSmoother
    private let window: UnsafeMutablePointer<Float>
    private let hop: UnsafeMutablePointer<Float>
    private let windowSize: Int
    private var filledCount = 0
    private var isGateOpen = false

    public init(
        sampleRate: Double,
        detector: any PitchDetector = MPMPitchDetector(),
        reference: ReferencePitch = .standard,
        configuration: Configuration = Configuration()
    ) {
        precondition(configuration.hopSize > 0 && configuration.hopSize <= detector.windowSize)
        self.sampleRate = sampleRate
        self.detector = detector
        self.configuration = configuration
        windowSize = detector.windowSize
        smoother = PitchSmoother(reference: reference, configuration: configuration.smoothing)
        window = .allocate(capacity: windowSize)
        window.initialize(repeating: 0, count: windowSize)
        hop = .allocate(capacity: configuration.hopSize)
    }

    deinit {
        window.deallocate()
        hop.deallocate()
    }

    /// Consome todos os saltos completos disponíveis e devolve o resultado do último,
    /// ou `nil` se ainda não havia áudio novo suficiente.
    public func process(from ringBuffer: SPSCRingBuffer) -> Output? {
        let hopSize = configuration.hopSize
        var latest: Output?
        while ringBuffer.availableToRead >= hopSize {
            ringBuffer.read(into: UnsafeMutableBufferPointer(start: hop, count: hopSize))
            appendHop(count: hopSize)
            latest = analyzeWindow()
        }
        return latest
    }

    /// Esquece o áudio e o histórico (por exemplo, ao retomar depois de uma pausa).
    public func reset() {
        filledCount = 0
        isGateOpen = false
        window.update(repeating: 0, count: windowSize)
        smoother.reset()
    }

    private func appendHop(count: Int) {
        window.update(from: window + count, count: windowSize - count)
        (window + windowSize - count).update(from: hop, count: count)
        filledCount = min(windowSize, filledCount + count)
    }

    private func analyzeWindow() -> Output {
        let samples = UnsafeBufferPointer(start: window, count: windowSize)
        let level = InputLevel(rms: LevelMeter.rms(of: samples), peak: LevelMeter.peak(of: samples))
        updateGate(level: level)

        guard isGateOpen, filledCount == windowSize else {
            if !isGateOpen { smoother.reset() }
            return Output(isSignalPresent: isGateOpen, level: level, reading: nil)
        }
        let estimate = detector.detect(samples, sampleRate: sampleRate)
        return Output(isSignalPresent: true, level: level, reading: smoother.process(estimate))
    }

    private func updateGate(level: InputLevel) {
        let decibels = level.rmsDecibels
        if isGateOpen {
            isGateOpen = decibels >= configuration.gateThresholdDecibels - configuration.gateHysteresisDecibels
        } else {
            isGateOpen = decibels >= configuration.gateThresholdDecibels
        }
    }
}
