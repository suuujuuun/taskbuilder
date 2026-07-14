import SwiftUI
import SwiftData

struct OverviewView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Document.orderIndex) private var documents: [Document]
    
    @State private var draggedItem: Document?
    @AppStorage("lastSelectedOverviewTag") private var lastSelectedTag: String = ""
    private var selectedTag: String? {
        get { lastSelectedTag.isEmpty ? nil : lastSelectedTag }
        set { lastSelectedTag = newValue ?? "" }
    }
    @AppStorage("tagOrder") private var tagOrderString: String = ""
    @State private var showingTagReorder = false
    @State private var editOrderTags: [String] = []
    @State private var selectedDocumentForEditing: Document?
    
    var body: some View {
        ZStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 30) {
                let filteredDocs = documents.filter { selectedTag == nil || $0.tags.contains(selectedTag!) }
                
                // Statistics
                let totalBooks = filteredDocs.count
                let totalPages = filteredDocs.reduce(0) { $0 + $1.totalPages }
                let totalRead = filteredDocs.reduce(0) { sum, doc in
                    let lastPage = doc.progressLogs.max(by: { $0.date < $1.date })?.page ?? 0
                    return sum + lastPage
                }
                let overallProgress = totalPages > 0 ? Int((totalRead / totalPages) * 100) : 0
                
                HStack(spacing: 20) {
                    StatCard(title: "TOTAL BOOKS", value: "\(totalBooks)", color: .primary)
                    StatCard(title: "PAGES READ", value: "\(totalRead.formatted()) / \(totalPages.formatted())", color: .primary)
                    StatCard(title: "GLOBAL PROGRESS", value: "\(overallProgress)%", color: .primary)
                }
                
                let existingTags = Array(Set(documents.flatMap { $0.tags }))
                let orderedTags = tagOrderString.components(separatedBy: ",").filter { !$0.isEmpty }
                let allTags = orderedTags.filter { existingTags.contains($0) } + existingTags.filter { !orderedTags.contains($0) }.sorted()
                
                HStack {
                    Text("Library Overview")
                        .font(.title)
                        .bold()
                    
                    Button(action: {
                        editOrderTags = allTags
                        showingTagReorder = true
                    }) {
                        Image(systemName: "arrow.up.arrow.down")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                    .popover(isPresented: $showingTagReorder) {
                        VStack(spacing: 10) {
                            Text("Reorder Tags").font(.headline)
                            List {
                                ForEach(editOrderTags, id: \.self) { tag in
                                    Text(tag)
                                }
                                .onMove { from, to in
                                    editOrderTags.move(fromOffsets: from, toOffset: to)
                                }
                            }
                            Button("Save") {
                                tagOrderString = editOrderTags.joined(separator: ",")
                                showingTagReorder = false
                            }
                            .buttonStyle(.borderedProminent)
                        }
                        .padding()
                        .frame(width: 200, height: 250)
                    }
                    
                    Spacer()
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack {
                            Button("All") {
                                lastSelectedTag = ""
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(selectedTag == nil ? .primary : Color(NSColor.controlBackgroundColor))
                            .foregroundColor(selectedTag == nil ? Color(NSColor.windowBackgroundColor) : .primary)
                            
                            ForEach(allTags, id: \.self) { tag in
                                Button(tag) {
                                    lastSelectedTag = tag
                                }
                                .buttonStyle(.borderedProminent)
                                .tint(selectedTag == tag ? .primary : Color(NSColor.controlBackgroundColor))
                                .foregroundColor(selectedTag == tag ? Color(NSColor.windowBackgroundColor) : .primary)
                            }
                        }
                    }
                }
                
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 250), spacing: 20)], spacing: 20) {
                    ForEach(filteredDocs) { doc in
                        DocumentCard(document: doc)
                            .onTapGesture {
                                selectedDocumentForEditing = doc
                            }
                            .onDrag {
                                self.draggedItem = doc
                                return NSItemProvider(object: doc.id.uuidString as NSString)
                            }
                            .onDrop(of: [.text], delegate: DocumentDropDelegate(item: doc, documents: documents, draggedItem: $draggedItem, modelContext: modelContext))
                    }
                }
            }
            }
            .padding(30)
            
            if let editingDoc = selectedDocumentForEditing {
                Color.black.opacity(0.6)
                    .ignoresSafeArea()
                    .onTapGesture {
                        selectedDocumentForEditing = nil
                    }
                
                DocumentDetailView(document: editingDoc)
                    .frame(width: 800, height: 550)
                    .background(Color(NSColor.windowBackgroundColor))
                    .cornerRadius(12)
                    .shadow(radius: 20)
            }
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
                
                Text(document.targetDate, format: .dateTime.month().day().year())
                    .font(.subheadline)
                    .foregroundColor(deadlineColor)
            }
            
            let lastLog = document.progressLogs.max(by: { $0.date < $1.date })
            let currentPage = lastLog?.page ?? 0
            let percentage = document.totalPages > 0 ? Int((currentPage / document.totalPages) * 100) : 0
            
            if let lastTopic = lastLog?.topic, !lastTopic.isEmpty {
                HStack(alignment: .top) {
                    Image(systemName: "book")
                        .foregroundColor(.secondary)
                    Text(lastTopic)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
            }
            
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

