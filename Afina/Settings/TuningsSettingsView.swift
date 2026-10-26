import AfinaCore
import SwiftUI

/// Lista e edição das afinações personalizadas de cada instrumento.
struct TuningsSettingsView: View {
    let tuner: TunerViewModel

    @State private var instrumentID = Instrument.guitar.id
    @State private var editing: EditorRequest?
    @State private var pendingDeletion: Tuning?

    private struct EditorRequest: Identifiable {
        let id = UUID()
        let tuning: Tuning
        let isNew: Bool
    }

    private var instrument: Instrument {
        Instrument.builtIn.first { $0.id == instrumentID } ?? .guitar
    }

    private var customTunings: [Tuning] {
        tuner.library.tunings(for: instrumentID)
    }

    var body: some View {
        Form {
            Picker("Instrumento", selection: $instrumentID) {
                ForEach(Instrument.builtIn) { instrument in
                    Text(LocalizedStringKey(instrument.name)).tag(instrument.id)
                }
            }

            Section("Afinações personalizadas") {
                if customTunings.isEmpty {
                    Text("Ainda não há afinações personalizadas para este instrumento.")
                        .foregroundStyle(.secondary)
                }
                ForEach(customTunings) { tuning in
                    row(for: tuning)
                }
            }

            Button("Nova afinação…", systemImage: "plus") {
                let base = instrument.tunings.first?.notes ?? []
                editing = EditorRequest(tuning: .custom(name: "", notes: base), isNew: true)
            }
        }
        .formStyle(.grouped)
        .sheet(item: $editing) { request in
            TuningEditorView(tuning: request.tuning, notation: tuner.notation) { saved in
                if request.isNew {
                    tuner.addCustomTuning(saved, to: instrumentID)
                } else {
                    tuner.updateCustomTuning(saved)
                }
            }
        }
        .confirmationDialog(
            "Apagar esta afinação?",
            isPresented: Binding(get: { pendingDeletion != nil }, set: { if !$0 { pendingDeletion = nil } }),
            presenting: pendingDeletion
        ) { tuning in
            Button("Apagar", role: .destructive) { tuner.removeCustomTuning(id: tuning.id) }
        } message: { tuning in
            Text(verbatim: tuning.name)
        }
    }

    private func row(for tuning: Tuning) -> some View {
        HStack {
            VStack(alignment: .leading) {
                Text(verbatim: tuning.name)
                Text(verbatim: tuning.notes.map { $0.name(in: tuner.notation) }.joined(separator: " "))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button("Editar", systemImage: "pencil") {
                editing = EditorRequest(tuning: tuning, isNew: false)
            }
            Button("Apagar", systemImage: "trash", role: .destructive) {
                pendingDeletion = tuning
            }
        }
        .labelStyle(.iconOnly)
        .buttonStyle(.borderless)
    }
}

/// Folha para criar ou editar uma afinação: nome e nota de cada corda.
struct TuningEditorView: View {
    @State private var tuning: Tuning
    let notation: NoteNotation
    let onSave: (Tuning) -> Void

    @Environment(\.dismiss) private var dismiss

    init(tuning: Tuning, notation: NoteNotation, onSave: @escaping (Tuning) -> Void) {
        _tuning = State(initialValue: tuning)
        self.notation = notation
        self.onSave = onSave
    }

    private var trimmedName: String {
        tuning.name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        VStack(spacing: 0) {
            Form {
                TextField("Nome", text: $tuning.name, prompt: Text("Por exemplo, Open C"))

                Section("Cordas") {
                    ForEach(tuning.notes.indices, id: \.self) { index in
                        noteRow(index)
                    }
                }
            }
            .formStyle(.grouped)

            HStack {
                Spacer()
                Button("Cancelar", role: .cancel) { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Guardar") {
                    tuning.name = trimmedName
                    onSave(tuning)
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(trimmedName.isEmpty)
            }
            .padding()
        }
        .frame(width: 400)
    }

    private func noteRow(_ index: Int) -> some View {
        let note = tuning.notes[index]
        return LabeledContent {
            HStack {
                Picker("Nota", selection: pitchClassBinding(index)) {
                    ForEach(PitchClass.allCases, id: \.self) { pitchClass in
                        Text(verbatim: pitchClass.name(in: notation)).tag(pitchClass)
                    }
                }
                .labelsHidden()
                .frame(width: 90)

                Stepper(value: octaveBinding(index), in: 0...6) {
                    Text(verbatim: "\(note.octave)")
                        .monospacedDigit()
                }
                .accessibilityLabel(Text("Oitava"))
            }
        } label: {
            Text("Corda \(index + 1)")
        }
    }

    private func pitchClassBinding(_ index: Int) -> Binding<PitchClass> {
        Binding(
            get: { tuning.notes[index].pitchClass },
            set: { tuning.notes[index] = Note($0, octave: tuning.notes[index].octave) }
        )
    }

    private func octaveBinding(_ index: Int) -> Binding<Int> {
        Binding(
            get: { tuning.notes[index].octave },
            set: { tuning.notes[index] = Note(tuning.notes[index].pitchClass, octave: $0) }
        )
    }
}
