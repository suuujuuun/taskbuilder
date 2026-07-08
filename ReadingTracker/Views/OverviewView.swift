import SwiftUI
import SwiftData

struct OverviewView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Document.orderIndex) private var documents: [Document]
    
    @State private var draggedItem: Document?
    @State private var selectedTag: String? = nil
    
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
                let overallProgress = totalPages > 0 ? Int((totalRead / totalPages) * 100) : 0
                
                HStack(spacing: 20) {
                    StatCard(title: "TOTAL BOOKS", value: "\(totalBooks)", color: .primary)
                    StatCard(title: "PAGES READ", value: "\(totalRead.formatted()) / \(totalPages.formatted())", color: .primary)
                    StatCard(title: "GLOBAL PROGRESS", value: "\(overallProgress)%", color: .primary)
                }
                
                let allTags = Array(Set(documents.flatMap { $0.tags })).sorted()
                
                HStack {
                    Text("Library Overview")
                        .font(.title)
                        .bold()
                    
                    Spacer()
                    
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
                }
                
                let filteredDocs = documents.filter { selectedTag == nil || $0.tags.contains(selectedTag!) }
                
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 250), spacing: 20)], spacing: 20) {
                    ForEach(filteredDocs) { doc in
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
    
    private var daysRemaining: Int {
        Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: Date()), to: Calendar.current.startOfDay(for: document.targetDate)).day ?? 0
    }
    
    private var isNearDeadline: Bool {
        daysRemaining <= 10 && daysRemaining >= 0
    }
    
    private var isOverdue: Bool {
        daysRemaining < 0
    }
    
    private var deadlineColor: Color {
        isOverdue ? Color.red : (isNearDeadline ? Color.orange : Color.secondary)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(document.title)
                    .font(.headline)
                
                Spacer()
                
                if let link = document.link, let url = link.toValidURL {
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
                Text("Due:")
                    .font(.subheadline)
                    .bold(isOverdue || isNearDeadline)
                    .foregroundColor(deadlineColor)
                
                DatePicker("", selection: Binding(
                    get: { document.targetDate },
                    set: { newValue in
                        document.targetDate = newValue
                        if let context = document.modelContext {
                            try? context.save()
                        }
                    }
                ), displayedComponents: .date)
                    .labelsHidden()
                    .datePickerStyle(.compact)
                    .tint(deadlineColor)
            }
            
            let lastLog = document.progressLogs.sorted { $0.date < $1.date }.last
            let currentPage = lastLog?.page ?? 0
            let percentage = document.totalPages > 0 ? Int((currentPage / document.totalPages) * 100) : 0
            
            ProgressView(value: Double(percentage), total: 100)
                .progressViewStyle(.linear)
                .tint(.primary)
            
            HStack {
                Text("\(percentage)%")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Text("\(currentPage.formatted()) / \(document.totalPages.formatted())")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            if !document.tags.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack {
                        ForEach(document.tags, id: \.self) { tag in
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
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isOverdue ? Color.red : (isNearDeadline ? Color.orange : Color.clear), lineWidth: 2)
        )
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
