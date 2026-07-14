import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct PapersView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var papers: [Paper]
    
    @State private var showingAddModal = false
    @State private var selectedTag: String? = nil
    
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
            
            let allTags = Array(Set(papers.flatMap { $0.tags })).sorted()
            if !allTags.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack {
                        Button("All") {
                            selectedTag = nil
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(selectedTag == nil ? .primary : Color(NSColor.controlBackgroundColor))
                        .foregroundColor(selectedTag == nil ? Color(NSColor.windowBackgroundColor) : .primary)
                        
                        ForEach(allTags, id: \.self) { tag in
                            Button(tag) {
                                selectedTag = tag
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(selectedTag == tag ? .primary : Color(NSColor.controlBackgroundColor))
                            .foregroundColor(selectedTag == tag ? Color(NSColor.windowBackgroundColor) : .primary)
                        }
                    }
                }
                .padding(.horizontal)
            }
            
            let filteredPapers = papers.filter { selectedTag == nil || $0.tags.contains(selectedTag!) }
            
            HStack(alignment: .top, spacing: 20) {
                PaperKanbanColumn(title: "Not Started", status: "Not Started", papers: filteredPapers)
                PaperKanbanColumn(title: "In Progress", status: "In Progress", papers: filteredPapers)
                PaperKanbanColumn(title: "Completed", status: "Completed", papers: filteredPapers)
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
    @State private var showingEditTags = false
    
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
            
            
            if !paper.tags.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack {
                        ForEach(paper.tags, id: \.self) { tag in
                            Text(tag)
                                .font(.caption2)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.secondary.opacity(0.2))
                                .cornerRadius(4)
                        }
                    }
                }
            }
            
            HStack {
                Spacer()
                Menu {
                    Button("Not Started") { updateStatus("Not Started") }
                    Button("In Progress") { updateStatus("In Progress") }
                    Button("Completed") { updateStatus("Completed") }
                    Divider()
                    Button("Edit Tags") { showingEditTags = true }
                    Button("Delete", role: .destructive) { deletePaper() }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .menuStyle(.borderlessButton)
                .frame(width: 20)
                .popover(isPresented: $showingEditTags) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Edit Tags")
                            .font(.headline)
                        TextField("Tags (comma separated)", text: Binding(
                            get: { paper.tags.joined(separator: ", ") },
                            set: { newValue in
                                let tags = newValue.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
                                paper.tags = tags
                                try? modelContext.save()
                            }
                        ))
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 250)
                    }
                    .padding()
                }
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
    @State private var tags = ""
    
    var body: some View {
        NavigationStack {
            Form {
                TextField("Paper Title", text: $title)
                TextField("URL", text: $url)
                TextField("Tags (comma separated)", text: $tags)
            }
            .padding()
            .navigationTitle("Add Paper")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let tagArray = tags.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
                        let paper = Paper(title: title, url: url, tags: tagArray)
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
