import AfinaCore
import SwiftUI

/// Separador do afinador: trata da permissão do microfone e só mantém o microfone ligado
/// enquanto está visível.
struct TunerSectionView: View {
    let tuner: TunerViewModel

    var body: some View {
        VStack(spacing: 16) {
            switch tuner.permission {
            case .authorized:
                TunerView(tuner: tuner)
                Divider()
                InputSectionView(tuner: tuner)
            case .denied, .restricted:
                MicrophonePermissionView()
            case .notDetermined:
                ProgressView("A pedir acesso ao microfone…")
            }
        }
        .task { await tuner.run() }
    }
}
