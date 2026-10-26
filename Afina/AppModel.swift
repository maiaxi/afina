import AfinaCore
import AppKit
import Observation

/// Estado global da app: afinador, metrónomo, preferências gerais e persistência.
@Observable
@MainActor
final class AppModel {
    let tuner: TunerViewModel
    let metronome: MetronomeViewModel

    /// Mostrar o ícone na Dock (por defeito a app vive só na barra de menus).
    var showInDock: Bool {
        didSet { Self.applyActivationPolicy(showInDock: showInDock) }
    }

    /// Atalhos globais por ação; ações sem entrada usam o atalho por defeito.
    var shortcuts: [ShortcutAction: GlobalShortcut] {
        didSet { registerShortcuts() }
    }

    /// Ações cujo atalho está ocupado por outra app.
    private(set) var conflictingShortcuts: Set<ShortcutAction> = []

    /// Incrementado quando um atalho pede o afinador; a janela muda para esse separador.
    private(set) var tunerRequestCount = 0

    /// Abre janelas a partir de fora das vistas (atalhos globais). Definido pela etiqueta da
    /// barra de menus, que existe sempre.
    @ObservationIgnored var openWindow: ((String) -> Void)?

    @ObservationIgnored private let store = PreferencesStore()
    @ObservationIgnored private let hotKeys = GlobalHotKeyCenter()

    init() {
        tuner = TunerViewModel(preferences: store.load(TunerPreferences.self, key: .tuner) ?? TunerPreferences())
        metronome = MetronomeViewModel()
        metronome.engine.apply(store.load(MetronomePreferences.self, key: .metronome) ?? MetronomePreferences())
        showInDock = store.load(Bool.self, key: .showInDock) ?? false
        let savedShortcuts = store.load([String: GlobalShortcut].self, key: .shortcuts) ?? [:]
        shortcuts = Dictionary(uniqueKeysWithValues: ShortcutAction.allCases.map { action in
            (action, savedShortcuts[action.rawValue] ?? action.defaultShortcut)
        })

        let store = store
        observeChanges(of: { [tuner] in tuner.preferences }) { store.save($0, key: .tuner) }
        observeChanges(of: { [metronome] in metronome.engine.preferences }) { store.save($0, key: .metronome) }
        observeChanges(of: { [weak self] in self?.showInDock ?? false }) { store.save($0, key: .showInDock) }
        observeChanges(of: { [weak self] in self?.shortcuts ?? [:] }) { shortcuts in
            store.save(Dictionary(uniqueKeysWithValues: shortcuts.map { ($0.key.rawValue, $0.value) }), key: .shortcuts)
        }

        hotKeys.onAction = { [weak self] action in self?.perform(action) }
        registerShortcuts()
    }

    private func registerShortcuts() {
        hotKeys.register(shortcuts)
        conflictingShortcuts = hotKeys.failedActions
    }

    private func perform(_ action: ShortcutAction) {
        switch action {
        case .toggleMetronome:
            metronome.togglePlayback()
        case .tapTempo:
            metronome.tap()
        case .openTuner:
            tunerRequestCount += 1
            openWindow?(WindowID.main)
            NSApplication.shared.activate()
        }
    }

    static func applyActivationPolicy(showInDock: Bool) {
        NSApplication.shared.setActivationPolicy(showInDock ? .regular : .accessory)
    }
}

/// Preferências guardadas em `UserDefaults` como JSON.
struct PreferencesStore {
    enum Key: String {
        case tuner, metronome, showInDock, shortcuts
    }

    var defaults = UserDefaults.standard

    func load<Value: Decodable>(_ type: Value.Type, key: Key) -> Value? {
        guard let data = defaults.data(forKey: key.rawValue) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }

    func save(_ value: some Encodable, key: Key) {
        guard let data = try? JSONEncoder().encode(value) else { return }
        defaults.set(data, forKey: key.rawValue)
    }
}

/// Chama `perform` com o novo valor sempre que alguma propriedade observável lida por `value` muda.
@MainActor
func observeChanges<Value: Equatable>(
    of value: @escaping @MainActor () -> Value,
    perform: @escaping @MainActor (Value) -> Void
) {
    withObservationTracking {
        _ = value()
    } onChange: {
        // `onChange` corre antes da alteração (willSet): lê-se o valor novo no ciclo seguinte.
        Task { @MainActor in
            perform(value())
            observeChanges(of: value, perform: perform)
        }
    }
}
