import AfinaCore
import SwiftUI

/// Cordas da afinação: destaca a que está a ser ouvida e marca as já afinadas.
struct StringsView: View {
    let notes: [Note]
    let activeIndex: Int?
    let tunedIndices: Set<Int>
    let notation: NoteNotation

    var body: some View {
        HStack(spacing: 8) {
            ForEach(Array(notes.enumerated()), id: \.offset) { index, note in
                StringBadge(
                    name: note.pitchClass.name(in: notation),
                    isActive: index == activeIndex,
                    isTuned: tunedIndices.contains(index)
                )
            }
        }
    }
}

private struct StringBadge: View {
    let name: String
    let isActive: Bool
    let isTuned: Bool

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Text(verbatim: name)
                .font(.system(.callout, design: .rounded).weight(isActive ? .bold : .regular))
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .frame(width: 38, height: 38)
                .background(Circle().fill(isActive ? AnyShapeStyle(.tint) : AnyShapeStyle(.quaternary)))
                .foregroundStyle(isActive ? AnyShapeStyle(.white) : AnyShapeStyle(.primary))

            if isTuned {
                Image(systemName: "checkmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(.white, .green)
                    .offset(x: 3, y: -3)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: name))
        .accessibilityValue(isTuned ? Text("Afinada") : Text(verbatim: ""))
        .accessibilityAddTraits(isActive ? .isSelected : [])
    }
}

#Preview {
    StringsView(
        notes: Instrument.guitar.tunings[0].notes,
        activeIndex: 2,
        tunedIndices: [0, 1],
        notation: .latin
    )
    .padding()
}
