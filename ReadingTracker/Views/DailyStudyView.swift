import SwiftUI
import SwiftData

struct DailyStudyView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \DailyTask.orderIndex) private var tasks: [DailyTask]
    @Query private var logs: [DailyTaskLog]
    
    @State private var newTaskTitle: String = ""
    @State private var currentDate: Date = Date()
    
    // Timer to update the date every minute in case they leave it open past 2 AM
    let timer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()
    
    private var logicalDateString: String {
        DailyStudyView.getLogicalDate(for: currentDate)
    }
    
    var body: some View {
        HStack(spacing: 0) {
            // Main Task List
            VStack(alignment: .leading, spacing: 20) {
                HStack {
                    Text("Daily Tasks")
                        .font(.largeTitle.bold())
                    Spacer()
                    Text(currentDate, format: .dateTime.month().day().weekday(.wide))
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 20)
                
                // Add Task
                HStack {
                    TextField("Add new daily task...", text: $newTaskTitle)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit { addTask() }
                    
                    Button(action: addTask) {
                        Image(systemName: "plus")
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(newTaskTitle.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                .padding(.horizontal, 24)
                
                List {
                    ForEach(tasks.filter { $0.isActive }) { task in
                        let isCompleted = isTaskCompletedToday(task)
                        
                        HStack {
                            Button(action: {
                                toggleTaskCompletion(task, currentlyCompleted: isCompleted)
                            }) {
                                Image(systemName: isCompleted ? "checkmark.circle.fill" : "circle")
                                    .font(.title2)
                                    .foregroundColor(isCompleted ? .white : .secondary)
                            }
                            .buttonStyle(.plain)
                            
                            Text(task.title)
                                .font(.title3)
                                .strikethrough(isCompleted)
                                .foregroundColor(isCompleted ? .secondary : .primary)
                            
                            Spacer()
                            
                            Image(systemName: "line.3.horizontal")
                                .foregroundColor(.secondary)
                                .opacity(0.5)
                        }
                        .padding(.vertical, 8)
                        .contextMenu {
                            Button("Delete", role: .destructive) {
                                deleteTask(task)
                            }
                        }
                    }
                    .onMove(perform: moveTask)
                }
                .listStyle(.plain)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            Divider()
            
            // Statistics Sidebar
            VStack(alignment: .leading, spacing: 24) {
                Text("Statistics")
                    .font(.title2.bold())
                    .padding(.top, 24)
                
                let stats = calculateStatistics()
                
                ScrollView {
                    VStack(spacing: 16) {
                    // Overall completion
                    VStack(spacing: 8) {
                        Text("Last 7 Days Completion")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        
                        ZStack {
                            Circle()
                                .stroke(Color.white.opacity(0.1), lineWidth: 10)
                            
                            Circle()
                                .trim(from: 0, to: CGFloat(stats.overallRate) / 100.0)
                                .stroke(Color.white.opacity(0.3), style: StrokeStyle(lineWidth: 10, lineCap: .round))
                                .rotationEffect(.degrees(-90))
                                .animation(.easeOut, value: stats.overallRate)
                            
                            Text("\(Int(stats.overallRate))%")
                                .font(.title.bold())
                        }
                        .frame(width: 100, height: 100)
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(16)
                    
                    // Leaderboard (Best & Worst)
                    if !stats.taskRates.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Task Breakdown")
                                .font(.headline)
                                .padding(.bottom, 4)
                            
                            ForEach(stats.taskRates, id: \.task.id) { rate in
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack {
                                        Text(rate.task.title)
                                            .font(.subheadline)
                                            .lineLimit(1)
                                        Spacer()
                                        Text("\(Int(rate.percentage))%")
                                            .font(.caption)
                                            .bold()
                                    }
                                    
                                    GeometryReader { geometry in
                                        ZStack(alignment: .leading) {
                                            Capsule()
                                                .fill(Color.white.opacity(0.1))
                                                .frame(height: 6)
                                            
                                            Capsule()
                                                .fill(rate.percentage < 50 && rate.totalDays > 1 ? Color.orange : Color.white.opacity(0.3))
                                                .frame(width: geometry.size.width * CGFloat(rate.percentage) / 100.0, height: 6)
                                        }
                                    }
                                    .frame(height: 6)
                                }
                            }
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(NSColor.controlBackgroundColor))
                        .cornerRadius(16)
                        
                        if let worst = stats.taskRates.last, worst.percentage < 50, worst.totalDays > 1 {
                            HStack {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.orange)
                                Text("Focus on: \(worst.task.title)")
                                    .font(.caption)
                                    .foregroundColor(.orange)
                                Spacer()
                            }
                            .padding()
                            .background(Color.orange.opacity(0.1))
                            .cornerRadius(12)
                        }
                    }
                    }
                }
                .scrollIndicators(.hidden)
                
                Spacer()
            }
            .frame(width: 300)
            .padding(.horizontal, 20)
            .background(Color(NSColor.windowBackgroundColor))
        }
        .navigationTitle("Daily Study")
        .onReceive(timer) { input in
            currentDate = input
        }
    }
    
    // MARK: - Logic
    
    private func addTask() {
        let title = newTaskTitle.trimmingCharacters(in: .whitespaces)
        guard !title.isEmpty else { return }
        
        let order = (tasks.map { $0.orderIndex }.max() ?? -1) + 1
        let task = DailyTask(title: title, orderIndex: order)
        modelContext.insert(task)
        try? modelContext.save()
        
        newTaskTitle = ""
    }
    
    private func moveTask(from source: IndexSet, to destination: Int) {
        var activeTasks = tasks.filter { $0.isActive }
        activeTasks.move(fromOffsets: source, toOffset: destination)
        
        for (index, task) in activeTasks.enumerated() {
            task.orderIndex = index
        }
        try? modelContext.save()
    }
    
    private func deleteTask(_ task: DailyTask) {
        modelContext.delete(task)
        try? modelContext.save()
    }
    
    private func isTaskCompletedToday(_ task: DailyTask) -> Bool {
        let logDate = logicalDateString
        return logs.contains(where: { $0.task?.id == task.id && $0.logicalDate == logDate && $0.isCompleted })
    }
    
    private func toggleTaskCompletion(_ task: DailyTask, currentlyCompleted: Bool) {
        let logDate = logicalDateString
        
        if let existingLog = logs.first(where: { $0.task?.id == task.id && $0.logicalDate == logDate }) {
            existingLog.isCompleted = !currentlyCompleted
        } else {
            let newLog = DailyTaskLog(logicalDate: logDate, isCompleted: !currentlyCompleted)
            newLog.task = task
            modelContext.insert(newLog)
        }
        
        try? modelContext.save()
    }
    
    // MARK: - Statistics
    
    struct TaskStat {
        let task: DailyTask
        let percentage: Double
        let totalDays: Int
    }
    
    private func calculateStatistics() -> (overallRate: Double, taskRates: [TaskStat]) {
        let activeTasks = tasks.filter { $0.isActive }
        if activeTasks.isEmpty { return (0, []) }
        
        // Generate last 7 logical dates
        let calendar = Calendar.current
        var last7Dates = Set<String>()
        for i in 0..<7 {
            if let d = calendar.date(byAdding: .day, value: -i, to: currentDate) {
                last7Dates.insert(DailyStudyView.getLogicalDate(for: d))
            }
        }
        
        let recentLogs = logs.filter { last7Dates.contains($0.logicalDate) && $0.isCompleted }
        
        var totalPossible = 0
        var totalCompleted = 0
        
        var taskRates: [TaskStat] = []
        
        for task in activeTasks {
            let daysSinceCreation = Calendar.current.dateComponents([.day], from: task.createdAt, to: currentDate).day ?? 0
            let totalPossibleForTask = min(7, daysSinceCreation + 1)
            
            let completedDays = recentLogs.filter { $0.task?.id == task.id }.count
            totalCompleted += completedDays
            totalPossible += totalPossibleForTask
            
            let percentage = totalPossibleForTask > 0 ? (Double(completedDays) / Double(totalPossibleForTask) * 100.0) : 0.0
            taskRates.append(TaskStat(task: task, percentage: percentage, totalDays: totalPossibleForTask))
        }
        
        let overallRate = totalPossible > 0 ? (Double(totalCompleted) / Double(totalPossible) * 100.0) : 0.0
        
        // Sort best to worst
        taskRates.sort { $0.percentage > $1.percentage }
        
        return (overallRate, taskRates)
    }
    
    // MARK: - Date Helpers
    
    static func getLogicalDate(for date: Date = Date()) -> String {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month, .day, .hour], from: date)
        
        if let hour = components.hour, hour < 2 {
            // Before 2 AM, it's part of the previous day
            if let previousDay = calendar.date(byAdding: .day, value: -1, to: date) {
                let prevComponents = calendar.dateComponents([.year, .month, .day], from: previousDay)
                return String(format: "%04d-%02d-%02d", prevComponents.year!, prevComponents.month!, prevComponents.day!)
            }
        }
        return String(format: "%04d-%02d-%02d", components.year!, components.month!, components.day!)
    }
}
