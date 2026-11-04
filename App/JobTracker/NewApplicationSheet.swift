import Domain
import SwiftUI
import ViewModels

/// The New Application sheet.
///
/// The form binds to `NewApplicationViewModel.draft`. Nothing reaches SwiftData until Add succeeds.
struct NewApplicationSheet: View {
    private enum Field {
        case link
    }

    @Bindable var viewModel: NewApplicationViewModel
    @Environment(\.dismiss) private var dismiss
    @FocusState private var focusedField: Field?
    @ScaledMetric(relativeTo: .body) private var labelWidth: CGFloat = 96

    var body: some View {
        NavigationStack {
            Form {
                linkSection
                detailsSection
                nextStepSection
                notesSection
            }
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
    }

    // MARK: Sections

    private var linkSection: some View {
        Section {
            HStack(spacing: 12) {
                Image(systemName: "link")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(width: 29, height: 29)
                    .background(.blue, in: RoundedRectangle(cornerRadius: 6.5, style: .continuous))
                    .accessibilityHidden(true)
                TextField("Paste a job link", text: $viewModel.draft.link)
                    .keyboardType(.URL)
                    .textContentType(.URL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .focused($focusedField, equals: .link)
                    .accessibilityIdentifier("linkField")
                PasteButton(payloadType: String.self) { strings in
                    guard let text = strings.first else { return }
                    Task { @MainActor in viewModel.draft.link = text }
                }
                .labelStyle(.titleOnly)
                .buttonBorderShape(.capsule)
            }
        } header: {
            Text("Job posting")
        } footer: {
            Text("The company and role are filled in from the posting.")
        }
    }

    private var detailsSection: some View {
        Section("Details") {
            field("Company", text: $viewModel.draft.company, identifier: "companyField")
            field("Role", text: $viewModel.draft.role, identifier: "roleField")
            Picker("Stage", selection: $viewModel.draft.stage) {
                ForEach(Stage.allCases) { stage in
                    stage.label.tag(stage)
                }
            }
            .pickerStyle(.menu)
            .accessibilityIdentifier("stagePicker")
            DatePicker("Applied on", selection: $viewModel.draft.appliedOn, displayedComponents: .date)
                .accessibilityIdentifier("appliedOnPicker")
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

    private func field(_ title: String, text: Binding<String>, identifier: String) -> some View {
        HStack {
            Text(title)
                .frame(width: labelWidth, alignment: .leading)
                .accessibilityHidden(true)
            TextField(title, text: text, prompt: Text("Required"))
                .textInputAutocapitalization(.words)
                .accessibilityIdentifier(identifier)
        }
    }
}

#Preview {
    Color.clear.sheet(isPresented: .constant(true)) {
        NewApplicationSheet(viewModel: NewApplicationViewModel(save: { _ in }))
    }
}
