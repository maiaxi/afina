import SwiftUI

/// Atalhos globais: ativar/desativar e escolher modificadores e tecla de cada ação.
struct ShortcutsSettingsView: View {
    @Bindable var model: AppModel

    var body: some View {
        Form {
            Section {
                ForEach(ShortcutAction.allCases) { action in
                    ShortcutRow(
                        title: Self.title(for: action),
                        shortcut: binding(for: action),
                        isConflicting: model.conflictingShortcuts.contains(action)
                    )
                }
            } footer: {
                Text("Funcionam em qualquer app, mesmo com o Afina em segundo plano.")
            }
        }
        .formStyle(.grouped)
    }

    private func binding(for action: ShortcutAction) -> Binding<GlobalShortcut> {
        Binding(
            get: { model.shortcuts[action] ?? action.defaultShortcut },
            set: { model.shortcuts[action] = $0 }
        )
    }

    private static func title(for action: ShortcutAction) -> LocalizedStringKey {
        switch action {
        case .toggleMetronome: "Tocar/parar o metrónomo"
        case .tapTempo: "Tap tempo"
        case .openTuner: "Abrir o afinador"
        }
    }
}

private struct ShortcutRow: View {
    let title: LocalizedStringKey
    @Binding var shortcut: GlobalShortcut
    let isConflicting: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Toggle(title, isOn: $shortcut.isEnabled)
                Spacer()
                Picker("Modificadores", selection: $shortcut.modifiers) {
                    ForEach(ShortcutModifiers.allCases, id: \.self) { modifiers in
                        Text(verbatim: modifiers.symbols).tag(modifiers)
                    }
                }
                .labelsHidden()
                .frame(width: 80)
                Picker("Tecla", selection: $shortcut.key) {
                    ForEach(ShortcutKey.allCases, id: \.self) { key in
                        Text(verbatim: key.rawValue).tag(key)
                    }
                }
                .labelsHidden()
                .frame(width: 60)
            }

            if isConflicting && shortcut.isEnabled {
                Label("Este atalho já está a ser usado por outra app. Escolhe outra combinação.", systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
        }
    }
}
