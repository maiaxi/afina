import Synchronization

/// Ring buffer lock-free de um produtor e um consumidor (SPSC) para amostras de áudio.
///
/// `write` só pode ser chamado pelo produtor (o tap de áudio); `read`, `availableToRead` e
/// `discardAll` só pelo consumidor (a análise). Nenhuma operação aloca memória nem bloqueia.
public final class SPSCRingBuffer: @unchecked Sendable {
    public let capacity: Int

    private let mask: Int
    private let storage: UnsafeMutablePointer<Float>
    // Contadores monótonos de amostras escritas/lidas; a posição real é `contador & mask`.
    private let writeCount = Atomic<Int>(0)
    private let readCount = Atomic<Int>(0)

    /// A capacidade efetiva é arredondada para a potência de 2 seguinte.
    public init(minimumCapacity: Int) {
        precondition(minimumCapacity > 0, "A capacidade tem de ser positiva")
        var capacity = 1
        while capacity < minimumCapacity { capacity <<= 1 }
        self.capacity = capacity
        mask = capacity - 1
        storage = .allocate(capacity: capacity)
        storage.initialize(repeating: 0, count: capacity)
    }

    deinit {
        storage.deallocate()
    }

    // MARK: Produtor

    /// Copia as amostras que couberem e devolve quantas foram escritas. Se o buffer estiver cheio,
    /// as restantes são descartadas (a análise prefere perder áudio novo a bloquear o thread de áudio).
    @discardableResult
    public func write(_ samples: UnsafeBufferPointer<Float>) -> Int {
        guard let source = samples.baseAddress else { return 0 }
        let written = writeCount.load(ordering: .relaxed)
        let read = readCount.load(ordering: .acquiring)
        let count = min(samples.count, capacity - (written - read))
        guard count > 0 else { return 0 }

        let start = written & mask
        let firstPart = min(count, capacity - start)
        (storage + start).update(from: source, count: firstPart)
        if count > firstPart {
            storage.update(from: source + firstPart, count: count - firstPart)
        }
        writeCount.store(written + count, ordering: .releasing)
        return count
    }

    // MARK: Consumidor

    public var availableToRead: Int {
        writeCount.load(ordering: .acquiring) - readCount.load(ordering: .relaxed)
    }

    /// Lê até `destination.count` amostras e devolve quantas foram lidas.
    @discardableResult
    public func read(into destination: UnsafeMutableBufferPointer<Float>) -> Int {
        guard let target = destination.baseAddress else { return 0 }
        let read = readCount.load(ordering: .relaxed)
        let written = writeCount.load(ordering: .acquiring)
        let count = min(destination.count, written - read)
        guard count > 0 else { return 0 }

        let start = read & mask
        let firstPart = min(count, capacity - start)
        target.update(from: storage + start, count: firstPart)
        if count > firstPart {
            (target + firstPart).update(from: storage, count: count - firstPart)
        }
        readCount.store(read + count, ordering: .releasing)
        return count
    }

    /// Descarta tudo o que estiver por ler (por exemplo, depois de mudar de dispositivo).
    public func discardAll() {
        readCount.store(writeCount.load(ordering: .acquiring), ordering: .releasing)
    }
}
