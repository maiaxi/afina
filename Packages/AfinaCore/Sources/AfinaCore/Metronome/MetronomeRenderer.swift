import Accelerate
import Synchronization

/// Parâmetros partilhados entre a UI e o thread de áudio, só com atómicos.
final class MetronomeParameters: Sendable {
    // UI → áudio
    let bpmBits = Atomic<UInt64>(120.0.bitPattern)
    let timeSignatureIndex = Atomic<Int>(2)
    let subdivision = Atomic<Int>(1)
    let volume = AtomicFloat(0.8)
    let beatPattern = Atomic<UInt64>(BeatPattern(defaultFor: .fourFour).packed)
    let isPlaying = Atomic<Bool>(false)
    /// Incrementado a cada arranque: o renderer recomeça o compasso quando o vê mudar.
    let startGeneration = Atomic<Int>(0)

    // áudio → UI
    let currentPulse = Atomic<Int>(-1)
    let pulseCount = Atomic<Int>(0)

    var bpm: Double {
        get { Double(bitPattern: bpmBits.load(ordering: .relaxed)) }
        set { bpmBits.store(newValue.bitPattern, ordering: .relaxed) }
    }
}

/// Gera os cliques do metrónomo, amostra a amostra. Corre no render callback do `AVAudioSourceNode`
/// e também offline nos testes.
///
/// O tempo conta-se em amostras: o clique n cai em `round(âncora + n × intervalo)`, por isso não há
/// deriva acumulada. Os parâmetros lêem-se uma vez por buffer e só entram em vigor no pulso
/// seguinte (re-ancorando o tempo nesse instante); o padrão de sons lê-se em cada pulso.
/// Os sons são pré-sintetizados na inicialização;
/// `render` só copia e escala, sem alocar nem bloquear.
final class MetronomeRenderer: @unchecked Sendable {
    let parameters: MetronomeParameters
    let sampleRate: Double

    private let clickLength: Int
    private let clicks: UnsafeMutablePointer<Float>
    private let timeSignatureCount: Int
    private let beatsPerBar: UnsafeMutablePointer<Int>

    // Estado do thread de áudio
    private var generation = -1
    private var bufferStart: Int64 = 0
    private var anchorSample = 0.0
    private var ticksSinceAnchor = 0
    private var nextOnset: Int64 = 0
    private var tickInterval = 0.0
    private var pulseIndex = 0
    private var subdivisionIndex = 0
    private var activeBPM = 0.0
    private var activeTimeSignature = 0
    private var activeSubdivision = 1
    private var activeClick = -1
    private var clickPosition = 0

    init(parameters: MetronomeParameters, sampleRate: Double) {
        self.parameters = parameters
        self.sampleRate = sampleRate

        clickLength = ClickSynth.length(sampleRate: sampleRate)
        clicks = .allocate(capacity: ClickKind.allCases.count * clickLength)
        for kind in ClickKind.allCases {
            let samples = ClickSynth.click(kind, sampleRate: sampleRate)
            (clicks + kind.rawValue * clickLength).initialize(from: samples, count: clickLength)
        }

        let signatures = TimeSignature.all
        timeSignatureCount = signatures.count
        beatsPerBar = .allocate(capacity: timeSignatureCount)
        for (index, signature) in signatures.enumerated() {
            beatsPerBar[index] = signature.beats
        }
    }

    deinit {
        clicks.deallocate()
        beatsPerBar.deallocate()
    }

    /// Preenche `frameCount` amostras mono em `output`.
    func render(into output: UnsafeMutablePointer<Float>, frameCount: Int) {
        defer { bufferStart += Int64(frameCount) }
        output.update(repeating: 0, count: frameCount)

        guard parameters.isPlaying.load(ordering: .acquiring) else {
            activeClick = -1
            return
        }
        let currentGeneration = parameters.startGeneration.load(ordering: .acquiring)
        if currentGeneration != generation {
            generation = currentGeneration
            restart(at: bufferStart)
        }

        var volume = parameters.volume.load()
        var frame = 0
        while true {
            let onsetFrame = Int(nextOnset - bufferStart)
            guard onsetFrame < frameCount else {
                playActiveClick(into: output, from: frame, to: frameCount, volume: &volume)
                return
            }
            let start = max(onsetFrame, frame)
            playActiveClick(into: output, from: frame, to: start, volume: &volume)
            frame = start
            triggerTick()
        }
    }

    // MARK: Agendamento

    private func restart(at sample: Int64) {
        pulseIndex = 0
        subdivisionIndex = 0
        activeClick = -1
        anchorSample = Double(sample)
        ticksSinceAnchor = 0
        nextOnset = sample
        applyParameters()
    }

    /// Lê os parâmetros e, se mudaram, recomeça a contagem a partir do instante exato do tique atual.
    private func applyParameters() {
        let bpm = parameters.bpm
        let signature = min(max(parameters.timeSignatureIndex.load(ordering: .relaxed), 0), timeSignatureCount - 1)
        let subdivision = max(1, parameters.subdivision.load(ordering: .relaxed))
        guard bpm != activeBPM || signature != activeTimeSignature || subdivision != activeSubdivision else { return }

        anchorSample += Double(ticksSinceAnchor) * tickInterval
        ticksSinceAnchor = 0
        activeBPM = bpm
        activeTimeSignature = signature
        activeSubdivision = subdivision
        tickInterval = sampleRate * 60 / (bpm * Double(subdivision))
        pulseIndex %= beatsPerBar[signature]
    }

    private func triggerTick() {
        let isPulseStart = subdivisionIndex == 0
        if isPulseStart { applyParameters() }

        if isPulseStart {
            let pattern = parameters.beatPattern.load(ordering: .relaxed)
            activeClick = BeatPattern.sound(atPulse: pulseIndex, in: pattern).clickKind?.rawValue ?? -1
        } else {
            activeClick = ClickKind.subdivision.rawValue
        }
        clickPosition = 0

        if isPulseStart {
            parameters.currentPulse.store(pulseIndex, ordering: .relaxed)
            parameters.pulseCount.add(1, ordering: .relaxed)
        }

        ticksSinceAnchor += 1
        nextOnset = Int64((anchorSample + Double(ticksSinceAnchor) * tickInterval).rounded())
        subdivisionIndex += 1
        if subdivisionIndex >= activeSubdivision {
            subdivisionIndex = 0
            pulseIndex = (pulseIndex + 1) % beatsPerBar[activeTimeSignature]
        }
    }

    // MARK: Síntese

    private func playActiveClick(
        into output: UnsafeMutablePointer<Float>,
        from start: Int,
        to end: Int,
        volume: inout Float
    ) {
        guard activeClick >= 0, end > start else { return }
        let count = min(end - start, clickLength - clickPosition)
        let source = clicks + activeClick * clickLength + clickPosition
        vDSP_vsmul(source, 1, &volume, output + start, 1, vDSP_Length(count))
        clickPosition += count
        if clickPosition >= clickLength { activeClick = -1 }
    }
}
