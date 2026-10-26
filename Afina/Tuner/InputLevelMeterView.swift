import AfinaCore
import SwiftUI

/// Barra de nível de entrada (RMS, com marca de pico) entre -60 e 0 dBFS.
struct InputLevelMeterView: View {
    let level: InputLevel

    private static let floorDecibels: Float = -60

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule().fill(.quaternary)
                    Capsule()
                        .fill(.tint)
                        .frame(width: geometry.size.width * fraction(level.rmsDecibels))
                    Rectangle()
                        .fill(.primary)
                        .frame(width: 2)
                        .offset(x: max(0, geometry.size.width * fraction(level.peakDecibels) - 2))
                }
            }
            .frame(height: 8)
            Text(verbatim: String(format: "%.0f dBFS", level.rmsDecibels))
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Nível de entrada"))
        .accessibilityValue(Text(verbatim: String(format: "%.0f dBFS", level.rmsDecibels)))
    }

    private func fraction(_ decibels: Float) -> CGFloat {
        CGFloat(min(max((decibels - Self.floorDecibels) / -Self.floorDecibels, 0), 1))
    }
}

#Preview {
    VStack {
        InputLevelMeterView(level: .silence)
        InputLevelMeterView(level: InputLevel(rms: 0.05, peak: 0.2))
        InputLevelMeterView(level: InputLevel(rms: 0.6, peak: 0.95))
    }
    .padding()
    .frame(width: 280)
}
