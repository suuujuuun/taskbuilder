import SwiftUI
import SwiftData

struct DiaryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \DiaryEntry.date, order: .reverse) private var entries: [DiaryEntry]
    
    @State private var selectedDate: Date = Date()
    @State private var currentText: String = ""
    @State private var currentEntry: DiaryEntry?
    
    private var calendar: Calendar {
        var cal = Calendar.current
        cal.timeZone = TimeZone.current
        return cal
    }
    
    var body: some View {
        HStack(spacing: 0) {
            // Left sidebar: Date picker & Recent
            VStack(spacing: 20) {
                // Calendar Container
                VStack(alignment: .leading) {
                    Text("Select Date")
                        .font(.headline)
                        .foregroundColor(.secondary)
                        .padding(.horizontal)
                        .padding(.top, 16)
                    
                    DatePicker(
                        "",
                        selection: Binding(
                            get: { selectedDate },
                            set: { newDate in
                                selectedDate = calendar.startOfDay(for: newDate)
                                loadEntry(for: selectedDate)
                            }
                        ),
                        displayedComponents: [.date]
                    )
                    .datePickerStyle(.graphical)
                    .padding(.horizontal)
                    .padding(.bottom, 16)
                }
                .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
                .cornerRadius(16)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
                .padding(.horizontal, 16)
                .padding(.top, 24)
                
                // Recent Entries
                VStack(alignment: .leading) {
                    Text("Highlights")
                        .font(.headline)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 20)
                    
                    ScrollView {
                        VStack(spacing: 8) {
                            let meaningfulEntries = entries.filter { $0.isHighlighted }
                            ForEach(meaningfulEntries) { entry in
                                Button(action: {
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        selectedDate = calendar.startOfDay(for: entry.date)
                                        loadEntry(for: selectedDate)
                                    }
                                }) {
                                    HStack {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(entry.date, format: .dateTime.month().day().year())
                                                .font(.subheadline)
                                                .fontWeight(.medium)
                                                .foregroundColor(calendar.isDate(entry.date, inSameDayAs: selectedDate) ? .white : .primary)
                                            
                                            Text(entry.content)
                                                .font(.caption)
                                                .lineLimit(1)
                                                .foregroundColor(calendar.isDate(entry.date, inSameDayAs: selectedDate) ? .white.opacity(0.7) : .secondary)
                                        }
                                        Spacer()
                                        Image(systemName: "chevron.right")
                                            .font(.caption)
                                            .foregroundColor(calendar.isDate(entry.date, inSameDayAs: selectedDate) ? .white.opacity(0.8) : .secondary.opacity(0.5))
                                    }
                                    .padding(12)
                                    .background(
                                        RoundedRectangle(cornerRadius: 12)
                                            .fill(calendar.isDate(entry.date, inSameDayAs: selectedDate) ? Color.white.opacity(0.15) : Color(NSColor.controlBackgroundColor))
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(Color.white.opacity(0.05), lineWidth: 1)
                                    )
                                }
                                .buttonStyle(.plain)
                                .padding(.horizontal, 16)
                            }
                        }
                        .padding(.vertical, 8)
                    }
                }
                
                Spacer()
            }
            .frame(width: 320)
            .background(Color(NSColor.windowBackgroundColor))
            
            Divider()
            
            // Right area: Text Editor
            VStack(alignment: .leading, spacing: 0) {
                // Header
                HStack(alignment: .bottom) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(selectedDate, format: .dateTime.weekday(.wide))
                            .font(.title3)
                            .foregroundColor(.secondary)
                            .fontWeight(.semibold)
                            .textCase(.uppercase)
                        
                        Text(selectedDate, format: .dateTime.month(.wide).day().year())
                            .font(.system(size: 36, weight: .bold, design: .serif))
                            .foregroundColor(.primary)
                    }
                    Spacer()
                    
                    if let entry = currentEntry {
                        Button(action: {
                            entry.isHighlighted.toggle()
                            try? modelContext.save()
                        }) {
                            Image(systemName: entry.isHighlighted ? "star.fill" : "star")
                                .foregroundColor(entry.isHighlighted ? .yellow : .secondary)
                                .font(.title3)
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, 8)
                    }
                    
                    if !currentText.isEmpty {
                        Text("\(currentText.count) chars")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.secondary.opacity(0.1))
                            .clipShape(Capsule())
                    }
                }
                .padding(.horizontal, 40)
                .padding(.top, 40)
                .padding(.bottom, 20)
                
                // Editor
                ZStack(alignment: .topLeading) {
                    if currentText.isEmpty {
                        Text("Write down your thoughts for the day...")
                            .font(.system(.title3, design: .serif))
                            .foregroundColor(.secondary.opacity(0.5))
                            .padding(.horizontal, 45)
                            .padding(.top, 8)
                            .allowsHitTesting(false)
                    }
                    
                    TextEditor(text: $currentText)
                        .font(.system(.title3, design: .serif))
                        .scrollContentBackground(.hidden)
                        .background(Color.clear)
                        .padding(.horizontal, 40)
                        .lineSpacing(8)
                        .onChange(of: currentText) { _, newValue in
                            saveEntry(text: newValue, for: selectedDate)
                        }
                }
                .padding(.bottom, 40)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(
                LinearGradient(
                    gradient: Gradient(colors: [Color(NSColor.controlBackgroundColor), Color(NSColor.windowBackgroundColor).opacity(0.8)]),
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
        }
        .navigationTitle("Diary")
        .onAppear {
            selectedDate = calendar.startOfDay(for: Date())
            loadEntry(for: selectedDate)
        }
    }
    
    private func loadEntry(for date: Date) {
        let startOfSelectedDate = calendar.startOfDay(for: date)
        if let existing = entries.first(where: { calendar.isDate($0.date, inSameDayAs: startOfSelectedDate) }) {
            currentEntry = existing
            currentText = existing.content
        } else {
            currentEntry = nil
            currentText = ""
        }
    }
    
    private func saveEntry(text: String, for date: Date) {
        if let entry = currentEntry {
            entry.content = text
        } else {
            if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return }
            
            let startOfSelectedDate = calendar.startOfDay(for: date)
            let newEntry = DiaryEntry(date: startOfSelectedDate, content: text)
            modelContext.insert(newEntry)
            currentEntry = newEntry
        }
        try? modelContext.save()
    }
}
