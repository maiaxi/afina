import SwiftUI

@main
struct AfinaApp: App {
    var body: some Scene {
        MenuBarExtra("Afina", systemImage: "tuningfork") {
            MenuBarContentView()
        }
        .menuBarExtraStyle(.window)
    }
}
