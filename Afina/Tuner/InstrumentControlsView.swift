import AfinaCore
import SwiftUI

/// Instrumento, afinação e capotraste.
struct InstrumentControlsView: View {
    @Bindable var tuner: TunerViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Picker("Instrumento", selection: $tuner.instrumentID) {
                ForEach(tuner.instruments) { instrument in
                    Text(LocalizedStringKey(instrument.name)).tag(instrument.id)
                }
            }

            Picker("Afinação", selection: $tuner.tuningID) {
                ForEach(tuner.instrument.tunings) { tuning in
                    TuningName(tuning: tuning).tag(tuning.id)
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

/// Nome de uma afinação: traduzido nas pré-definidas, tal como escrito nas personalizadas.
struct TuningName: View {
    let tuning: Tuning

    var body: some View {
        if tuning.isCustom {
            Text(verbatim: tuning.name)
        } else {
            Text(LocalizedStringKey(tuning.name))
        }
    }
}
