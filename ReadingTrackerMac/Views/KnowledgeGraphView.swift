import SwiftUI
import SwiftData
import SpriteKit

struct KnowledgeGraphView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var nodes: [ConceptNode]
    @Query private var links: [ConceptLink]
    @Query private var memos: [GeneralMemo]
    
    @State private var selectedNode: ConceptNode?
    @State private var isEditing = false
    @State private var searchText = ""
    @State private var isLinkMode = false
    
    var body: some View {
        HStack(spacing: 0) {
            ZStack(alignment: .top) {
                GraphSpriteView(
                    nodes: nodes,
                    links: links,
                    searchText: searchText,
                    isLinkMode: isLinkMode,
                    onNodeSelected: { id in
                        selectedNode = nodes.first(where: { $0.id == id })
                        isEditing = false
                    },
                    onNodeMoved: { id, position in
                        if let node = nodes.first(where: { $0.id == id }) {
                            node.x = position.x
                            node.y = position.y
                            try? modelContext.save()
                        }
                    },
                    onLinkCreated: { srcId, tgtId in
                        if let src = nodes.first(where: { $0.id == srcId }),
                           let tgt = nodes.first(where: { $0.id == tgtId }),
                           srcId != tgtId {
                            let link = ConceptLink(source: src, target: tgt)
                            modelContext.insert(link)
                            try? modelContext.save()
                        }
                    }
                )
                .ignoresSafeArea()
                
                // Overlay controls
                HStack {
                    Button(action: addNode) {
                        Label("New Concept", systemImage: "plus")
                    }
                    .buttonStyle(.borderedProminent)
                    
                    Toggle(isOn: $isLinkMode) {
                        Image(systemName: "link")
                    }
                    .toggleStyle(.button)
                    
                    Spacer()
                    
                    Button(role: .destructive, action: deleteAllNodes) {
                        Image(systemName: "trash.fill")
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
                                Button("Edit") { isEditing = true }
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
                            
                            TextEditor(text: Binding(
                                get: { node.content },
                                set: { node.content = $0 }
                            ))
                            .font(.system(.body, design: .monospaced))
                            .padding(.horizontal)
                            
                        } else {
                            Text(node.title.isEmpty ? "Untitled Concept" : node.title)
                                .font(.largeTitle.bold())
                                .foregroundColor(node.title.isEmpty ? .secondary : .primary)
                                .padding(.horizontal)
                                
                            Divider().padding(.vertical, 8)
                            
                            ScrollView {
                                VStack(alignment: .leading) {
                                    if let attrStr = try? AttributedString(markdown: node.content, options: AttributedString.MarkdownParsingOptions(interpretedSyntax: .full)) {
                                        Text(attrStr)
                                            .font(.body)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                    } else {
                                        Text(node.content)
                                            .font(.body)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                    }
                                }
                                .padding(.horizontal)
                                
                                VStack(alignment: .leading, spacing: 8) {
                                    if !node.linksOut.isEmpty || !node.linksIn.isEmpty {
                                        Text("Connections")
                                            .font(.headline)
                                            .padding(.top, 16)
                                            .padding(.bottom, 4)
                                    }
                                    
                                    ForEach(node.linksOut.filter { $0.modelContext != nil && !$0.isDeleted }) { link in
                                        if let target = link.target, target.modelContext != nil, !target.isDeleted {
                                            HStack {
                                                Image(systemName: "arrow.right.circle.fill").foregroundColor(.secondary)
                                                Text(target.title.isEmpty ? "Untitled Concept" : target.title)
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
                                        if let source = link.source, source.modelContext != nil, !source.isDeleted {
                                            HStack {
                                                Image(systemName: "arrow.left.circle.fill").foregroundColor(.secondary)
                                                Text(source.title.isEmpty ? "Untitled Concept" : source.title)
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
                    .frame(width: 350)
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
                        
                        Text("Knowledge Graph")
                            .font(.headline)
                            .padding(.top, 16)
                    }
                    .padding()
                    .frame(width: 350)
                }
            }
            .frame(maxHeight: .infinity)
            .background(Color(NSColor.controlBackgroundColor))
        }
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
            modelContext.delete(node)
            try? modelContext.save()
            selectedNode = nil
        }
    }
    
    private func deleteAllNodes() {
        for node in nodes { modelContext.delete(node) }
        for link in links { modelContext.delete(link) }
        try? modelContext.save()
        selectedNode = nil
    }
}

// MARK: - SpriteKit Integration

struct GraphNodeData {
    let id: UUID
    let title: String
    let content: String
    var x: Double
    var y: Double
}

struct GraphLinkData {
    let sourceId: UUID
    let targetId: UUID
}

struct GraphSpriteView: NSViewRepresentable {
    var nodes: [ConceptNode]
    var links: [ConceptLink]
    var searchText: String
    var isLinkMode: Bool
    
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
        view.presentScene(scene)
        
        updateSceneData(scene)
        return view
    }
    
    func updateNSView(_ nsView: SKView, context: Context) {
        if let scene = nsView.scene as? GraphScene {
            updateSceneData(scene)
        }
    }
    
    private func updateSceneData(_ scene: GraphScene) {
        let nodeData = nodes.compactMap { node -> GraphNodeData? in
            guard node.modelContext != nil, !node.isDeleted else { return nil }
            return GraphNodeData(id: node.id, title: node.title, content: node.content, x: node.x, y: node.y)
        }
        
        let linkData = links.compactMap { link -> GraphLinkData? in
            guard link.modelContext != nil, !link.isDeleted else { return nil }
            guard let src = link.source, src.modelContext != nil, !src.isDeleted else { return nil }
            guard let tgt = link.target, tgt.modelContext != nil, !tgt.isDeleted else { return nil }
            
            return GraphLinkData(sourceId: src.id, targetId: tgt.id)
        }
        
        scene.updateData(nodes: nodeData, links: linkData, searchText: searchText, isLinkMode: isLinkMode)
    }
}

class GraphScene: SKScene {
    var onNodeSelected: ((UUID) -> Void)?
    var onNodeMoved: ((UUID, CGPoint) -> Void)?
    var onLinkCreated: ((UUID, UUID) -> Void)?
    
    var draggedNodes: Set<UUID> = []
    
    private var nodeSprites: [UUID: SKNode] = [:]
    private var linkLines: [SKShapeNode] = []
    
    private var _nodes: [GraphNodeData] = []
    private var _links: [GraphLinkData] = []
    
    private var dragTarget: SKNode?
    private var isLinking: Bool = false
    private var tempLinkLine: SKShapeNode?
    
    let cameraNode = SKCameraNode()
    
    override func didMove(to view: SKView) {
        self.backgroundColor = NSColor.black
        self.physicsWorld.gravity = .zero
        self.camera = cameraNode
        self.addChild(cameraNode)
    }
    
    func updateData(nodes: [GraphNodeData], links: [GraphLinkData], searchText: String, isLinkMode: Bool) {
        self._nodes = nodes
        self._links = links
        self.isLinking = isLinkMode
        
        let newIds = Set(nodes.map { $0.id })
        for (id, sprite) in nodeSprites {
            if !newIds.contains(id) {
                sprite.removeFromParent()
                nodeSprites.removeValue(forKey: id)
            }
        }
        
        for node in nodes {
            let isMatch = !searchText.isEmpty && (node.title.localizedCaseInsensitiveContains(searchText) || node.content.localizedCaseInsensitiveContains(searchText))
            let isDimmed = !searchText.isEmpty && !isMatch
            
            if let sprite = nodeSprites[node.id] {
                // If it exists, just ensure it's at the right spot if it wasn't being dragged
                if sprite != dragTarget && !draggedNodes.contains(node.id) {
                    sprite.position = CGPoint(x: node.x == 0 ? frame.midX : node.x, y: node.y == 0 ? frame.midY : node.y)
                }
                
                if let dot = sprite.childNode(withName: "dot") as? SKShapeNode {
                    dot.fillColor = isMatch ? .yellow : (isDimmed ? .darkGray : .white)
                    dot.xScale = isMatch ? 1.5 : 1.0
                    dot.yScale = isMatch ? 1.5 : 1.0
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
                dot.fillColor = isMatch ? .yellow : (isDimmed ? .darkGray : .white)
                dot.xScale = isMatch ? 1.5 : 1.0
                dot.yScale = isMatch ? 1.5 : 1.0
                dot.strokeColor = .clear
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
        for line in linkLines { line.removeFromParent() }
        linkLines.removeAll()
        
        for link in _links {
            guard let n1 = nodeSprites[link.sourceId], let n2 = nodeSprites[link.targetId] else { continue }
            
            let path = CGMutablePath()
            path.move(to: n1.position)
            path.addLine(to: n2.position)
            
            let line = SKShapeNode(path: path)
            line.strokeColor = NSColor.systemGray.withAlphaComponent(0.5)
            line.lineWidth = 1
            line.zPosition = -1
            addChild(line)
            linkLines.append(line)
        }
    }
    
    private func getConnectedComponent(for nodeId: UUID) -> Set<UUID> {
        var visited = Set<UUID>()
        var queue = [nodeId]
        visited.insert(nodeId)
        
        while !queue.isEmpty {
            let current = queue.removeFirst()
            for link in _links {
                let fromId = link.sourceId
                let toId = link.targetId
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
                    draggedNodes = getConnectedComponent(for: draggedId)
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
                        dot.fillColor = .cyan
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
                            onNodeMoved?(id, sprite.position)
                        }
                    }
                } else {
                    target.position = location
                    if let uuidString = target.name, let id = UUID(uuidString: uuidString) {
                        onNodeMoved?(id, location)
                    }
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
        let zoomMultiplier: CGFloat = 1.0 + (event.scrollingDeltaY * -0.01)
        var newScale = camera.xScale * zoomMultiplier
        newScale = max(0.2, min(newScale, 5.0))
        camera.setScale(newScale)
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
                if let uuid = UUID(uuidString: target.name ?? "") {
                    onNodeMoved?(uuid, target.position)
                }
            }
        }
        
        dragTarget = nil
        draggedNodes.removeAll()
        // don't reset isLinking here because it's bound to the toggle state
    }
}
