import Carbon.HIToolbox

/// Ações disponíveis por atalho global.
enum ShortcutAction: String, CaseIterable, Codable, Identifiable {
    case toggleMetronome
    case tapTempo
    case openTuner

    var id: String { rawValue }

    var defaultShortcut: GlobalShortcut {
        switch self {
        case .toggleMetronome: GlobalShortcut(key: .m, modifiers: .controlOption)
        case .tapTempo: GlobalShortcut(key: .t, modifiers: .controlOption)
        case .openTuner: GlobalShortcut(key: .a, modifiers: .controlOption)
        }
    }
}

/// Combinações de modificadores oferecidas. Uma lista fechada evita atalhos sem modificadores
/// (que roubariam teclas normais a todas as apps).
enum ShortcutModifiers: String, CaseIterable, Codable {
    case controlOption
    case controlOptionCommand
    case optionCommand
    case shiftCommand

    var symbols: String {
        switch self {
        case .controlOption: "⌃⌥"
        case .controlOptionCommand: "⌃⌥⌘"
        case .optionCommand: "⌥⌘"
        case .shiftCommand: "⇧⌘"
        }
    }

    var carbonFlags: UInt32 {
        switch self {
        case .controlOption: UInt32(controlKey | optionKey)
        case .controlOptionCommand: UInt32(controlKey | optionKey | cmdKey)
        case .optionCommand: UInt32(optionKey | cmdKey)
        case .shiftCommand: UInt32(shiftKey | cmdKey)
        }
    }
}

/// Teclas de letras e algarismos (posições ANSI).
enum ShortcutKey: String, CaseIterable, Codable {
    case a = "A", b = "B", c = "C", d = "D", e = "E", f = "F", g = "G", h = "H", i = "I", j = "J"
    case k = "K", l = "L", m = "M", n = "N", o = "O", p = "P", q = "Q", r = "R", s = "S", t = "T"
    case u = "U", v = "V", w = "W", x = "X", y = "Y", z = "Z"
    case zero = "0", one = "1", two = "2", three = "3", four = "4"
    case five = "5", six = "6", seven = "7", eight = "8", nine = "9"

    var keyCode: Int {
        switch self {
        case .a: kVK_ANSI_A
        case .b: kVK_ANSI_B
        case .c: kVK_ANSI_C
        case .d: kVK_ANSI_D
        case .e: kVK_ANSI_E
        case .f: kVK_ANSI_F
        case .g: kVK_ANSI_G
        case .h: kVK_ANSI_H
        case .i: kVK_ANSI_I
        case .j: kVK_ANSI_J
        case .k: kVK_ANSI_K
        case .l: kVK_ANSI_L
        case .m: kVK_ANSI_M
        case .n: kVK_ANSI_N
        case .o: kVK_ANSI_O
        case .p: kVK_ANSI_P
        case .q: kVK_ANSI_Q
        case .r: kVK_ANSI_R
        case .s: kVK_ANSI_S
        case .t: kVK_ANSI_T
        case .u: kVK_ANSI_U
        case .v: kVK_ANSI_V
        case .w: kVK_ANSI_W
        case .x: kVK_ANSI_X
        case .y: kVK_ANSI_Y
        case .z: kVK_ANSI_Z
        case .zero: kVK_ANSI_0
        case .one: kVK_ANSI_1
        case .two: kVK_ANSI_2
        case .three: kVK_ANSI_3
        case .four: kVK_ANSI_4
        case .five: kVK_ANSI_5
        case .six: kVK_ANSI_6
        case .seven: kVK_ANSI_7
        case .eight: kVK_ANSI_8
        case .nine: kVK_ANSI_9
        }
    }
}

struct GlobalShortcut: Hashable, Codable {
    var isEnabled = true
    var key: ShortcutKey
    var modifiers: ShortcutModifiers

    var displayName: String { modifiers.symbols + key.rawValue }
}
