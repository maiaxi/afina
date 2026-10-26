import AfinaCore
import SwiftUI

/// Conteúdo do popover da barra de menus: afinador e metrónomo em separadores.
struct MenuBarContentView: View {
    let tuner: TunerViewModel
    let metronome: MetronomeViewModel

    private enum Section: Hashable {
        case tuner, metronome
    }

    @State private var section = Section.tuner

    var body: some View {
        VStack(spacing: 16) {
            Picker("Secção", selection: $section) {
                Text("Afinador").tag(Section.tuner)
                Text("Metrónomo").tag(Section.metronome)
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            switch section {
            case .tuner: TunerSectionView(tuner: tuner)
            case .metronome: MetronomeView(metronome: metronome)
            }

            Divider()
            HStack {
                Spacer()
                Button("Sair do Afina") {
                    NSApplication.shared.terminate(nil)
                }
                .keyboardShortcut("q")
            }
        }
        .padding(20)
        .frame(width: 320)
    }
}
