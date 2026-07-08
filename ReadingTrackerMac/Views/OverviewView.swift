import SwiftUI
import SwiftData

struct OverviewView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Document.orderIndex) private var documents: [Document]
    
    @State private var draggedItem: Document?
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 30) {
                // Statistics
                let totalBooks = documents.count
                let totalPages = documents.reduce(0) { $0 + $1.totalPages }
                let totalRead = documents.reduce(0) { sum, doc in
                    let lastPage = doc.progressLogs.sorted { $0.date < $1.date }.last?.page ?? 0
                    return sum + lastPage
                }
                let overallProgress = totalPages > 0 ? Int((Double(totalRead) / Double(totalPages)) * 100) : 0
                
                HStack(spacing: 20) {
                    StatCard(title: "TOTAL BOOKS", value: "\(totalBooks)", color: .primary)
                    StatCard(title: "PAGES READ", value: "\(totalRead) / \(totalPages)", color: .primary)
                    StatCard(title: "GLOBAL PROGRESS", value: "\(overallProgress)%", color: .primary)
                }
                
                Text("Library Overview")
                    .font(.title)
                    .bold()
                
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 250), spacing: 20)], spacing: 20) {
                    ForEach(documents) { doc in
                        DocumentCard(document: doc)
                            .onDrag {
                                self.draggedItem = doc
                                return NSItemProvider(object: doc.id.uuidString as NSString)
                            }
                            .onDrop(of: [.text], delegate: DocumentDropDelegate(item: doc, documents: documents, draggedItem: $draggedItem, modelContext: modelContext))
                    }
                }
            }
            .padding(30)
        }
    }
}

struct StatCard: View {
    var title: String
    var value: String
    var color: Color
    
    var body: some View {
        VStack(alignment: .leading) {
            Text(title)
                .font(.caption)
                .bold()
                .foregroundColor(.secondary)
            Text(value)
                .font(.system(size: 30, weight: .bold))
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(color, lineWidth: 2)
        )
    }
}

struct DocumentCard: View {
    @Bindable var document: Document
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(document.title)
                    .font(.headline)
                
                Spacer()
                
                if let link = document.link, let url = link.toValidURL {
                    Button("GO") {
                        NSWorkspace.shared.open(url)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .tint(.primary)
                }
            }
            
            let lastLog = document.progressLogs.sorted { $0.date < $1.date }.last
            let currentPage = lastLog?.page ?? 0
            let percentage = document.totalPages > 0 ? Int((Double(currentPage) / Double(document.totalPages)) * 100) : 0
            
            ProgressView(value: Double(percentage), total: 100)
                .progressViewStyle(.linear)
                .tint(.primary)
            
            HStack {
                Text("\(percentage)%")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Text("\(currentPage) / \(document.totalPages)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
        .shadow(radius: 2)
    }
}

struct DocumentDropDelegate: DropDelegate {
    let item: Document
    var documents: [Document]
    @Binding var draggedItem: Document?
    var modelContext: ModelContext
    
    func performDrop(info: DropInfo) -> Bool {
        draggedItem = nil
        return true
    }
    
    func dropEntered(info: DropInfo) {
        guard let draggedItem = draggedItem,
              draggedItem != item,
              let from = documents.firstIndex(of: draggedItem),
              let to = documents.firstIndex(of: item) else { return }
        
        var items = documents
        items.move(fromOffsets: IndexSet(integer: from), toOffset: to > from ? to + 1 : to)
        
        for (index, doc) in items.enumerated() {
            doc.orderIndex = index
        }
    }
}
