import AfinaCore
import SwiftUI

/// Escolha do dispositivo de entrada, nível do sinal e leitura de pitch em bruto (para debug;
/// o afinador propriamente dito vem na fase 4).
struct InputMonitorView: View {
    @Bindable var tuner: TunerViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Picker("Entrada", selection: $tuner.selectedDeviceUID) {
                Text("Predefinição do sistema").tag(String?.none)
                ForEach(tuner.devices) { device in
                    Text(verbatim: device.name).tag(Optional(device.uid))
                }
            }

            InputLevelMeterView(level: tuner.level)

            pitchReadout

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

    @ViewBuilder
    private var pitchReadout: some View {
        if let reading = tuner.analysis?.reading {
            Text(verbatim: String(
                format: "%@  %+.1f¢  ·  %.2f Hz",
                reading.note.name(in: .english), reading.cents, reading.frequency
            ))
            .font(.title3.monospacedDigit())
        } else {
            Text("À espera de som…")
                .font(.title3)
                .foregroundStyle(.secondary)
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
