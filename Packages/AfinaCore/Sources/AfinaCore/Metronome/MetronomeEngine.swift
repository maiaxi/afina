import AVFAudio
import Foundation
import Observation

/// Metrónomo com `AVAudioEngine` + `AVAudioSourceNode`. Motor próprio, independente do afinador,
/// para poder continuar a tocar com o afinador parado.
@Observable
@MainActor
public final class MetronomeEngine {
    public static let bpmRange: ClosedRange<Double> = 20...300

    public var bpm = 120.0 {
        didSet {
            bpm = min(max(bpm, Self.bpmRange.lowerBound), Self.bpmRange.upperBound)
            parameters.bpm = bpm
        }
    }

    public var timeSignature = TimeSignature.fourFour {
        didSet {
            let index = TimeSignature.all.firstIndex(of: timeSignature) ?? 0
            parameters.timeSignatureIndex.store(index, ordering: .relaxed)
        }
    }

    public var subdivision = Subdivision.none {
        didSet { parameters.subdivision.store(subdivision.rawValue, ordering: .relaxed) }
    }

    /// 0–1.
    public var volume: Float = 0.8 {
        didSet {
            volume = min(max(volume, 0), 1)
            parameters.volume.store(volume)
        }
    }

    public private(set) var isPlaying = false
    /// Descrição do último erro ao arrancar o áudio, se houver.
    public private(set) var startError: String?

    @ObservationIgnored private let parameters = MetronomeParameters()
    @ObservationIgnored private var engine: AVAudioEngine?
    @ObservationIgnored private var configurationObserver: (any NSObjectProtocol)?

    public init() {}

    /// Pulso atual no compasso (0 = primeiro) e contador de pulsos tocados desde o arranque.
    /// Barato: pode ser lido a cada frame da UI.
    public var position: (pulse: Int, count: Int)? {
        guard isPlaying else { return nil }
        let pulse = parameters.currentPulse.load(ordering: .relaxed)
        guard pulse >= 0 else { return nil }
        return (pulse, parameters.pulseCount.load(ordering: .relaxed))
    }

    public func start() {
        guard !isPlaying else { return }
        do {
            try startEngine()
            isPlaying = true
            startError = nil
        } catch {
            stopEngine()
            startError = error.localizedDescription
        }
    }

    public func stop() {
        guard isPlaying else { return }
        isPlaying = false
        stopEngine()
    }

    public func toggle() {
        isPlaying ? stop() : start()
    }

    // MARK: Motor

    private func startEngine() throws {
        let engine = AVAudioEngine()
        let sampleRate = engine.outputNode.outputFormat(forBus: 0).sampleRate
        guard sampleRate > 0,
              let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)
        else { throw CocoaError(.featureUnsupported) }

        let renderer = MetronomeRenderer(parameters: parameters, sampleRate: sampleRate)
        let source = Self.makeSourceNode(renderer: renderer, format: format)
        engine.attach(source)
        engine.connect(source, to: engine.mainMixerNode, format: format)

        parameters.currentPulse.store(-1, ordering: .relaxed)
        parameters.pulseCount.store(0, ordering: .relaxed)
        parameters.startGeneration.add(1, ordering: .releasing)
        parameters.isPlaying.store(true, ordering: .releasing)

        engine.prepare()
        try engine.start()
        self.engine = engine
        observeConfigurationChanges(of: engine)
    }

    private func stopEngine() {
        parameters.isPlaying.store(false, ordering: .releasing)
        if let configurationObserver {
            NotificationCenter.default.removeObserver(configurationObserver)
        }
        configurationObserver = nil
        engine?.stop()
        engine = nil
    }

    private func observeConfigurationChanges(of engine: AVAudioEngine) {
        configurationObserver = NotificationCenter.default.addObserver(
            forName: .AVAudioEngineConfigurationChange,
            object: engine,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.handleConfigurationChange() }
        }
    }

    /// Saída mudou (auscultadores, interface USB): recomeça no novo dispositivo/sample rate.
    private func handleConfigurationChange() {
        guard isPlaying, engine?.isRunning != true else { return }
        stopEngine()
        do {
            try startEngine()
        } catch {
            isPlaying = false
            startError = error.localizedDescription
        }
    }

    // MARK: Thread de áudio

    /// `nonisolated` para o bloco não herdar o `MainActor`: corre no thread de áudio.
    nonisolated private static func makeSourceNode(
        renderer: MetronomeRenderer,
        format: AVAudioFormat
    ) -> AVAudioSourceNode {
        AVAudioSourceNode(format: format) { _, _, frameCount, audioBufferList in
            let buffers = UnsafeMutableAudioBufferListPointer(audioBufferList)
            guard buffers.count > 0, let first = buffers[0].mData?.assumingMemoryBound(to: Float.self) else {
                return noErr
            }
            let frames = Int(frameCount)
            renderer.render(into: first, frameCount: frames)
            for index in 1..<max(1, buffers.count) {
                buffers[index].mData?.assumingMemoryBound(to: Float.self).update(from: first, count: frames)
            }
            return noErr
        }
    }
}
