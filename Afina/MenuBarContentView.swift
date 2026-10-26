import AfinaCore
import SwiftUI

/// Conteúdo do popover da barra de menus.
struct MenuBarContentView: View {
    let tuner: TunerViewModel

    var body: some View {
        VStack(spacing: 16) {
            content
            Divider()
            Button("Sair do Afina") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q")
        }
        .padding(20)
        .frame(width: 320)
        // O microfone só está ativo com o popover aberto.
        .task { await tuner.run() }
    }

    @ViewBuilder
    private var content: some View {
        switch tuner.permission {
        case .authorized:
            TunerView(tuner: tuner)
            Divider()
            InputSectionView(tuner: tuner)
        case .denied, .restricted:
            MicrophonePermissionView()
        case .notDetermined:
            ProgressView("A pedir acesso ao microfone…")
        }
    }
}
