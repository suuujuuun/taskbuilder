import SwiftUI
import SwiftData

struct ContentView: View {
    @State private var selectedView: AppView? = .details
    @Environment(\.modelContext) private var modelContext
    
    @Query private var documents: [Document]
    @Query private var progressLogs: [ProgressLog]
    @Query private var todos: [Todo]
    @Query private var papers: [Paper]
    @Query private var conceptNodes: [ConceptNode]
    @Query private var conceptLinks: [ConceptLink]
    @Query private var memos: [GeneralMemo]
    
    @State private var showingAlert = false
    @State private var alertMessage = ""
    
    enum AppView: Hashable {
        case details
        case overview
        case papers
        case planning
        case graph
    }
    
    var body: some View {
        NavigationSplitView {
            List(selection: $selectedView) {
                NavigationLink(value: AppView.details) {
                    Label("Details", systemImage: "list.bullet.rectangle.portrait")
                }
                NavigationLink(value: AppView.overview) {
                    Label("Overview", systemImage: "square.grid.2x2")
                }
                NavigationLink(value: AppView.papers) {
                    Label("Papers", systemImage: "doc.text")
                }
                NavigationLink(value: AppView.planning) {
                    Label("To-Do & Memo", systemImage: "checkmark.square")
                }
                NavigationLink(value: AppView.graph) {
                    Label("Knowledge Graph", systemImage: "brain.head.profile")
                }
            }
            .navigationTitle("Tracker")
            .listStyle(.sidebar)
        } detail: {
            switch selectedView {
            case .details:
                DetailsView()
            case .overview:
                OverviewView()
            case .papers:
                PapersView()
            case .planning:
                PlanningView()
            case .graph:
                KnowledgeGraphView()
            case .none:
                Text("Select a view")
                    .foregroundColor(.secondary)
            }
        }
        .frame(minWidth: 1000, minHeight: 600)
        .preferredColorScheme(.dark)
        .tint(.white)
        .toolbar {
            ToolbarItemGroup {
                Button("Import JSON") { importData() }
                Button("Export JSON") { exportData() }
            }
        }
        .alert("Status", isPresented: $showingAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(alertMessage)
        }
    }
    
    private func exportData() {
        let backup = BackupData(
            documents: documents.map { BackupDocument(id: $0.id, title: $0.title, totalPages: $0.totalPages, targetDate: $0.targetDate, difficulty: $0.difficulty, link: $0.link, orderIndex: $0.orderIndex) },
            progressLogs: progressLogs.map { BackupProgressLog(id: $0.id, date: $0.date, page: $0.page, topic: $0.topic, satisfaction: $0.satisfaction, documentId: $0.document?.id) },
            todos: todos.map { BackupTodo(id: $0.id, text: $0.text, completed: $0.completed, status: $0.status) },
            papers: papers.map { BackupPaper(id: $0.id, title: $0.title, url: $0.url, status: $0.status) },
            conceptNodes: conceptNodes.map { BackupConceptNode(id: $0.id, title: $0.title, shortName: $0.shortName, content: $0.content, x: $0.x, y: $0.y) },
            conceptLinks: conceptLinks.map { BackupConceptLink(id: $0.id, sourceId: $0.source?.id ?? UUID(), targetId: $0.target?.id ?? UUID()) },
            memos: memos.map { BackupMemo(id: $0.id, text: $0.text) }
        )
        
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        encoder.dateEncodingStrategy = .iso8601
        
        guard let data = try? encoder.encode(backup) else {
            alertMessage = "Failed to encode data."
            showingAlert = true
            return
        }
        
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = "ReadingTrackerBackup.json"
        
        if panel.runModal() == .OK, let url = panel.url {
            do {
                try data.write(to: url)
                alertMessage = "Exported successfully."
            } catch {
                alertMessage = "Failed to write file."
            }
            showingAlert = true
        }
    }
    
    private func importData() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        
        if panel.runModal() == .OK, let url = panel.url {
            do {
                let data = try Data(contentsOf: url)
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601
                let backup = try decoder.decode(BackupData.self, from: data)
                
                // Clear existing
                try modelContext.delete(model: Document.self)
                try modelContext.delete(model: ProgressLog.self)
                try modelContext.delete(model: Todo.self)
                try modelContext.delete(model: Paper.self)
                try modelContext.delete(model: ConceptNode.self)
                try modelContext.delete(model: ConceptLink.self)
                try modelContext.delete(model: GeneralMemo.self)
                
                // Import
                var docMap = [UUID: Document]()
                for b in backup.documents {
                    let doc = Document(title: b.title, totalPages: b.totalPages, targetDate: b.targetDate, difficulty: b.difficulty, link: b.link, orderIndex: b.orderIndex)
                    doc.id = b.id
                    modelContext.insert(doc)
                    docMap[b.id] = doc
                }
                
                for b in backup.progressLogs {
                    let log = ProgressLog(date: b.date, page: b.page, topic: b.topic, satisfaction: b.satisfaction)
                    log.id = b.id
                    if let docId = b.documentId { log.document = docMap[docId] }
                    modelContext.insert(log)
                }
                
                for b in backup.todos {
                    let todo = Todo(text: b.text, completed: b.completed, status: b.status)
                    todo.id = b.id
                    modelContext.insert(todo)
                }
                
                for b in backup.papers {
                    let paper = Paper(title: b.title, url: b.url, status: b.status)
                    paper.id = b.id
                    modelContext.insert(paper)
                }
                
                var nodeMap = [UUID: ConceptNode]()
                for b in backup.conceptNodes {
                    let node = ConceptNode(title: b.title, shortName: b.shortName, content: b.content)
                    node.id = b.id
                    node.x = b.x
                    node.y = b.y
                    modelContext.insert(node)
                    nodeMap[b.id] = node
                }
                
                for b in backup.conceptLinks {
                    if let src = nodeMap[b.sourceId], let tgt = nodeMap[b.targetId] {
                        let link = ConceptLink(source: src, target: tgt)
                        link.id = b.id
                        modelContext.insert(link)
                    }
                }
                
                for b in backup.memos {
                    let memo = GeneralMemo(text: b.text)
                    memo.id = b.id
                    modelContext.insert(memo)
                }
                
                try modelContext.save()
                alertMessage = "Imported successfully."
            } catch {
                alertMessage = "Failed to import JSON: \(error.localizedDescription)"
            }
            showingAlert = true
        }
}
}
