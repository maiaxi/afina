import SwiftUI

/// Conteúdo do popover da barra de menus. Placeholder até à fase 4.
struct MenuBarContentView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "tuningfork")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)
            Text("Afinador e metrónomo em breve")
                .font(.headline)
            Divider()
            Button("Sair do Afina") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q")
        }
        .padding(20)
        .frame(width: 280)
    }
}

#Preview {
    MenuBarContentView()
}
