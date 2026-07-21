import SwiftUI
import SwiftData
import AppKit

struct BusinessView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Business.orderIndex) private var businesses: [Business]
    
    @AppStorage("selectedBusinessID") private var selectedBusinessIDString: String = ""
    @State private var localSelectedBusinessID: UUID? = nil
    
    var selectedBusiness: Business? {
        if let local = localSelectedBusinessID, let b = businesses.first(where: { $0.id == local }) {
            return b
        }
        if let uuid = UUID(uuidString: selectedBusinessIDString), let b = businesses.first(where: { $0.id == uuid }) {
            return b
        }
        return businesses.first
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header Bar
            HStack {
                if businesses.isEmpty {
                    Text("No Businesses Found")
                        .font(.headline)
                        .foregroundColor(.secondary)
                } else {
                    Picker("", selection: Binding<UUID?>(
                        get: { selectedBusiness?.id },
                        set: { newID in
                            if let newID = newID {
                                localSelectedBusinessID = newID
                                selectedBusinessIDString = newID.uuidString
                            }
                        }
                    )) {
                        ForEach(businesses) { business in
                            Text(business.name.isEmpty ? "Unnamed Business" : business.name)
                                .tag(Optional(business.id))
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(width: 250)
                }
                
                Spacer()
                
                Button(action: {
                    let maxOrder = businesses.map { $0.orderIndex }.max() ?? -1
                    let newBusiness = Business(name: "New Business", orderIndex: maxOrder + 1)
                    modelContext.insert(newBusiness)
                    try? modelContext.save()
                    localSelectedBusinessID = newBusiness.id
                    selectedBusinessIDString = newBusiness.id.uuidString
                }) {
                    Label("Add", systemImage: "plus")
                }
                .buttonStyle(.borderedProminent)
                .tint(.gray)
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            
            Divider()
            
            // Detail Content
            if let business = selectedBusiness {
                BusinessDetailView(business: business)
                    .id(business.id)
            } else {
                Spacer()
                Text("Click 'Add' to create a new business profile.")
                    .foregroundColor(.secondary)
                Spacer()
            }
        }
        .onAppear {
            if businesses.isEmpty {
                // Do nothing
            } else if localSelectedBusinessID == nil && selectedBusinessIDString.isEmpty {
                if let first = businesses.first {
                    localSelectedBusinessID = first.id
                    selectedBusinessIDString = first.id.uuidString
                }
            }
        }
    }
}

struct DonutChartView: View {
    var percentage: Double
    var color: Color = .gray
    
    var body: some View {
        ZStack {
            Circle()
                .stroke(lineWidth: 16)
                .opacity(0.2)
                .foregroundColor(color)
            
            Circle()
                .trim(from: 0.0, to: CGFloat(min(percentage, 1.0)))
                .stroke(style: StrokeStyle(lineWidth: 16, lineCap: .round, lineJoin: .round))
                .foregroundColor(color)
                .rotationEffect(Angle(degrees: 270.0))
                .animation(.easeInOut(duration: 0.3), value: percentage)
            
            Text(String(format: "%.1f%%", min(percentage, 1.0) * 100.0))
                .font(.title2)
                .bold()
                .foregroundColor(.primary)
        }
        .frame(width: 120, height: 120)
    }
}

struct BusinessDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var business: Business
    
    var calculatedAchievement: Double {
        let current = Double(business.currentRevenue.filter { $0.isNumber }) ?? 0
        let target = Double(business.targetRevenue.filter { $0.isNumber }) ?? 0
        if target == 0 { return 0 }
        return min(max(current / target, 0), 1)
    }
    
    private func formatCurrency(_ value: String) -> String {
        let clean = value.filter { $0.isNumber }
        guard let doubleVal = Double(clean) else { return "" }
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: doubleVal)) ?? ""
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header section with Donut Chart and Revenue
                HStack(alignment: .top, spacing: 30) {
                    // Left: Donut Chart
                    VStack {
                        Text("Achievement")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        
                        DonutChartView(percentage: calculatedAchievement)
                            .padding(.vertical, 8)
                    }
                    .frame(width: 150)
                    
                    // Right: Summary stats
                    VStack(alignment: .leading, spacing: 16) {
                        TextField("Business Name", text: $business.name)
                            .font(.system(size: 36, weight: .bold))
                            .textFieldStyle(.plain)
                        
                        HStack(spacing: 12) {
                            Label("Target Goal:", systemImage: "target")
                                .font(.headline)
                                .foregroundColor(.secondary)
                                .frame(width: 140, alignment: .leading)
                            TextField("Target Goal", text: $business.targetGoal)
                                .textFieldStyle(.roundedBorder)
                        }
                        
                        HStack(spacing: 12) {
                            Label("Target Revenue:", systemImage: "dollarsign.circle")
                                .font(.headline)
                                .foregroundColor(.secondary)
                                .frame(width: 140, alignment: .leading)
                            HStack {
                                TextField("e.g. 10000", text: $business.targetRevenue)
                                    .textFieldStyle(.roundedBorder)
                                Text(formatCurrency(business.targetRevenue))
                                    .foregroundColor(.secondary)
                                    .frame(minWidth: 80, alignment: .leading)
                            }
                        }
                        
                        HStack(spacing: 12) {
                            Label("Current Revenue:", systemImage: "dollarsign.arrow.circlepath")
                                .font(.headline)
                                .foregroundColor(.secondary)
                                .frame(width: 140, alignment: .leading)
                            HStack {
                                TextField("e.g. 5000", text: $business.currentRevenue)
                                    .textFieldStyle(.roundedBorder)
                                Text(formatCurrency(business.currentRevenue))
                                    .foregroundColor(.secondary)
                                    .frame(minWidth: 80, alignment: .leading)
                            }
                        }
                        
                        HStack(spacing: 12) {
                            Label("Feasibility:", systemImage: "chart.bar.fill")
                                .font(.headline)
                                .foregroundColor(.secondary)
                                .frame(width: 140, alignment: .leading)
                            Picker("", selection: $business.feasibility) {
                                Text("1").tag(1)
                                Text("2").tag(2)
                                Text("3").tag(3)
                                Text("4").tag(4)
                                Text("5").tag(5)
                            }
                            .pickerStyle(.segmented)
                            .frame(width: 180)
                        }
                    }
                    
                    Spacer()
                }
                .padding()
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(16)
                .shadow(radius: 1)
                
                // Details Grid (3 columns for dense layout)
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), alignment: .top), count: 3), spacing: 16) {
                    EditableDetailSection(title: "Website URL", icon: "link", text: $business.websiteURL)
                    EditableDetailSection(title: "GitHub Repo", icon: "chevron.left.forwardslash.chevron.right", text: $business.githubURL)
                    EditableDetailSection(title: "Executive Summary", icon: "doc.text.magnifyingglass", text: $business.executiveSummary)
                    EditableDetailSection(title: "Target Market Size", icon: "chart.pie", text: $business.targetMarketSize)
                    EditableDetailSection(title: "Core Features", icon: "star.square", text: $business.coreFeatures)
                    EditableDetailSection(title: "Marketing Strategy", icon: "megaphone.fill", text: $business.marketingStrategy)
                    EditableDetailSection(title: "SWOT Analysis", icon: "chart.bar.xaxis", text: $business.swotAnalysis)
                    EditableDetailSection(title: "Budget", icon: "banknote", text: $business.budget)
                    EditableDetailSection(title: "Timeline", icon: "calendar", text: $business.timeline)
                    EditableDetailSection(title: "Team Structure", icon: "person.3.fill", text: $business.teamStructure)
                    EditableDetailSection(title: "Risk Management", icon: "exclamationmark.triangle.fill", text: $business.riskManagement)
                    EditableDetailSection(title: "KPIs", icon: "chart.line.uptrend.xyaxis", text: $business.kpis)
                    EditableDetailSection(title: "Target Audience", icon: "person.2.circle", text: $business.targetAudience)
                    EditableDetailSection(title: "Competitors", icon: "figure.walk", text: $business.competitors)
                    EditableDetailSection(title: "Business Model", icon: "briefcase.fill", text: $business.businessModel)
                }
                
                // Tech Stack Tags
                TechStackTagsView(text: $business.techStack)
                
                // Massive Multi-line Blocks
                BusinessChecklistView(todos: $business.todoList)
                
                InteractiveContactsView(contacts: $business.contactList)
                
                EditableDetailSection(title: "Reference Papers & Links", icon: "books.vertical.fill", text: $business.referenceLinks, isMultiline: true, minHeight: 100)
                
                EditableDetailSection(title: "Business Plan", icon: "text.book.closed.fill", text: $business.plan, isMultiline: true, minHeight: 300)
                
                EditableDetailSection(title: "Architecture & Logic", icon: "network", text: $business.architectureLogic, isMultiline: true, minHeight: 250)
                
                Button(role: .destructive, action: {
                    modelContext.delete(business)
                    try? modelContext.save()
                }) {
                    Label("Delete Business", systemImage: "trash")
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.secondary.opacity(0.1))
                        .cornerRadius(8)
                }
                .buttonStyle(.plain)
                .foregroundColor(.secondary)
                .padding(.top, 24)
            }
            .padding(24)
        }
    }
}

// MARK: - Tech Stack Tags Layout
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(in: proposal.width ?? 0, subviews: subviews, spacing: spacing)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(in: bounds.width, subviews: subviews, spacing: spacing)
        for (index, subview) in subviews.enumerated() {
            let point = result.points[index]
            subview.place(at: CGPoint(x: point.x + bounds.minX, y: point.y + bounds.minY), proposal: ProposedViewSize(result.sizes[index]))
        }
    }

    struct FlowResult {
        var size: CGSize = .zero
        var points: [CGPoint] = []
        var sizes: [CGSize] = []

        init(in maxWidth: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var currentX: CGFloat = 0
            var currentY: CGFloat = 0
            var lineHeight: CGFloat = 0
            var maxX: CGFloat = 0

            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)
                if currentX + size.width > maxWidth && currentX > 0 {
                    currentX = 0
                    currentY += lineHeight + spacing
                    lineHeight = 0
                }
                points.append(CGPoint(x: currentX, y: currentY))
                sizes.append(size)
                lineHeight = max(lineHeight, size.height)
                currentX += size.width + spacing
                maxX = max(maxX, currentX)
            }
            size = CGSize(width: maxWidth > 0 ? maxWidth : maxX, height: currentY + lineHeight)
        }
    }
}

struct TechStackTagsView: View {
    @Binding var text: String
    @State private var newTag: String = ""
    
    var tags: [String] {
        text.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Tech Stack", systemImage: "server.rack")
                .font(.headline)
                .foregroundColor(.secondary)
            
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "plus.square.dashed")
                        .foregroundColor(.secondary)
                        .font(.system(size: 18))
                    TextField("Add tech stack... (Press Enter)", text: $newTag)
                        .textFieldStyle(.plain)
                        .onSubmit {
                            let trimmed = newTag.trimmingCharacters(in: .whitespacesAndNewlines)
                            if !trimmed.isEmpty {
                                var currentTags = tags
                                if !currentTags.contains(trimmed) {
                                    currentTags.append(trimmed)
                                    text = currentTags.joined(separator: ", ")
                                }
                                newTag = ""
                            }
                        }
                }
                
                if !tags.isEmpty {
                    FlowLayout(spacing: 8) {
                        ForEach(tags, id: \.self) { tag in
                            HStack(spacing: 4) {
                                Text(tag)
                                    .font(.subheadline)
                                Button(action: {
                                    var currentTags = tags
                                    if let idx = currentTags.firstIndex(of: tag) {
                                        currentTags.remove(at: idx)
                                        text = currentTags.joined(separator: ", ")
                                    }
                                }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(.secondary)
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.vertical, 6)
                            .padding(.horizontal, 12)
                            .background(Color(NSColor.controlBackgroundColor))
                            .cornerRadius(12)
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.secondary.opacity(0.3), lineWidth: 1))
                        }
                    }
                    .padding(.top, 4)
                }
            }
            .padding(12)
            .background(Color(NSColor.textBackgroundColor))
            .cornerRadius(8)
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.secondary.opacity(0.2), lineWidth: 1))
        }
    }
}

// MARK: - Legacy Views
struct EditableDetailSection: View {
    let title: String
    let icon: String
    @Binding var text: String
    var isMultiline: Bool = false
    var minHeight: CGFloat = 120
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(title, systemImage: icon)
                .font(.headline)
                .foregroundColor(.secondary)
            
            if isMultiline {
                TextEditor(text: $text)
                    .frame(minHeight: minHeight)
                    .padding(4)
                    .background(Color(NSColor.textBackgroundColor))
                    .cornerRadius(8)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.secondary.opacity(0.2), lineWidth: 1))
            } else {
                TextField("Enter \(title)", text: $text)
                    .textFieldStyle(.roundedBorder)
            }
        }
    }
}

struct BusinessChecklistView: View {
    @Binding var todos: [BusinessTodo]
    @State private var newTodo: String = ""
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Action Items (To-Dos)", systemImage: "checklist")
                .font(.headline)
                .foregroundColor(.secondary)
            
            VStack(alignment: .leading, spacing: 8) {
                ForEach($todos) { $todo in
                    HStack {
                        Button(action: {
                            todo.isCompleted.toggle()
                        }) {
                            Image(systemName: todo.isCompleted ? "checkmark.square.fill" : "square")
                                .foregroundColor(todo.isCompleted ? .gray : .secondary)
                                .font(.system(size: 18))
                        }
                        .buttonStyle(.plain)
                        
                        TextField("Todo item", text: $todo.title)
                            .textFieldStyle(.plain)
                            .strikethrough(todo.isCompleted, color: .gray)
                            .foregroundColor(todo.isCompleted ? .gray : .primary)
                        
                        Button(action: {
                            if let index = todos.firstIndex(where: { $0.id == todo.id }) {
                                todos.remove(at: index)
                            }
                        }) {
                            Image(systemName: "xmark")
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                
                HStack {
                    Image(systemName: "plus.square.dashed")
                        .foregroundColor(.secondary)
                        .font(.system(size: 18))
                    TextField("Add new item... (Press Enter)", text: $newTodo)
                        .textFieldStyle(.plain)
                        .onSubmit {
                            if !newTodo.trimmingCharacters(in: .whitespaces).isEmpty {
                                todos.append(BusinessTodo(title: newTodo))
                                newTodo = ""
                            }
                        }
                }
            }
            .padding(12)
            .background(Color(NSColor.textBackgroundColor))
            .cornerRadius(8)
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.secondary.opacity(0.2), lineWidth: 1))
        }
    }
}

struct InteractiveContactsView: View {
    @Binding var contacts: [BusinessContact]
    
    @State private var newName: String = ""
    @State private var newInfo: String = ""
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Contacts & Consulting", systemImage: "person.crop.circle.badge.plus")
                .font(.headline)
                .foregroundColor(.secondary)
            
            VStack(spacing: 12) {
                // Add new contact form
                HStack {
                    TextField("Name", text: $newName)
                        .textFieldStyle(.roundedBorder)
                    TextField("Role / Email / Phone", text: $newInfo)
                        .textFieldStyle(.roundedBorder)
                    Button(action: {
                        let trimmedName = newName.trimmingCharacters(in: .whitespacesAndNewlines)
                        if !trimmedName.isEmpty {
                            contacts.append(BusinessContact(name: trimmedName, info: newInfo.trimmingCharacters(in: .whitespacesAndNewlines)))
                            newName = ""
                            newInfo = ""
                        }
                    }) {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(.gray)
                            .font(.title2)
                    }
                    .buttonStyle(.plain)
                }
                
                // List of contacts
                if !contacts.isEmpty {
                    VStack(spacing: 8) {
                        ForEach($contacts) { $contact in
                            InteractiveContactCard(contact: $contact, onDelete: {
                                if let idx = contacts.firstIndex(where: { $0.id == contact.id }) {
                                    contacts.remove(at: idx)
                                }
                            })
                        }
                    }
                }
            }
            .padding(12)
            .background(Color(NSColor.textBackgroundColor))
            .cornerRadius(8)
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.secondary.opacity(0.2), lineWidth: 1))
        }
    }
}

struct InteractiveContactCard: View {
    @Binding var contact: BusinessContact
    var onDelete: () -> Void
    @State private var isExpanded: Bool = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: {
                withAnimation { isExpanded.toggle() }
            }) {
                HStack {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .foregroundColor(.secondary)
                        .frame(width: 20)
                    
                    VStack(alignment: .leading) {
                        Text(contact.name)
                            .font(.headline)
                        if !contact.info.isEmpty {
                            Text(contact.info)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                    Spacer()
                    
                    Button(action: onDelete) {
                        Image(systemName: "trash")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
                .padding()
            }
            .buttonStyle(.plain)
            
            if isExpanded {
                Divider()
                VStack(alignment: .leading, spacing: 4) {
                    Text("Progress / Status")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    TextEditor(text: $contact.progress)
                        .frame(minHeight: 80)
                        .padding(4)
                        .background(Color(NSColor.textBackgroundColor))
                        .cornerRadius(6)
                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.secondary.opacity(0.2), lineWidth: 1))
                }
                .padding()
            }
        }
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.secondary.opacity(0.2), lineWidth: 1))
    }
}
