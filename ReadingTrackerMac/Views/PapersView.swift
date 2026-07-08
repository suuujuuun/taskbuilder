import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct PapersView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var papers: [Paper]
    
    @State private var showingAddModal = false
    
    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Text("Papers Board").font(.title2).bold()
                Spacer()
                Button(action: { showingAddModal = true }) {
                    Label("Add Paper", systemImage: "plus")
                }
            }
            .padding()
            
            HStack(alignment: .top, spacing: 20) {
                PaperKanbanColumn(title: "Not Started", status: "Not Started", papers: papers)
                PaperKanbanColumn(title: "In Progress", status: "In Progress", papers: papers)
                PaperKanbanColumn(title: "Completed", status: "Completed", papers: papers)
            }
            .padding(.horizontal)
        }
        .navigationTitle("Papers")
        .sheet(isPresented: $showingAddModal) {
            AddPaperView()
        }
    }
}

struct PaperKanbanColumn: View {
    let title: String
    let status: String
    var papers: [Paper]
    @Environment(\.modelContext) private var modelContext
    
    var filteredPapers: [Paper] {
        papers.filter { $0.status == status || ($0.status.isEmpty && status == "Not Started") }
    }
    
    var body: some View {
        VStack(alignment: .leading) {
            Text("\(title) (\(filteredPapers.count))")
                .font(.headline)
                .padding(.bottom, 5)
            
            ScrollView {
                VStack(spacing: 10) {
                    ForEach(filteredPapers) { paper in
                        PaperKanbanCard(paper: paper)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(NSColor.unemphasizedSelectedContentBackgroundColor).opacity(0.3))
        .cornerRadius(8)
        .onDrop(of: [.plainText], isTargeted: nil) { providers in
            if let provider = providers.first {
                provider.loadItem(forTypeIdentifier: UTType.plainText.identifier, options: nil) { (data, error) in
                    if let data = data as? Data, let uuidString = String(data: data, encoding: .utf8), let uuid = UUID(uuidString: uuidString) {
                        DispatchQueue.main.async {
                            if let paper = papers.first(where: { $0.id == uuid }) {
                                paper.status = status
                                try? modelContext.save()
                            }
                        }
                    }
                }
                return true
            }
            return false
        }
    }
}

struct PaperKanbanCard: View {
    @Bindable var paper: Paper
    @Environment(\.modelContext) private var modelContext
    
    var body: some View {
        VStack(alignment: .leading) {
            Text(paper.title)
                .font(.body)
                .bold()
            
            HStack {
                TextField("URL", text: $paper.url)
                    .textFieldStyle(.plain)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                if let url = paper.url.toValidURL {
                    Button(action: {
                        NSWorkspace.shared.open(url)
                    }) {
                        Text("GO")
                            .font(.caption)
                            .bold()
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(Color.primary)
                            .foregroundColor(Color(NSColor.windowBackgroundColor))
                            .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                }
            }
            
            HStack {
                Spacer()
                Menu {
                    Button("Not Started") { updateStatus("Not Started") }
                    Button("In Progress") { updateStatus("In Progress") }
                    Button("Completed") { updateStatus("Completed") }
                    Divider()
                    Button("Delete", role: .destructive) { deletePaper() }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .menuStyle(.borderlessButton)
                .frame(width: 20)
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(6)
        .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
        .onDrag {
            let provider = NSItemProvider(item: paper.id.uuidString.data(using: .utf8) as NSData?, typeIdentifier: UTType.plainText.identifier)
            return provider
        }
    }
    
    private func updateStatus(_ status: String) {
        paper.status = status
        try? modelContext.save()
    }
    
    private func deletePaper() {
        modelContext.delete(paper)
        try? modelContext.save()
    }
}

struct AddPaperView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @State private var title = ""
    @State private var url = ""
    
    var body: some View {
        NavigationStack {
            Form {
                TextField("Paper Title", text: $title)
                TextField("URL", text: $url)
            }
            .padding()
            .navigationTitle("Add Paper")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let paper = Paper(title: title, url: url)
                        modelContext.insert(paper)
                        try? modelContext.save()
                        dismiss()
                    }
                    .disabled(title.isEmpty)
                }
            }
        }
        .frame(width: 400, height: 200)
    }
}
