/// Suaviza estimativas de pitch sucessivas para a UI: mediana (rejeita picos isolados, como um
/// erro de oitava num só frame), EMA nos cents, e histerese na troca de nota.
///
/// Trabalha em números MIDI fracionários, por isso é independente da frequência.
public final class PitchSmoother {
    public struct Configuration: Hashable, Sendable {
        /// Número de estimativas na mediana.
        public var medianLength = 5
        /// Peso da estimativa nova na EMA (0–1; mais alto reage mais depressa).
        public var smoothingFactor = 0.3
        /// Saltos maiores do que isto (por exemplo, uma nota nova) reiniciam a EMA.
        public var jumpCents = 50.0
        /// Margem além dos ±50¢ antes de trocar a nota mostrada.
        public var hysteresisCents = 10.0
        /// Estimativas em falta seguidas que ainda mostram a última leitura.
        public var holdCount = 4

        public init() {}
    }

    public var reference: ReferencePitch
    public let configuration: Configuration

    private var recent: [Double] = []
    private var smoothed: Double?
    private var currentNote: Note?
    private var lastReading: PitchReading?
    private var missingCount = 0

    public init(reference: ReferencePitch = .standard, configuration: Configuration = Configuration()) {
        self.reference = reference
        self.configuration = configuration
        recent.reserveCapacity(configuration.medianLength)
    }

    /// Junta uma estimativa (ou a falta dela) e devolve a leitura a mostrar.
    public func process(_ estimate: PitchEstimate?) -> PitchReading? {
        guard let estimate, let midiNumber = reference.midiNumber(forFrequency: estimate.frequency) else {
            return handleMissingEstimate()
        }
        missingCount = 0

        if recent.count == configuration.medianLength { recent.removeFirst() }
        recent.append(midiNumber)
        let median = Self.median(of: recent)

        if let previous = smoothed, abs(median - previous) * 100 <= configuration.jumpCents {
            smoothed = previous + configuration.smoothingFactor * (median - previous)
        } else {
            smoothed = median
        }
        let value = smoothed ?? median

        let nearest = Note(midiNumber: Int(value.rounded()))
        if let note = currentNote {
            let limit = 0.5 + configuration.hysteresisCents / 100
            if abs(value - Double(note.midiNumber)) > limit { currentNote = nearest }
        } else {
            currentNote = nearest
        }
        let note = currentNote ?? nearest

        let reading = PitchReading(
            frequency: reference.frequency(ofMIDINumber: value),
            note: note,
            cents: (value - Double(note.midiNumber)) * 100
        )
        lastReading = reading
        return reading
    }

    public func reset() {
        recent.removeAll(keepingCapacity: true)
        smoothed = nil
        currentNote = nil
        lastReading = nil
        missingCount = 0
    }

    private func handleMissingEstimate() -> PitchReading? {
        missingCount += 1
        if missingCount > configuration.holdCount { reset() }
        return lastReading
    }

    private static func median(of values: [Double]) -> Double {
        let sorted = values.sorted()
        let middle = sorted.count / 2
        return sorted.count.isMultiple(of: 2) ? (sorted[middle - 1] + sorted[middle]) / 2 : sorted[middle]
    }
}
