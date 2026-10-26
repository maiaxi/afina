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

    @ObservationIgnored private let store = PreferencesStore()

    init() {
        tuner = TunerViewModel(preferences: store.load(TunerPreferences.self, key: .tuner) ?? TunerPreferences())
        metronome = MetronomeViewModel()
        metronome.engine.apply(store.load(MetronomePreferences.self, key: .metronome) ?? MetronomePreferences())
        showInDock = store.load(Bool.self, key: .showInDock) ?? false

        let store = store
        observeChanges(of: { [tuner] in tuner.preferences }) { store.save($0, key: .tuner) }
        observeChanges(of: { [metronome] in metronome.engine.preferences }) { store.save($0, key: .metronome) }
        observeChanges(of: { [weak self] in self?.showInDock ?? false }) { store.save($0, key: .showInDock) }
    }

    static func applyActivationPolicy(showInDock: Bool) {
        NSApplication.shared.setActivationPolicy(showInDock ? .regular : .accessory)
    }
}

/// Preferências guardadas em `UserDefaults` como JSON.
struct PreferencesStore {
    enum Key: String {
        case tuner, metronome, showInDock
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
