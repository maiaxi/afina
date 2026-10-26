import SwiftUI

@main
struct AfinaApp: App {
    @State private var tuner = TunerViewModel()

    var body: some Scene {
        MenuBarExtra("Afina", systemImage: "tuningfork") {
            MenuBarContentView(tuner: tuner)
        }
        .menuBarExtraStyle(.window)
    }
}
