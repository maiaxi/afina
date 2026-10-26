import AfinaCore
import Foundation
import Observation

/// Estado do metrónomo para a UI. O motor continua a tocar com o popover fechado.
@Observable
@MainActor
final class MetronomeViewModel {
    let engine = MetronomeEngine()

    /// Pulso atual no compasso enquanto toca.
    private(set) var currentPulse: Int?

    @ObservationIgnored private var tapTempo = TapTempo()
    @ObservationIgnored private var positionTask: Task<Void, Never>?

    /// Cadência de atualização do indicador visual (~30 Hz).
    private static let refreshInterval = Duration.milliseconds(33)

    func togglePlayback() {
        engine.toggle()
        positionTask?.cancel()
        currentPulse = nil
        guard engine.isPlaying else { return }
        positionTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                self.currentPulse = self.engine.position?.pulse
                try? await Task.sleep(for: Self.refreshInterval)
            }
        }
    }

    func adjustBPM(by delta: Double) {
        engine.bpm = (engine.bpm + delta).rounded()
    }

    func tap() {
        if let bpm = tapTempo.tap(at: ProcessInfo.processInfo.systemUptime) {
            engine.bpm = bpm.rounded()
        }
    }
}
