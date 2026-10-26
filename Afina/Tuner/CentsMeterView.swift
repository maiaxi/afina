import SwiftUI

/// Escala de -50 a +50 cents com agulha e zona verde de tolerância.
/// Desvios maiores do que ±50 encostam a agulha à ponta.
struct CentsMeterView: View {
    let cents: Double?
    let tolerance: Double

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorSchemeContrast) private var contrast

    private static let range = 50.0
    private static let tickValues = stride(from: -50, through: 50, by: 10).map(Double.init)

    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            ZStack {
                RoundedRectangle(cornerRadius: 3)
                    .fill(.green.opacity(contrast == .increased ? 0.5 : 0.25))
                    .frame(width: width * tolerance / Self.range, height: geometry.size.height)

                ForEach(Self.tickValues, id: \.self) { value in
                    Rectangle()
                        .fill(contrast == .increased ? AnyShapeStyle(.primary) : AnyShapeStyle(.secondary))
                        .frame(width: 1, height: value == 0 ? geometry.size.height : geometry.size.height * (value.truncatingRemainder(dividingBy: 50) == 0 ? 0.6 : 0.35))
                        .offset(x: position(value, width: width))
                }

                Capsule()
                    .fill(needleColor)
                    .frame(width: 4, height: geometry.size.height)
                    .offset(x: position(cents ?? 0, width: width))
                    .opacity(cents == nil ? 0 : 1)
                    .animation(reduceMotion ? nil : .easeOut(duration: 0.12), value: cents)
            }
            .frame(width: width, height: geometry.size.height)
        }
        .frame(height: 36)
        .accessibilityHidden(true) // lido em conjunto com a nota (ver `TunerAccessibility`)
    }

    private func position(_ value: Double, width: CGFloat) -> CGFloat {
        let clamped = min(max(value, -Self.range), Self.range)
        return CGFloat(clamped / Self.range) * (width / 2 - 2)
    }

    private var needleColor: Color {
        guard let cents else { return .secondary }
        return abs(cents) <= tolerance ? .green : .orange
    }
}

#Preview {
    VStack(spacing: 20) {
        CentsMeterView(cents: nil, tolerance: 3)
        CentsMeterView(cents: 2, tolerance: 3)
        CentsMeterView(cents: -27, tolerance: 3)
        CentsMeterView(cents: 140, tolerance: 3)
    }
    .padding()
    .frame(width: 300)
}
