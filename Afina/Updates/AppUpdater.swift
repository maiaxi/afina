import AppKit
import Observation
import Sparkle

/// Atualizações automáticas com Sparkle, a partir das releases do GitHub (ver `SUFeedURL`).
/// Nas builds de Debug o Sparkle não arranca, para não oferecer a release por cima da build local.
@Observable
@MainActor
final class AppUpdater {
    var automaticallyChecksForUpdates: Bool {
        didSet { controller.updater.automaticallyChecksForUpdates = automaticallyChecksForUpdates }
    }

    @ObservationIgnored private let userDriverDelegate = UserDriverDelegate()
    @ObservationIgnored private let controller: SPUStandardUpdaterController

    init() {
        #if DEBUG
        let startsUpdater = false
        #else
        let startsUpdater = true
        #endif
        controller = SPUStandardUpdaterController(
            startingUpdater: startsUpdater,
            updaterDelegate: nil,
            userDriverDelegate: userDriverDelegate
        )
        automaticallyChecksForUpdates = controller.updater.automaticallyChecksForUpdates
    }

    var isEnabled: Bool {
        #if DEBUG
        false
        #else
        true
        #endif
    }

    func checkForUpdates() {
        NSApplication.shared.activate()
        controller.checkForUpdates(nil)
    }
}

/// A app vive na barra de menus: as verificações em segundo plano mostram o aviso sem roubar o foco.
private final class UserDriverDelegate: NSObject, SPUStandardUserDriverDelegate {
    var supportsGentleScheduledUpdateReminders: Bool { true }
}
