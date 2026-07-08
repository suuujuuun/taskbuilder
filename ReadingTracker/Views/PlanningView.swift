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
                            
                            Spacer()
                            
                            Button(action: {
                                withAnimation {
                                    modelContext.delete(todo)
                                    try? modelContext.save()
                                }
                            }) {
                                Image(systemName: "xmark")
                                    .foregroundColor(.gray)
                            }
                            .buttonStyle(.plain)
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
    @State private var selectedTab: Int = 0
    @State private var text: String = ""
    @State private var activeTabIndices: [Int] = [0, 1, 2, 3]
    
    var body: some View {
        VStack(spacing: 8) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(activeTabIndices, id: \.self) { index in
                        let isSelected = selectedTab == index
                        HStack {
                            if isSelected {
                                TextField("Name", text: Binding(
                                    get: { getTabName(for: index) },
                                    set: { saveTabName($0, for: index) }
                                ))
                                .textFieldStyle(.plain)
                                .multilineTextAlignment(.center)
                                .frame(minWidth: 50)
                            } else {
                                Text(getTabName(for: index))
                            }
                        }
                        .font(.caption)
                        .padding(.vertical, 6)
                        .padding(.horizontal, 12)
                        .background(isSelected ? Color.primary : Color(NSColor.controlBackgroundColor))
                        .foregroundColor(isSelected ? Color(NSColor.windowBackgroundColor) : .primary)
                        .cornerRadius(6)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(Color.primary.opacity(0.2), lineWidth: 1)
                        )
                        .onTapGesture {
                            selectedTab = index
                            loadMemo(for: index)
                        }
                    }
                    }
                    
                    Button(action: {
                        let nextIndex = (activeTabIndices.max() ?? -1) + 1
                        activeTabIndices.append(nextIndex)
                        selectedTab = nextIndex
                        loadMemo(for: nextIndex)
                    }) {
                        Image(systemName: "plus")
                            .font(.caption)
                            .padding(.vertical, 6)
                            .padding(.horizontal, 12)
                            .background(Color(NSColor.controlBackgroundColor))
                            .foregroundColor(.primary)
                            .cornerRadius(6)
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(Color.primary.opacity(0.2), lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 2)
            }
            
            TextEditor(text: $text)
                .font(.system(.body, design: .monospaced))
                .padding(8)
                .background(Color(NSColor.textBackgroundColor))
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                )
                .onChange(of: text) { _, newValue in
                    saveMemoText(newValue, for: selectedTab)
                }
        }
        .onAppear {
            let storedIndices = Set(memos.map { $0.tabIndex })
            let combined = storedIndices.union(activeTabIndices)
            activeTabIndices = Array(combined).sorted()
            if activeTabIndices.isEmpty { activeTabIndices = [0] }
            if !activeTabIndices.contains(selectedTab) {
                selectedTab = activeTabIndices.first ?? 0
            }
            loadMemo(for: selectedTab)
        }
    }
    
    private func getTabName(for index: Int) -> String {
        if let memo = memos.first(where: { $0.tabIndex == index }), let name = memo.tabName, !name.isEmpty {
            return name
        }
        return "Tab \(index + 1)"
    }
    
    private func saveTabName(_ name: String, for index: Int) {
        if let memo = memos.first(where: { $0.tabIndex == index }) {
            memo.tabName = name
            try? modelContext.save()
        } else {
            let newMemo = GeneralMemo(text: "", tabIndex: index, tabName: name)
            modelContext.insert(newMemo)
            try? modelContext.save()
        }
    }
    
    private func loadMemo(for index: Int) {
        if let memo = memos.first(where: { $0.tabIndex == index }) {
            text = memo.text
        } else {
            text = ""
        }
    }
    
    private func saveMemoText(_ newText: String, for index: Int) {
        if let memo = memos.first(where: { $0.tabIndex == index }) {
            if memo.text != newText {
                memo.text = newText
                try? modelContext.save()
            }
        } else {
            let newMemo = GeneralMemo(text: newText, tabIndex: index)
            modelContext.insert(newMemo)
            try? modelContext.save()
        }
    }
}
