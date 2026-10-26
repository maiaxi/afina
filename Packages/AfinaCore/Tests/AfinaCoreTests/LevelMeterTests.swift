import Foundation
import Testing
@testable import AfinaCore

struct LevelMeterTests {
    @Test func fullScaleSineIsMinus3dBFS() {
        let sine = Signals.sine(frequency: 440, amplitude: 1, sampleRate: 48_000, count: 48_000)
        sine.withUnsafeBufferPointer { samples in
            let rms = LevelMeter.rms(of: samples)
            #expect(abs(rms - Float(1 / 2.0.squareRoot())) < 1e-3)
            #expect(abs(LevelMeter.decibelsFullScale(rms) + 3.01) < 0.01)
            #expect(abs(LevelMeter.peak(of: samples) - 1) < 1e-3)
        }
    }

    @Test func silenceIsFloored() {
        let silence = [Float](repeating: 0, count: 1024)
        silence.withUnsafeBufferPointer { samples in
            #expect(LevelMeter.rms(of: samples) == 0)
            #expect(LevelMeter.decibelsFullScale(0) == LevelMeter.silenceDecibels)
        }
        #expect(LevelMeter.decibelsFullScale(1e-20) == LevelMeter.silenceDecibels)
        #expect(LevelMeter.rms(of: UnsafeBufferPointer(start: nil, count: 0)) == 0)
    }

    @Test func peakUsesMagnitude() {
        let samples: [Float] = [0.1, -0.8, 0.5]
        samples.withUnsafeBufferPointer { #expect(LevelMeter.peak(of: $0) == 0.8) }
    }

    @Test func atomicFloatStoresExactValue() {
        let value = AtomicFloat()
        #expect(value.load() == 0)
        value.store(-0.123)
        #expect(value.load() == -0.123)
    }
}
