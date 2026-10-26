import Testing
@testable import AfinaCore

struct SPSCRingBufferTests {
    @Test func capacityIsRoundedUpToPowerOfTwo() {
        #expect(SPSCRingBuffer(minimumCapacity: 1).capacity == 1)
        #expect(SPSCRingBuffer(minimumCapacity: 100).capacity == 128)
        #expect(SPSCRingBuffer(minimumCapacity: 4096).capacity == 4096)
    }

    @Test func readsBackWhatWasWrittenInOrder() {
        let ring = SPSCRingBuffer(minimumCapacity: 8)
        #expect(write([1, 2, 3], to: ring) == 3)
        #expect(ring.availableToRead == 3)
        #expect(read(2, from: ring) == [1, 2])
        #expect(read(10, from: ring) == [3])
        #expect(ring.availableToRead == 0)
        #expect(read(4, from: ring) == [])
    }

    @Test func wrapsAroundTheEnd() {
        let ring = SPSCRingBuffer(minimumCapacity: 8)
        write([1, 2, 3, 4, 5, 6], to: ring)
        #expect(read(5, from: ring) == [1, 2, 3, 4, 5])
        // Escreve através do fim do armazenamento
        #expect(write([7, 8, 9, 10, 11, 12], to: ring) == 6)
        #expect(read(10, from: ring) == [6, 7, 8, 9, 10, 11, 12])
    }

    @Test func dropsSamplesWhenFull() {
        let ring = SPSCRingBuffer(minimumCapacity: 4)
        #expect(write([1, 2, 3, 4, 5, 6], to: ring) == 4)
        #expect(write([7], to: ring) == 0)
        #expect(read(10, from: ring) == [1, 2, 3, 4])
    }

    @Test func discardAllSkipsPendingSamples() {
        let ring = SPSCRingBuffer(minimumCapacity: 8)
        write([1, 2, 3], to: ring)
        ring.discardAll()
        #expect(ring.availableToRead == 0)
        write([4], to: ring)
        #expect(read(4, from: ring) == [4])
    }

    @Test func concurrentProducerAndConsumerPreserveOrder() async {
        let ring = SPSCRingBuffer(minimumCapacity: 1024)
        let total = 1_000_000

        let producer = Task.detached {
            var next = 0
            var chunk = [Float](repeating: 0, count: 300)
            while next < total {
                let count = min(chunk.count, total - next)
                for index in 0..<count { chunk[index] = Float(next + index) }
                let written = chunk.withUnsafeBufferPointer { ring.write(UnsafeBufferPointer(rebasing: $0[0..<count])) }
                next += written
            }
        }

        let consumer = Task.detached { () -> Bool in
            var expected = 0
            var chunk = [Float](repeating: 0, count: 257)
            while expected < total {
                let count = chunk.withUnsafeMutableBufferPointer { ring.read(into: $0) }
                for index in 0..<count where chunk[index] != Float(expected + index) {
                    return false
                }
                expected += count
            }
            return true
        }

        await producer.value
        #expect(await consumer.value)
    }

    // MARK: Auxiliares

    @discardableResult
    private func write(_ samples: [Float], to ring: SPSCRingBuffer) -> Int {
        samples.withUnsafeBufferPointer { ring.write($0) }
    }

    private func read(_ count: Int, from ring: SPSCRingBuffer) -> [Float] {
        var output = [Float](repeating: 0, count: count)
        let read = output.withUnsafeMutableBufferPointer { ring.read(into: $0) }
        return Array(output.prefix(read))
    }
}
