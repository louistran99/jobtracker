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
    ///
    /// Menus render images as templates in the tint color at icon size, ignoring `foregroundStyle`. The dot is a small
    /// image drawn in its own color so the stage picker shows it as designed.
    var label: some View {
        Label {
            Text(title)
        } icon: {
            Image(uiImage: dot)
        }
    }

    private var dot: UIImage {
        let configuration = UIImage.SymbolConfiguration(pointSize: 9)
        let symbol = UIImage(systemName: "circle.fill", withConfiguration: configuration) ?? UIImage()
        // Menus put no space between a label's icon and title, so the inset leaves the design's gap after the dot.
        let tinted = symbol.withTintColor(UIColor(color), renderingMode: .alwaysOriginal)
        return tinted.withAlignmentRectInsets(UIEdgeInsets(top: 0, left: 0, bottom: 0, right: -5))
    }
}
