/// Instrumento com as suas afinações. Para os pré-definidos, `name` é a chave de localização em pt-PT.
public struct Instrument: Identifiable, Hashable, Codable, Sendable {
    public let id: String
    public var name: String
    public var tunings: [Tuning]

    public init(id: String, name: String, tunings: [Tuning]) {
        self.id = id
        self.name = name
        self.tunings = tunings
    }
}
