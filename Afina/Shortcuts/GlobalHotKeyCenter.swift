import Carbon.HIToolbox

/// Regista atalhos globais com `RegisterEventHotKey` (Carbon). Funciona com App Sandbox e não
/// precisa de permissão de Acessibilidade, ao contrário de monitorizar o teclado.
@MainActor
final class GlobalHotKeyCenter {
    /// Chamado no thread principal quando um atalho é premido.
    var onAction: ((ShortcutAction) -> Void)?

    /// Ações cujo atalho não foi possível registar (normalmente já usado por outra app).
    private(set) var failedActions: Set<ShortcutAction> = []

    private var registrations: [EventHotKeyRef] = []
    private var eventHandler: EventHandlerRef?
    private static let signature: OSType = 0x4146_4E41 // "AFNA"

    /// Substitui todos os atalhos registados pelos de `shortcuts`.
    func register(_ shortcuts: [ShortcutAction: GlobalShortcut]) {
        installEventHandlerIfNeeded()
        for registration in registrations {
            UnregisterEventHotKey(registration)
        }
        registrations.removeAll()
        failedActions.removeAll()

        for (index, action) in ShortcutAction.allCases.enumerated() {
            guard let shortcut = shortcuts[action], shortcut.isEnabled else { continue }
            var reference: EventHotKeyRef?
            let status = RegisterEventHotKey(
                UInt32(shortcut.key.keyCode),
                shortcut.modifiers.carbonFlags,
                EventHotKeyID(signature: Self.signature, id: UInt32(index)),
                GetApplicationEventTarget(),
                0,
                &reference
            )
            if status == noErr, let reference {
                registrations.append(reference)
            } else {
                failedActions.insert(action)
            }
        }
    }

    private func installEventHandlerIfNeeded() {
        guard eventHandler == nil else { return }
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        // O centro vive enquanto a app vive (é do AppModel), por isso a referência não retida é segura.
        let context = Unmanaged.passUnretained(self).toOpaque()
        InstallEventHandler(GetApplicationEventTarget(), { _, event, context in
            guard let event, let context else { return OSStatus(eventNotHandledErr) }
            var hotKeyID = EventHotKeyID()
            let status = GetEventParameter(
                event,
                EventParamName(kEventParamDirectObject),
                EventParamType(typeEventHotKeyID),
                nil,
                MemoryLayout<EventHotKeyID>.size,
                nil,
                &hotKeyID
            )
            guard status == noErr else { return status }
            let center = Unmanaged<GlobalHotKeyCenter>.fromOpaque(context).takeUnretainedValue()
            // Os eventos Carbon da aplicação chegam no run loop principal.
            MainActor.assumeIsolated { center.handle(hotKeyID) }
            return noErr
        }, 1, &eventType, context, &eventHandler)
    }

    private func handle(_ hotKeyID: EventHotKeyID) {
        guard hotKeyID.signature == Self.signature,
              ShortcutAction.allCases.indices.contains(Int(hotKeyID.id))
        else { return }
        onAction?(ShortcutAction.allCases[Int(hotKeyID.id)])
    }
}
