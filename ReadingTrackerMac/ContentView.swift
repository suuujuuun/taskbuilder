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
            documents: documents.map { BackupDocument(id: FlexibleID(uuid: $0.id), title: $0.title, totalPages: $0.totalPages, targetDate: $0.targetDate, difficulty: $0.difficulty, link: $0.link, orderIndex: $0.orderIndex, progressLogs: $0.progressLogs.map { BackupProgressLog(id: FlexibleID(uuid: $0.id), date: $0.date, page: $0.page, topic: $0.topic, satisfaction: $0.satisfaction) }) },
            progressLogs: progressLogs.map { BackupProgressLog(id: FlexibleID(uuid: $0.id), date: $0.date, page: $0.page, topic: $0.topic, satisfaction: $0.satisfaction, documentId: $0.document.map { FlexibleID(uuid: $0.id) }) },
            todos: todos.map { BackupTodo(id: FlexibleID(uuid: $0.id), text: $0.text, completed: $0.completed, status: $0.status) },
            papers: papers.map { BackupPaper(id: FlexibleID(uuid: $0.id), title: $0.title, url: $0.url, status: $0.status) },
            conceptNodes: conceptNodes.map { BackupConceptNode(id: FlexibleID(uuid: $0.id), title: $0.title, shortName: $0.shortName, content: $0.content, x: $0.x, y: $0.y) },
            conceptLinks: conceptLinks.map { BackupConceptLink(id: FlexibleID(uuid: $0.id), sourceId: FlexibleID(uuid: $0.source?.id ?? UUID()), targetId: FlexibleID(uuid: $0.target?.id ?? UUID())) },
            memos: memos.map { BackupMemo(id: FlexibleID(uuid: $0.id), text: $0.text) }
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
                decoder.dateDecodingStrategy = .custom { decoder in
                    let container = try decoder.singleValueContainer()
                    if let str = try? container.decode(String.self) {
                        let formatter = ISO8601DateFormatter()
                        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                        if let date = formatter.date(from: str) { return date }
                        let formatter2 = ISO8601DateFormatter()
                        if let date = formatter2.date(from: str) { return date }
                    }
                    if let d = try? container.decode(Double.self) {
                        return Date(timeIntervalSinceReferenceDate: d)
                    }
                    throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid date format")
                }
                
                let jsonObj = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
                let foundKeys = jsonObj?.keys.joined(separator: ", ") ?? "unknown"
                
                var debugInfo = ""
                if let dict = jsonObj {
                    let dType = type(of: dict["data"])
                    debugInfo += "\nDataType: \(dType)"
                    if let dataArr = dict["data"] as? [[String: Any]], let first = dataArr.first {
                        let typeInfo = first.map { "\($0.key):\(type(of: $0.value))" }.joined(separator: ", ")
                        debugInfo += "\nData keys: \(first.keys.joined(separator: ", "))\nTypes: \(typeInfo)"
                        
                        if let plArr = first["progressLogs"] as? [[String: Any]], let plFirst = plArr.first {
                            let plTypeInfo = plFirst.map { "\($0.key):\(type(of: $0.value))" }.joined(separator: ", ")
                            debugInfo += "\nPL Types: \(plTypeInfo)"
                        }
                    } else if let dataDict = dict["data"] as? [String: Any] {
                        debugInfo += "\nData is Dict, keys: \(dataDict.keys.prefix(3).joined(separator: ", "))"
                        if let firstVal = dataDict.values.first as? [String: Any] {
                            debugInfo += "\nInner keys: \(firstVal.keys.joined(separator: ", "))"
                        }
                    }
                    
                    let mType = type(of: dict["memo"])
                    debugInfo += "\nMemoType: \(mType)"
                    if let memoArr = dict["memo"] as? [[String: Any]], let first = memoArr.first {
                        debugInfo += "\nMemo keys: \(first.keys.joined(separator: ", "))"
                    } else if let memoDict = dict["memo"] as? [String: Any] {
                        debugInfo += "\nMemo is Dict, keys: \(memoDict.keys.prefix(3).joined(separator: ", "))"
                    }
                }
                
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
                var insertedLogIds = Set<UUID>()
                for b in backup.documents ?? [] {
                    let doc = Document(title: b.title ?? "Untitled", totalPages: b.totalPages ?? 0, targetDate: b.targetDate ?? Date(), difficulty: b.difficulty, link: b.link, orderIndex: b.orderIndex ?? 0)
                    doc.id = b.id?.uuid ?? UUID()
                    modelContext.insert(doc)
                    docMap[doc.id] = doc
                    
                    for p in b.progressLogs ?? [] {
                        let uuid = p.id?.uuid ?? UUID()
                        if insertedLogIds.contains(uuid) { continue }
                        insertedLogIds.insert(uuid)
                        let log = ProgressLog(date: p.date ?? Date(), page: p.page ?? 0, topic: p.topic ?? "", satisfaction: p.satisfaction)
                        log.id = uuid
                        log.document = doc
                        modelContext.insert(log)
                    }
                }
                
                for b in backup.progressLogs ?? [] {
                    let uuid = b.id?.uuid ?? UUID()
                    if insertedLogIds.contains(uuid) { continue }
                    insertedLogIds.insert(uuid)
                    let log = ProgressLog(date: b.date ?? Date(), page: b.page ?? 0, topic: b.topic ?? "", satisfaction: b.satisfaction)
                    log.id = uuid
                    if let docId = b.documentId?.uuid { log.document = docMap[docId] }
                    modelContext.insert(log)
                }
                
                for b in backup.todos ?? [] {
                    let todo = Todo(text: b.text ?? "", completed: b.completed ?? false, status: b.status ?? "Todo")
                    todo.id = b.id?.uuid ?? UUID()
                    modelContext.insert(todo)
                }
                
                for b in backup.papers ?? [] {
                    let paper = Paper(title: b.title ?? "Untitled", url: b.url ?? "", status: b.status ?? "Not Started")
                    paper.id = b.id?.uuid ?? UUID()
                    modelContext.insert(paper)
                }
                
                var nodeMap = [UUID: ConceptNode]()
                for b in backup.conceptNodes ?? [] {
                    let node = ConceptNode(title: b.title ?? "Untitled", shortName: b.shortName, content: b.content ?? "")
                    node.id = b.id?.uuid ?? UUID()
                    node.x = b.x ?? 0.0
                    node.y = b.y ?? 0.0
                    modelContext.insert(node)
                    nodeMap[node.id] = node
                }
                
                for b in backup.conceptLinks ?? [] {
                    if let sId = b.sourceId?.uuid, let tId = b.targetId?.uuid, let src = nodeMap[sId], let tgt = nodeMap[tId] {
                        let link = ConceptLink(source: src, target: tgt)
                        link.id = b.id?.uuid ?? UUID()
                        modelContext.insert(link)
                    }
                }
                
                for b in backup.memos ?? [] {
                    let memo = GeneralMemo(text: b.text ?? "")
                    memo.id = b.id?.uuid ?? UUID()
                    modelContext.insert(memo)
                }
                
                try modelContext.save()
                alertMessage = "Imported successfully.\nFound keys: \(foundKeys)\nLoaded Books: \(backup.documents?.count ?? 0), Memos: \(backup.memos?.count ?? 0), Papers: \(backup.papers?.count ?? 0)\(debugInfo)"
            } catch let DecodingError.dataCorrupted(context) {
                alertMessage = "Data corrupted: \(context.debugDescription)"
            } catch let DecodingError.keyNotFound(key, context) {
                alertMessage = "Missing key '\(key.stringValue)' at \(context.codingPath.map(\.stringValue).joined(separator: "."))"
            } catch let DecodingError.typeMismatch(type, context) {
                alertMessage = "Type mismatch for '\(context.codingPath.last?.stringValue ?? "unknown")'. Expected \(type)."
            } catch let DecodingError.valueNotFound(type, context) {
                alertMessage = "Value not found for '\(context.codingPath.last?.stringValue ?? "unknown")'. Expected \(type)."
            } catch {
                alertMessage = "Failed to import JSON: \(error.localizedDescription)"
            }
            showingAlert = true
        }
}
}
