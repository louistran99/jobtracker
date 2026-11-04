import Domain
import SwiftUI

extension Stage {
    /// The stage colors from the design: gray, indigo, orange, green, and red.
    var color: Color {
        switch self {
        case .applied: Color(.systemGray)
        case .screening: Color(.systemIndigo)
        case .onsite: Color(.systemOrange)
        case .offer: Color(.systemGreen)
        case .rejected: Color(.systemRed)
        }
    }

    /// A stage title with its color dot.
    var label: some View {
        Label {
            Text(title)
        } icon: {
            Image(systemName: "circle.fill")
                .foregroundStyle(color)
        }
    }
}
