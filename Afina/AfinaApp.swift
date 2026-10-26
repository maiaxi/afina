import SwiftUI

@main
struct AfinaApp: App {
    @State private var tuner = TunerViewModel()
    @State private var metronome = MetronomeViewModel()

    var body: some Scene {
        MenuBarExtra("Afina", systemImage: "tuningfork") {
            MenuBarContentView(tuner: tuner, metronome: metronome)
        }
        .menuBarExtraStyle(.window)
    }
}
