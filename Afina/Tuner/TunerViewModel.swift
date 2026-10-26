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

    /// Mudar de instrumento seleciona a primeira afinação dele.
    var instrumentID = Instrument.guitar.id {
        didSet {
            guard instrumentID != oldValue else { return }
            tuningID = instrument.tunings.first?.id ?? tuningID
            progress.reset()
        }
    }

    var tuningID = Instrument.guitar.tunings[0].id {
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

    var gateThresholdDecibels: Float = -55 {
        didSet { analyzer?.configuration.gateThresholdDecibels = gateThresholdDecibels }
    }

    private(set) var library = TuningLibrary()

    var selectedDeviceUID: String? {
        get { audioInput.selectedDeviceUID }
        set { audioInput.selectedDeviceUID = newValue }
    }

    // MARK: Derivados

    var instruments: [Instrument] { library.instruments }

    var instrument: Instrument {
        instruments.first { $0.id == instrumentID } ?? Instrument.guitar
    }

    var tuning: Tuning {
        instrument.tunings.first { $0.id == tuningID } ?? instrument.tunings.first ?? Instrument.guitar.tunings[0]
    }

    var activeTuning: Tuning { tuning.withCapo(atFret: capo) }

    var target: TunerTarget? {
        TunerTarget(reading: analysis?.reading, mode: mode, tuning: activeTuning, reference: reference)
    }

    private(set) var progress = TuningProgress()

    var isSignalPresent: Bool { analysis?.isSignalPresent ?? false }

    var inputState: AudioInput.State { audioInput.state }

    var activeDevice: AudioDevice? {
        if case .running(let format) = audioInput.state { format.device } else { nil }
    }

    // MARK: Preferências

    init(preferences: TunerPreferences = TunerPreferences()) {
        library = preferences.library
        mode = preferences.mode
        instrumentID = preferences.instrumentID
        tuningID = preferences.tuningID
        capo = preferences.capo
        reference = ReferencePitch(a4: preferences.referenceA4)
        tolerance = preferences.tolerance
        notation = preferences.notation
        gateThresholdDecibels = preferences.gateThresholdDecibels
        audioInput.selectedDeviceUID = preferences.inputDeviceUID
    }

    var preferences: TunerPreferences {
        var preferences = TunerPreferences()
        preferences.mode = mode
        preferences.instrumentID = instrumentID
        preferences.tuningID = tuning.id
        preferences.capo = capo
        preferences.referenceA4 = reference.a4
        preferences.tolerance = tolerance
        preferences.notation = notation
        preferences.inputDeviceUID = selectedDeviceUID
        preferences.gateThresholdDecibels = gateThresholdDecibels
        preferences.library = library
        return preferences
    }

    // MARK: Afinações personalizadas

    func addCustomTuning(_ tuning: Tuning, to instrumentID: String) {
        library.add(tuning, to: instrumentID)
    }

    func updateCustomTuning(_ tuning: Tuning) {
        library.update(tuning)
        if tuning.id == tuningID { progress.reset() }
    }

    func removeCustomTuning(id: String) {
        library.remove(tuningID: id)
        if id == tuningID { tuningID = instrument.tunings.first?.id ?? tuningID }
    }

    // MARK: Ciclo de vida

    @ObservationIgnored private var deviceObserver: AudioDeviceChangeObserver?
    @ObservationIgnored private var analyzer: PitchAnalyzer?
    @ObservationIgnored private var viewerCount = 0
    @ObservationIgnored private var monitoringTask: Task<Void, Never>?
    @ObservationIgnored private var finishingTask: Task<Void, Never>?

    /// Cadência de atualização da UI (~30 Hz).
    private static let refreshInterval = Duration.milliseconds(33)

    /// Chamar com `.task` em cada vista que mostra o afinador (popover, janela, Definições).
    /// O microfone fica ligado enquanto houver pelo menos uma visível.
    func run() async {
        viewerCount += 1
        if viewerCount == 1 {
            // Espera que a monitorização anterior acabe de desligar antes de voltar a ligar
            let previous = finishingTask
            monitoringTask = Task {
                await previous?.value
                await monitor()
            }
        }

        while !Task.isCancelled {
            try? await Task.sleep(for: .seconds(3600))
        }

        viewerCount -= 1
        if viewerCount == 0 {
            monitoringTask?.cancel()
            finishingTask = monitoringTask
            monitoringTask = nil
        }
    }

    private func monitor() async {
        if MicrophonePermission.status == .notDetermined {
            _ = await MicrophonePermission.request()
        }
        permission = MicrophonePermission.status
        guard permission == .authorized, !Task.isCancelled else { return }

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
            var configuration = PitchAnalyzer.Configuration()
            configuration.gateThresholdDecibels = gateThresholdDecibels
            analyzer = PitchAnalyzer(sampleRate: format.sampleRate, reference: reference, configuration: configuration)
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
