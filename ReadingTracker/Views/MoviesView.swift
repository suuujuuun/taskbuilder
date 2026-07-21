import SwiftUI
import SwiftData
import AppKit
import PhotosUI

struct MoviesView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var movies: [Movie]
    
    @State private var showingAddSheet = false
    @State private var sortOption: SortOption = .manual
    @State private var tagFilter: String = "All"
    @State private var draggedMovie: Movie?
    
    enum SortOption: String, CaseIterable {
        case manual = "Manual"
        case rating = "Rating"
        case title = "Title"
    }
    
    var filteredAndSortedMovies: [Movie] {
        var result = movies
        if tagFilter != "All" {
            result = result.filter { $0.tags.contains(tagFilter) }
        }
        
        switch sortOption {
        case .manual:
            return result.sorted { $0.orderIndex < $1.orderIndex }
        case .rating:
            return result.sorted { $0.rating > $1.rating }
        case .title:
            return result.sorted { $0.title < $1.title }
        }
    }
    
    var allTags: [String] {
        var tags = Set<String>()
        for movie in movies {
            for tag in movie.tags { tags.insert(tag) }
        }
        return ["All"] + Array(tags).sorted()
    }
    
    let columns = Array(repeating: GridItem(.flexible(), spacing: 16), count: 6)
    
    var body: some View {
        VStack {
            HStack {
                Picker("Sort by", selection: $sortOption) {
                    ForEach(SortOption.allCases, id: \.self) { option in
                        Text(option.rawValue).tag(option)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 200)
                
                Picker("Tag Filter", selection: $tagFilter) {
                    ForEach(allTags, id: \.self) { tag in
                        Text(tag).tag(tag)
                    }
                }
                .frame(width: 150)
                
                Spacer()
                
                Button(action: { showingAddSheet = true }) {
                    Image(systemName: "plus")
                    Text("Add Movie")
                }
            }
            .padding()
            
            ScrollView {
                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(filteredAndSortedMovies) { movie in
                        MovieCard(movie: movie)
                            .onDrag {
                                if sortOption == .manual && tagFilter == "All" {
                                    self.draggedMovie = movie
                                    return NSItemProvider(object: movie.id.uuidString as NSString)
                                }
                                return NSItemProvider()
                            }
                            .onDrop(of: [.text], delegate: MovieDropDelegate(item: movie, items: movies, draggedItem: $draggedMovie, modelContext: modelContext, isEnabled: sortOption == .manual && tagFilter == "All"))
                    }
                }
                .padding()
            }
        }
        .navigationTitle("Movies")
        .sheet(isPresented: $showingAddSheet) {
            EditMovieView(movie: nil)
        }
    }
}

struct MovieCard: View {
    let movie: Movie
    @State private var showingEditSheet = false
    @State private var loadedImage: NSImage? = nil
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack(alignment: .topTrailing) {
                Group {
                    if let image = loadedImage {
                        Image(nsImage: image)
                            .resizable()
                            .scaledToFill()
                    } else if movie.imagePath != nil {
                        Rectangle()
                            .fill(Color.gray.opacity(0.1))
                            .overlay(ProgressView().scaleEffect(0.5))
                    } else {
                        Rectangle()
                            .fill(Color.gray.opacity(0.3))
                            .overlay(Image(systemName: "film").foregroundColor(.secondary).font(.largeTitle))
                    }
                }
                .frame(minWidth: 0, maxWidth: .infinity)
                .frame(height: 200)
                .clipped()
                .task(id: movie.imagePath) {
                    if let path = movie.imagePath {
                        let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent(path)
                        let data = await Task.detached { try? Data(contentsOf: url) }.value
                        await MainActor.run {
                            if let data = data, let image = NSImage(data: data) {
                                self.loadedImage = image
                            } else {
                                self.loadedImage = nil
                            }
                        }
                    } else {
                        self.loadedImage = nil
                    }
                }
                .cornerRadius(8)
                
                Text(String(format: "%.1f ⭐️", movie.rating))
                    .font(.caption).bold()
                    .padding(4)
                    .background(Color.black.opacity(0.7))
                    .foregroundColor(.white)
                    .cornerRadius(4)
                    .padding(4)
            }
            
            Text(movie.title)
                .font(.headline)
                .lineLimit(1)
            
            Text(movie.director)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .lineLimit(1)
            
            if !movie.tags.isEmpty {
                Text(movie.tags.joined(separator: ", "))
                    .font(.caption2)
                    .foregroundColor(Color(red: 0.6, green: 0.9, blue: 0.6))
                    .lineLimit(1)
            }
            
            Spacer(minLength: 0)
        }
        .padding(8)
        .frame(height: 290)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
        .shadow(radius: 2)
        .onTapGesture {
            showingEditSheet = true
        }
        .sheet(isPresented: $showingEditSheet) {
            EditMovieView(movie: movie)
        }
    }
    
    private func loadImage(named: String) -> NSImage? {
        let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent(named)
        return NSImage(contentsOf: url)
    }
}

struct EditMovieView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var movies: [Movie]
    
    let movie: Movie?
    
    @State private var title: String = ""
    @State private var director: String = ""
    @State private var rating: Double = 0.0
    @State private var review: String = ""
    @State private var tagsString: String = ""
    @State private var imagePath: String? = nil
    @State private var isProcessingImage = false
    @State private var selectedPhotoItem: PhotosPickerItem? = nil
    
    var body: some View {
        VStack(spacing: 16) {
            Text(movie == nil ? "Add Movie" : "Edit Movie")
                .font(.title2).bold()
            
            HStack(alignment: .top, spacing: 20) {
                // Left: Image and Upload
                VStack(spacing: 12) {
                    if let imagePath = imagePath, let image = loadImage(named: imagePath) {
                        Image(nsImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 140, height: 200)
                            .clipped()
                            .cornerRadius(8)
                    } else {
                        Rectangle()
                            .fill(Color.gray.opacity(0.2))
                            .frame(width: 140, height: 200)
                            .cornerRadius(8)
                            .overlay(Image(systemName: "photo").foregroundColor(.secondary).font(.largeTitle))
                    }
                    
                    if isProcessingImage {
                        ProgressView().scaleEffect(0.5)
                    } else {
                        HStack {
                            Button(action: selectImageFast) { Image(systemName: "folder") }
                                .help("Select File...")
                            PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                                Image(systemName: "photo.on.rectangle")
                            }
                            .buttonStyle(.bordered)
                            .help("Photos App...")
                            .onChange(of: selectedPhotoItem) { _, newItem in
                                if let newItem = newItem {
                                    processSelectedPhotoItem(newItem)
                                }
                            }
                        }
                    }
                }
                
                // Right: Details
                VStack(spacing: 16) {
                    HStack {
                        Image(systemName: "text.book.closed").foregroundColor(.secondary).frame(width: 24)
                        TextField("Title", text: $title)
                            .textFieldStyle(.roundedBorder)
                    }
                    HStack {
                        Image(systemName: "person.fill").foregroundColor(.secondary).frame(width: 24)
                        TextField("Director", text: $director)
                            .textFieldStyle(.roundedBorder)
                    }
                    HStack {
                        Image(systemName: "star.fill").foregroundColor(.yellow).frame(width: 24)
                        Slider(value: $rating, in: 0...5, step: 0.5)
                        Text(String(format: "%.1f", rating)).frame(width: 30)
                    }
                    HStack {
                        Image(systemName: "tag.fill").foregroundColor(Color(red: 0.6, green: 0.9, blue: 0.6)).frame(width: 24)
                        TextField("Tags (comma separated)", text: $tagsString)
                            .textFieldStyle(.roundedBorder)
                    }
                }
            }
            .padding(.vertical, 8)
            
            // Bottom: Review
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "square.and.pencil").foregroundColor(.secondary)
                    Text("Review").font(.headline)
                }
                TextEditor(text: $review)
                    .frame(height: 120)
                    .padding(4)
                    .background(Color(NSColor.textBackgroundColor))
                    .cornerRadius(8)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.secondary.opacity(0.2), lineWidth: 1))
            }
            
            HStack {
                if let movie = movie {
                    Button("Delete") {
                        modelContext.delete(movie)
                        try? modelContext.save()
                        dismiss()
                    }
                    .foregroundColor(.red)
                }
                
                Spacer()
                
                Button("Cancel") {
                    dismiss()
                }
                
                Button("Save") {
                    saveMovie()
                }
                .buttonStyle(.borderedProminent)
                .disabled(title.isEmpty)
            }
            .padding()
        }
        .frame(width: 500)
        .padding()
        .onAppear {
            if let movie = movie {
                title = movie.title
                director = movie.director
                rating = movie.rating
                review = movie.review
                tagsString = movie.tags.joined(separator: ", ")
                imagePath = movie.imagePath
            }
        }
    }
    
    private func saveMovie() {
        let tags = tagsString.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        
        if let movie = movie {
            movie.title = title
            movie.director = director
            movie.rating = rating
            movie.review = review
            movie.imagePath = imagePath
            movie.tags = tags
        } else {
            let maxOrder = movies.map { $0.orderIndex }.max() ?? -1
            let newMovie = Movie(title: title, director: director, rating: rating, review: review, imagePath: imagePath, tags: tags, orderIndex: maxOrder + 1)
            modelContext.insert(newMovie)
        }
        
        try? modelContext.save()
        dismiss()
    }
    
    private func selectImageFast() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image]
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        
        panel.begin { response in
            if response == .OK, let url = panel.url {
                processSelectedImage(url)
            }
        }
    }

    private func processSelectedImage(_ url: URL) {
        guard url.startAccessingSecurityScopedResource() else { return }
        
        isProcessingImage = true
        
        DispatchQueue.global(qos: .userInitiated).async {
            let filename = UUID().uuidString + ".jpg"
            let destURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent(filename)
            var success = false
            
            do {
                if let image = NSImage(contentsOf: url) {
                    let maxSize: CGFloat = 600
                    let ratio = min(maxSize / image.size.width, maxSize / image.size.height)
                    
                    var finalImage = image
                    if ratio < 1.0 {
                        let newSize = NSSize(width: image.size.width * ratio, height: image.size.height * ratio)
                        let newImage = NSImage(size: newSize)
                        newImage.lockFocus()
                        image.draw(in: NSRect(origin: .zero, size: newSize), from: NSRect(origin: .zero, size: image.size), operation: .copy, fraction: 1.0)
                        newImage.unlockFocus()
                        finalImage = newImage
                    }
                    
                    if let tiffData = finalImage.tiffRepresentation, let bitmap = NSBitmapImageRep(data: tiffData), let jpeg = bitmap.representation(using: .jpeg, properties: [.compressionFactor: 0.8]) {
                        try jpeg.write(to: destURL)
                        success = true
                    }
                }
            } catch {
                print("Error saving image: \(error)")
            }
            
            url.stopAccessingSecurityScopedResource()
            
            DispatchQueue.main.async {
                if success {
                    self.imagePath = filename
                }
                self.isProcessingImage = false
            }
        }
    }
    
    private func processSelectedPhotoItem(_ item: PhotosPickerItem) {
        isProcessingImage = true
        
        item.loadTransferable(type: Data.self) { result in
            DispatchQueue.global(qos: .userInitiated).async {
                let filename = UUID().uuidString + ".jpg"
                let destURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent(filename)
                var success = false
                
                switch result {
                case .success(let data?):
                    if let image = NSImage(data: data) {
                        let maxSize: CGFloat = 600
                        let ratio = min(maxSize / image.size.width, maxSize / image.size.height)
                        
                        var finalImage = image
                        if ratio < 1.0 {
                            let newSize = NSSize(width: image.size.width * ratio, height: image.size.height * ratio)
                            let newImage = NSImage(size: newSize)
                            newImage.lockFocus()
                            image.draw(in: NSRect(origin: .zero, size: newSize), from: NSRect(origin: .zero, size: image.size), operation: .copy, fraction: 1.0)
                            newImage.unlockFocus()
                            finalImage = newImage
                        }
                        
                        if let tiffData = finalImage.tiffRepresentation, let bitmap = NSBitmapImageRep(data: tiffData), let jpeg = bitmap.representation(using: .jpeg, properties: [.compressionFactor: 0.8]) {
                            do {
                                try jpeg.write(to: destURL)
                                success = true
                            } catch {
                                print("Error writing photo: \(error)")
                            }
                        }
                    }
                case .success(nil):
                    print("No data found")
                case .failure(let error):
                    print("Error loading photo: \(error)")
                }
                
                DispatchQueue.main.async {
                    if success {
                        self.imagePath = filename
                    }
                    self.isProcessingImage = false
                }
            }
        }
    }
    
    private func loadImage(named: String) -> NSImage? {
        let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent(named)
        return NSImage(contentsOf: url)
    }
}

struct MovieDropDelegate: DropDelegate {
    let item: Movie
    var items: [Movie]
    @Binding var draggedItem: Movie?
    var modelContext: ModelContext
    var isEnabled: Bool
    
    func dropEntered(info: DropInfo) {
        guard isEnabled, let draggedItem, draggedItem != item else { return }
        
        let sorted = items.sorted { $0.orderIndex < $1.orderIndex }
        guard let fromIndex = sorted.firstIndex(of: draggedItem),
              let toIndex = sorted.firstIndex(of: item) else { return }
        
        if fromIndex != toIndex {
            var newItems = sorted
            newItems.move(fromOffsets: IndexSet(integer: fromIndex), toOffset: toIndex > fromIndex ? toIndex + 1 : toIndex)
            
            for (index, movie) in newItems.enumerated() {
                movie.orderIndex = index
            }
            try? modelContext.save()
        }
    }
    
    func dropUpdated(info: DropInfo) -> DropProposal? {
        return DropProposal(operation: isEnabled ? .move : .forbidden)
    }
    
    func performDrop(info: DropInfo) -> Bool {
        draggedItem = nil
        return true
    }
}
