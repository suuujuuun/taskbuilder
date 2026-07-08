import SwiftUI
import SwiftData

struct PlanningView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var todos: [Todo]
    @Query private var memos: [GeneralMemo]
    
    @State private var newTodoText = ""
    
    var body: some View {
        HSplitView {
            // Left side: Todo List
            VStack(alignment: .leading) {
                HStack {
                    Text("To-Do List").font(.title2).bold()
                    Spacer()
                    TextField("New task...", text: $newTodoText)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 200)
                        .onSubmit { addTodo() }
                    Button(action: addTodo) { Image(systemName: "plus") }
                        .disabled(newTodoText.isEmpty)
                }
                .padding()
                
                List {
                    ForEach(todos) { todo in
                        HStack {
                            Toggle("", isOn: Binding(
                                get: { todo.completed },
                                set: { newValue in
                                    todo.completed = newValue
                                    try? modelContext.save()
                                }
                            ))
                            Text(todo.text)
                                .strikethrough(todo.completed, color: .secondary)
                                .foregroundColor(todo.completed ? .secondary : .primary)
                        }
                    }
                    .onDelete(perform: deleteTodos)
                }
            }
            .frame(minWidth: 300)
            
            // Right side: General Memo
            VStack(alignment: .leading) {
                Text("General Memo").font(.title2).bold()
                    .padding([.top, .horizontal])
                
                MemoEditorView(memos: memos)
                    .padding()
            }
            .frame(minWidth: 250)
            .background(Color(NSColor.controlBackgroundColor))
        }
        .navigationTitle("To-Do & Memo")
    }
    
    private func addTodo() {
        guard !newTodoText.isEmpty else { return }
        let todo = Todo(text: newTodoText, status: "Todo")
        modelContext.insert(todo)
        try? modelContext.save()
        newTodoText = ""
    }
    
    private func deleteTodos(offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                modelContext.delete(todos[index])
            }
            try? modelContext.save()
        }
    }
}

struct MemoEditorView: View {
    var memos: [GeneralMemo]
    @Environment(\.modelContext) private var modelContext
    @State private var text: String = ""
    
    var body: some View {
        TextEditor(text: $text)
            .font(.system(.body, design: .monospaced))
            .onAppear {
                if let firstMemo = memos.first {
                    text = firstMemo.text
                } else {
                    let newMemo = GeneralMemo()
                    modelContext.insert(newMemo)
                    try? modelContext.save()
                }
            }
            .onChange(of: text) { _, newValue in
                if let memo = memos.first {
                    memo.text = newValue
                    try? modelContext.save()
                }
            }
    }
}
