// Afinações pré-definidas. A primeira de cada instrumento é a afinação por defeito.

private func tuning(_ id: String, _ name: String, _ notes: [(PitchClass, Int)]) -> Tuning {
    Tuning(id: id, name: name, notes: notes.map { Note($0.0, octave: $0.1) })
}

extension Instrument {
    public static let builtIn: [Instrument] = [guitar, bass4, bass5, ukulele, cavaquinho, portugueseGuitar]

    public static let guitar = Instrument(id: "guitar", name: "Guitarra", tunings: [
        tuning("guitar.standard", "Standard", [(.e, 2), (.a, 2), (.d, 3), (.g, 3), (.b, 3), (.e, 4)]),
        tuning("guitar.dropD", "Drop D", [(.d, 2), (.a, 2), (.d, 3), (.g, 3), (.b, 3), (.e, 4)]),
        tuning("guitar.halfStepDown", "Meio tom abaixo",
               [(.dSharp, 2), (.gSharp, 2), (.cSharp, 3), (.fSharp, 3), (.aSharp, 3), (.dSharp, 4)]),
        tuning("guitar.wholeStepDown", "Tom abaixo", [(.d, 2), (.g, 2), (.c, 3), (.f, 3), (.a, 3), (.d, 4)]),
        tuning("guitar.dadgad", "DADGAD", [(.d, 2), (.a, 2), (.d, 3), (.g, 3), (.a, 3), (.d, 4)]),
        tuning("guitar.openG", "Open G", [(.d, 2), (.g, 2), (.d, 3), (.g, 3), (.b, 3), (.d, 4)]),
        tuning("guitar.openD", "Open D", [(.d, 2), (.a, 2), (.d, 3), (.fSharp, 3), (.a, 3), (.d, 4)]),
        tuning("guitar.openE", "Open E", [(.e, 2), (.b, 2), (.e, 3), (.gSharp, 3), (.b, 3), (.e, 4)]),
    ])

    public static let bass4 = Instrument(id: "bass4", name: "Baixo (4 cordas)", tunings: [
        tuning("bass4.standard", "Standard", [(.e, 1), (.a, 1), (.d, 2), (.g, 2)]),
        tuning("bass4.dropD", "Drop D", [(.d, 1), (.a, 1), (.d, 2), (.g, 2)]),
    ])

    /// No Drop D de 5 cordas mantém-se o Si grave e desce-se o Mi para Ré (o Lá0 ficaria abaixo dos 30 Hz).
    public static let bass5 = Instrument(id: "bass5", name: "Baixo (5 cordas)", tunings: [
        tuning("bass5.standard", "Standard", [(.b, 0), (.e, 1), (.a, 1), (.d, 2), (.g, 2)]),
        tuning("bass5.dropD", "Drop D", [(.b, 0), (.d, 1), (.a, 1), (.d, 2), (.g, 2)]),
    ])

    /// Standard reentrante (Sol agudo).
    public static let ukulele = Instrument(id: "ukulele", name: "Ukulele", tunings: [
        tuning("ukulele.standard", "Standard", [(.g, 4), (.c, 4), (.e, 4), (.a, 4)]),
        tuning("ukulele.baritone", "Barítono", [(.d, 3), (.g, 3), (.b, 3), (.e, 4)]),
    ])

    public static let cavaquinho = Instrument(id: "cavaquinho", name: "Cavaquinho", tunings: [
        tuning("cavaquinho.standard", "Standard", [(.d, 4), (.g, 4), (.b, 4), (.d, 5)]),
    ])

    /// Uma nota por ordem (par de cordas), da 6.ª para a 1.ª. Nas ordens 4–6 o par é à oitava;
    /// aqui usa-se a corda mais grave do par. Coimbra fica um tom abaixo de Lisboa.
    public static let portugueseGuitar = Instrument(id: "portugueseGuitar", name: "Guitarra portuguesa", tunings: [
        tuning("portugueseGuitar.lisbon", "Lisboa", [(.d, 3), (.a, 3), (.b, 3), (.e, 4), (.a, 4), (.b, 4)]),
        tuning("portugueseGuitar.coimbra", "Coimbra", [(.c, 3), (.g, 3), (.a, 3), (.d, 4), (.g, 4), (.a, 4)]),
    ])
}
