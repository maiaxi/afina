/// Tempo a partir de toques: média dos intervalos dos últimos toques; recomeça depois de uma pausa.
public struct TapTempo: Sendable {
    public let maximumTaps: Int
    /// Segundos sem toques ao fim dos quais a contagem recomeça.
    public let resetInterval: Double

    private var taps: [Double] = []

    public init(maximumTaps: Int = 6, resetInterval: Double = 2) {
        precondition(maximumTaps >= 2)
        self.maximumTaps = maximumTaps
        self.resetInterval = resetInterval
    }

    /// Regista um toque no instante `time` (segundos, relógio monotónico) e devolve o BPM
    /// estimado, ou `nil` se ainda só houver um toque.
    public mutating func tap(at time: Double) -> Double? {
        if let last = taps.last, time - last > resetInterval || time <= last {
            taps.removeAll()
        }
        taps.append(time)
        if taps.count > maximumTaps { taps.removeFirst(taps.count - maximumTaps) }

        guard let first = taps.first, let last = taps.last, taps.count >= 2 else { return nil }
        let averageInterval = (last - first) / Double(taps.count - 1)
        return 60 / averageInterval
    }

    public mutating func reset() {
        taps.removeAll()
    }
}
