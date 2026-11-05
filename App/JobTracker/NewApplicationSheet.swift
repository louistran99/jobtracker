import Domain
import SwiftUI
import ViewModels

/// The New Application sheet.
///
/// The form binds to `NewApplicationViewModel.draft`. Nothing reaches SwiftData until Add succeeds. Pasting a job
/// link fetches the posting and fills in the company and role; the link field shows how that fetch is going.
struct NewApplicationSheet: View {
    private enum Field {
        case link
    }

    @Bindable var viewModel: NewApplicationViewModel
    @Environment(\.dismiss) private var dismiss
    @FocusState private var focusedField: Field?
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .body) private var labelWidth: CGFloat = 96
    /// The system Paste button's height. Every link state keeps the row this tall, so the form doesn't jump when the
    /// Paste button gives way to the fetch status.
    @ScaledMetric(relativeTo: .body) private var linkRowMinHeight: CGFloat = 34

    var body: some View {
        NavigationStack {
            Form {
                linkSection
                detailsSection
                nextStepSection
                notesSection
            }
            .animation(.default, value: viewModel.linkState)
            .navigationTitle("New Application")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        focusedField = nil
                        viewModel.cancel()
                    }
                    .accessibilityIdentifier("cancelButton")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add", action: viewModel.add)
                        .disabled(!viewModel.canAdd)
                        .accessibilityIdentifier("addButton")
                }
            }
            .alert(
                viewModel.alertTitle,
                isPresented: $viewModel.isPresentingAlert,
                presenting: viewModel.alert
            ) { alert in
                switch alert {
                case .discard:
                    Button("Discard", role: .destructive, action: viewModel.confirmDiscard)
                    Button("Keep Editing", role: .cancel) {}
                case .saveFailed:
                    Button("OK", role: .cancel) {}
                }
            } message: { alert in
                if alert == .saveFailed {
                    Text("The application could not be saved. Try again.")
                }
            }
        }
        .interactiveDismissDisabled(viewModel.blocksInteractiveDismiss)
        .onChange(of: viewModel.shouldDismiss) { _, shouldDismiss in
            if shouldDismiss { dismiss() }
        }
        .task { focusedField = .link }
        .task(id: viewModel.postingURL) { await viewModel.loadPosting() }
        .onChange(of: viewModel.linkState) {
            if let announcement = viewModel.linkStateAnnouncement {
                AccessibilityNotification.Announcement(announcement).post()
            }
        }
    }

    // MARK: Sections

    private var linkSection: some View {
        Section {
            HStack(spacing: 12) {
                LinkTile()
                    .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
                    .accessibilityHidden(true)
                TextField("Paste a job link", text: $viewModel.draft.link)
                    .keyboardType(.URL)
                    .textContentType(.URL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .submitLabel(.go)
                    .onSubmit { focusedField = nil }
                    .focused($focusedField, equals: .link)
                    .accessibilityIdentifier("linkField")
                linkAccessory
            }
            .frame(minHeight: linkRowMinHeight)
            // The design runs the separator under the link tile, not from the text.
            .alignmentGuide(.listRowSeparatorLeading) { _ in 0 }
            if case .found(let metadata) = viewModel.linkState {
                PostingSummaryRow(metadata: metadata)
            }
            if let note = viewModel.duplicateNote {
                Text(note)
                    .font(.subheadline)
                    .accessibilityIdentifier("duplicateNote")
            }
        } header: {
            Text("Job posting")
        } footer: {
            if let footer = viewModel.linkFooter {
                Text(footer)
                    .accessibilityIdentifier("linkFooter")
            }
        }
    }

    /// The Paste button while the field is empty, then the fetch status.
    @ViewBuilder private var linkAccessory: some View {
        switch viewModel.linkState {
        case .idle:
            if viewModel.draft.link.isEmpty {
                PasteButton(payloadType: String.self) { strings in
                    guard let text = strings.first else { return }
                    Task { @MainActor in viewModel.draft.link = text }
                }
                .labelStyle(.titleOnly)
                .buttonBorderShape(.capsule)
            }
        case .fetching:
            ProgressView()
                .accessibilityLabel("Fetching details")
                .accessibilityIdentifier("linkStatus")
        case .found:
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
                .accessibilityLabel("Posting found")
                .accessibilityIdentifier("linkStatus")
        case .couldNotRead:
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
                .accessibilityLabel("Couldn't read posting")
                .accessibilityIdentifier("linkStatus")
        case .duplicate:
            Image(systemName: "square.on.square")
                .foregroundStyle(.blue)
                .accessibilityLabel("Already added")
                .accessibilityIdentifier("linkStatus")
        }
    }

    private var detailsSection: some View {
        Section {
            field("Company", text: $viewModel.draft.company, identifier: "companyField")
            field("Role", text: $viewModel.draft.role, identifier: "roleField")
            Picker("Stage", selection: $viewModel.draft.stage) {
                ForEach(Stage.allCases) { stage in
                    stage.label.tag(stage)
                }
            }
            .pickerStyle(.menu)
            // The design shows the chosen stage in secondary text, not the accent color.
            .tint(.secondary)
            .accessibilityIdentifier("stagePicker")
            DatePicker("Applied on", selection: $viewModel.draft.appliedOn, displayedComponents: .date)
                .accessibilityIdentifier("appliedOnPicker")
        } header: {
            Text("Details")
        } footer: {
            if let footer = viewModel.detailsFooter {
                Text(footer)
                    .accessibilityIdentifier("detailsFooter")
            }
        }
    }

    private var nextStepSection: some View {
        Section("Next step") {
            Toggle("Add a next step", isOn: $viewModel.draft.hasNextStep.animation())
                .accessibilityIdentifier("nextStepToggle")
            if viewModel.draft.hasNextStep {
                TextField("What's next?", text: $viewModel.draft.nextStepTitle)
                    .accessibilityIdentifier("nextStepTitleField")
                DatePicker("Date", selection: $viewModel.draft.nextStepDate)
                    .accessibilityIdentifier("nextStepDatePicker")
            }
        }
    }

    private var notesSection: some View {
        Section("Notes") {
            TextEditor(text: $viewModel.draft.notes)
                .frame(minHeight: 96)
                .overlay(alignment: .topLeading) {
                    if viewModel.draft.notes.isEmpty {
                        Text("Referral, salary range, anything worth remembering")
                            .foregroundStyle(.tertiary)
                            .padding(.top, 8)
                            .padding(.leading, 5)
                            .allowsHitTesting(false)
                            .accessibilityHidden(true)
                    }
                }
                .accessibilityLabel("Notes")
                .accessibilityIdentifier("notesField")
        }
    }

    /// A labeled text field. At accessibility text sizes the label sits above the field, so neither is cut off.
    private func field(_ title: String, text: Binding<String>, identifier: String) -> some View {
        let isStacked = dynamicTypeSize.isAccessibilitySize
        let layout = isStacked ? AnyLayout(VStackLayout(alignment: .leading, spacing: 4)) : AnyLayout(HStackLayout())
        return layout {
            Text(title)
                .frame(width: isStacked ? nil : labelWidth, alignment: .leading)
                .accessibilityHidden(true)
            TextField(title, text: text, prompt: Text("Required"))
                .textInputAutocapitalization(.words)
                .accessibilityIdentifier(identifier)
        }
    }
}

/// The blue link tile at the start of the link field.
private struct LinkTile: View {
    @ScaledMetric(relativeTo: .subheadline) private var size: CGFloat = 29

    var body: some View {
        Image(systemName: "link")
            .font(.system(size: size * 0.52, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(.blue, in: RoundedRectangle(cornerRadius: size * 0.224, style: .continuous))
    }
}

/// The posting's company with where and when, shown under the link once the posting is found.
private struct PostingSummaryRow: View {
    let metadata: PostingMetadata

    var body: some View {
        let title = metadata.company ?? metadata.role ?? ""
        HStack(spacing: 12) {
            CompanyMonogram(name: title)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                if let summary = metadata.summary() {
                    Text(summary)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("postingSummary")
    }
}

#Preview("Empty") {
    sheetPreview(.couldNotRead, link: "")
}

#Preview("Fetching") {
    sheetPreview(.fetching, link: "https://jobs.ashbyhq.com/grow-therapy/eb6b5a30-a02d-47b7-83ac-51839574d2d2")
}

#Preview("Found") {
    sheetPreview(.found, link: "https://jobs.ashbyhq.com/grow-therapy/eb6b5a30-a02d-47b7-83ac-51839574d2d2")
}

#Preview("Couldn't read") {
    sheetPreview(.couldNotRead, link: "https://www.linkedin.com/jobs/view/4021187733")
}

#Preview("Already added") {
    sheetPreview(.fetching, link: "stripe.com/jobs/listing/6519024", addedOn: .now.addingTimeInterval(-24 * 86_400))
}

@MainActor private func sheetPreview(_ stub: PostingStub, link: String, addedOn: Date? = nil) -> some View {
    var draft = ApplicationDraft()
    draft.link = link
    let viewModel = NewApplicationViewModel(
        draft: draft,
        fetchPosting: stub.fetchPosting,
        dateAdded: { _ in addedOn },
        save: { _ in }
    )
    return Color.clear.sheet(isPresented: .constant(true)) {
        NewApplicationSheet(viewModel: viewModel)
    }
}
