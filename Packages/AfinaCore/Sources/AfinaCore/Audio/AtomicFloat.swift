import Synchronization

/// `Float` partilhado entre threads sem locks (guardado como padrão de bits num `Atomic<UInt32>`).
/// Seguro para usar no thread de áudio.
public final class AtomicFloat: Sendable {
    private let bits: Atomic<UInt32>

    public init(_ value: Float = 0) {
        bits = Atomic(value.bitPattern)
    }

    public func load() -> Float {
        Float(bitPattern: bits.load(ordering: .relaxed))
    }

    public func store(_ value: Float) {
        bits.store(value.bitPattern, ordering: .relaxed)
    }
}
