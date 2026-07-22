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
    @Query private var movies: [Movie]
    @Query private var businesses: [Business]
    @Query private var diaries: [DiaryEntry]
    @Query private var people: [Person]
    @Query private var dailyTasks: [DailyTask]
    @Query private var dailyTaskLogs: [DailyTaskLog]
    
    @AppStorage("sidebarTabOrder") private var sidebarTabOrderString: String = ""
    @AppStorage("tagOrder") private var tagOrderString: String = ""
    @State private var sidebarTabs: [AppView] = AppView.allCases
    
    @State private var showingAlert = false
    @State private var alertMessage = ""
    
    enum AppView: String, Hashable, Codable, CaseIterable {
        case details
        case overview
        case papers
        case planning
        case graph
        case movies
        case business
        case diary
        case people
        case dailyTasks
        
        var title: String {
            switch self {
            case .details: return "Details"
            case .overview: return "Overview"
            case .papers: return "Papers"
            case .planning: return "To-Do & Memo"
            case .diary: return "Diary"
            case .graph: return "Knowledge Graph"
            case .movies: return "Movies"
            case .business: return "Business"
            case .people: return "People"
            case .dailyTasks: return "Daily Study"
            }
        }
        
        var icon: String {
            switch self {
            case .details: return "list.bullet.rectangle.portrait"
            case .overview: return "square.grid.2x2"
            case .papers: return "doc.text"
            case .planning: return "checkmark.square"
            case .diary: return "book.pages"
            case .graph: return "brain.head.profile"
            case .movies: return "film"
            case .business: return "briefcase"
            case .people: return "person.2"
            case .dailyTasks: return "checkmark.seal"
            }
        }
    }
    
    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            List(selection: $selectedView) {
                ForEach(sidebarTabs, id: \.self) { tab in
                    NavigationLink(value: tab) {
                        Label(tab.title, systemImage: tab.icon)
                    }
                }
                .onMove { source, destination in
                    sidebarTabs.move(fromOffsets: source, toOffset: destination)
                    sidebarTabOrderString = sidebarTabs.map { $0.rawValue }.joined(separator: ",")
                }
            }
            .navigationTitle("Tracker")
            .listStyle(.sidebar)
            .toolbar(removing: .sidebarToggle)
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
                KnowledgeGraphView(columnVisibility: $columnVisibility)
            case .movies:
                MoviesView()
            case .business:
                BusinessView()
            case .diary:
                DiaryView()
            case .people:
                PeopleView()
            case .dailyTasks:
                DailyStudyView()
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
            ToolbarItem(placement: .navigation) {
                Button(action: {
                    if columnVisibility == .all {
                        columnVisibility = .detailOnly
                    } else {
                        columnVisibility = .all
                    }
                }) {
                    Image(systemName: "sidebar.left")
                }
                .help("Toggle Sidebar")
            }
            
            ToolbarItemGroup(placement: .primaryAction) {
                Button("Import JSON") { importData() }
                Button("Export JSON") { exportData() }
            }
        }
        .alert("Status", isPresented: $showingAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(alertMessage)
        }
        .onAppear {
            let saved = sidebarTabOrderString.split(separator: ",").compactMap { AppView(rawValue: String($0)) }
            var merged = saved
            for view in AppView.allCases {
                if !merged.contains(view) {
                    merged.append(view)
                }
            }
            sidebarTabs = merged
        }
    }
    
    private func getDocumentsDirectory() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
    
    private func exportData() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = "ReadingTrackerBackup.json"
        
        if panel.runModal() == .OK, let url = panel.url {
            // Build dictionaries to map PersistentIdentifier -> UUID without triggering faults
            var docMap = [PersistentIdentifier: UUID]()
            for d in documents where !d.isDeleted { docMap[d.persistentModelID] = d.id }
            
            var nodeMap = [PersistentIdentifier: UUID]()
            for n in conceptNodes where !n.isDeleted { nodeMap[n.persistentModelID] = n.id }
            
            let safeDocs = documents.filter { !$0.isDeleted }.map { doc in
                BackupDocument(id: FlexibleID(uuid: doc.id), title: doc.title, totalPages: doc.totalPages, targetDate: doc.targetDate, difficulty: doc.difficulty, link: doc.link, orderIndex: doc.orderIndex, progressLogs: doc.progressLogs.filter { !$0.isDeleted }.map { BackupProgressLog(id: FlexibleID(uuid: $0.id), date: $0.date, page: $0.page, topic: $0.topic, satisfaction: $0.satisfaction) }, tags: doc.tags)
            }
            
            let safeLogs = progressLogs.filter { !$0.isDeleted }.compactMap { log -> BackupProgressLog? in
                var docId: UUID? = nil
                if let dProxy = log.document {
                    if let dId = docMap[dProxy.persistentModelID] {
                        docId = dId
                    } else {
                        // Dangling proxy! Safely discard or set to nil. We'll discard it since it's orphaned.
                        return nil
                    }
                }
                return BackupProgressLog(id: FlexibleID(uuid: log.id), date: log.date, page: log.page, topic: log.topic, satisfaction: log.satisfaction, documentId: docId.map { FlexibleID(uuid: $0) })
            }
            
            let safeTodos = todos.filter { !$0.isDeleted }.map { t in
                BackupTodo(id: FlexibleID(uuid: t.id), text: t.text, completed: t.completed, status: t.status, orderIndex: t.orderIndex, deadline: t.deadline, isImportant: t.isImportant)
            }
            
            let safePapers = papers.filter { !$0.isDeleted }.map { p in
                BackupPaper(id: FlexibleID(uuid: p.id), title: p.title, url: p.url, status: p.status, tags: p.tags)
            }
            
            let safeNodes = conceptNodes.filter { !$0.isDeleted }.map { n in
                BackupConceptNode(id: FlexibleID(uuid: n.id), title: n.title, shortName: n.shortName, content: n.content, x: n.x, y: n.y, tags: n.tags)
            }
            
            let safeLinks = conceptLinks.filter { !$0.isDeleted }.compactMap { link -> BackupConceptLink? in
                guard let sProxy = link.source, let tProxy = link.target else { return nil }
                // Safely lookup IDs via persistentModelID to avoid SIGTRAP on dangling proxies
                guard let sId = nodeMap[sProxy.persistentModelID],
                      let tId = nodeMap[tProxy.persistentModelID] else {
                    return nil
                }
                return BackupConceptLink(id: FlexibleID(uuid: link.id), sourceId: FlexibleID(uuid: sId), targetId: FlexibleID(uuid: tId))
            }
            
            let safeMemos = memos.filter { !$0.isDeleted }.map { m in
                BackupMemo(id: FlexibleID(uuid: m.id), text: m.text, tabIndex: m.tabIndex, tabName: m.tabName)
            }
            
            struct MovieMeta {
                let id: UUID; let title: String; let director: String; let rating: Double
                let review: String; let imagePath: String?; let tags: [String]; let orderIndex: Int
            }
            
            let moviesMeta = movies.filter { !$0.isDeleted }.map { m in
                MovieMeta(id: m.id, title: m.title, director: m.director, rating: m.rating, review: m.review, imagePath: m.imagePath, tags: m.tags, orderIndex: m.orderIndex)
            }
            
            let safeBusinesses = businesses.filter { !$0.isDeleted }.map { b in
                BackupBusiness(id: FlexibleID(uuid: b.id), name: b.name, plan: b.plan, targetGoal: b.targetGoal, targetRevenue: b.targetRevenue, achievementRate: b.achievementRate, feasibility: b.feasibility, targetAudience: b.targetAudience, competitors: b.competitors, businessModel: b.businessModel, executiveSummary: b.executiveSummary, marketingStrategy: b.marketingStrategy, swotAnalysis: b.swotAnalysis, budget: b.budget, timeline: b.timeline, riskManagement: b.riskManagement, teamStructure: b.teamStructure, kpis: b.kpis, actionItems: b.actionItems, targetMarketSize: b.targetMarketSize, coreFeatures: b.coreFeatures, websiteURL: b.websiteURL, githubURL: b.githubURL, techStack: b.techStack, architectureLogic: b.architectureLogic, referenceLinks: b.referenceLinks, currentRevenue: b.currentRevenue, contacts: b.contacts, contactList: b.contactList, todoList: b.todoList, orderIndex: b.orderIndex, tags: b.tags)
            }
            
            let safeDiaries = diaries.filter { !$0.isDeleted }.map { d in
                BackupDiaryEntry(id: FlexibleID(uuid: d.id), date: d.date, content: d.content, isHighlighted: d.isHighlighted)
            }
            
            struct PersonMeta {
                let id: UUID; let name: String; let role: String; let link: String
                let imagePath: String?; let comment: String; let tags: [String]; let orderIndex: Int
                let isEnglish: Bool
            }
            
            let peopleMeta = people.filter { !$0.isDeleted }.map { p in
                PersonMeta(id: p.id, name: p.name, role: p.role, link: p.link, imagePath: p.imagePath, comment: p.comment, tags: p.tags, orderIndex: p.orderIndex, isEnglish: p.isEnglish)
            }
            
            let safeDailyTasks = dailyTasks.filter { !$0.isDeleted }.map { t in
                BackupDailyTask(id: FlexibleID(uuid: t.id), title: t.title, orderIndex: t.orderIndex, isActive: t.isActive, createdAt: t.createdAt)
            }
            
            var taskMap = [PersistentIdentifier: UUID]()
            for t in dailyTasks where !t.isDeleted { taskMap[t.persistentModelID] = t.id }
            
            let safeDailyTaskLogs = dailyTaskLogs.filter { !$0.isDeleted }.compactMap { l -> BackupDailyTaskLog? in
                var tId: UUID? = nil
                if let tProxy = l.task {
                    if let tMappedId = taskMap[tProxy.persistentModelID] {
                        tId = tMappedId
                    } else {
                        return nil
                    }
                }
                return BackupDailyTaskLog(id: FlexibleID(uuid: l.id), logicalDate: l.logicalDate, isCompleted: l.isCompleted, taskId: tId.map { FlexibleID(uuid: $0) })
            }
            
            let tOrder = tagOrderString
            let docsDir = getDocumentsDirectory()
            
            Task.detached {
                // Process heavy file I/O and encoding in the background
                var moviesBackup: [BackupMovie] = []
                for m in moviesMeta {
                    var imgData: Data? = nil
                    if let path = m.imagePath {
                        let fileURL = docsDir.appendingPathComponent(path)
                        imgData = try? Data(contentsOf: fileURL)
                    }
                    moviesBackup.append(BackupMovie(id: FlexibleID(uuid: m.id), title: m.title, director: m.director, rating: m.rating, review: m.review, imagePath: m.imagePath, tags: m.tags, imageData: imgData, orderIndex: m.orderIndex))
                }
                
                var peopleBackup: [BackupPerson] = []
                for p in peopleMeta {
                    var imgData: Data? = nil
                    if let path = p.imagePath {
                        let fileURL = docsDir.appendingPathComponent(path)
                        imgData = try? Data(contentsOf: fileURL)
                    }
                    peopleBackup.append(BackupPerson(id: FlexibleID(uuid: p.id), name: p.name, role: p.role, link: p.link, imagePath: p.imagePath, comment: p.comment, tags: p.tags, imageData: imgData, orderIndex: p.orderIndex, isEnglish: p.isEnglish))
                }
                
                let backup = BackupData(
                    documents: safeDocs, progressLogs: safeLogs, todos: safeTodos, papers: safePapers,
                    conceptNodes: safeNodes, conceptLinks: safeLinks, memos: safeMemos, movies: moviesBackup, businesses: safeBusinesses, diaries: safeDiaries, people: peopleBackup, dailyTasks: safeDailyTasks, dailyTaskLogs: safeDailyTaskLogs, tagOrder: tOrder
                )
                
                let encoder = JSONEncoder()
                encoder.outputFormatting = .prettyPrinted
                encoder.dateEncodingStrategy = .iso8601
                
                do {
                    let data = try encoder.encode(backup)
                    try data.write(to: url)
                    await MainActor.run {
                        self.alertMessage = "Exported successfully."
                        self.showingAlert = true
                    }
                } catch {
                    await MainActor.run {
                        self.alertMessage = "Failed to export: \(error.localizedDescription)"
                        self.showingAlert = true
                    }
                }
            }
        }
    }
    
    private func importData() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        
        if panel.runModal() == .OK, let url = panel.url {
            Task.detached {
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
                    
                    let backup = try decoder.decode(BackupData.self, from: data)
                    
                    await MainActor.run {
                        if let tagOrder = backup.tagOrder {
                            self.tagOrderString = tagOrder
                        }
                        
                        var existingDocs = [UUID: Document]()
                        for d in self.documents { existingDocs[d.id] = d }
                        
                        var existingLogs = [UUID: ProgressLog]()
                        for l in self.progressLogs { existingLogs[l.id] = l }
                        
                        var existingTodos = [UUID: Todo]()
                        for t in self.todos { existingTodos[t.id] = t }
                        
                        var existingPapers = [UUID: Paper]()
                        for p in self.papers { existingPapers[p.id] = p }
                        
                        var existingNodes = [UUID: ConceptNode]()
                        for n in self.conceptNodes { existingNodes[n.id] = n }
                        
                        var existingLinks = [UUID: ConceptLink]()
                        for l in self.conceptLinks { existingLinks[l.id] = l }
                        
                        var existingMemos = [UUID: GeneralMemo]()
                        for m in self.memos { existingMemos[m.id] = m }
                        
                        var existingMovies = [UUID: Movie]()
                        for m in self.movies { existingMovies[m.id] = m }
                        
                        var existingBusinesses = [UUID: Business]()
                        for b in self.businesses { existingBusinesses[b.id] = b }

                        var existingDiaries = [UUID: DiaryEntry]()
                        for d in self.diaries { existingDiaries[d.id] = d }
                        
                        var existingPeople = [UUID: Person]()
                        for p in self.people { existingPeople[p.id] = p }

                        var existingDailyTasks = [UUID: DailyTask]()
                        for t in self.dailyTasks { existingDailyTasks[t.id] = t }

                        var existingDailyTaskLogs = [UUID: DailyTaskLog]()
                        for l in self.dailyTaskLogs { existingDailyTaskLogs[l.id] = l }

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
                                self.modelContext.insert(doc)
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
                                    self.modelContext.insert(log)
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
                                self.modelContext.insert(log)
                            }
                        }
                        
                        for b in backup.todos ?? [] {
                            let uuid = b.id?.uuid ?? UUID()
                            if let existing = existingTodos[uuid] {
                                existing.text = b.text ?? ""
                                existing.completed = b.completed ?? false
                                existing.status = b.status ?? "Todo"
                                existing.orderIndex = b.orderIndex ?? 0
                                existing.deadline = b.deadline
                                existing.isImportant = b.isImportant ?? false
                            } else {
                                let todo = Todo(text: b.text ?? "", completed: b.completed ?? false, status: b.status ?? "Todo", orderIndex: b.orderIndex ?? 0, deadline: b.deadline, isImportant: b.isImportant ?? false)
                                todo.id = uuid
                                self.modelContext.insert(todo)
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
                                self.modelContext.insert(paper)
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
                                node.tags = b.tags ?? []
                            } else {
                                node = ConceptNode(title: b.title ?? "Untitled", shortName: b.shortName, content: b.content ?? "", tags: b.tags ?? [])
                                node.id = uuid
                                self.modelContext.insert(node)
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
                                    self.modelContext.insert(link)
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
                                self.modelContext.insert(memo)
                            }
                        }
                        
                        for b in backup.movies ?? [] {
                            let uuid = b.id?.uuid ?? UUID()
                            
                            var finalImagePath = b.imagePath
                            if let data = b.imageData {
                                let filename = UUID().uuidString + ".jpg"
                                let fileURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent(filename)
                                do {
                                    try data.write(to: fileURL)
                                    finalImagePath = filename
                                } catch {
                                    print("Error saving imported image: \(error)")
                                }
                            }
                            
                            if let existing = existingMovies[uuid] {
                                existing.title = b.title ?? "Untitled"
                                existing.director = b.director ?? ""
                                existing.rating = b.rating ?? 0.0
                                existing.review = b.review ?? ""
                                if finalImagePath != nil { existing.imagePath = finalImagePath }
                                existing.tags = b.tags ?? []
                                existing.orderIndex = b.orderIndex ?? 0
                            } else {
                                let movie = Movie(title: b.title ?? "Untitled", director: b.director ?? "", rating: b.rating ?? 0.0, review: b.review ?? "", imagePath: finalImagePath, tags: b.tags ?? [], orderIndex: b.orderIndex ?? 0)
                                movie.id = uuid
                                self.modelContext.insert(movie)
                            }
                        }
                        
                        for b in backup.businesses ?? [] {
                            let uuid = b.id?.uuid ?? UUID()
                            if let existing = existingBusinesses[uuid] {
                                existing.name = b.name ?? ""
                                existing.plan = b.plan ?? ""
                                existing.targetGoal = b.targetGoal ?? ""
                                existing.targetRevenue = b.targetRevenue ?? ""
                                existing.achievementRate = b.achievementRate ?? 0.0
                                existing.feasibility = b.feasibility ?? 3
                                existing.targetAudience = b.targetAudience ?? ""
                                existing.competitors = b.competitors ?? ""
                                existing.businessModel = b.businessModel ?? ""
                                existing.executiveSummary = b.executiveSummary ?? ""
                                existing.marketingStrategy = b.marketingStrategy ?? ""
                                existing.swotAnalysis = b.swotAnalysis ?? ""
                                existing.budget = b.budget ?? ""
                                existing.timeline = b.timeline ?? ""
                                existing.riskManagement = b.riskManagement ?? ""
                                existing.teamStructure = b.teamStructure ?? ""
                                existing.kpis = b.kpis ?? ""
                                existing.actionItems = b.actionItems ?? ""
                                existing.targetMarketSize = b.targetMarketSize ?? ""
                                existing.coreFeatures = b.coreFeatures ?? ""
                                existing.websiteURL = b.websiteURL ?? ""
                                existing.githubURL = b.githubURL ?? ""
                                existing.techStack = b.techStack ?? ""
                                existing.architectureLogic = b.architectureLogic ?? ""
                                existing.referenceLinks = b.referenceLinks ?? ""
                                existing.currentRevenue = b.currentRevenue ?? ""
                                existing.contacts = b.contacts ?? ""
                                existing.contactList = b.contactList ?? []
                                existing.todoList = b.todoList ?? []
                                existing.tags = b.tags ?? []
                                existing.orderIndex = b.orderIndex ?? 0
                            } else {
                                let business = Business(name: b.name ?? "", plan: b.plan ?? "", targetGoal: b.targetGoal ?? "", targetRevenue: b.targetRevenue ?? "", currentRevenue: b.currentRevenue ?? "", achievementRate: b.achievementRate ?? 0.0, feasibility: b.feasibility ?? 3, targetAudience: b.targetAudience ?? "", competitors: b.competitors ?? "", businessModel: b.businessModel ?? "", executiveSummary: b.executiveSummary ?? "", marketingStrategy: b.marketingStrategy ?? "", swotAnalysis: b.swotAnalysis ?? "", budget: b.budget ?? "", timeline: b.timeline ?? "", riskManagement: b.riskManagement ?? "", teamStructure: b.teamStructure ?? "", kpis: b.kpis ?? "", actionItems: b.actionItems ?? "", targetMarketSize: b.targetMarketSize ?? "", coreFeatures: b.coreFeatures ?? "", websiteURL: b.websiteURL ?? "", githubURL: b.githubURL ?? "", techStack: b.techStack ?? "", architectureLogic: b.architectureLogic ?? "", referenceLinks: b.referenceLinks ?? "", contacts: b.contacts ?? "", contactList: b.contactList ?? [], todoList: b.todoList ?? [], orderIndex: b.orderIndex ?? 0, tags: b.tags ?? [])
                                business.id = uuid
                                self.modelContext.insert(business)
                            }
                        }
                        
                        for b in backup.diaries ?? [] {
                            let uuid = b.id?.uuid ?? UUID()
                            if let existing = existingDiaries[uuid] {
                                existing.date = b.date ?? Date()
                                existing.content = b.content ?? ""
                                existing.isHighlighted = b.isHighlighted ?? false
                            } else {
                                let entry = DiaryEntry(date: b.date ?? Date(), content: b.content ?? "", isHighlighted: b.isHighlighted ?? false)
                                entry.id = uuid
                                self.modelContext.insert(entry)
                            }
                        }
                        
                        for b in backup.people ?? [] {
                            let uuid = b.id?.uuid ?? UUID()
                            
                            var finalImagePath = b.imagePath
                            if let data = b.imageData {
                                let filename = UUID().uuidString + ".jpg"
                                let fileURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent(filename)
                                do {
                                    try data.write(to: fileURL)
                                    finalImagePath = filename
                                } catch {
                                    print("Error saving imported image: \(error)")
                                }
                            }
                            
                            if let existing = existingPeople[uuid] {
                                existing.name = b.name ?? ""
                                existing.role = b.role ?? ""
                                existing.link = b.link ?? ""
                                if finalImagePath != nil { existing.imagePath = finalImagePath }
                                existing.comment = b.comment ?? ""
                                existing.tags = b.tags ?? []
                                existing.orderIndex = b.orderIndex ?? 0
                                existing.isEnglish = b.isEnglish ?? false
                            } else {
                                let person = Person(name: b.name ?? "", role: b.role ?? "", link: b.link ?? "", imagePath: finalImagePath, comment: b.comment ?? "", tags: b.tags ?? [], orderIndex: b.orderIndex ?? 0, isEnglish: b.isEnglish ?? false)
                                person.id = uuid
                                self.modelContext.insert(person)
                            }
                        }
                        
                        var taskMap = [UUID: DailyTask]()
                        for b in backup.dailyTasks ?? [] {
                            let uuid = b.id?.uuid ?? UUID()
                            let task: DailyTask
                            if let existing = existingDailyTasks[uuid] {
                                task = existing
                                task.title = b.title ?? "Untitled"
                                task.orderIndex = b.orderIndex ?? 0
                                task.isActive = b.isActive ?? true
                                task.createdAt = b.createdAt ?? Date()
                            } else {
                                task = DailyTask(title: b.title ?? "Untitled", orderIndex: b.orderIndex ?? 0, isActive: b.isActive ?? true, createdAt: b.createdAt ?? Date())
                                task.id = uuid
                                self.modelContext.insert(task)
                            }
                            taskMap[uuid] = task
                        }
                        
                        for b in backup.dailyTaskLogs ?? [] {
                            let uuid = b.id?.uuid ?? UUID()
                            if let existing = existingDailyTaskLogs[uuid] {
                                existing.logicalDate = b.logicalDate ?? ""
                                existing.isCompleted = b.isCompleted ?? false
                                if let taskId = b.taskId?.uuid, let task = taskMap[taskId] {
                                    existing.task = task
                                }
                            } else {
                                let log = DailyTaskLog(logicalDate: b.logicalDate ?? "", isCompleted: b.isCompleted ?? false)
                                log.id = uuid
                                if let taskId = b.taskId?.uuid, let task = taskMap[taskId] {
                                    log.task = task
                                }
                                self.modelContext.insert(log)
                            }
                        }
                        
                        do {
                            try self.modelContext.save()
                            self.alertMessage = "Imported successfully."
                        } catch {
                            self.alertMessage = "Failed to save to database: \(error.localizedDescription)"
                        }
                        self.showingAlert = true
                    }
                } catch let DecodingError.dataCorrupted(context) {
                    await MainActor.run { self.alertMessage = "Data corrupted: \(context.debugDescription)"; self.showingAlert = true }
                } catch let DecodingError.keyNotFound(key, context) {
                    await MainActor.run { self.alertMessage = "Missing key '\(key.stringValue)' at \(context.codingPath.map(\.stringValue).joined(separator: "."))"; self.showingAlert = true }
                } catch let DecodingError.typeMismatch(type, context) {
                    await MainActor.run { self.alertMessage = "Type mismatch for '\(context.codingPath.last?.stringValue ?? "unknown")'. Expected \(type)."; self.showingAlert = true }
                } catch let DecodingError.valueNotFound(type, context) {
                    await MainActor.run { self.alertMessage = "Value not found for '\(context.codingPath.last?.stringValue ?? "unknown")'. Expected \(type)."; self.showingAlert = true }
                } catch {
                    await MainActor.run { self.alertMessage = "Failed to import JSON: \(error.localizedDescription)"; self.showingAlert = true }
                }
            }
        }
}
}
