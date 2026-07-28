import SwiftUI
import SwiftData

struct ClassNotesView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ClassNote.orderIndex) private var notes: [ClassNote]
    
    @State private var selectedNote: ClassNote?
    @State private var newCourseName: String = ""
    @State private var newTitle: String = ""
    
    var groupedNotes: [String: [ClassNote]] {
        Dictionary(grouping: notes, by: { $0.courseName })
    }
    
    var body: some View {
        HSplitView {
            // Left sidebar: List of courses and notes
            VStack(alignment: .leading) {
                Text("Class Notes")
                    .font(.title2.bold())
                    .padding([.top, .horizontal])
                
                List(selection: $selectedNote) {
                    ForEach(groupedNotes.keys.sorted(), id: \.self) { course in
                        Section(header: Text(course).font(.headline)) {
                            ForEach(groupedNotes[course] ?? []) { note in
                                NavigationLink(value: note) {
                                    VStack(alignment: .leading) {
                                        Text(note.title)
                                            .font(.body)
                                        Text(note.date, format: .dateTime.month().day())
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                .contextMenu {
                                    Button("Delete", role: .destructive) {
                                        modelContext.delete(note)
                                        try? modelContext.save()
                                        if selectedNote == note { selectedNote = nil }
                                    }
                                }
                            }
                        }
                    }
                }
                .listStyle(.sidebar)
                
                Divider()
                
                VStack(spacing: 8) {
                    TextField("Course Name", text: $newCourseName)
                        .textFieldStyle(.roundedBorder)
                    TextField("Note Title", text: $newTitle)
                        .textFieldStyle(.roundedBorder)
                    Button(action: addNote) {
                        Label("Add Note", systemImage: "plus")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(newCourseName.isEmpty || newTitle.isEmpty)
                }
                .padding()
            }
            .frame(minWidth: 200, maxWidth: 300, maxHeight: .infinity)
            
            // Right side: Note editor
            if let note = selectedNote {
                ClassNoteEditor(note: note)
            } else {
                VStack {
                    Image(systemName: "books.vertical")
                        .font(.system(size: 60))
                        .foregroundColor(.secondary)
                        .padding(.bottom, 8)
                    Text("Select or create a note")
                        .font(.title3)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .navigationTitle("Class Notes")
    }
    
    private func addNote() {
        let order = (notes.map { $0.orderIndex }.max() ?? -1) + 1
        let note = ClassNote(title: newTitle, courseName: newCourseName, content: "", date: Date(), orderIndex: order)
        modelContext.insert(note)
        try? modelContext.save()
        selectedNote = note
        newTitle = ""
    }
}

struct ClassNoteEditor: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var note: ClassNote
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 8) {
                TextField("Title", text: $note.title)
                    .font(.title.bold())
                    .textFieldStyle(.plain)
                    .onChange(of: note.title) { _, _ in try? modelContext.save() }
                
                HStack {
                    TextField("Course", text: $note.courseName)
                        .font(.subheadline)
                        .textFieldStyle(.plain)
                        .foregroundColor(.secondary)
                        .onChange(of: note.courseName) { _, _ in try? modelContext.save() }
                    
                    Spacer()
                    
                    DatePicker("", selection: $note.date, displayedComponents: .date)
                        .labelsHidden()
                        .datePickerStyle(.compact)
                        .onChange(of: note.date) { _, _ in try? modelContext.save() }
                }
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            
            Divider()
            
            TextEditor(text: $note.content)
                .font(.system(.body, design: .monospaced))
                .padding()
                .background(Color(NSColor.textBackgroundColor))
                .onChange(of: note.content) { _, _ in try? modelContext.save() }
        }
        .frame(minWidth: 400, maxWidth: .infinity, maxHeight: .infinity)
    }
}
