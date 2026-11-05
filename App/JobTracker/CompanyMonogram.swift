import SwiftUI

/// A rounded tile with a company's first letter, standing in for its logo.
///
/// The color comes from the name, so a company keeps the same color across launches and screens.
struct CompanyMonogram: View {
    let name: String

    /// Colors from the design, minus near-black so the tile stays visible in dark mode.
    private static let palette: [Color] = [
        Color(red: 0x63 / 255, green: 0x5B / 255, blue: 0xFF / 255),
        Color(red: 0xFF / 255, green: 0x5A / 255, blue: 0x5F / 255),
        Color(red: 0x1D / 255, green: 0xB9 / 255, blue: 0x54 / 255),
        Color(red: 0x58 / 255, green: 0xCC / 255, blue: 0x02 / 255),
        Color(red: 0x5E / 255, green: 0x6A / 255, blue: 0xD2 / 255),
    ]

    var body: some View {
        Tile(initial: initial, color: color)
            // The tile grows with the text but stops before it crowds out the company name.
            .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
            .accessibilityHidden(true)
    }

    private var initial: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines).first.map { String($0).uppercased() } ?? "?"
    }

    private var color: Color {
        Self.palette[Self.paletteIndex(for: name)]
    }

    private struct Tile: View {
        let initial: String
        let color: Color
        @ScaledMetric(relativeTo: .headline) private var size: CGFloat = 40

        var body: some View {
            Text(initial)
                .font(.system(size: size * 0.45, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: size, height: size)
                .background(color, in: RoundedRectangle(cornerRadius: size / 4, style: .continuous))
        }
    }

    /// A stable FNV-1a hash of the lowercased name. `hashValue` is seeded per launch, so it can't be used here.
    private static func paletteIndex(for name: String) -> Int {
        var hash: UInt64 = 0xcbf2_9ce4_8422_2325
        for byte in name.lowercased().utf8 {
            hash ^= UInt64(byte)
            hash &*= 0x0000_0100_0000_01b3
        }
        return Int(hash % UInt64(palette.count))
    }
}

#Preview {
    HStack {
        ForEach(["Stripe", "Airbnb", "Grow Therapy", "Linear", "Duolingo"], id: \.self) { name in
            CompanyMonogram(name: name)
        }
    }
}
