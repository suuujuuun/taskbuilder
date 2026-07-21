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
            DailyTaskLog.self
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .defaultSize(width: 1000, height: 600)
        .modelContainer(sharedModelContainer)
    }
}
