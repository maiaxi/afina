import AfinaCore
import SwiftUI

/// Afinador e metrónomo em separadores. Usado no popover da barra de menus e na janela destacável.
struct MenuBarContentView: View {
    let model: AppModel
    /// `true` na janela: esconde o botão de abrir em janela.
    let isDetached: Bool

    private enum Section: Hashable {
        case tuner, metronome
    }

    @State private var section = Section.tuner
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(spacing: 16) {
            Picker("Secção", selection: $section) {
                Text("Afinador").tag(Section.tuner)
                Text("Metrónomo").tag(Section.metronome)
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            switch section {
            case .tuner: TunerSectionView(tuner: model.tuner)
            case .metronome: MetronomeView(metronome: model.metronome)
            }

            Divider()
            footer
        }
        .padding(20)
        .frame(width: 320)
        .onChange(of: model.tunerRequestCount) {
            if isDetached { section = .tuner }
        }
    }

    private var footer: some View {
        HStack(spacing: 12) {
            Button {
                open(WindowID.settings)
            } label: {
                Label("Definições", systemImage: "gearshape")
            }
            .keyboardShortcut(",")

            if !isDetached {
                Button {
                    open(WindowID.main)
                } label: {
                    Label("Abrir em janela", systemImage: "macwindow")
                }
            }

            Spacer()

            Button("Sair do Afina") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q")
        }
        .labelStyle(.iconOnly)
        .buttonStyle(.borderless)
    }

    private func open(_ id: String) {
        openWindow(id: id)
        NSApplication.shared.activate()
    }
}
