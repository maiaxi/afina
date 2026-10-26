import AppKit
import SwiftUI

@main
struct AfinaApp: App {
    @NSApplicationDelegateAdaptor private var appDelegate: AppDelegate
    @State private var model = AppModel()

    var body: some Scene {
        MenuBarExtra {
            MenuBarContentView(model: model, isDetached: false)
        } label: {
            MenuBarLabel(model: model)
        }
        .menuBarExtraStyle(.window)

        Window("Afina", id: WindowID.main) {
            MenuBarContentView(model: model, isDetached: true)
        }
        .windowResizability(.contentSize)
        .defaultLaunchBehavior(.suppressed)

        Window("Definições do Afina", id: WindowID.settings) {
            SettingsView(model: model)
        }
        .windowResizability(.contentSize)
        .defaultLaunchBehavior(.suppressed)
    }
}

/// Ícone da barra de menus: mostra um metrónomo enquanto este toca. Como existe sempre, é também
/// por aqui que o `AppModel` recebe a ação de abrir janelas (usada pelos atalhos globais).
private struct MenuBarLabel: View {
    let model: AppModel
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Image(systemName: model.metronome.engine.isPlaying ? "metronome.fill" : "tuningfork")
            .accessibilityLabel(Text(verbatim: "Afina"))
            .onAppear {
                model.openWindow = { id in openWindow(id: id) }
            }
    }
}

enum WindowID {
    static let main = "main"
    static let settings = "settings"
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // O Info.plist arranca sem Dock (LSUIElement); aplica-se aqui a preferência guardada.
        let showInDock = PreferencesStore().load(Bool.self, key: .showInDock) ?? false
        AppModel.applyActivationPolicy(showInDock: showInDock)
    }

    /// Com a app na Dock, fechar a última janela não a termina: continua na barra de menus.
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }
}
