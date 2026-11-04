import SwiftUI

struct ApplicationsView: View {
    var body: some View {
        NavigationStack {
            ContentUnavailableView {
                Label("No Applications", systemImage: "briefcase")
            } description: {
                Text("Applications you add will show up here.")
            }
            .navigationTitle("Applications")
        }
    }
}

#Preview {
    ApplicationsView()
}
