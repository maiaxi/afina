import AfinaCore
import SwiftUI

/// Metrónomo: indicador de pulsos, BPM, tap tempo, compasso, subdivisão e volume.
struct MetronomeView: View {
    let metronome: MetronomeViewModel
    @Bindable private var engine: MetronomeEngine

    init(metronome: MetronomeViewModel) {
        self.metronome = metronome
        engine = metronome.engine
    }

    var body: some View {
        VStack(spacing: 16) {
            BeatIndicatorView(signature: engine.timeSignature, currentPulse: metronome.currentPulse)

            bpmControls

            HStack(spacing: 12) {
                Button(action: metronome.togglePlayback) {
                    Label(
                        engine.isPlaying ? "Parar" : "Tocar",
                        systemImage: engine.isPlaying ? "stop.fill" : "play.fill"
                    )
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.space, modifiers: [])

                Button("Tap", action: metronome.tap)
                    .frame(width: 70)
            }
            .controlSize(.large)

            Picker("Compasso", selection: $engine.timeSignature) {
                ForEach(TimeSignature.all) { signature in
                    Text(verbatim: signature.id).tag(signature)
                }
            }

            Picker("Subdivisão", selection: $engine.subdivision) {
                Text("Nenhuma").tag(Subdivision.none)
                Text("Em 2").tag(Subdivision.two)
                Text("Em 3 (tercinas)").tag(Subdivision.three)
                Text("Em 4").tag(Subdivision.four)
            }

            HStack {
                Image(systemName: "speaker.fill")
                    .foregroundStyle(.secondary)
                Slider(value: $engine.volume, in: 0...1) {
                    Text("Volume")
                }
                .labelsHidden()
                Image(systemName: "speaker.wave.3.fill")
                    .foregroundStyle(.secondary)
            }

            if let startError = engine.startError {
                Label("Não foi possível iniciar o áudio.", systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.red)
                    .font(.callout)
                    .help(startError)
            }
        }
    }

    private var bpmControls: some View {
        VStack(spacing: 8) {
            HStack(spacing: 6) {
                stepButton(-5)
                stepButton(-1)
                VStack(spacing: 0) {
                    TextField("BPM", value: $engine.bpm, format: .number.precision(.fractionLength(0)))
                        .font(.system(size: 40, weight: .semibold, design: .rounded).monospacedDigit())
                        .multilineTextAlignment(.center)
                        .textFieldStyle(.plain)
                        .frame(width: 100)
                    Text(verbatim: "BPM")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                stepButton(1)
                stepButton(5)
            }
            Slider(value: $engine.bpm, in: MetronomeEngine.bpmRange, step: 1) {
                Text(verbatim: "BPM")
            }
            .labelsHidden()
        }
    }

    private func stepButton(_ delta: Double) -> some View {
        Button {
            metronome.adjustBPM(by: delta)
        } label: {
            Text(verbatim: delta > 0 ? "+\(Int(delta))" : "\(Int(delta))")
                .monospacedDigit()
                .frame(minWidth: 24)
        }
        .buttonStyle(.bordered)
        .accessibilityLabel(Text(delta > 0 ? "Aumentar \(Int(delta)) BPM" : "Diminuir \(Int(-delta)) BPM"))
    }
}

/// Um círculo por pulso; o primeiro (acento) é maior e os inícios de grupo médios.
struct BeatIndicatorView: View {
    let signature: TimeSignature
    let currentPulse: Int?

    var body: some View {
        HStack(spacing: signature.beats > 7 ? 4 : 8) {
            ForEach(0..<signature.beats, id: \.self) { pulse in
                Circle()
                    .fill(fill(for: pulse))
                    .frame(width: size(for: pulse), height: size(for: pulse))
                    .frame(width: 22, height: 22)
            }
        }
        .frame(height: 24)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Tempo"))
        .accessibilityValue(Text(verbatim: currentPulse.map { "\($0 + 1)/\(signature.beats)" } ?? "–"))
    }

    private func size(for pulse: Int) -> CGFloat {
        if pulse == 0 { return 22 }
        return signature.isGroupStart(pulse) ? 16 : 11
    }

    private func fill(for pulse: Int) -> AnyShapeStyle {
        guard pulse == currentPulse else { return AnyShapeStyle(.quaternary) }
        return pulse == 0 ? AnyShapeStyle(.orange) : AnyShapeStyle(.tint)
    }
}

#Preview("Indicador 7/8") {
    BeatIndicatorView(signature: .sevenEight, currentPulse: 2)
        .padding()
}

#Preview("Metrónomo parado") {
    MetronomeView(metronome: MetronomeViewModel())
        .padding()
        .frame(width: 320)
}
