import Foundation

/// Sinais sintéticos para os testes (nada de ficheiros de áudio no repositório).
enum Signals {
    static func sine(frequency: Double, amplitude: Float, sampleRate: Double, count: Int) -> [Float] {
        (0..<count).map { index in
            amplitude * Float(sin(2 * .pi * frequency * Double(index) / sampleRate))
        }
    }
}
