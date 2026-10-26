import AfinaCore
import SwiftUI

/// Afinador completo: modo, escolhas de instrumento, nota, medidor de cents e cordas.
struct TunerView: View {
    @Bindable var tuner: TunerViewModel

    var body: some View {
        VStack(spacing: 16) {
            Picker("Modo", selection: $tuner.mode) {
                Text("Instrumento").tag(TunerMode.instrument)
                Text("Cromático").tag(TunerMode.chromatic)
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            if tuner.mode == .instrument {
                InstrumentControlsView(tuner: tuner)
            }

            NoteDisplayView(
                target: tuner.target,
                frequency: tuner.analysis?.reading?.frequency,
                isSignalPresent: tuner.isSignalPresent,
                tolerance: tuner.tolerance,
                notation: tuner.notation
            )

            CentsMeterView(cents: tuner.target?.cents, tolerance: tuner.tolerance)

            if tuner.mode == .instrument {
                StringsView(
                    notes: tuner.activeTuning.notes,
                    activeIndex: tuner.target?.stringIndex,
                    tunedIndices: tuner.progress.tunedStrings,
                    notation: tuner.notation
                )
            }

            Stepper(value: $tuner.referenceFrequency, in: ReferencePitch.allowedRange, step: 1) {
                Text("Lá = \(Int(tuner.reference.a4)) Hz")
                    .monospacedDigit()
            }
        }
    }
}
