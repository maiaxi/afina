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
            BeatIndicatorView(
                pattern: engine.beatPattern,
                currentPulse: metronome.currentPulse,
                onSelect: engine.cycleSound(atPulse:)
            )

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
            // Sem `step`: com 281 valores o macOS desenha uma marca por passo. Arredonda-se à mão.
            Slider(value: roundedBPM, in: MetronomeEngine.bpmRange) {
                Text(verbatim: "BPM")
            }
            .labelsHidden()
        }
    }

    private var roundedBPM: Binding<Double> {
        Binding(get: { engine.bpm }, set: { engine.bpm = $0.rounded() })
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

/// Um círculo por pulso, com o tamanho a indicar o som (acento, tempo, fraco; só contorno =
/// silêncio). Carregar num círculo muda o som desse pulso.
struct BeatIndicatorView: View {
    let pattern: BeatPattern
    let currentPulse: Int?
    let onSelect: (Int) -> Void

    var body: some View {
        // 12 pulsos (12/8) têm de caber nos ~280 pt do popover
        let isCompact = pattern.sounds.count > 7
        HStack(spacing: isCompact ? 2 : 8) {
            ForEach(Array(pattern.sounds.enumerated()), id: \.offset) { pulse, sound in
                Button {
                    onSelect(pulse)
                } label: {
                    PulseDot(sound: sound, isCurrent: pulse == currentPulse)
                        .frame(width: isCompact ? 21 : 24, height: 24)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help(Text("Carrega para mudar o som deste tempo"))
                .accessibilityLabel(Text("Tempo \(pulse + 1)"))
                .accessibilityValue(Self.soundName(sound))
                .accessibilityHint(Text("Carrega para mudar o som deste tempo"))
                .accessibilityAddTraits(pulse == currentPulse ? .isSelected : [])
            }
        }
        .frame(height: 24)
    }

    private static func soundName(_ sound: PulseSound) -> Text {
        switch sound {
        case .accent: Text("Acento")
        case .beat: Text("Tempo forte")
        case .weakBeat: Text("Tempo fraco")
        case .silent: Text("Silêncio")
        }
    }
}

private struct PulseDot: View {
    let sound: PulseSound
    let isCurrent: Bool

    var body: some View {
        if sound == .silent {
            Circle()
                .strokeBorder(isCurrent ? AnyShapeStyle(.tint) : AnyShapeStyle(.tertiary), lineWidth: 1.5)
                .frame(width: 11, height: 11)
        } else {
            Circle()
                .fill(fill)
                .frame(width: size, height: size)
        }
    }

    private var size: CGFloat {
        switch sound {
        case .accent: 22
        case .beat: 16
        case .weakBeat, .silent: 11
        }
    }

    private var fill: AnyShapeStyle {
        guard isCurrent else { return AnyShapeStyle(.quaternary) }
        return sound == .accent ? AnyShapeStyle(.orange) : AnyShapeStyle(.tint)
    }
}

#Preview("Indicador 7/8") {
    BeatIndicatorView(pattern: BeatPattern(defaultFor: .sevenEight), currentPulse: 2, onSelect: { _ in })
        .padding()
}

#Preview("Padrão com silêncio") {
    BeatIndicatorView(pattern: BeatPattern(sounds: [.accent, .silent, .beat, .weakBeat]), currentPulse: 1, onSelect: { _ in })
        .padding()
}

#Preview("Metrónomo parado") {
    MetronomeView(metronome: MetronomeViewModel())
        .padding()
        .frame(width: 320)
}
