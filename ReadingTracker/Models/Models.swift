import Foundation
import SwiftData

@Model
final class Document {
    var id: UUID = UUID()
    var title: String
    var totalPages: Double
    var targetDate: Date
    var difficulty: Int?
    var link: String?
    var orderIndex: Int = 0
    
    @Relationship(deleteRule: .cascade)
    var progressLogs: [ProgressLog] = []
    
    var tags: [String] = []
    
    init(title: String, totalPages: Double, targetDate: Date, difficulty: Int? = nil, link: String? = nil, orderIndex: Int = 0, tags: [String] = []) {
        self.title = title
        self.totalPages = totalPages
        self.targetDate = targetDate
        self.difficulty = difficulty
        self.link = link
        self.orderIndex = orderIndex
        self.tags = tags
    }
}

@Model
final class ProgressLog {
    var id: UUID = UUID()
    var date: Date
    var page: Double
    var topic: String
    var satisfaction: Int?
    
    var document: Document?
    
    init(date: Date = Date(), page: Double, topic: String, satisfaction: Int? = nil) {
        self.date = date
        self.page = page
        self.topic = topic
        self.satisfaction = satisfaction
    }
}

@Model
final class Todo {
    var id: UUID = UUID()
    var text: String
    var completed: Bool
    var status: String = "Todo"
    
    init(text: String, completed: Bool = false, status: String = "Todo") {
        self.text = text
        self.completed = completed
        self.status = status
    }
}

@Model
final class GeneralMemo {
    var id: UUID = UUID()
    var text: String
    var tabIndex: Int = 0
    var tabName: String?
    
    init(text: String = "", tabIndex: Int = 0, tabName: String? = nil) {
        self.text = text
        self.tabIndex = tabIndex
        self.tabName = tabName
    }
}

@Model
final class Paper {
    var id: UUID = UUID()
    var title: String
    var url: String
    var status: String // "Not Started", "In Progress", "Completed"
    var tags: [String] = []
    
    init(title: String, url: String, status: String = "Not Started", tags: [String] = []) {
        self.title = title
        self.url = url
        self.status = status
        self.tags = tags
    }
}

@Model
final class ConceptNode {
    var id: UUID = UUID()
    var title: String
    var shortName: String?
    var content: String
    var x: Double = 0.0
    var y: Double = 0.0
    var tags: [String] = []
    
    @Relationship(deleteRule: .cascade, inverse: \ConceptLink.source)
    var linksOut: [ConceptLink] = []
    
    @Relationship(deleteRule: .cascade, inverse: \ConceptLink.target)
    var linksIn: [ConceptLink] = []
    
    init(title: String, shortName: String? = nil, content: String, tags: [String] = []) {
        self.title = title
        self.shortName = shortName
        self.content = content
        self.tags = tags
    }
}

@Model
final class ConceptLink {
    var id: UUID = UUID()
    
    var source: ConceptNode?
    var target: ConceptNode?
    
    init(source: ConceptNode, target: ConceptNode) {
        self.source = source
        self.target = target
    }
}

// MARK: - Backup & Restore Models

struct FlexibleID: Codable, Hashable {
    var uuid: UUID
    
    init(uuid: UUID) {
        self.uuid = uuid
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let intValue = try? container.decode(Int.self) {
            let stringValue = String(format: "%032llx", Int64(intValue))
            let uuidString = "\(stringValue.prefix(8))-\(stringValue.dropFirst(8).prefix(4))-\(stringValue.dropFirst(12).prefix(4))-\(stringValue.dropFirst(16).prefix(4))-\(stringValue.dropFirst(20))"
            self.uuid = UUID(uuidString: uuidString) ?? UUID()
        } else if let strValue = try? container.decode(String.self) {
            self.uuid = UUID(uuidString: strValue) ?? UUID()
        } else {
            self.uuid = UUID()
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(uuid.uuidString)
    }
}

struct BackupData: Codable {
    var documents: [BackupDocument]?
    var progressLogs: [BackupProgressLog]?
    var todos: [BackupTodo]?
    var papers: [BackupPaper]?
    var conceptNodes: [BackupConceptNode]?
    var conceptLinks: [BackupConceptLink]?
    var memos: [BackupMemo]?
    var tagOrder: String?

    init(documents: [BackupDocument]? = nil, progressLogs: [BackupProgressLog]? = nil, todos: [BackupTodo]? = nil, papers: [BackupPaper]? = nil, conceptNodes: [BackupConceptNode]? = nil, conceptLinks: [BackupConceptLink]? = nil, memos: [BackupMemo]? = nil, tagOrder: String? = nil) {
        self.documents = documents
        self.progressLogs = progressLogs
        self.todos = todos
        self.papers = papers
        self.conceptNodes = conceptNodes
        self.conceptLinks = conceptLinks
        self.memos = memos
        self.tagOrder = tagOrder
    }

    private struct DynamicCodingKeys: CodingKey {
        var stringValue: String
        init?(stringValue: String) { self.stringValue = stringValue }
        var intValue: Int? { nil }
        init?(intValue: Int) { return nil }
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: DynamicCodingKeys.self)
        
        func decodeArray<T: Codable>(_ keys: [String]) -> [T]? {
            for key in keys {
                if let k = DynamicCodingKeys(stringValue: key) {
                    if container.contains(k) {
                        do {
                            let array = try container.decode([T].self, forKey: k)
                            return array
                        } catch {
                            print("Decoding error for key \(key): \(error)")
                        }
                    }
                }
            }
            return nil
        }
        
        documents = decodeArray(["documents", "books", "data"])
        progressLogs = decodeArray(["progressLogs", "logs"])
        todos = decodeArray(["todos"])
        papers = decodeArray(["papers", "links"])
        conceptNodes = decodeArray(["conceptNodes", "concepts"])
        conceptLinks = decodeArray(["conceptLinks"])
        memos = decodeArray(["memos", "generalMemos", "notes", "quotes"])
        
        if let k = DynamicCodingKeys(stringValue: "tagOrder") {
            tagOrder = try? container.decodeIfPresent(String.self, forKey: k)
        }
        
        // Handle 'memo' if it's an array of strings or single string
        if let k = DynamicCodingKeys(stringValue: "memo") {
            if let memoStrs = try? container.decode([String].self, forKey: k) {
                let m = memoStrs.map { BackupMemo(id: nil, text: $0) }
                memos = (memos ?? []) + m
            } else if let memoStr = try? container.decode(String.self, forKey: k) {
                memos = (memos ?? []) + [BackupMemo(id: nil, text: memoStr)]
            } else if let memoObjs = try? container.decode([BackupMemo].self, forKey: k) {
                memos = (memos ?? []) + memoObjs
            }
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: DynamicCodingKeys.self)
        if let k = DynamicCodingKeys(stringValue: "documents") { try container.encodeIfPresent(documents, forKey: k) }
        if let k = DynamicCodingKeys(stringValue: "progressLogs") { try container.encodeIfPresent(progressLogs, forKey: k) }
        if let k = DynamicCodingKeys(stringValue: "todos") { try container.encodeIfPresent(todos, forKey: k) }
        if let k = DynamicCodingKeys(stringValue: "papers") { try container.encodeIfPresent(papers, forKey: k) }
        if let k = DynamicCodingKeys(stringValue: "conceptNodes") { try container.encodeIfPresent(conceptNodes, forKey: k) }
        if let k = DynamicCodingKeys(stringValue: "conceptLinks") { try container.encodeIfPresent(conceptLinks, forKey: k) }
        if let k = DynamicCodingKeys(stringValue: "memos") { try container.encodeIfPresent(memos, forKey: k) }
        if let k = DynamicCodingKeys(stringValue: "tagOrder") { try container.encodeIfPresent(tagOrder, forKey: k) }
    }
}

struct BackupDocument: Codable {
    var id: FlexibleID?
    var title: String?
    var totalPages: Double?
    var targetDate: Date?
    var difficulty: Int?
    var link: String?
    var orderIndex: Int?
    var progressLogs: [BackupProgressLog]?
    var tags: [String]?

    enum CodingKeys: String, CodingKey {
        case id, title, totalPages, targetDate, difficulty, link, orderIndex, progressLogs, tags
    }

    init(id: FlexibleID? = nil, title: String? = nil, totalPages: Double? = nil, targetDate: Date? = nil, difficulty: Int? = nil, link: String? = nil, orderIndex: Int? = nil, progressLogs: [BackupProgressLog]? = nil, tags: [String]? = nil) {
        self.id = id; self.title = title; self.totalPages = totalPages; self.targetDate = targetDate; self.difficulty = difficulty; self.link = link; self.orderIndex = orderIndex; self.progressLogs = progressLogs; self.tags = tags
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try? container.decodeIfPresent(FlexibleID.self, forKey: .id)
        self.title = (try? container.decodeIfPresent(String.self, forKey: .title)) ?? (try? container.decodeIfPresent(Int.self, forKey: .title).map { String($0) })
        self.totalPages = try? container.decodeIfPresent(Double.self, forKey: .totalPages)
        if self.totalPages == nil, let d = try? container.decodeIfPresent(Int.self, forKey: .totalPages) { self.totalPages = Double(d) }
        self.targetDate = try? container.decodeIfPresent(Date.self, forKey: .targetDate)
        self.difficulty = try? container.decodeIfPresent(Int.self, forKey: .difficulty)
        if self.difficulty == nil, let d = try? container.decodeIfPresent(Double.self, forKey: .difficulty) { self.difficulty = Int(d) }
        self.link = try? container.decodeIfPresent(String.self, forKey: .link)
        self.orderIndex = try? container.decodeIfPresent(Int.self, forKey: .orderIndex)
        self.progressLogs = try? container.decodeIfPresent([BackupProgressLog].self, forKey: .progressLogs)
        self.tags = try? container.decodeIfPresent([String].self, forKey: .tags)
    }
}

struct BackupProgressLog: Codable {
    var id: FlexibleID?
    var date: Date?
    var page: Double?
    var topic: String?
    var satisfaction: Int?
    var documentId: FlexibleID?

    enum CodingKeys: String, CodingKey {
        case id, date, page, topic, satisfaction, documentId
    }

    init(id: FlexibleID? = nil, date: Date? = nil, page: Double? = nil, topic: String? = nil, satisfaction: Int? = nil, documentId: FlexibleID? = nil) {
        self.id = id; self.date = date; self.page = page; self.topic = topic; self.satisfaction = satisfaction; self.documentId = documentId
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try? container.decodeIfPresent(FlexibleID.self, forKey: .id)
        self.date = try? container.decodeIfPresent(Date.self, forKey: .date)
        self.page = try? container.decodeIfPresent(Double.self, forKey: .page)
        if self.page == nil, let d = try? container.decodeIfPresent(Int.self, forKey: .page) { self.page = Double(d) }
        self.topic = (try? container.decodeIfPresent(String.self, forKey: .topic)) ?? (try? container.decodeIfPresent(Int.self, forKey: .topic).map { String($0) })
        self.satisfaction = try? container.decodeIfPresent(Int.self, forKey: .satisfaction)
        if self.satisfaction == nil, let d = try? container.decodeIfPresent(Double.self, forKey: .satisfaction) { self.satisfaction = Int(d) }
        self.documentId = try? container.decodeIfPresent(FlexibleID.self, forKey: .documentId)
    }
}

struct BackupTodo: Codable {
    var id: FlexibleID?
    var text: String?
    var completed: Bool?
    var status: String?
}

struct BackupPaper: Codable {
    var id: FlexibleID?
    var title: String?
    var url: String?
    var status: String?
    var tags: [String]?
}

struct BackupConceptNode: Codable {
    var id: FlexibleID?
    var title: String?
    var shortName: String?
    var content: String?
    var x: Double?
    var y: Double?
    var tags: [String]?
}

struct BackupConceptLink: Codable {
    var id: FlexibleID?
    var sourceId: FlexibleID?
    var targetId: FlexibleID?
}

struct BackupMemo: Codable {
    var id: FlexibleID?
    var text: String?
    var tabIndex: Int?
    var tabName: String?
    
    init(id: FlexibleID? = nil, text: String? = nil, tabIndex: Int? = nil, tabName: String? = nil) {
        self.id = id
        self.text = text
        self.tabIndex = tabIndex
        self.tabName = tabName
    }
}

extension String {
    var toValidURL: URL? {
        var cleaned = self.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleaned.isEmpty { return nil }
        if cleaned.hasPrefix("file://") {
            return URL(string: cleaned)
        }
        if cleaned.hasPrefix("/") || cleaned.hasPrefix("~") {
            let expanded = (cleaned as NSString).expandingTildeInPath
            return URL(fileURLWithPath: expanded)
        }
        if !cleaned.contains("://") {
            cleaned = "https://" + cleaned
        }
        return URL(string: cleaned) ?? URL(string: cleaned.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")
    }
}
