import SwiftUI
import SwiftData

struct ContentView: View {
    @State private var selectedView: AppView? = .details
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    @Environment(\.modelContext) private var modelContext
    
    @Query private var documents: [Document]
    @Query private var progressLogs: [ProgressLog]
    @Query private var todos: [Todo]
    @Query private var papers: [Paper]
    @Query private var conceptNodes: [ConceptNode]
    @Query private var conceptLinks: [ConceptLink]
    @Query private var memos: [GeneralMemo]
    
    @AppStorage("tagOrder") private var tagOrderString: String = ""
    
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
        NavigationSplitView(columnVisibility: $columnVisibility) {
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
            default:
                Text("Select a view from the sidebar")
                    .font(.largeTitle)
                    .foregroundColor(.secondary)
            }
        }
        .onChange(of: selectedView) { _, newValue in
            if newValue == .graph {
                columnVisibility = .detailOnly
            } else {
                columnVisibility = .all
            }
        }
        .frame(minWidth: 1000, idealWidth: 1000, minHeight: 600, idealHeight: 600)
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
            documents: documents.map { BackupDocument(id: FlexibleID(uuid: $0.id), title: $0.title, totalPages: $0.totalPages, targetDate: $0.targetDate, difficulty: $0.difficulty, link: $0.link, orderIndex: $0.orderIndex, progressLogs: $0.progressLogs.map { BackupProgressLog(id: FlexibleID(uuid: $0.id), date: $0.date, page: $0.page, topic: $0.topic, satisfaction: $0.satisfaction) }, tags: $0.tags) },
            progressLogs: progressLogs.map { BackupProgressLog(id: FlexibleID(uuid: $0.id), date: $0.date, page: $0.page, topic: $0.topic, satisfaction: $0.satisfaction, documentId: $0.document.map { FlexibleID(uuid: $0.id) }) },
            todos: todos.map { BackupTodo(id: FlexibleID(uuid: $0.id), text: $0.text, completed: $0.completed, status: $0.status) },
            papers: papers.map { BackupPaper(id: FlexibleID(uuid: $0.id), title: $0.title, url: $0.url, status: $0.status, tags: $0.tags) },
            conceptNodes: conceptNodes.map { BackupConceptNode(id: FlexibleID(uuid: $0.id), title: $0.title, shortName: $0.shortName, content: $0.content, x: $0.x, y: $0.y) },
            conceptLinks: conceptLinks.map { BackupConceptLink(id: FlexibleID(uuid: $0.id), sourceId: FlexibleID(uuid: $0.source?.id ?? UUID()), targetId: FlexibleID(uuid: $0.target?.id ?? UUID())) },
            memos: memos.map { BackupMemo(id: FlexibleID(uuid: $0.id), text: $0.text, tabIndex: $0.tabIndex, tabName: $0.tabName) },
            tagOrder: tagOrderString
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
                
                if let tagOrder = backup.tagOrder {
                    tagOrderString = tagOrder
                }
                
                // Maps for existing data
                var existingDocs = [UUID: Document]()
                for d in documents { existingDocs[d.id] = d }
                
                var existingLogs = [UUID: ProgressLog]()
                for l in progressLogs { existingLogs[l.id] = l }
                
                var existingTodos = [UUID: Todo]()
                for t in todos { existingTodos[t.id] = t }
                
                var existingPapers = [UUID: Paper]()
                for p in papers { existingPapers[p.id] = p }
                
                var existingNodes = [UUID: ConceptNode]()
                for n in conceptNodes { existingNodes[n.id] = n }
                
                var existingLinks = [UUID: ConceptLink]()
                for l in conceptLinks { existingLinks[l.id] = l }
                
                var existingMemos = [UUID: GeneralMemo]()
                for m in memos { existingMemos[m.id] = m }

                // Import
                var docMap = [UUID: Document]()
                var insertedLogIds = Set<UUID>()
                for b in backup.documents ?? [] {
                    let uuid = b.id?.uuid ?? UUID()
                    let doc: Document
                    if let existing = existingDocs[uuid] {
                        doc = existing
                        doc.title = b.title ?? "Untitled"
                        doc.totalPages = b.totalPages ?? 0
                        doc.targetDate = b.targetDate ?? Date()
                        doc.difficulty = b.difficulty
                        doc.link = b.link
                        doc.orderIndex = b.orderIndex ?? 0
                        doc.tags = b.tags ?? []
                    } else {
                        doc = Document(title: b.title ?? "Untitled", totalPages: b.totalPages ?? 0, targetDate: b.targetDate ?? Date(), difficulty: b.difficulty, link: b.link, orderIndex: b.orderIndex ?? 0, tags: b.tags ?? [])
                        doc.id = uuid
                        modelContext.insert(doc)
                    }
                    docMap[uuid] = doc
                    
                    for p in b.progressLogs ?? [] {
                        let pUuid = p.id?.uuid ?? UUID()
                        if insertedLogIds.contains(pUuid) { continue }
                        insertedLogIds.insert(pUuid)
                        
                        let log: ProgressLog
                        if let existing = existingLogs[pUuid] {
                            log = existing
                            log.date = p.date ?? Date()
                            log.page = p.page ?? 0
                            log.topic = p.topic ?? ""
                            log.satisfaction = p.satisfaction
                        } else {
                            log = ProgressLog(date: p.date ?? Date(), page: p.page ?? 0, topic: p.topic ?? "", satisfaction: p.satisfaction)
                            log.id = pUuid
                            log.document = doc
                            modelContext.insert(log)
                        }
                    }
                }
                
                for b in backup.progressLogs ?? [] {
                    let uuid = b.id?.uuid ?? UUID()
                    if insertedLogIds.contains(uuid) { continue }
                    insertedLogIds.insert(uuid)
                    
                    let log: ProgressLog
                    if let existing = existingLogs[uuid] {
                        log = existing
                        log.date = b.date ?? Date()
                        log.page = b.page ?? 0
                        log.topic = b.topic ?? ""
                        log.satisfaction = b.satisfaction
                        if let docId = b.documentId?.uuid, let doc = docMap[docId] {
                            log.document = doc
                        }
                    } else {
                        log = ProgressLog(date: b.date ?? Date(), page: b.page ?? 0, topic: b.topic ?? "", satisfaction: b.satisfaction)
                        log.id = uuid
                        if let docId = b.documentId?.uuid { log.document = docMap[docId] }
                        modelContext.insert(log)
                    }
                }
                
                for b in backup.todos ?? [] {
                    let uuid = b.id?.uuid ?? UUID()
                    if let existing = existingTodos[uuid] {
                        existing.text = b.text ?? ""
                        existing.completed = b.completed ?? false
                        existing.status = b.status ?? "Todo"
                    } else {
                        let todo = Todo(text: b.text ?? "", completed: b.completed ?? false, status: b.status ?? "Todo")
                        todo.id = uuid
                        modelContext.insert(todo)
                    }
                }
                
                for b in backup.papers ?? [] {
                    let uuid = b.id?.uuid ?? UUID()
                    if let existing = existingPapers[uuid] {
                        existing.title = b.title ?? "Untitled"
                        existing.url = b.url ?? ""
                        existing.status = b.status ?? "Not Started"
                        existing.tags = b.tags ?? []
                    } else {
                        let paper = Paper(title: b.title ?? "Untitled", url: b.url ?? "", status: b.status ?? "Not Started", tags: b.tags ?? [])
                        paper.id = uuid
                        modelContext.insert(paper)
                    }
                }
                
                var nodeMap = [UUID: ConceptNode]()
                for b in backup.conceptNodes ?? [] {
                    let uuid = b.id?.uuid ?? UUID()
                    let node: ConceptNode
                    if let existing = existingNodes[uuid] {
                        node = existing
                        node.title = b.title ?? "Untitled"
                        node.shortName = b.shortName
                        node.content = b.content ?? ""
                        node.x = b.x ?? 0.0
                        node.y = b.y ?? 0.0
                    } else {
                        node = ConceptNode(title: b.title ?? "Untitled", shortName: b.shortName, content: b.content ?? "")
                        node.id = uuid
                        modelContext.insert(node)
                    }
                    nodeMap[uuid] = node
                }
                
                for b in backup.conceptLinks ?? [] {
                    let uuid = b.id?.uuid ?? UUID()
                    if let existing = existingLinks[uuid] {
                        if let sId = b.sourceId?.uuid, let tId = b.targetId?.uuid, let src = nodeMap[sId], let tgt = nodeMap[tId] {
                            existing.source = src
                            existing.target = tgt
                        }
                    } else {
                        if let sId = b.sourceId?.uuid, let tId = b.targetId?.uuid, let src = nodeMap[sId], let tgt = nodeMap[tId] {
                            let link = ConceptLink(source: src, target: tgt)
                            link.id = uuid
                            modelContext.insert(link)
                        }
                    }
                }
                
                for b in backup.memos ?? [] {
                    let uuid = b.id?.uuid ?? UUID()
                    if let existing = existingMemos[uuid] {
                        existing.text = b.text ?? ""
                        existing.tabIndex = b.tabIndex ?? 0
                        existing.tabName = b.tabName
                    } else {
                        let memo = GeneralMemo(text: b.text ?? "", tabIndex: b.tabIndex ?? 0, tabName: b.tabName)
                        memo.id = uuid
                        modelContext.insert(memo)
                    }
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
