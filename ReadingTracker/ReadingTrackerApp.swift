import SwiftUI
import SwiftData

@main
struct ReadingTrackerApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Document.self,
            ProgressLog.self,
            Todo.self,
            Paper.self,
            ConceptNode.self,
            ConceptLink.self,
            GeneralMemo.self,
            Movie.self,
            Business.self,
            DiaryEntry.self,
            Person.self,
            DailyTask.self,
            DailyTaskLog.self,
            ClassNote.self
        ])
        
        let appSupportDir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appDir = appSupportDir.appendingPathComponent("ReadingTracker", isDirectory: true)
        
        if !FileManager.default.fileExists(atPath: appDir.path) {
            try? FileManager.default.createDirectory(at: appDir, withIntermediateDirectories: true, attributes: nil)
        }
        
        let storeURL = appDir.appendingPathComponent("ReadingTracker.sqlite")
        let modelConfiguration = ModelConfiguration(url: storeURL)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .tint(.primary)
        }
        .defaultSize(width: 1000, height: 600)
        .modelContainer(sharedModelContainer)
    }
}
