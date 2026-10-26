import AfinaCore
import SwiftUI

/// Nota grande com oitava, frequência e desvio em cents.
struct NoteDisplayView: View {
    let target: TunerTarget?
    let frequency: Double?
    let isSignalPresent: Bool
    let tolerance: Double
    let notation: NoteNotation

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(verbatim: target?.note.pitchClass.name(in: notation) ?? "–")
                    .font(.system(size: 64, weight: .semibold, design: .rounded))
                    .foregroundStyle(noteColor)
                if let octave = target?.note.octave {
                    Text(verbatim: "\(octave)")
                        .font(.system(size: 24, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                }
            }
            .contentTransition(reduceMotion ? .identity : .numericText())

            detail
                .font(.callout.monospacedDigit())
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 110)
    }

    @ViewBuilder
    private var detail: some View {
        if let target, let frequency {
            HStack(spacing: 12) {
                // O ✓ indica "afinado" sem depender só da cor
                HStack(spacing: 3) {
                    if target.isInTune(tolerance: tolerance) {
                        Image(systemName: "checkmark")
                    }
                    Text(verbatim: Self.centsText(target.cents))
                }
                .foregroundStyle(noteColor)
                Text(verbatim: frequency.formatted(.number.precision(.fractionLength(1))) + " Hz")
            }
        } else if isSignalPresent {
            Text(verbatim: " ")
        } else {
            Text("À espera de som…")
        }
    }

    private var noteColor: Color {
        guard let target else { return .secondary }
        return target.isInTune(tolerance: tolerance) ? .green : .orange
    }

    private static func centsText(_ cents: Double) -> String {
        cents.formatted(.number.precision(.fractionLength(0)).sign(strategy: .always(includingZero: false))) + "¢"
    }
}

#Preview("Afinada") {
    NoteDisplayView(
        target: TunerTarget(note: Note(.e, octave: 2), cents: 1.4, stringIndex: 0),
        frequency: 82.48, isSignalPresent: true, tolerance: 3, notation: .english
    )
}

#Preview("Desafinada, notação latina") {
    NoteDisplayView(
        target: TunerTarget(note: Note(.g, octave: 3), cents: -18, stringIndex: 3),
        frequency: 194, isSignalPresent: true, tolerance: 3, notation: .latin
    )
}

#Preview("Silêncio") {
    NoteDisplayView(target: nil, frequency: nil, isSignalPresent: false, tolerance: 3, notation: .english)
}
