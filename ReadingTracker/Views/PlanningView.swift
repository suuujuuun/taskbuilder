import SwiftUI
import SwiftData

struct PlanningView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var todos: [Todo]
    @Query private var memos: [GeneralMemo]
    
    @State private var newTodoText = ""
    @State private var newTodoDeadline: Date? = nil
    @State private var selectedTab = "All"
    let tabs = ["All", "Important", "General", "Work", "Study", "Personal"]
    
    var filteredTodos: [Todo] {
        var result = todos
        if selectedTab == "Important" {
            result = todos.filter { $0.isImportant }
        } else if selectedTab != "All" {
            result = todos.filter { $0.status == selectedTab }
        }
        return result.sorted { $0.orderIndex < $1.orderIndex }
    }
    
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
                        
                    if let deadline = newTodoDeadline {
                        DatePicker("", selection: Binding(get: { deadline }, set: { newTodoDeadline = $0 }), displayedComponents: .date)
                            .labelsHidden()
                            .datePickerStyle(.compact)
                            .frame(width: 100)
                        Button(action: { newTodoDeadline = nil }) {
                            Image(systemName: "xmark.circle.fill").foregroundColor(.gray)
                        }.buttonStyle(.plain)
                    } else {
                        Button(action: { newTodoDeadline = Date() }) {
                            Image(systemName: "calendar.badge.plus").foregroundColor(.gray)
                        }.buttonStyle(.plain)
                    }
                    
                    Button(action: addTodo) { Image(systemName: "plus") }
                        .disabled(newTodoText.isEmpty)
                }
                .padding([.horizontal, .top])
                
                Picker("Category", selection: $selectedTab) {
                    ForEach(tabs, id: \.self) { tab in
                        Text(tab).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.bottom, 8)
                
                List {
                    ForEach(filteredTodos) { todo in
                        HStack {
                            Toggle("", isOn: Binding(
                                get: { todo.completed },
                                set: { newValue in
                                    todo.completed = newValue
                                    try? modelContext.save()
                                }
                            ))
                            .labelsHidden()
                            
                            TextField("Task", text: Binding(
                                get: { todo.text },
                                set: { newValue in
                                    todo.text = newValue
                                    try? modelContext.save()
                                }
                            ))
                            .textFieldStyle(.plain)
                            .strikethrough(todo.completed, color: .secondary)
                            .foregroundColor(todo.completed ? .secondary : .primary)
                            
                            Spacer()
                            
                            if let deadline = todo.deadline {
                                Text(deadline, format: .dateTime.month().day())
                                    .font(.caption)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(deadlineColor(deadline).opacity(0.1))
                                    .foregroundColor(deadlineColor(deadline))
                                    .cornerRadius(4)
                                    
                                Button(action: {
                                    todo.deadline = nil
                                    try? modelContext.save()
                                }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(.gray)
                                        .font(.caption)
                                }
                                .buttonStyle(.plain)
                            }
                            
                            Menu {
                                ForEach(["General", "Work", "Study", "Personal"], id: \.self) { status in
                                    Button(status) {
                                        todo.status = status
                                        try? modelContext.save()
                                    }
                                }
                            } label: {
                                Image(systemName: "arrow.right.square")
                                    .foregroundColor(.gray)
                            }
                            .menuStyle(.borderlessButton)
                            .tint(.gray)
                            .fixedSize()
                            
                            Button(action: {
                                todo.isImportant.toggle()
                                try? modelContext.save()
                            }) {
                                Image(systemName: todo.isImportant ? "star.fill" : "star")
                                    .foregroundColor(todo.isImportant ? .yellow : .gray)
                            }
                            .buttonStyle(.plain)
                            
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
                        .padding(.vertical, 2)
                    }
                    .onDelete(perform: deleteTodos)
                    .onMove(perform: moveTodos)
                }
            }
            .frame(minWidth: 300, maxWidth: .infinity, maxHeight: .infinity)
            
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
        let currentStatus = (selectedTab == "All" || selectedTab == "Important") ? "General" : selectedTab
        let maxOrder = todos.map { $0.orderIndex }.max() ?? -1
        let todo = Todo(text: newTodoText, status: currentStatus, orderIndex: maxOrder + 1, deadline: newTodoDeadline, isImportant: selectedTab == "Important")
        modelContext.insert(todo)
        try? modelContext.save()
        newTodoText = ""
        newTodoDeadline = nil
    }
    
    private func deadlineColor(_ date: Date) -> Color {
        let days = Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: Date()), to: Calendar.current.startOfDay(for: date)).day ?? 0
        if days < 0 { return .red }
        if days <= 3 { return .orange }
        return .secondary
    }
    
    private func moveTodos(from source: IndexSet, to destination: Int) {
        var revisedItems = filteredTodos
        revisedItems.move(fromOffsets: source, toOffset: destination)
        for (index, item) in revisedItems.enumerated() {
            item.orderIndex = index
        }
        try? modelContext.save()
    }
    
    private func deleteTodos(offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                modelContext.delete(filteredTodos[index])
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
