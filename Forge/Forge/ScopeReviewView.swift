//
//  ScopeReviewView.swift
//  Forge
//
//  Feature 5: Review/edit a ScopePacket — tasks grouped by trade, swipe-to-delete,
//             tap-to-edit, amber questions, per-item and bulk approval.
//  Feature 6: Copy-to-clipboard and share sheet export (formatted markdown).
//  Phase 3:   PDF export via PDFGenerator; project context passed in for metadata.
//

import SwiftUI
import SwiftData

struct ScopeReviewView: View {
    @Bindable var packet: ScopePacket
    let project: Project
    @Environment(\.modelContext) private var modelContext

    @State private var editingTask: TradeTask?
    @State private var showingMarkdownShare = false
    @State private var showingPDFShare = false
    @State private var showingBuildertrend = false
    @State private var showingFieldNotesShare = false
    @State private var pdfURL: URL?
    @State private var buildertrendURL: URL?
    @State private var isGeneratingPDF = false
    @State private var isGeneratingBuildertrend = false
    @State private var copiedToClipboard = false
    @State private var errorMessage: String?
    @State private var showingError = false

    private static let tradeOrder = [
        "demo", "framing", "plumbing", "electrical", "HVAC",
        "drywall", "tile", "paint", "carpentry", "flooring",
        "roofing", "windows", "doors", "other"
    ]

    private var groupedTasks: [(trade: String, tasks: [TradeTask])] {
        let dict = Dictionary(grouping: packet.tasksByTrade, by: \.trade)
        let known = Self.tradeOrder
            .filter { dict[$0] != nil }
            .map { (trade: $0, tasks: dict[$0]!) }
        let unknown = dict.keys
            .filter { !Self.tradeOrder.contains($0) }
            .sorted()
            .map { (trade: $0, tasks: dict[$0]!) }
        return known + unknown
    }

    private var allApproved: Bool {
        !packet.tasksByTrade.isEmpty && packet.tasksByTrade.allSatisfy(\.isApproved)
    }

    private var approvedCount: Int {
        packet.tasksByTrade.filter(\.isApproved).count
    }

    var body: some View {
        List {
            scopeSummarySection
            approvalProgressSection
            ForEach(groupedTasks, id: \.trade) { group in
                tradeSection(trade: group.trade, tasks: group.tasks)
            }
        }
        .navigationTitle("Scope Review")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button {
                        approveAll()
                    } label: {
                        Label("Approve All", systemImage: "checkmark.seal")
                    }
                    .disabled(allApproved)

                    Divider()

                    Button {
                        copyToClipboard()
                    } label: {
                        Label(
                            copiedToClipboard ? "Copied!" : "Copy as Markdown",
                            systemImage: copiedToClipboard ? "checkmark" : "doc.on.clipboard"
                        )
                    }

                    Button {
                        showingMarkdownShare = true
                    } label: {
                        Label("Share as Markdown…", systemImage: "square.and.arrow.up")
                    }

                    Button {
                        Task { await exportAsPDF() }
                    } label: {
                        if isGeneratingPDF {
                            Label("Generating PDF…", systemImage: "clock")
                        } else {
                            Label("Export as PDF…", systemImage: "doc.richtext")
                        }
                    }
                    .disabled(isGeneratingPDF)

                    Divider()

                    Button {
                        Task { await exportForBuildertrend() }
                    } label: {
                        if isGeneratingBuildertrend {
                            Label("Preparing…", systemImage: "clock")
                        } else {
                            Label("Export for Buildertrend (CSV)…", systemImage: "tablecells")
                        }
                    }
                    .disabled(isGeneratingBuildertrend)

                    Button {
                        shareFieldNotes()
                    } label: {
                        Label("Export Field Notes…", systemImage: "list.clipboard")
                    }

                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .sheet(item: $editingTask) { task in
            EditTaskSheet(task: task)
        }
        .sheet(isPresented: $showingMarkdownShare) {
            ShareSheet(activityItems: [ExportModule.markdownExport(packet: packet)])
        }
        .sheet(isPresented: $showingPDFShare) {
            if let url = pdfURL {
                ShareSheet(activityItems: [url])
            }
        }
        .sheet(isPresented: $showingBuildertrend) {
            if let url = buildertrendURL {
                ShareSheet(activityItems: [url])
            }
        }
        .sheet(isPresented: $showingFieldNotesShare) {
            ShareSheet(activityItems: [BuildertrendExporter.fieldNotesExport(packet: packet, project: project)])
        }
        .alert("Export Failed", isPresented: $showingError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "An unknown error occurred.")
        }
    }

    // MARK: - Sections

    private var scopeSummarySection: some View {
        Section("Scope Summary") {
            Text(packet.scopeSummary)
                .font(.callout)
        }
    }

    private var approvalProgressSection: some View {
        Section {
            HStack {
                let total = packet.tasksByTrade.count
                Label(
                    "\(approvedCount) of \(total) approved",
                    systemImage: allApproved ? "checkmark.seal.fill" : "checkmark.seal"
                )
                .foregroundStyle(allApproved ? .green : .secondary)
                .font(.subheadline)

                Spacer()

                if !allApproved {
                    Button("Approve All") { approveAll() }
                        .font(.subheadline)
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                }
            }
        }
    }

    @ViewBuilder
    private func tradeSection(trade: String, tasks: [TradeTask]) -> some View {
        Section(trade.capitalized) {
            ForEach(tasks) { task in
                TaskRow(task: task) {
                    editingTask = task
                }
            }
            .onDelete { offsets in
                deleteTasks(at: offsets, in: tasks)
            }
        }
    }

    // MARK: - Actions

    private func approveAll() {
        for task in packet.tasksByTrade {
            task.isApproved = true
        }
        packet.status = .approved
    }

    private func deleteTasks(at offsets: IndexSet, in tasks: [TradeTask]) {
        for index in offsets {
            let task = tasks[index]
            packet.tasksByTrade.removeAll { $0.id == task.id }
            modelContext.delete(task)
        }
    }

    private func copyToClipboard() {
        UIPasteboard.general.string = ExportModule.markdownExport(packet: packet)
        copiedToClipboard = true
        Task {
            try? await Task.sleep(for: .seconds(2))
            copiedToClipboard = false
        }
    }

    private func exportAsPDF() async {
        isGeneratingPDF = true
        defer { isGeneratingPDF = false }
        do {
            pdfURL = try PDFGenerator.generate(packet: packet, project: project)
            showingPDFShare = true
        } catch {
            errorMessage = error.localizedDescription
            showingError = true
        }
    }

    private func exportForBuildertrend() async {
        isGeneratingBuildertrend = true
        defer { isGeneratingBuildertrend = false }
        do {
            buildertrendURL = try BuildertrendExporter.csvTempFile(packet: packet, project: project)
            showingBuildertrend = true
            packet.status = .exported
        } catch {
            errorMessage = error.localizedDescription
            showingError = true
        }
    }

    private func shareFieldNotes() {
        showingFieldNotesShare = true
    }
}

// MARK: - TaskRow

private struct TaskRow: View {
    @Bindable var task: TradeTask
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(alignment: .top, spacing: 12) {
                Button {
                    task.isApproved.toggle()
                } label: {
                    Image(systemName: task.isApproved ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(task.isApproved ? .green : .secondary)
                        .imageScale(.large)
                }
                .buttonStyle(.plain)

                VStack(alignment: .leading, spacing: 4) {
                    Text(task.taskDescription)
                        .font(.subheadline)
                        .foregroundStyle(task.isQuestion ? .orange : .primary)
                        .multilineTextAlignment(.leading)

                    if task.isQuestion {
                        Label("Needs confirmation", systemImage: "questionmark.circle.fill")
                            .font(.caption2)
                            .foregroundStyle(.orange)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.vertical, 2)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - EditTaskSheet

private struct EditTaskSheet: View {
    @Bindable var task: TradeTask
    @Environment(\.dismiss) private var dismiss

    @State private var draftDescription = ""
    @State private var draftIsQuestion = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Task Description") {
                    TextEditor(text: $draftDescription)
                        .frame(minHeight: 80)
                }

                Section {
                    Toggle("Needs Confirmation", isOn: $draftIsQuestion)
                        .tint(.orange)
                } footer: {
                    Text("Flag this task as a question or uncertainty that must be resolved before work begins.")
                }
            }
            .navigationTitle("Edit Task")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        task.taskDescription = draftDescription
                        task.isQuestion = draftIsQuestion
                        dismiss()
                    }
                    .disabled(draftDescription.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .onAppear {
            draftDescription = task.taskDescription
            draftIsQuestion = task.isQuestion
        }
    }
}

// MARK: - ShareSheet

private struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uvc: UIActivityViewController, context: Context) {}
}
