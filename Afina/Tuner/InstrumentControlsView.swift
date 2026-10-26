import AfinaCore
import SwiftUI

/// Instrumento, afinação e capotraste.
struct InstrumentControlsView: View {
    @Bindable var tuner: TunerViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Picker("Instrumento", selection: $tuner.instrument) {
                ForEach(Instrument.builtIn) { instrument in
                    Text(LocalizedStringKey(instrument.name)).tag(instrument)
                }
            }

            Picker("Afinação", selection: $tuner.tuning) {
                ForEach(tuner.instrument.tunings) { tuning in
                    Text(LocalizedStringKey(tuning.name)).tag(tuning)
                }
            }

            Stepper(value: $tuner.capo, in: 0...12) {
                if tuner.capo == 0 {
                    Text("Sem capotraste")
                } else {
                    Text("Capotraste na casa \(tuner.capo)")
                }
            }
        }
    }
}
