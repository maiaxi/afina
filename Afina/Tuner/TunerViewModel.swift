import AfinaCore
import Foundation
import Observation

/// Estado do afinador para a UI: permissão, entrada de áudio, escolhas do utilizador e leitura atual.
@Observable
@MainActor
final class TunerViewModel {
    // MARK: Entrada

    private(set) var permission = MicrophonePermission.status
    private(set) var level = InputLevel.silence
    private(set) var devices: [AudioDevice] = []
    private(set) var analysis: PitchAnalyzer.Output?

    let audioInput = AudioInput()

    // MARK: Escolhas

    var mode = TunerMode.instrument {
        didSet { progress.reset() }
    }

    var instrument = Instrument.guitar {
        didSet {
            guard instrument != oldValue, let first = instrument.tunings.first else { return }
            tuning = first
        }
    }

    var tuning = Instrument.guitar.tunings[0] {
        didSet { progress.reset() }
    }

    var capo = 0 {
        didSet { progress.reset() }
    }

    var reference = ReferencePitch.standard {
        didSet { analyzer?.reference = reference }
    }

    /// Lá de referência em Hz, para ligar diretamente a um `Stepper`.
    var referenceFrequency: Double {
        get { reference.a4 }
        set { reference = ReferencePitch(a4: newValue) }
    }

    /// Desvio máximo (em cents) para considerar a nota afinada.
    var tolerance = 3.0
    var notation = NoteNotation.english

    // MARK: Leitura

    private(set) var progress = TuningProgress()

    var activeTuning: Tuning { tuning.withCapo(atFret: capo) }

    var target: TunerTarget? {
        TunerTarget(reading: analysis?.reading, mode: mode, tuning: activeTuning, reference: reference)
    }

    var isSignalPresent: Bool { analysis?.isSignalPresent ?? false }

    var selectedDeviceUID: String? {
        get { audioInput.selectedDeviceUID }
        set { audioInput.selectedDeviceUID = newValue }
    }

    var inputState: AudioInput.State { audioInput.state }

    var activeDevice: AudioDevice? {
        if case .running(let format) = audioInput.state { format.device } else { nil }
    }

    // MARK: Ciclo de vida

    @ObservationIgnored private var deviceObserver: AudioDeviceChangeObserver?
    @ObservationIgnored private var analyzer: PitchAnalyzer?

    /// Cadência de atualização da UI (~30 Hz).
    private static let refreshInterval = Duration.milliseconds(33)

    /// Corre enquanto a vista estiver visível (usar com `.task`): o microfone só fica ligado
    /// durante esse tempo e desliga-se quando a tarefa é cancelada.
    func run() async {
        if MicrophonePermission.status == .notDetermined {
            _ = await MicrophonePermission.request()
        }
        permission = MicrophonePermission.status
        guard permission == .authorized else { return }

        refreshDevices()
        deviceObserver = AudioDeviceChangeObserver { [weak self] in self?.refreshDevices() }
        audioInput.start()
        defer {
            audioInput.stop()
            deviceObserver = nil
            level = .silence
            analysis = nil
            analyzer = nil
        }

        while !Task.isCancelled {
            level = audioInput.level
            analyzeAvailableAudio()
            try? await Task.sleep(for: Self.refreshInterval)
        }
    }

    /// A análise de uma janela custa poucas dezenas de µs, por isso corre aqui, ao ritmo da UI;
    /// o ring buffer absorve atrasos do thread principal.
    private func analyzeAvailableAudio() {
        guard case .running(let format) = audioInput.state else {
            analysis = nil
            return
        }
        if analyzer?.sampleRate != format.sampleRate {
            analyzer = PitchAnalyzer(sampleRate: format.sampleRate, reference: reference)
            audioInput.ringBuffer.discardAll()
        }
        guard let output = analyzer?.process(from: audioInput.ringBuffer) else { return }
        analysis = output
        if mode == .instrument {
            progress.update(with: target, tolerance: tolerance)
        }
    }

    private func refreshDevices() {
        devices = AudioDeviceCatalog.inputDevices()
    }
}
