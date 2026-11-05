import Domain
import Persistence
import SwiftData
import SwiftUI
import ViewModels

struct ApplicationsView: View {
    let fetchPosting: NewApplicationViewModel.FetchPosting

    @Query(sort: \Application.createdAt, order: .reverse) private var applications: [Application]
    @Environment(\.modelContext) private var modelContext
    @State private var newApplication: NewApplicationViewModel?

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Applications")
                .toolbar {
                    ToolbarItem(placement: .primaryAction) {
                        Button {
                            newApplication = NewApplicationViewModel(fetchPosting: fetchPosting) {
                                try ApplicationRepository(context: modelContext).add($0)
                            }
                        } label: {
                            Label("New Application", systemImage: "plus")
                        }
                        .accessibilityIdentifier("newApplicationButton")
                    }
                }
                .sheet(item: $newApplication) { viewModel in
                    NewApplicationSheet(viewModel: viewModel)
                        .presentationDetents([.large])
                }
        }
    }

    @ViewBuilder private var content: some View {
        if applications.isEmpty {
            ContentUnavailableView {
                Label("No Applications", systemImage: "briefcase")
            } description: {
                Text("Applications you add will show up here.")
            }
        } else {
            List(applications) { application in
                ApplicationRow(application: application)
            }
            .accessibilityIdentifier("applicationsList")
        }
    }
}

private struct ApplicationRow: View {
    let application: Application

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text(application.company)
                    .font(.headline)
                Text(application.role)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(application.stage.title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(application.stage.color)
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("applicationRow")
    }
}

#Preview {
    ApplicationsView(fetchPosting: PostingStub.found.fetchPosting)
        .modelContainer(for: Application.self, inMemory: true)
}
