import SwiftUI
import SwiftData

struct DetailsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Document.orderIndex) private var documents: [Document]
    
    @State private var selectedDocument: Document?
    @State private var showingAddModal = false
    
    var body: some View {
        NavigationSplitView {
            List(selection: $selectedDocument) {
                ForEach(documents) { doc in
                    NavigationLink(value: doc) {
                        DocumentRowView(doc: doc)
                    }
                }
                .onDelete(perform: deleteDocuments)
            }
            .navigationTitle("Documents")
            .toolbar {
                ToolbarItem {
                    Button(action: { showingAddModal = true }) {
                        Label("Add Document", systemImage: "plus")
                    }
                }
            }
        } detail: {
            if let doc = selectedDocument {
                DocumentDetailView(document: doc, onDelete: {
                    modelContext.delete(doc)
                    try? modelContext.save()
                    selectedDocument = nil
                })
            } else {
                VStack(spacing: 16) {
                    Text("“Books are a uniquely portable magic.”")
                        .font(.custom("Palatino", size: 18))
                        .italic()
                        .multilineTextAlignment(.center)
                    
                    Text("- Stephen King")
                        .font(.custom("Palatino", size: 14))
                        .foregroundColor(.secondary)
                }
                .padding()
            }
        }
        .sheet(isPresented: $showingAddModal) {
            AddDocumentView()
        }
    }
    
    private func deleteDocuments(offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                modelContext.delete(documents[index])
            }
            try? modelContext.save()
        }
    }
    
    private func calculateProgress(for doc: Document) -> Double {
        let lastLog = doc.progressLogs.max(by: { $0.date < $1.date })
        let currentPage = lastLog?.page ?? 0
        return doc.totalPages > 0 ? currentPage / doc.totalPages : 0
    }
}

struct DocumentRowView: View {
    let doc: Document
    
    var body: some View {
        let daysRemaining = Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: Date()), to: Calendar.current.startOfDay(for: doc.targetDate)).day ?? 0
        let isNearDeadline = daysRemaining <= 10 && daysRemaining >= 0
        let isOverdue = daysRemaining < 0
        let deadlineColor = isOverdue ? Color.red : (isNearDeadline ? Color.orange : Color.secondary)

        VStack(alignment: .leading) {
            Text(doc.title)
                .font(.headline)
                .foregroundColor((isOverdue || isNearDeadline) ? deadlineColor : .primary)
            
            HStack {
                Text("\(doc.totalPages.formatted()) pages")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Spacer()
                Text("Due: \(doc.targetDate, format: .dateTime.month().day())")
                    .font(.caption)
                    .bold(isOverdue || isNearDeadline)
                    .foregroundColor(deadlineColor)
            }
            
            let lastLog = doc.progressLogs.max(by: { $0.date < $1.date })
            let currentPage = lastLog?.page ?? 0
            let progress = doc.totalPages > 0 ? currentPage / doc.totalPages : 0
            
            ProgressView(value: progress)
                .progressViewStyle(.linear)
                .tint(.primary)
        }
        .padding(.vertical, 4)
    }
}

struct DocumentDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var document: Document
    var onDelete: (() -> Void)? = nil
    
    @State private var newPage: String = ""
    @State private var newTopic: String = ""
    @State private var newSatisfaction: String = ""
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack(alignment: .top) {
                    let daysRemaining = Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: Date()), to: Calendar.current.startOfDay(for: document.targetDate)).day ?? 0
                    let isNearDeadline = daysRemaining <= 10 && daysRemaining >= 0
                    let isOverdue = daysRemaining < 0
                    let deadlineColor = isOverdue ? Color.red : (isNearDeadline ? Color.orange : Color.primary)

                    VStack(alignment: .leading) {
                        Text("Difficulty: \(document.difficulty.map { "\($0)/5" } ?? "N/A")")
                            .foregroundColor(.secondary)
                        TextField("Title", text: Binding(
                            get: { document.title },
                            set: { newValue in
                                document.title = newValue
                                try? modelContext.save()
                            }
                        ))
                            .font(.largeTitle)
                            .bold()
                            .foregroundColor((isOverdue || isNearDeadline) ? deadlineColor : .primary)
                            .textFieldStyle(.plain)
                        
                        if isOverdue {
                            Text("Overdue by \(-daysRemaining) days")
                                .font(.headline)
                                .foregroundColor(.red)
                        } else if isNearDeadline {
                            Text("Due in \(daysRemaining) days")
                                .font(.headline)
                                .foregroundColor(.orange)
                        }
                    }
                    Spacer()
                    VStack(alignment: .trailing) {
                        DatePicker("Target Date", selection: Binding(
                            get: { document.targetDate },
                            set: { newValue in
                                document.targetDate = newValue
                                try? modelContext.save()
                            }
                        ), displayedComponents: .date)
                            .labelsHidden()
                        
                        HStack {
                            TextField("Shortcut Link", text: Binding(get: { document.link ?? "" }, set: { document.link = $0 }))
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 200)
                            
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
                        
                        TextField("Tags (comma separated)", text: Binding(
                            get: { document.tags.joined(separator: ", ") },
                            set: { newValue in
                                let tags = newValue.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
                                document.tags = tags
                                try? modelContext.save()
                            }
                        ))
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 200)
                    }
                }
                
                let lastLog = document.progressLogs.max(by: { $0.date < $1.date })
                let currentPage = lastLog?.page ?? 0
                let remaining = document.totalPages - currentPage
                let percentage = document.totalPages > 0 ? Int((currentPage / document.totalPages) * 100) : 0
                
                HStack {
                    Text("Total Pages:")
                        .foregroundColor(.secondary)
                    TextField("Total", value: Binding(
                        get: { document.totalPages },
                        set: { newValue in
                            document.totalPages = newValue
                            try? modelContext.save()
                        }
                    ), format: .number)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 80)
                    
                    Text("| **\(remaining.formatted()) pages remaining (\(percentage)%)**")
                        .foregroundColor(.secondary)
                }
                
                Divider()
                
                // Add Log Form
                GroupBox("Log Progress") {
                    HStack(alignment: .bottom) {
                        VStack(alignment: .leading) {
                            Text("Page")
                            TextField("Page", text: $newPage)
                        }
                        VStack(alignment: .leading) {
                            Text("Topic")
                            TextField("Topic", text: $newTopic)
                        }
                        VStack(alignment: .leading) {
                            Text("Satisfaction (1-5)")
                            TextField("1-5", text: $newSatisfaction)
                        }
                        Button("Log") {
                            addLog()
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.primary)
                    }
                    .padding()
                }
                
                HStack {
                    Text("Reading History")
                        .font(.title2)
                        .bold()
                    
                    Spacer()
                    
                    if !document.progressLogs.isEmpty {
                        Button("Clear All") {
                            for log in document.progressLogs {
                                modelContext.delete(log)
                            }
                            document.progressLogs.removeAll()
                            try? modelContext.save()
                        }
                        .buttonStyle(.bordered)
                        .tint(.primary)
                    }
                }
                
                ForEach(document.progressLogs.sorted { $0.date > $1.date }) { log in
                    ProgressLogRowView(log: log, document: document)
                }
            }
            .padding()
        }
        .onAppear {
            if let last = document.progressLogs.max(by: { $0.date < $1.date }) {
                newPage = String(format: "%g", last.page)
            }
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(role: .destructive, action: {
                    onDelete?()
                }) {
                    Label("Delete Document", systemImage: "trash")
                        .foregroundColor(.secondary)
                }
            }
        }
    }
    
    private func addLog() {
        let cleanedPage = newPage.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let page = Double(cleanedPage) else { return }
        let sat = Int(newSatisfaction.trimmingCharacters(in: .whitespacesAndNewlines))
        
        let log = ProgressLog(page: page, topic: newTopic, satisfaction: sat)
        modelContext.insert(log)
        document.progressLogs.append(log)
        
        try? modelContext.save()
        
        // Reset form
        newTopic = ""
        newSatisfaction = ""
    }
}

struct AddDocumentView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @State private var title = ""
    @State private var totalPages = ""
    @State private var targetDate = Date()
    @State private var difficulty = ""
    @State private var link = ""
    @State private var tags = ""
    
    var body: some View {
        NavigationStack {
            Form {
                TextField("Title", text: $title)
                TextField("Total Pages", text: $totalPages)
                DatePicker("Target Date", selection: $targetDate, displayedComponents: .date)
                TextField("Difficulty (1-5)", text: $difficulty)
                TextField("Link", text: $link)
                TextField("Tags (comma separated)", text: $tags)
            }
            .padding()
            .navigationTitle("Add Document")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        save()
                    }
                    .disabled(title.isEmpty || Double(totalPages) == nil)
                }
            }
        }
        .frame(width: 400, height: 300)
    }
    
    private func save() {
        guard let pages = Double(totalPages) else { return }
        let diff = Int(difficulty)
        let tagArray = tags.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        
        let doc = Document(title: title, totalPages: pages, targetDate: targetDate, difficulty: diff, link: link.isEmpty ? nil : link, tags: tagArray)
        modelContext.insert(doc)
        try? modelContext.save()
        dismiss()
    }
}

struct ProgressLogRowView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var log: ProgressLog
    let document: Document
    
    @State private var isEditing = false
    @State private var editPage: String = ""
    @State private var editTopic: String = ""
    @State private var editSatisfaction: String = ""
    
    var body: some View {
        GroupBox {
            if isEditing {
                VStack(alignment: .trailing, spacing: 10) {
                    HStack {
                        VStack(alignment: .leading) {
                            Text("Page").font(.caption)
                            TextField("Page", text: $editPage)
                        }
                        VStack(alignment: .leading) {
                            Text("Topic").font(.caption)
                            TextField("Topic", text: $editTopic)
                        }
                        VStack(alignment: .leading) {
                            Text("Satisfaction").font(.caption)
                            TextField("1-5", text: $editSatisfaction)
                        }
                    }
                    HStack {
                        Button("Cancel") { isEditing = false }
                        Button("Save") {
                            if let p = Double(editPage) {
                                log.page = p
                            }
                            log.topic = editTopic
                            if let s = Int(editSatisfaction) {
                                log.satisfaction = s
                            } else if editSatisfaction.isEmpty {
                                log.satisfaction = nil
                            }
                            try? modelContext.save()
                            isEditing = false
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.primary)
                    }
                }
            } else {
                HStack {
                    VStack(alignment: .leading) {
                        Text("Page \(log.page.formatted())")
                            .font(.headline)
                        Text(log.topic.isEmpty ? "No topic" : log.topic)
                            .foregroundColor(.secondary)
                        if let sat = log.satisfaction {
                            Text("Satisfaction: \(sat)/5")
                                .font(.caption)
                        }
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 8) {
                        Text(log.date, format: .dateTime)
                            .foregroundColor(.secondary)
                            .font(.caption)
                        HStack {
                            Button(action: {
                                editPage = String(format: "%g", log.page)
                                editTopic = log.topic
                                editSatisfaction = log.satisfaction.map { String($0) } ?? ""
                                isEditing = true
                            }) {
                                Image(systemName: "pencil")
                            }
                            .buttonStyle(.plain)
                            .foregroundColor(.secondary)
                            
                            Button(action: {
                                if let index = document.progressLogs.firstIndex(of: log) {
                                    document.progressLogs.remove(at: index)
                                }
                                modelContext.delete(log)
                                try? modelContext.save()
                            }) {
                                Image(systemName: "trash")
                            }
                            .buttonStyle(.plain)
                            .foregroundColor(.secondary)
                        }
                    }
                }
            }
        }
    }
}
