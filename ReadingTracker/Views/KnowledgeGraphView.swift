import SwiftUI
import SwiftData
import SpriteKit

struct KnowledgeGraphView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var nodes: [ConceptNode]
    @Query private var links: [ConceptLink]
    @Query private var memos: [GeneralMemo]
    
    @Binding var columnVisibility: NavigationSplitViewVisibility
    
    @State private var selectedNode: ConceptNode?
    @State private var isEditing = false
    @State private var searchText = ""
    @State private var connectionSearchText = ""
    @State private var isLinkMode = false
    @State private var zoomScale: CGFloat = 1.0
    @State private var isMoveTogetherMode = false
    @State private var triggerRearrange = false
    @State private var hasInitialFit = false
    
    @State private var selectedTag: String? = nil
    @State private var tagInputText = ""
    @State private var triggerFitScreen = false
    @State private var targetCameraPosition: CGPoint?
    
    private var allAvailableTags: [String] {
        let allTags = validNodes.flatMap { $0.tags }
        return Array(Set(allTags)).sorted()
    }
    
    private var validNodes: [ConceptNode] {
        nodes.filter { $0.modelContext != nil && !$0.isDeleted }
    }
    
    private var validLinks: [ConceptLink] {
        links.filter { $0.modelContext != nil && !$0.isDeleted }
    }
    
    var body: some View {
        HStack(spacing: 0) {
            ZStack(alignment: .top) {
                GraphSpriteView(
                    nodes: validNodes,
                    links: validLinks,
                    selectedNodeId: selectedNode?.id,
                    searchText: searchText,
                    selectedTag: selectedTag,
                    isLinkMode: isLinkMode,
                    zoomScale: zoomScale,
                    isMoveTogetherMode: isMoveTogetherMode,
                    triggerRearrange: $triggerRearrange,
                    triggerFitScreen: $triggerFitScreen,
                    targetCameraPosition: targetCameraPosition,
                    onZoomChanged: { newScale in
                        zoomScale = newScale
                    },
                    onNodeSelected: { id in
                        selectedNode = validNodes.first(where: { $0.id == id })
                        isEditing = false
                    },
                    onNodeMoved: { id, position in
                        if let node = validNodes.first(where: { $0.id == id }) {
                            node.x = position.x
                            node.y = position.y
                        }
                    },
                    onLinkCreated: { srcId, tgtId in
                        if let src = validNodes.first(where: { $0.id == srcId }),
                           let tgt = validNodes.first(where: { $0.id == tgtId }),
                           srcId != tgtId {
                            let link = ConceptLink(source: src, target: tgt)
                            modelContext.insert(link)
                            try? modelContext.save()
                        }
                    }
                )
                .ignoresSafeArea()
                .onAppear {
                    if !hasInitialFit && !validNodes.isEmpty {
                        fitNodesToScreen()
                        hasInitialFit = true
                    }
                }
                .onChange(of: validNodes.count) { _, _ in
                    if !hasInitialFit && !validNodes.isEmpty {
                        fitNodesToScreen()
                        hasInitialFit = true
                    }
                }
                
                // Overlay controls
                HStack {
                    Button(action: addNode) {
                        Image(systemName: "plus")
                    }
                    .buttonStyle(.borderedProminent)
                    .help("New Concept")
                    
                    Toggle(isOn: $isLinkMode) {
                        Image(systemName: "link")
                    }
                    .toggleStyle(.button)
                    .help("Link Mode")
                    
                    Toggle(isOn: $isMoveTogetherMode) {
                        Image(systemName: "square.dashed.inset.filled")
                    }
                    .toggleStyle(.button)
                    .help("Move Together")
                    
                    Button(action: { triggerRearrange = true }) {
                        Image(systemName: "wand.and.stars")
                    }
                    .buttonStyle(.bordered)
                    .help("Rearrange Nodes")
                    
                    Spacer()
                    
                    HStack(spacing: 8) {
                        Button(action: { zoomScale = min(50.0, zoomScale + 0.2) }) {
                            Image(systemName: "minus.magnifyingglass")
                        }.buttonStyle(.bordered).help("Zoom Out")
                        
                        Button(action: { zoomScale = max(0.1, zoomScale - 0.2) }) {
                            Image(systemName: "plus.magnifyingglass")
                        }.buttonStyle(.bordered).help("Zoom In")
                    }
                    .padding(.trailing, 10)
                    

                    TextField("Search concepts...", text: $searchText)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 250)
                }
                .padding()
            }
            
            Divider()
            
            // Detail panel
            VStack {
                if let node = selectedNode {
                    VStack(alignment: .leading, spacing: 0) {
                        HStack {
                            Spacer()
                            if !isEditing {
                                Button(role: .destructive, action: deleteSelectedNode) {
                                    Image(systemName: "trash")
                                }
                            } else {
                                Button("Done") { 
                                    isEditing = false
                                    try? modelContext.save()
                                }
                                .buttonStyle(.borderedProminent)
                            }
                        }
                        .padding([.top, .horizontal])
                        .padding(.bottom, 8)
                        
                        if isEditing {
                            TextField("Title", text: Binding(
                                get: { node.title },
                                set: { node.title = $0 }
                            ))
                            .font(.largeTitle.bold())
                            .textFieldStyle(.plain)
                            .padding(.horizontal)
                            
                            Divider().padding(.vertical, 8)
                            
                            // Compact Edit Tags UI
                            VStack(alignment: .leading, spacing: 4) {
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 6) {
                                        Image(systemName: "tag").foregroundColor(.secondary).font(.caption)
                                        
                                        ForEach(node.tags, id: \.self) { tag in
                                            HStack(spacing: 2) {
                                                Text(tag)
                                                Button(action: {
                                                    node.tags = node.tags.filter { $0 != tag }
                                                }) {
                                                    Image(systemName: "xmark").font(.system(size: 8, weight: .bold))
                                                }.buttonStyle(.plain)
                                            }
                                            .font(.caption)
                                            .padding(.vertical, 2)
                                            .padding(.horizontal, 6)
                                            .background(Color.secondary.opacity(0.15))
                                            .cornerRadius(6)
                                        }
                                        
                                        TextField("Add tag...", text: $tagInputText)
                                            .textFieldStyle(.plain)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                            .frame(minWidth: 60)
                                            .onSubmit {
                                                let newTag = tagInputText.trimmingCharacters(in: .whitespaces)
                                                if !newTag.isEmpty && !node.tags.contains(newTag) {
                                                    node.tags = node.tags + [newTag]
                                                    tagInputText = ""
                                                }
                                            }
                                    }
                                }
                                
                                if !tagInputText.isEmpty {
                                    let suggestions = allAvailableTags.filter { $0.localizedCaseInsensitiveContains(tagInputText) && !node.tags.contains($0) }
                                    if !suggestions.isEmpty {
                                        ScrollView(.horizontal, showsIndicators: false) {
                                            HStack(spacing: 4) {
                                                ForEach(suggestions, id: \.self) { sug in
                                                    Button(action: {
                                                        node.tags = node.tags + [sug]
                                                        tagInputText = ""
                                                    }) {
                                                        Text(sug)
                                                            .font(.caption)
                                                            .padding(.vertical, 2)
                                                            .padding(.horizontal, 6)
                                                            .background(Color.secondary.opacity(0.1))
                                                            .cornerRadius(4)
                                                    }
                                                    .buttonStyle(.plain)
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                            .padding(.horizontal)
                            
                            Divider().padding(.vertical, 8)
                            
                            TextEditor(text: Binding(
                                get: { node.content },
                                set: { node.content = $0 }
                            ))
                            .font(.system(.body, design: .monospaced))
                            .padding(.horizontal)
                            .padding(.bottom, 20)
                            
                        } else {
                            Text(node.title.isEmpty ? "Untitled Concept" : node.title)
                                .font(.largeTitle.bold())
                                .foregroundColor(node.title.isEmpty ? .secondary : .primary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal)
                                .contentShape(Rectangle())
                                .onTapGesture { isEditing = true }
                                
                            Divider().padding(.vertical, 8)
                            
                            if !node.tags.isEmpty {
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack {
                                        ForEach(node.tags, id: \.self) { tag in
                                            Button(action: {
                                                if selectedTag == tag {
                                                    selectedTag = nil
                                                } else {
                                                    selectedTag = tag
                                                }
                                            }) {
                                                Text(tag)
                                            }
                                            .buttonStyle(.plain)
                                            .padding(.vertical, 4)
                                            .padding(.horizontal, 8)
                                            .background(selectedTag == tag ? Color.purple.opacity(0.4) : Color.gray.opacity(0.2))
                                            .cornerRadius(8)
                                        }
                                    }
                                }
                                .padding(.horizontal)
                                .padding(.bottom, 8)
                            }
                            
                            ScrollView {
                                VStack(alignment: .leading) {
                                    Text(node.content)
                                        .font(.body)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                                .padding(.horizontal)
                                .contentShape(Rectangle())
                                .onTapGesture { isEditing = true }
                                
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Connections")
                                        .font(.headline)
                                        .padding(.top, 16)
                                        .padding(.bottom, 4)
                                    
                                    HStack {
                                        Image(systemName: "magnifyingglass").foregroundColor(.secondary)
                                        TextField("Search to connect...", text: $connectionSearchText)
                                            .textFieldStyle(.roundedBorder)
                                            .frame(minHeight: 28)
                                    }
                                    .padding(.vertical, 4)
                                    .padding(.bottom, 8)
                                    
                                    if !connectionSearchText.isEmpty {
                                        let searchResults = validNodes.filter { $0.id != node.id && ($0.title.localizedCaseInsensitiveContains(connectionSearchText) || $0.content.localizedCaseInsensitiveContains(connectionSearchText)) }
                                        if !searchResults.isEmpty {
                                            ScrollView {
                                                VStack(alignment: .leading) {
                                                    ForEach(searchResults) { targetNode in
                                                        Button(action: {
                                                            let link = ConceptLink(source: node, target: targetNode)
                                                            modelContext.insert(link)
                                                            try? modelContext.save()
                                                            connectionSearchText = ""
                                                        }) {
                                                            HStack {
                                                                Image(systemName: "link.badge.plus")
                                                                Text(targetNode.title.isEmpty ? "Untitled Concept" : targetNode.title)
                                                                    .lineLimit(1)
                                                            }
                                                        }
                                                        .buttonStyle(.plain)
                                                        .foregroundColor(.accentColor)
                                                        .padding(.vertical, 4)
                                                    }
                                                }
                                            }
                                            .frame(maxHeight: 150)
                                            
                                            Divider().padding(.vertical, 4)
                                        }
                                    }
                                    
                                    ForEach(node.linksOut.filter { $0.modelContext != nil && !$0.isDeleted }) { link in
                                        if let target = link.target, validNodes.contains(where: { $0.persistentModelID == target.persistentModelID }) {
                                            HStack {
                                                Button(action: {
                                                    selectedNode = target
                                                }) {
                                                    HStack {
                                                        Image(systemName: "arrow.right.circle.fill").foregroundColor(.secondary)
                                                        Text(target.title.isEmpty ? "Untitled Concept" : target.title)
                                                            .foregroundColor(.primary)
                                                    }
                                                }
                                                .buttonStyle(.plain)
                                                .onHover { isHovered in
                                                    if isHovered { NSCursor.pointingHand.push() } else { NSCursor.pop() }
                                                }
                                                
                                                Spacer()
                                                Button(role: .destructive, action: {
                                                    modelContext.delete(link)
                                                    try? modelContext.save()
                                                }) {
                                                    Image(systemName: "xmark.circle.fill").foregroundColor(.red)
                                                }
                                                .buttonStyle(.plain)
                                            }
                                        }
                                    }
                                    ForEach(node.linksIn.filter { $0.modelContext != nil && !$0.isDeleted }) { link in
                                        if let source = link.source, validNodes.contains(where: { $0.persistentModelID == source.persistentModelID }) {
                                            HStack {
                                                Button(action: {
                                                    selectedNode = source
                                                }) {
                                                    HStack {
                                                        Image(systemName: "arrow.left.circle.fill").foregroundColor(.secondary)
                                                        Text(source.title.isEmpty ? "Untitled Concept" : source.title)
                                                            .foregroundColor(.primary)
                                                    }
                                                }
                                                .buttonStyle(.plain)
                                                .onHover { isHovered in
                                                    if isHovered { NSCursor.pointingHand.push() } else { NSCursor.pop() }
                                                }
                                                
                                                Spacer()
                                                Button(role: .destructive, action: {
                                                    modelContext.delete(link)
                                                    try? modelContext.save()
                                                }) {
                                                    Image(systemName: "xmark.circle.fill").foregroundColor(.red)
                                                }
                                                .buttonStyle(.plain)
                                            }
                                        }
                                    }
                                }
                                .padding(.horizontal)
                                .padding(.bottom, 20)
                            }
                        }
                    }
                    .frame(width: 450)
                } else {
                    VStack(spacing: 16) {
                        Text("Somewhere, something incredible is waiting to be known.")
                            .font(.custom("Palatino", size: 18))
                            .italic()
                            .multilineTextAlignment(.center)
                            
                        Text("- Carl Sagan")
                            .font(.custom("Palatino", size: 14))
                            .foregroundColor(.secondary)
                            .padding(.top, 4)
                    }
                    .padding()
                    .frame(width: 450)
                }
            }
            .frame(maxHeight: .infinity)
            .background(Color(NSColor.controlBackgroundColor))
        }
    }
    
    private func fitNodesToScreen() {
        guard !validNodes.isEmpty else { return }
        let xs = validNodes.map { $0.x }
        let ys = validNodes.map { $0.y }
        let minX = xs.min() ?? 0
        let maxX = xs.max() ?? 0
        let minY = ys.min() ?? 0
        let maxY = ys.max() ?? 0
        
        let width = max(maxX - minX + 400, 800)
        let height = max(maxY - minY + 400, 600)
        
        let scaleX = width / 800.0
        let scaleY = height / 600.0
        var newScale = max(scaleX, scaleY)
        newScale = max(0.1, min(newScale, 50.0))
        zoomScale = newScale
        
        targetCameraPosition = CGPoint(x: (minX + maxX) / 2, y: (minY + maxY) / 2)
        triggerFitScreen = true
    }
    
    private func addNode() {
        let node = ConceptNode(title: "", shortName: nil, content: "")
        modelContext.insert(node)
        try? modelContext.save()
        selectedNode = node
        isEditing = true
    }
    
    private func deleteSelectedNode() {
        if let node = selectedNode {
            for link in node.linksIn { modelContext.delete(link) }
            for link in node.linksOut { modelContext.delete(link) }
            modelContext.delete(node)
            try? modelContext.save()
            selectedNode = nil
        }
    }
    

}

// MARK: - SpriteKit Integration

struct GraphSpriteView: NSViewRepresentable {
    var nodes: [ConceptNode]
    var links: [ConceptLink]
    var selectedNodeId: UUID?
    var searchText: String
    var selectedTag: String?
    var isLinkMode: Bool
    var zoomScale: CGFloat
    var isMoveTogetherMode: Bool
    @Binding var triggerRearrange: Bool
    @Binding var triggerFitScreen: Bool
    var targetCameraPosition: CGPoint?
    
    var onZoomChanged: (CGFloat) -> Void
    var onNodeSelected: (UUID) -> Void
    var onNodeMoved: (UUID, CGPoint) -> Void
    var onLinkCreated: (UUID, UUID) -> Void
    
    func makeNSView(context: Context) -> SKView {
        let view = SKView()
        let scene = GraphScene(size: CGSize(width: 800, height: 600))
        scene.scaleMode = .resizeFill
        scene.onNodeSelected = onNodeSelected
        scene.onNodeMoved = onNodeMoved
        scene.onLinkCreated = onLinkCreated
        scene.onZoomChanged = onZoomChanged
        view.presentScene(scene)
        
        scene.updateData(nodes: nodes, links: links, selectedNodeId: selectedNodeId, searchText: searchText, selectedTag: selectedTag, isLinkMode: isLinkMode)
        scene.cameraNode.setScale(zoomScale)
        return view
    }
    
    func updateNSView(_ nsView: SKView, context: Context) {
        if let scene = nsView.scene as? GraphScene {
            scene.isMoveTogetherMode = isMoveTogetherMode
            scene.updateData(nodes: nodes, links: links, selectedNodeId: selectedNodeId, searchText: searchText, selectedTag: selectedTag, isLinkMode: isLinkMode)
            
            if triggerFitScreen {
                if let pos = targetCameraPosition {
                    scene.cameraNode.position = pos
                }
                scene.cameraNode.setScale(zoomScale)
                DispatchQueue.main.async { triggerFitScreen = false }
            } else if scene.cameraNode.xScale != zoomScale {
                scene.cameraNode.setScale(zoomScale)
            }
            
            if triggerRearrange {
                scene.rearrangeNodes()
                DispatchQueue.main.async { triggerRearrange = false }
            }
        }
    }
}

class GraphScene: SKScene {
    var onNodeSelected: ((UUID) -> Void)?
    var onNodeMoved: ((UUID, CGPoint) -> Void)?
    var onLinkCreated: ((UUID, UUID) -> Void)?
    var onZoomChanged: ((CGFloat) -> Void)?
    
    var isMoveTogetherMode = false
    
    var draggedNodes: Set<UUID> = []
    
    private var nodeSprites: [UUID: SKNode] = [:]
    private var linkLinesNode: SKShapeNode = SKShapeNode()
    
    struct LinkData {
        let sourceId: UUID
        let targetId: UUID
    }
    
    private var _linksData: [LinkData] = []
    
    private var dragTarget: SKNode?
    private var isLinking: Bool = false
    private var tempLinkLine: SKShapeNode?
    private var needsPathUpdate: Bool = true
    
    let cameraNode = SKCameraNode()
    
    override func didMove(to view: SKView) {
        self.backgroundColor = NSColor.black
        self.physicsWorld.gravity = .zero
        self.camera = cameraNode
        self.addChild(cameraNode)
        
        linkLinesNode.strokeColor = NSColor.systemGray.withAlphaComponent(0.5)
        linkLinesNode.lineWidth = 1
        linkLinesNode.zPosition = -1
        self.addChild(linkLinesNode)
    }
    
    func updateData(nodes: [ConceptNode], links: [ConceptLink], selectedNodeId: UUID?, searchText: String, selectedTag: String?, isLinkMode: Bool) {
        needsPathUpdate = true
        var validNodeIDs: [PersistentIdentifier: UUID] = [:]
        for node in nodes {
            guard node.modelContext != nil, !node.isDeleted else { continue }
            validNodeIDs[node.persistentModelID] = node.id
        }
        
        self._linksData = links.compactMap { link in
            guard link.modelContext != nil, !link.isDeleted, 
                  let src = link.source, let tgt = link.target else { return nil }
            
            guard let srcId = validNodeIDs[src.persistentModelID],
                  let tgtId = validNodeIDs[tgt.persistentModelID] else { return nil }
                  
            return LinkData(sourceId: srcId, targetId: tgtId)
        }
        self.isLinking = isLinkMode
        
        let newIds = Set(validNodeIDs.values)
        for (id, sprite) in nodeSprites {
            if !newIds.contains(id) {
                sprite.removeFromParent()
                nodeSprites.removeValue(forKey: id)
            }
        }
        
        for node in nodes {
            guard node.modelContext != nil, !node.isDeleted else { continue }
            let isSelected = node.id == selectedNodeId
            let isMatch = !searchText.isEmpty && (node.title.localizedCaseInsensitiveContains(searchText) || node.content.localizedCaseInsensitiveContains(searchText))
            let isTagMatch = selectedTag != nil && node.tags.contains(selectedTag!)
            let isDimmed = !searchText.isEmpty && !isMatch
            
            let color: NSColor
            if isSelected {
                color = NSColor(red: 0.3, green: 0.8, blue: 1.0, alpha: 1.0)
            } else if isTagMatch {
                color = .systemPurple
            } else if isMatch {
                color = .yellow
            } else if isDimmed {
                color = .darkGray
            } else {
                color = .white
            }
            
            if let sprite = nodeSprites[node.id] {
                // If it exists, just ensure it's at the right spot if it wasn't being dragged
                if sprite != dragTarget && !draggedNodes.contains(node.id) {
                    sprite.position = CGPoint(x: node.x == 0 ? frame.midX : node.x, y: node.y == 0 ? frame.midY : node.y)
                }
                
                if let dot = sprite.childNode(withName: "dot") as? SKShapeNode {
                    dot.fillColor = color
                    dot.xScale = (isMatch || isTagMatch) ? 1.5 : (isSelected ? 1.3 : 1.0)
                    dot.yScale = (isMatch || isTagMatch) ? 1.5 : (isSelected ? 1.3 : 1.0)
                    if isSelected {
                        dot.strokeColor = NSColor(red: 0.3, green: 0.8, blue: 1.0, alpha: 1.0)
                        dot.glowWidth = 8.0
                    } else {
                        dot.strokeColor = .clear
                        dot.glowWidth = 0.0
                    }
                }
            } else {
                let group = SKNode()
                // initial placement
                if node.x == 0 && node.y == 0 {
                    group.position = CGPoint(x: frame.midX + CGFloat.random(in: -100...100), y: frame.midY + CGFloat.random(in: -100...100))
                    onNodeMoved?(node.id, group.position)
                } else {
                    group.position = CGPoint(x: node.x, y: node.y)
                }
                group.name = node.id.uuidString
                
                let dot = SKShapeNode(circleOfRadius: 5)
                dot.fillColor = color
                dot.xScale = (isMatch || isTagMatch) ? 1.5 : (isSelected ? 1.3 : 1.0)
                dot.yScale = (isMatch || isTagMatch) ? 1.5 : (isSelected ? 1.3 : 1.0)
                if isSelected {
                    dot.strokeColor = NSColor(red: 0.3, green: 0.8, blue: 1.0, alpha: 1.0)
                    dot.glowWidth = 8.0
                } else {
                    dot.strokeColor = .clear
                    dot.glowWidth = 0.0
                }
                dot.name = "dot"
                group.addChild(dot)
                
                // Increase hit area slightly
                let hitArea = SKShapeNode(circleOfRadius: 20)
                hitArea.fillColor = .clear
                hitArea.strokeColor = .clear
                group.addChild(hitArea)
                
                addChild(group)
                nodeSprites[node.id] = group
            }
        }
    }
    
    override func update(_ currentTime: TimeInterval) {
        var isMoving = false
        for sprite in nodeSprites.values {
            if sprite.hasActions() { isMoving = true; break }
        }
        
        if !isMoving && dragTarget == nil && !needsPathUpdate { return }
        needsPathUpdate = false
        
        let path = CGMutablePath()
        for linkData in _linksData {
            let srcId = linkData.sourceId
            let tgtId = linkData.targetId
            guard let n1 = nodeSprites[srcId], let n2 = nodeSprites[tgtId] else { continue }
            
            path.move(to: n1.position)
            path.addLine(to: n2.position)
        }
        linkLinesNode.path = path
    }
    
    private func getConnectedComponent(for nodeId: UUID) -> Set<UUID> {
        var visited = Set<UUID>()
        var queue = [nodeId]
        visited.insert(nodeId)
        
        while !queue.isEmpty {
            let current = queue.removeFirst()
            for linkData in _linksData {
                let fromId = linkData.sourceId
                let toId = linkData.targetId
                
                if fromId == current && !visited.contains(toId) {
                    visited.insert(toId)
                    queue.append(toId)
                }
                if toId == current && !visited.contains(fromId) {
                    visited.insert(fromId)
                    queue.append(fromId)
                }
            }
        }
        return visited
    }
    
    override func mouseDown(with event: NSEvent) {
        let location = event.location(in: self)
        let nodesAtLoc = nodes(at: location)
        
        // isLinking is now controlled by isLinkMode via updateData, 
        // but we can also allow shift as a fallback
        let shiftPressed = event.modifierFlags.contains(.shift)
        let linkingMode = isLinking || shiftPressed
        
        for node in nodesAtLoc {
            if let uuidString = node.name ?? node.parent?.name,
               let uuid = UUID(uuidString: uuidString) {
                let parentNode = node.parent?.name == uuidString ? node.parent : node
                dragTarget = parentNode
                
                if let draggedId = UUID(uuidString: uuidString) {
                    if isMoveTogetherMode {
                        draggedNodes = getConnectedComponent(for: draggedId)
                    } else {
                        draggedNodes = [draggedId]
                    }
                }
                
                if linkingMode {
                    // Start temporary link line
                    tempLinkLine = SKShapeNode()
                    tempLinkLine?.strokeColor = .white
                    tempLinkLine?.lineWidth = 1
                    tempLinkLine?.zPosition = -1
                    if let tl = tempLinkLine { addChild(tl) }
                } else {
                    onNodeSelected?(uuid)
                    if let dot = parentNode?.childNode(withName: "dot") as? SKShapeNode {
                        dot.fillColor = NSColor(red: 0.3, green: 0.8, blue: 1.0, alpha: 1.0)
                        dot.xScale = 1.3
                        dot.yScale = 1.3
                        dot.strokeColor = NSColor(red: 0.3, green: 0.8, blue: 1.0, alpha: 1.0)
                        dot.glowWidth = 8.0
                    }
                }
                break
            }
        }
    }
    
    override func mouseDragged(with event: NSEvent) {
        let location = event.location(in: self)
        
        let shiftPressed = event.modifierFlags.contains(.shift)
        let linkingMode = isLinking || shiftPressed
        
        if let target = dragTarget {
            if linkingMode, let tl = tempLinkLine {
                let path = CGMutablePath()
                path.move(to: target.position)
                path.addLine(to: location)
                tl.path = path
            } else {
                let dx = location.x - target.position.x
                let dy = location.y - target.position.y
                
                if !draggedNodes.isEmpty {
                    for id in draggedNodes {
                        if let sprite = nodeSprites[id] {
                            sprite.position.x += dx
                            sprite.position.y += dy
                        }
                    }
                } else {
                    target.position = location
                }
            }
        } else {
            if let camera = self.camera {
                camera.position.x -= event.deltaX * camera.xScale
                camera.position.y += event.deltaY * camera.yScale
            }
        }
    }
    override func scrollWheel(with event: NSEvent) {
        guard let camera = self.camera else { return }
        let delta = event.scrollingDeltaY != 0 ? event.scrollingDeltaY : event.deltaY * 5.0
        let zoomMultiplier: CGFloat = 1.0 + (delta * -0.01)
        var newScale = camera.xScale * zoomMultiplier
        newScale = max(0.1, min(newScale, 50.0))
        camera.setScale(newScale)
        onZoomChanged?(newScale)
    }
    
    override func magnify(with event: NSEvent) {
        guard let camera = self.camera else { return }
        var newScale = camera.xScale * (1.0 - event.magnification)
        newScale = max(0.1, min(newScale, 50.0))
        camera.setScale(newScale)
        onZoomChanged?(newScale)
    }
    
    override func mouseUp(with event: NSEvent) {
        let location = event.location(in: self)
        
        let shiftPressed = event.modifierFlags.contains(.shift)
        let linkingMode = isLinking || shiftPressed
        
        if let target = dragTarget {
            if linkingMode {
                // Find node under mouse
                let nodesAtLoc = nodes(at: location)
                for node in nodesAtLoc {
                    if let tgtUuidString = node.name ?? node.parent?.name,
                       let tgtUuid = UUID(uuidString: tgtUuidString),
                       let srcUuidString = target.name,
                       let srcUuid = UUID(uuidString: srcUuidString),
                       srcUuid != tgtUuid {
                        onLinkCreated?(srcUuid, tgtUuid)
                        break
                    }
                }
                
                tempLinkLine?.removeFromParent()
                tempLinkLine = nil
            } else {
                if let dot = target.childNode(withName: "dot") as? SKShapeNode {
                    dot.fillColor = .white
                }
                if !draggedNodes.isEmpty {
                    for id in draggedNodes {
                        if let sprite = nodeSprites[id] {
                            onNodeMoved?(id, sprite.position)
                        }
                    }
                } else {
                    if let uuid = UUID(uuidString: target.name ?? "") {
                        onNodeMoved?(uuid, target.position)
                    }
                }
            }
        }
        
        dragTarget = nil
        draggedNodes.removeAll()
        // don't reset isLinking here because it's bound to the toggle state
    }
    
    func rearrangeNodes() {
        let k = 150.0
        let k_sq = k * k
        var positions: [UUID: CGPoint] = [:]
        for (id, sprite) in nodeSprites { positions[id] = sprite.position }
        
        // Capture links data so we can use it safely in background
        let linksData = self._linksData
        let nodeKeys = Array(nodeSprites.keys)
        let midX = frame.midX
        let midY = frame.midY
        
        DispatchQueue.global(qos: .userInitiated).async {
            for _ in 0..<150 {
                var forces: [UUID: CGPoint] = [:]
                for id in nodeKeys { forces[id] = .zero }
                
                for i in 0..<nodeKeys.count {
                    for j in (i+1)..<nodeKeys.count {
                        let id1 = nodeKeys[i]; let id2 = nodeKeys[j]
                        let p1 = positions[id1] ?? .zero; let p2 = positions[id2] ?? .zero
                        let dx = p1.x - p2.x; let dy = p1.y - p2.y
                        let distSq = max(dx*dx + dy*dy, 0.1)
                        let dist = sqrt(distSq)
                        if dist < 1000 {
                            let force = k_sq / dist
                            let fx = (dx / dist) * force
                            let fy = (dy / dist) * force
                            forces[id1, default: .zero].x += fx; forces[id1, default: .zero].y += fy
                            forces[id2, default: .zero].x -= fx; forces[id2, default: .zero].y -= fy
                        }
                    }
                }
                
                for link in linksData {
                    guard let p1 = positions[link.sourceId], let p2 = positions[link.targetId] else { continue }
                    let dx = p1.x - p2.x; let dy = p1.y - p2.y
                    let dist = max(sqrt(dx*dx + dy*dy), 0.1)
                    let force = (dist * dist) / k
                    let fx = (dx / dist) * force; let fy = (dy / dist) * force
                    forces[link.sourceId, default: .zero].x -= fx; forces[link.sourceId, default: .zero].y -= fy
                    forces[link.targetId, default: .zero].x += fx; forces[link.targetId, default: .zero].y += fy
                }
                
                let center = CGPoint(x: midX, y: midY)
                for id in nodeKeys {
                    let p = positions[id] ?? .zero
                    let dx = center.x - p.x; let dy = center.y - p.y
                    let dist = max(sqrt(dx*dx + dy*dy), 0.1)
                    let force = dist * 0.1
                    forces[id, default: .zero].x += (dx / dist) * force; forces[id, default: .zero].y += (dy / dist) * force
                }
                
                for id in nodeKeys {
                    let f = forces[id] ?? .zero
                    let maxMove: CGFloat = 50.0
                    let moveDist = sqrt(f.x*f.x + f.y*f.y)
                    let scale = min(moveDist, maxMove) / max(moveDist, 0.1)
                    positions[id, default: .zero].x += f.x * scale * 0.1
                    positions[id, default: .zero].y += f.y * scale * 0.1
                }
            }
            
            DispatchQueue.main.async {
                self.needsPathUpdate = true
                for (id, sprite) in self.nodeSprites {
                    if let newPos = positions[id] {
                        let action = SKAction.move(to: newPos, duration: 0.8)
                        action.timingMode = .easeInEaseOut
                        sprite.run(action)
                        self.onNodeMoved?(id, newPos)
                    }
                }
            }
        }
    }
}
