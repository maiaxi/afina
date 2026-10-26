import AppKit
import SwiftUI

/// Ecrã mostrado quando o acesso ao microfone foi recusado.
struct MicrophonePermissionView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "mic.slash")
                .font(.system(size: 36))
                .foregroundStyle(.secondary)
            Text("Sem acesso ao microfone")
                .font(.headline)
            Text("Para afinar, o Afina precisa de ouvir o teu instrumento. Ativa o acesso em Definições do Sistema → Privacidade e Segurança → Microfone.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            Button("Abrir Definições do Sistema", action: openMicrophoneSettings)
                .buttonStyle(.borderedProminent)
        }
    }

    private func openMicrophoneSettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone") else {
            return
        }
        NSWorkspace.shared.open(url)
    }
}

#Preview {
    MicrophonePermissionView()
        .padding()
        .frame(width: 280)
}
