import SwiftUI
import SwiftData
import AppKit

struct PeopleView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Person.orderIndex) private var people: [Person]
    
    @State private var showingAddPerson = false
    @State private var selectedTag: String? = nil
    
    private var allTags: [String] {
        let tags = people.flatMap { $0.tags }
        return Array(Set(tags)).sorted()
    }
    
    var filteredPeople: [Person] {
        if let tag = selectedTag {
            return people.filter { $0.tags.contains(tag) }
        }
        return people
    }
    
    let columns = [
        GridItem(.adaptive(minimum: 160, maximum: 200), spacing: 24)
    ]
    
    var body: some View {
        VStack {
            // Tag Filter
            ScrollView(.horizontal, showsIndicators: false) {
                HStack {
                    Button("All") {
                        selectedTag = nil
                    }
                    .buttonStyle(.plain)
                    .padding(.vertical, 6)
                    .padding(.horizontal, 12)
                    .background(selectedTag == nil ? Color.white.opacity(0.15) : Color.white.opacity(0.05))
                    .foregroundColor(selectedTag == nil ? .white : .secondary)
                    .cornerRadius(16)
                    
                    ForEach(allTags, id: \.self) { tag in
                        Button(tag) {
                            selectedTag = tag
                        }
                        .buttonStyle(.plain)
                        .padding(.vertical, 6)
                        .padding(.horizontal, 12)
                        .background(selectedTag == tag ? Color.white.opacity(0.15) : Color.white.opacity(0.05))
                        .foregroundColor(selectedTag == tag ? .white : .secondary)
                        .cornerRadius(16)
                    }
                }
                .padding()
            }
            
            if people.isEmpty {
                Spacer()
                Text("No people added yet.")
                    .foregroundColor(.secondary)
                Spacer()
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 24) {
                        ForEach(filteredPeople) { person in
                            PersonCard(person: person)
                                .contextMenu {
                                    Button("Delete", role: .destructive) {
                                        deletePerson(person)
                                    }
                                }
                        }
                    }
                    .padding()
                }
            }
        }
        .navigationTitle("People & Subscriptions")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: { showingAddPerson = true }) {
                    Image(systemName: "plus")
                }
                .help("Add Person")
            }
        }
        .sheet(isPresented: $showingAddPerson) {
            AddPersonView(isPresented: $showingAddPerson)
        }
    }
    
    private func deletePerson(_ person: Person) {
        modelContext.delete(person)
        try? modelContext.save()
    }
}

struct PersonCard: View {
    var person: Person
    
    var body: some View {
        VStack(spacing: 12) {
            // Photo & Badge
            ZStack(alignment: .topTrailing) {
                Button(action: {
                    if let url = person.link.toValidURL {
                        NSWorkspace.shared.open(url)
                    }
                }) {
                    Group {
                        if let imagePath = person.imagePath,
                           let url = getDocumentsDirectory()?.appendingPathComponent(imagePath),
                           let nsImage = NSImage(contentsOf: url) {
                            Image(nsImage: nsImage)
                                .resizable()
                                .scaledToFill()
                        } else {
                            Image(systemName: "person.crop.circle.fill")
                                .resizable()
                                .scaledToFit()
                                .foregroundColor(.gray)
                        }
                    }
                    .frame(width: 120, height: 120)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Color.secondary.opacity(0.5), lineWidth: 2))
                }
                .buttonStyle(.plain)
                .onHover { isHovered in
                    if isHovered { NSCursor.pointingHand.push() } else { NSCursor.pop() }
                }
                
                // Role Badge
                RoleBadge(role: person.role)
                    .offset(x: 10, y: 10)
            }
            
            // Info
            VStack(spacing: 4) {
                Text(person.name)
                    .font(.headline)
                    .lineLimit(1)
                
                if !person.comment.isEmpty {
                    Text(person.comment)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                }
                
                if !person.tags.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 4) {
                            ForEach(person.tags, id: \.self) { tag in
                                Text(tag)
                                    .font(.system(size: 10))
                                    .padding(.vertical, 2)
                                    .padding(.horizontal, 6)
                                    .background(Color.white.opacity(0.1))
                                    .cornerRadius(4)
                            }
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.2), radius: 5, x: 0, y: 2)
    }
    
    private func getDocumentsDirectory() -> URL? {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
    }
}

struct RoleBadge: View {
    var role: String
    
    var body: some View {
        Group {
            let initial = String(role.first ?? "U").uppercased()
            Text(initial)
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.white)
                .frame(width: 24, height: 24)
        }
        .background(Circle().fill(Color.secondary).padding(1))
        .shadow(radius: 2)
    }
}

struct AddPersonView: View {
    @Binding var isPresented: Bool
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Person.orderIndex) private var people: [Person]
    
    @State private var name: String = ""
    @State private var role: String = "YouTuber"
    @State private var link: String = ""
    @State private var comment: String = ""
    @State private var tagsString: String = ""
    @State private var selectedImageData: Data? = nil
    
    let roles = ["YouTuber", "Researcher", "Blogger", "News", "Other"]
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Add Person").font(.title).bold()
            
            Form {
                TextField("Name", text: $name)
                
                Picker("Role", selection: $role) {
                    ForEach(roles, id: \.self) { role in
                        Text(role).tag(role)
                    }
                }
                
                TextField("Link URL", text: $link)
                
                TextField("Comment", text: $comment)
                
                TextField("Tags (comma separated)", text: $tagsString)
                
                HStack {
                    Text("Photo:")
                    Button("Select Image") {
                        selectImage()
                    }
                    if selectedImageData != nil {
                        Image(systemName: "checkmark.circle.fill").foregroundColor(.green)
                    }
                }
            }
            .frame(width: 400)
            
            HStack {
                Button("Cancel") {
                    isPresented = false
                }
                
                Button("Save") {
                    savePerson()
                }
                .buttonStyle(.borderedProminent)
                .disabled(name.isEmpty || link.isEmpty)
            }
        }
        .padding(30)
        .frame(minWidth: 450)
    }
    
    private func selectImage() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image]
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url {
            selectedImageData = try? Data(contentsOf: url)
        }
    }
    
    private func savePerson() {
        var imagePath: String? = nil
        if let data = selectedImageData {
            let filename = UUID().uuidString + ".jpg"
            if let docsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
                let fileURL = docsDir.appendingPathComponent(filename)
                try? data.write(to: fileURL)
                imagePath = filename
            }
        }
        
        let tags = tagsString.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        let maxOrder = people.map { $0.orderIndex }.max() ?? -1
        
        let newPerson = Person(name: name, role: role, link: link, imagePath: imagePath, comment: comment, tags: tags, orderIndex: maxOrder + 1)
        modelContext.insert(newPerson)
        try? modelContext.save()
        isPresented = false
    }
}
