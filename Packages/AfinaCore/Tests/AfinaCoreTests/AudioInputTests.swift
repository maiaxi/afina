import AVFAudio
import Testing
@testable import AfinaCore

struct AudioInputTests {
    @Test func tapCopiesFirstChannelAndPublishesLevel() throws {
        let format = try #require(AVAudioFormat(standardFormatWithSampleRate: 48_000, channels: 2))
        let buffer = try #require(AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 1024))
        buffer.frameLength = 1024
        let channels = try #require(buffer.floatChannelData)
        let sine = Signals.sine(frequency: 1000, amplitude: 0.5, sampleRate: 48_000, count: 1024)
        for index in 0..<1024 {
            channels[0][index] = sine[index]
            channels[1][index] = 0.9 // segundo canal tem de ser ignorado
        }

        let ring = SPSCRingBuffer(minimumCapacity: 4096)
        let rms = AtomicFloat()
        let peak = AtomicFloat()
        let tap = AudioInput.makeTapBlock(ringBuffer: ring, rmsLevel: rms, peakLevel: peak)
        tap(buffer, AVAudioTime(sampleTime: 0, atRate: 48_000))

        var captured = [Float](repeating: 0, count: 2048)
        let count = captured.withUnsafeMutableBufferPointer { ring.read(into: $0) }
        #expect(count == 1024)
        #expect(Array(captured.prefix(count)) == sine)
        #expect(abs(rms.load() - 0.5 / Float(2.0.squareRoot())) < 1e-3)
        #expect(abs(peak.load() - 0.5) < 1e-3)
    }

    @Test func deviceCatalogListsOnlyInputs() {
        let devices = AudioDeviceCatalog.inputDevices()
        #expect(devices.allSatisfy { $0.inputChannelCount > 0 && !$0.name.isEmpty })
        #expect(Set(devices.map(\.uid)).count == devices.count)
        if let defaultID = AudioDeviceCatalog.defaultInputDeviceID() {
            #expect(devices.contains { $0.id == defaultID })
        }
    }
}
