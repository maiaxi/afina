import AfinaCore
import Foundation
import Observation

/// Estado do afinador para a UI. Por agora (fase 2) só permissão, dispositivos e nível de entrada.
@Observable
@MainActor
final class TunerViewModel {
    private(set) var permission = MicrophonePermission.status
    private(set) var level = InputLevel.silence
    private(set) var devices: [AudioDevice] = []

    let audioInput = AudioInput()

    @ObservationIgnored private var deviceObserver: AudioDeviceChangeObserver?

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
        }

        while !Task.isCancelled {
            level = audioInput.level
            try? await Task.sleep(for: Self.refreshInterval)
        }
    }

    private func refreshDevices() {
        devices = AudioDeviceCatalog.inputDevices()
    }
}
