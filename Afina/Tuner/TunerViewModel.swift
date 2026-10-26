import AfinaCore
import Foundation
import Observation

/// Estado do afinador para a UI: permissão, dispositivos, nível de entrada e leitura de pitch.
@Observable
@MainActor
final class TunerViewModel {
    private(set) var permission = MicrophonePermission.status
    private(set) var level = InputLevel.silence
    private(set) var devices: [AudioDevice] = []
    private(set) var analysis: PitchAnalyzer.Output?

    let audioInput = AudioInput()

    @ObservationIgnored private var deviceObserver: AudioDeviceChangeObserver?
    @ObservationIgnored private var analyzer: PitchAnalyzer?

    /// Cadência de atualização da UI (~30 Hz).
    private static let refreshInterval = Duration.milliseconds(33)

    var inputState: AudioInput.State { audioInput.state }

    var selectedDeviceUID: String? {
        get { audioInput.selectedDeviceUID }
        set { audioInput.selectedDeviceUID = newValue }
    }

    var activeDevice: AudioDevice? {
        if case .running(let format) = audioInput.state { format.device } else { nil }
    }

    /// Corre enquanto a vista estiver visível (usar com `.task`): o microfone só fica ligado
    /// durante esse tempo e desliga-se quando a tarefa é cancelada.
    func run() async {
        if MicrophonePermission.status == .notDetermined {
            _ = await MicrophonePermission.request()
        }
        permission = MicrophonePermission.status
        guard permission == .authorized else { return }

        refreshDevices()
        deviceObserver = AudioDeviceChangeObserver { [weak self] in self?.refreshDevices() }
        audioInput.start()
        defer {
            audioInput.stop()
            deviceObserver = nil
            level = .silence
            analysis = nil
            analyzer = nil
        }

        while !Task.isCancelled {
            level = audioInput.level
            analyzeAvailableAudio()
            try? await Task.sleep(for: Self.refreshInterval)
        }
    }

    /// A análise de uma janela custa poucas dezenas de µs, por isso corre aqui, ao ritmo da UI;
    /// o ring buffer absorve atrasos do thread principal.
    private func analyzeAvailableAudio() {
        guard case .running(let format) = audioInput.state else {
            analysis = nil
            return
        }
        if analyzer?.sampleRate != format.sampleRate {
            analyzer = PitchAnalyzer(sampleRate: format.sampleRate)
            audioInput.ringBuffer.discardAll()
        }
        if let output = analyzer?.process(from: audioInput.ringBuffer) {
            analysis = output
        }
    }

    private func refreshDevices() {
        devices = AudioDeviceCatalog.inputDevices()
    }
}
