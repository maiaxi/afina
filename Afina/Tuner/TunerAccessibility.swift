import AfinaCore
import SwiftUI

/// Textos do VoiceOver para a leitura do afinador, por exemplo "Mi 2, 5 cents abaixo".
enum TunerAccessibility {
    static func label(for target: TunerTarget?, notation: NoteNotation) -> Text {
        guard let target else { return Text("À espera de som…") }
        return Text(verbatim: "\(spokenName(of: target.note.pitchClass, notation: notation)) \(target.note.octave)")
    }

    static func value(for target: TunerTarget?, tolerance: Double) -> Text {
        guard let target else { return Text(verbatim: "") }
        if target.isInTune(tolerance: tolerance) { return Text("Afinado") }
        let cents = Int(abs(target.cents).rounded())
        return target.cents < 0 ? Text("\(cents) cents abaixo") : Text("\(cents) cents acima")
    }

    /// O "♯" nem sempre é lido pelo VoiceOver; diz-se "sustenido"/"sharp" por extenso.
    private static func spokenName(of pitchClass: PitchClass, notation: NoteNotation) -> String {
        let name = pitchClass.name(in: notation)
        guard name.hasSuffix("♯") else { return name }
        return String(localized: "\(String(name.dropLast())) sustenido")
    }
}
