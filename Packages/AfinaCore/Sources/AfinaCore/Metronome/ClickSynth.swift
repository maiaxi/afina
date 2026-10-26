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

    var frequency: Double {
        switch self {
        case .accent: 1500
        case .beat, .weakBeat: 1000
        case .subdivision: 800
        }
    }

    var amplitude: Float {
        switch self {
        case .accent: 1
        case .beat: 0.75
        case .weakBeat: 0.55
        case .subdivision: 0.4
        }
    }
}

/// Sons de clique sintetizados: cosseno curto com ataque linear de 1 ms e decaimento exponencial.
/// A primeira amostra nunca é zero, o que torna o início de cada clique fácil de medir nos testes.
public enum ClickSynth {
    public static let duration = 0.03

    public static func length(sampleRate: Double) -> Int {
        Int((duration * sampleRate).rounded())
    }

    public static func click(_ kind: ClickKind, sampleRate: Double) -> [Float] {
        let length = length(sampleRate: sampleRate)
        let attack = max(1, Int(0.001 * sampleRate))
        let decayTime = 0.008
        return (0..<length).map { index in
            let time = Double(index) / sampleRate
            let envelope = index < attack ? Double(index + 1) / Double(attack) : exp(-(time - Double(attack) / sampleRate) / decayTime)
            return kind.amplitude * Float(envelope * cos(2 * .pi * kind.frequency * time))
        }
    }
}
