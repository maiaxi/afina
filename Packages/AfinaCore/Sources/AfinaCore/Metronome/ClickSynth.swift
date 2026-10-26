import Foundation

/// Tipos de clique, do mais forte para o mais fraco.
public enum ClickKind: Int, CaseIterable, Sendable {
    /// Primeiro pulso do compasso.
    case accent
    /// Início de cada grupo (todos os pulsos nos compassos simples).
    case beat
    /// Pulsos dentro de um grupo (6/8, 7/8, 12/8).
    case weakBeat
    /// Cliques entre pulsos.
    case subdivision

    // Cada tipo difere na altura e no volume: só com o volume (menos de 3 dB) não se distinguiam.
    var frequency: Double {
        switch self {
        case .accent: 1500
        case .beat: 1000
        case .weakBeat: 800
        case .subdivision: 600
        }
    }

    var amplitude: Float {
        switch self {
        case .accent: 1
        case .beat: 0.8
        case .weakBeat: 0.5
        case .subdivision: 0.35
        }
    }
}

/// Timbre dos cliques.
public enum ClickSound: String, CaseIterable, Codable, Sendable {
    /// Cosseno curto: limpo e agudo.
    case beep
    /// Parciais inarmónicos com decaimento rápido, lembra um bloco de madeira.
    case wood
}

/// Sons de clique sintetizados, normalizados para o pico ser exatamente `kind.amplitude`.
/// A primeira amostra nunca é zero, o que torna o início de cada clique fácil de medir nos testes.
public enum ClickSynth {
    public static let duration = 0.03

    public static func length(sampleRate: Double) -> Int {
        Int((duration * sampleRate).rounded())
    }

    public static func click(_ kind: ClickKind, sound: ClickSound = .beep, sampleRate: Double) -> [Float] {
        let length = length(sampleRate: sampleRate)
        let attack = max(1, Int(attackTime(sound) * sampleRate))
        let decayTime = decayTime(sound)
        let raw: [Double] = (0..<length).map { index in
            let time = Double(index) / sampleRate
            let envelope = index < attack
                ? Double(index + 1) / Double(attack)
                : exp(-(time - Double(attack) / sampleRate) / decayTime)
            return envelope * waveform(sound, frequency: kind.frequency, time: time)
        }
        let peak = raw.map(abs).max() ?? 1
        return raw.map { kind.amplitude * Float($0 / peak) }
    }

    private static func attackTime(_ sound: ClickSound) -> Double {
        switch sound {
        case .beep: 0.001
        case .wood: 0.0003
        }
    }

    private static func decayTime(_ sound: ClickSound) -> Double {
        switch sound {
        case .beep: 0.008
        case .wood: 0.004
        }
    }

    private static func waveform(_ sound: ClickSound, frequency: Double, time: Double) -> Double {
        switch sound {
        case .beep:
            cos(2 * .pi * frequency * time)
        case .wood:
            // Parciais de uma barra livre (1 : 2,76 : 5,40), uma oitava acima para soar a "toc"
            cos(2 * .pi * 2 * frequency * time)
                + 0.5 * cos(2 * .pi * 2 * 2.76 * frequency * time)
                + 0.25 * cos(2 * .pi * 2 * 5.40 * frequency * time)
        }
    }
}
