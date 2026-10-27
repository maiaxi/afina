import AfinaCore
import SwiftUI

/// Janela de Definições.
struct SettingsView: View {
    let model: AppModel

    var body: some View {
        TabView {
            Tab("Geral", systemImage: "gearshape") {
                GeneralSettingsView(model: model)
            }
            Tab("Afinador", systemImage: "tuningfork") {
                TunerSettingsView(tuner: model.tuner)
            }
            Tab("Afinações", systemImage: "list.bullet") {
                TuningsSettingsView(tuner: model.tuner)
            }
            Tab("Metrónomo", systemImage: "metronome") {
                MetronomeSettingsView(engine: model.metronome.engine)
            }
            Tab("Atalhos", systemImage: "keyboard") {
                ShortcutsSettingsView(model: model)
            }
        }
        .frame(width: 480)
    }
}

struct GeneralSettingsView: View {
    @Bindable var model: AppModel
    @Bindable private var tuner: TunerViewModel

    init(model: AppModel) {
        self.model = model
        tuner = model.tuner
    }

    var body: some View {
        Form {
            Toggle("Mostrar na Dock", isOn: $model.showInDock)
            Picker("Nomes das notas", selection: $tuner.notation) {
                Text(verbatim: "C D E F G A B").tag(NoteNotation.english)
                Text(verbatim: "Dó Ré Mi Fá Sol Lá Si").tag(NoteNotation.latin)
            }

            UpdatesSection(updater: model.updater)
        }
        .formStyle(.grouped)
    }
}

private struct UpdatesSection: View {
    @Bindable var updater: AppUpdater

    private var version: String {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? "?"
        let build = info?["CFBundleVersion"] as? String ?? "?"
        return "\(short) (\(build))"
    }

    var body: some View {
        Section {
            Toggle("Procurar atualizações automaticamente", isOn: $updater.automaticallyChecksForUpdates)
            LabeledContent {
                Button("Procurar agora", action: updater.checkForUpdates)
            } label: {
                Text("Versão \(version)")
            }
        } header: {
            Text("Atualizações")
        } footer: {
            if !updater.isEnabled {
                Text("As atualizações estão desligadas nas builds de desenvolvimento.")
            }
        }
        .disabled(!updater.isEnabled)
    }
}

struct TunerSettingsView: View {
    @Bindable var tuner: TunerViewModel

    var body: some View {
        Form {
            Section {
                Picker("Entrada", selection: $tuner.selectedDeviceUID) {
                    Text("Predefinição do sistema").tag(String?.none)
                    ForEach(tuner.devices) { device in
                        Text(verbatim: device.name).tag(Optional(device.uid))
                    }
                }
            }

            Section {
                Stepper(value: $tuner.tolerance, in: TunerPreferences.toleranceRange, step: 1) {
                    Text("Tolerância: ±\(Int(tuner.tolerance)) cents")
                }
            } footer: {
                Text("Desvio máximo para a nota ficar verde e a corda contar como afinada.")
            }

            Section {
                LabeledContent("Limiar de som") {
                    HStack {
                        Slider(value: $tuner.gateThresholdDecibels, in: TunerPreferences.gateThresholdRange)
                        Text(verbatim: "\(Int(tuner.gateThresholdDecibels)) dBFS")
                            .monospacedDigit()
                            .frame(width: 70, alignment: .trailing)
                    }
                }
                LabeledContent("Nível atual") {
                    GateMeterView(level: tuner.level, threshold: tuner.gateThresholdDecibels)
                }
            } footer: {
                Text("Abaixo deste nível o afinador fica à espera de som. Sobe-o se o ruído da sala aparecer como notas; desce-o se o instrumento não for detetado.")
            }
        }
        .formStyle(.grouped)
        // O medidor precisa do microfone enquanto este separador está visível.
        .task { await tuner.run() }
    }
}

/// Nível de entrada com a marca do limiar do noise gate.
private struct GateMeterView: View {
    let level: InputLevel
    let threshold: Float

    private static let floor: Float = -90

    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            ZStack(alignment: .leading) {
                Capsule().fill(.quaternary)
                Capsule()
                    .fill(level.rmsDecibels >= threshold ? AnyShapeStyle(.green) : AnyShapeStyle(.secondary))
                    .frame(width: width * fraction(level.rmsDecibels))
                Rectangle()
                    .fill(.primary)
                    .frame(width: 2)
                    .offset(x: width * fraction(threshold) - 1)
            }
        }
        .frame(height: 8)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Nível de entrada"))
        .accessibilityValue(Text(verbatim: "\(Int(level.rmsDecibels)) dBFS"))
    }

    private func fraction(_ decibels: Float) -> CGFloat {
        CGFloat(min(max((decibels - Self.floor) / -Self.floor, 0), 1))
    }
}

struct MetronomeSettingsView: View {
    @Bindable var engine: MetronomeEngine

    var body: some View {
        Form {
            Picker("Som do clique", selection: $engine.clickSound) {
                Text("Bip").tag(ClickSound.beep)
                Text("Madeira").tag(ClickSound.wood)
            }
        }
        .formStyle(.grouped)
    }
}
