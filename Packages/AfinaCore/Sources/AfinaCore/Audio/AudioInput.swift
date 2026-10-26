import AVFAudio
import CoreAudio
import Foundation
import Observation

public enum AudioInputError: Error, Hashable, Sendable {
    /// Não há nenhum dispositivo de entrada (ou o escolhido não tem canais de entrada).
    case noInputDevice
    /// O dispositivo existe mas não foi possível usá-lo.
    case deviceUnavailable
    case engineStartFailed(String)
}

/// Captura do microfone com `AVAudioEngine`.
///
/// O tap copia o primeiro canal (mono) para `ringBuffer` e publica o nível em atómicos, sem alocar
/// nem bloquear. A análise consome `ringBuffer`; a UI lê `level` à cadência que quiser.
/// Recupera sozinho de mudanças de configuração e de dispositivos a ligar/desligar.
@Observable
@MainActor
public final class AudioInput {
    public struct Format: Hashable, Sendable {
        public let device: AudioDevice
        public let sampleRate: Double
        public let channelCount: Int
    }

    public enum State: Hashable, Sendable {
        case stopped
        case running(Format)
        case failed(AudioInputError)
    }

    public private(set) var state: State = .stopped

    /// UID do dispositivo escolhido; `nil` segue a entrada por defeito do sistema.
    /// Se o escolhido não estiver ligado, usa-se a entrada por defeito até ele voltar.
    public var selectedDeviceUID: String? {
        didSet {
            guard selectedDeviceUID != oldValue, isActive else { return }
            restart()
        }
    }

    /// ~1,4 s a 48 kHz: folga para a análise se atrasar sem perder áudio.
    @ObservationIgnored public let ringBuffer = SPSCRingBuffer(minimumCapacity: 1 << 16)

    @ObservationIgnored private let rmsLevel = AtomicFloat()
    @ObservationIgnored private let peakLevel = AtomicFloat()
    @ObservationIgnored private var engine: AVAudioEngine?
    @ObservationIgnored private var configurationObserver: (any NSObjectProtocol)?
    @ObservationIgnored private var deviceObserver: AudioDeviceChangeObserver?
    @ObservationIgnored private var isActive = false

    private static let tapBufferSize: AVAudioFrameCount = 1024

    public init() {}

    /// Nível do último bloco capturado. Barato: pode ser lido a cada frame.
    public var level: InputLevel {
        InputLevel(rms: rmsLevel.load(), peak: peakLevel.load())
    }

    public func start() {
        guard !isActive else { return }
        isActive = true
        deviceObserver = AudioDeviceChangeObserver { [weak self] in
            self?.handleDeviceListChange()
        }
        startEngine()
    }

    public func stop() {
        guard isActive else { return }
        isActive = false
        deviceObserver = nil
        stopEngine()
        state = .stopped
    }

    // MARK: Motor

    private func restart() {
        stopEngine()
        startEngine()
    }

    private func startEngine() {
        do {
            state = .running(try makeRunningEngine())
        } catch {
            state = .failed(error)
        }
    }

    private func makeRunningEngine() throws(AudioInputError) -> Format {
        guard let device = resolveDevice() else { throw .noInputDevice }

        // Um motor novo por arranque: evita estado herdado do dispositivo anterior.
        let engine = AVAudioEngine()
        let input = engine.inputNode
        do {
            try input.auAudioUnit.setDeviceID(device.id)
        } catch {
            throw .deviceUnavailable
        }

        let hardwareFormat = input.inputFormat(forBus: 0)
        guard hardwareFormat.sampleRate > 0, hardwareFormat.channelCount > 0 else { throw .noInputDevice }

        // `format: nil` usa o formato do próprio nó e evita a exceção de formatos incompatíveis.
        input.installTap(
            onBus: 0,
            bufferSize: Self.tapBufferSize,
            format: nil,
            block: Self.makeTapBlock(ringBuffer: ringBuffer, rmsLevel: rmsLevel, peakLevel: peakLevel)
        )
        engine.prepare()
        do {
            try engine.start()
        } catch {
            input.removeTap(onBus: 0)
            throw .engineStartFailed(error.localizedDescription)
        }

        self.engine = engine
        observeConfigurationChanges(of: engine)
        ringBuffer.discardAll()

        let tapFormat = input.outputFormat(forBus: 0)
        return Format(device: device, sampleRate: tapFormat.sampleRate, channelCount: Int(tapFormat.channelCount))
    }

    private func stopEngine() {
        if let configurationObserver {
            NotificationCenter.default.removeObserver(configurationObserver)
        }
        configurationObserver = nil
        engine?.inputNode.removeTap(onBus: 0)
        engine?.stop()
        engine = nil
        rmsLevel.store(0)
        peakLevel.store(0)
    }

    private func resolveDevice() -> AudioDevice? {
        let devices = AudioDeviceCatalog.inputDevices()
        if let selectedDeviceUID, let selected = devices.first(where: { $0.uid == selectedDeviceUID }) {
            return selected
        }
        guard let defaultID = AudioDeviceCatalog.defaultInputDeviceID() else { return devices.first }
        return devices.first { $0.id == defaultID } ?? devices.first
    }

    // MARK: Mudanças externas

    private func observeConfigurationChanges(of engine: AVAudioEngine) {
        configurationObserver = NotificationCenter.default.addObserver(
            forName: .AVAudioEngineConfigurationChange,
            object: engine,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.handleConfigurationChange() }
        }
    }

    private func handleConfigurationChange() {
        // O AVAudioEngine para sozinho quando a configuração muda; se ainda corre, não há nada a fazer.
        guard isActive, engine?.isRunning != true else { return }
        restart()
    }

    private func handleDeviceListChange() {
        guard isActive else { return }
        let current: AudioDevice? = if case .running(let format) = state { format.device } else { nil }
        if current?.id != resolveDevice()?.id || current == nil {
            restart()
        }
    }

    // MARK: Thread de áudio

    /// Bloco do tap. `nonisolated` para não herdar o `MainActor` (correria no thread de áudio).
    /// Só lê o buffer, escreve no ring buffer e em atómicos: sem alocações, locks nem logging.
    nonisolated static func makeTapBlock(
        ringBuffer: SPSCRingBuffer,
        rmsLevel: AtomicFloat,
        peakLevel: AtomicFloat
    ) -> AVAudioNodeTapBlock {
        { buffer, _ in
            guard let channels = buffer.floatChannelData, buffer.stride == 1 else { return }
            let samples = UnsafeBufferPointer(start: channels[0], count: Int(buffer.frameLength))
            ringBuffer.write(samples)
            rmsLevel.store(LevelMeter.rms(of: samples))
            peakLevel.store(LevelMeter.peak(of: samples))
        }
    }
}
