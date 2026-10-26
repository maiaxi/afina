import AfinaCore
import SwiftUI

/// Dispositivo de entrada, nível do sinal e avisos sobre a entrada.
struct InputSectionView: View {
    @Bindable var tuner: TunerViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Picker("Entrada", selection: $tuner.selectedDeviceUID) {
                Text("Predefinição do sistema").tag(String?.none)
                ForEach(tuner.devices) { device in
                    Text(verbatim: device.name).tag(Optional(device.uid))
                }
            }

            InputLevelMeterView(level: tuner.level)

            if case .failed(let error) = tuner.inputState {
                Label(message(for: error), systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.red)
                    .font(.callout)
            }

            if tuner.activeDevice?.isBluetooth == true {
                Label("Microfones Bluetooth têm menos qualidade e mais latência. Para afinar, prefere o microfone interno ou uma interface de áudio.", systemImage: "info.circle")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func message(for error: AudioInputError) -> LocalizedStringKey {
        switch error {
        case .noInputDevice: "Nenhum dispositivo de entrada disponível."
        case .deviceUnavailable: "O dispositivo de entrada não está disponível."
        case .engineStartFailed: "Não foi possível iniciar o áudio."
        }
    }
}
