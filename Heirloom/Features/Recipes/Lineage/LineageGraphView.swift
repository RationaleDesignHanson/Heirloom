import SwiftUI

/// Interactive graph visualization of recipe lineage
struct LineageGraphView: View {
    let tree: LineageTree
    let onTapNode: (Recipe) -> Void

    @State private var layoutAlgorithm: LineageLayoutAlgorithm = .hierarchical
    @State private var scale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var nodePositions: [UUID: CGPoint] = [:]
    @State private var selectedNodeID: UUID?

    private let nodeRadius: CGFloat = 40

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background
                Color.white
                    .ignoresSafeArea()

                // Graph canvas
                Canvas { context, size in
                    // Apply transformations
                    context.translateBy(x: offset.width, y: offset.height)
                    context.scaleBy(x: scale, y: scale)

                    // Draw edges first (so they appear behind nodes)
                    drawEdges(context: context, size: size)

                    // Draw nodes
                    drawNodes(context: context, size: size)
                }
                .gesture(
                    SimultaneousGesture(
                        MagnificationGesture()
                            .onChanged { value in
                                scale = min(max(value, 0.5), 3.0)
                            },
                        DragGesture()
                            .onChanged { value in
                                offset = CGSize(
                                    width: offset.width + value.translation.width,
                                    height: offset.height + value.translation.height
                                )
                            }
                    )
                )

                // Controls overlay
                VStack {
                    HStack {
                        Spacer()
                        controlsMenu
                    }
                    Spacer()
                }
                .padding()

                // Stats overlay
                VStack {
                    Spacer()
                    statsCard
                }
                .padding()
            }
            .onAppear {
                calculateLayout(in: geometry.size)
            }
            .onChange(of: layoutAlgorithm) { _, _ in
                calculateLayout(in: geometry.size)
            }
        }
    }

    // MARK: - Controls Menu

    private var controlsMenu: some View {
        Menu {
            Picker("Layout", selection: $layoutAlgorithm) {
                ForEach([LineageLayoutAlgorithm.hierarchical, .timeline, .force], id: \.self) { algorithm in
                    Label(algorithm.displayName, systemImage: algorithm.icon)
                        .tag(algorithm)
                }
            }

            Divider()

            Button {
                withAnimation(.spring()) {
                    scale = 1.0
                    offset = .zero
                }
            } label: {
                Label("Reset View", systemImage: "arrow.counterclockwise")
            }
        } label: {
            Image(systemName: "slider.horizontal.3")
                .font(.system(size: 20))
                .foregroundStyle(HeirloomColors.tomato)
                .padding(12)
                .background(Circle().fill(.white).shadow(radius: 5))
        }
    }

    // MARK: - Stats Card

    private var statsCard: some View {
        VStack(alignment: .leading, spacing: HeirloomSpacing.xs) {
            Text(tree.stats.displaySummary)
                .font(HeirloomFonts.caption1)
                .foregroundStyle(HeirloomColors.primaryText)

            if let selectedNode = tree.nodes.first(where: { $0.recipe.id == selectedNodeID }) {
                Divider()

                Text(selectedNode.recipe.title)
                    .font(HeirloomFonts.bodyBold)
                    .foregroundStyle(HeirloomColors.primaryText)
                    .lineLimit(1)

                Text(selectedNode.generationBadge)
                    .font(HeirloomFonts.caption2)
                    .foregroundStyle(selectedNode.generationColor)

                Text(selectedNode.stats.displayStats)
                    .font(HeirloomFonts.caption2)
                    .foregroundStyle(HeirloomColors.secondaryText)
            }
        }
        .padding(HeirloomSpacing.md)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.white)
                .shadow(color: .black.opacity(0.1), radius: 10, y: 5)
        )
    }

    // MARK: - Drawing

    private func drawEdges(context: GraphicsContext, size: CGSize) {
        for edge in tree.edges {
            guard let fromPos = nodePositions[edge.fromID],
                  let toPos = nodePositions[edge.toID] else {
                continue
            }

            // Draw line
            var path = Path()
            path.move(to: fromPos)
            path.addLine(to: toPos)

            context.stroke(
                path,
                with: .color(edge.edgeType.color.opacity(0.5)),
                lineWidth: 2
            )

            // Draw arrow
            drawArrow(context: context, from: fromPos, to: toPos, color: edge.edgeType.color)
        }
    }

    private func drawArrow(context: GraphicsContext, from: CGPoint, to: CGPoint, color: Color) {
        let arrowSize: CGFloat = 8

        // Calculate arrow position (slightly before the target node)
        let dx = to.x - from.x
        let dy = to.y - from.y
        let distance = sqrt(dx * dx + dy * dy)

        guard distance > 0 else { return }

        let ratio = (distance - nodeRadius - 5) / distance
        let arrowPos = CGPoint(
            x: from.x + dx * ratio,
            y: from.y + dy * ratio
        )

        // Calculate arrow angle
        let angle = atan2(dy, dx)

        // Draw arrowhead
        var arrowPath = Path()
        arrowPath.move(to: arrowPos)
        arrowPath.addLine(to: CGPoint(
            x: arrowPos.x - arrowSize * cos(angle - .pi / 6),
            y: arrowPos.y - arrowSize * sin(angle - .pi / 6)
        ))
        arrowPath.move(to: arrowPos)
        arrowPath.addLine(to: CGPoint(
            x: arrowPos.x - arrowSize * cos(angle + .pi / 6),
            y: arrowPos.y - arrowSize * sin(angle + .pi / 6)
        ))

        context.stroke(arrowPath, with: .color(color.opacity(0.7)), lineWidth: 2)
    }

    private func drawNodes(context: GraphicsContext, size: CGSize) {
        for node in tree.nodes {
            guard let position = nodePositions[node.recipe.id] else { continue }

            let isSelected = node.recipe.id == selectedNodeID

            // Draw node circle
            let circlePath = Path(ellipseIn: CGRect(
                x: position.x - nodeRadius,
                y: position.y - nodeRadius,
                width: nodeRadius * 2,
                height: nodeRadius * 2
            ))

            // Fill
            context.fill(
                circlePath,
                with: .color(node.generationColor.opacity(isSelected ? 1.0 : 0.8))
            )

            // Border
            context.stroke(
                circlePath,
                with: .color(isSelected ? HeirloomColors.charcoal : .white),
                lineWidth: isSelected ? 3 : 2
            )

            // Draw generation badge
            let badgeText = Text(node.generationBadge)
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(.white)

            context.draw(badgeText, at: position)

            // Draw title below node
            if scale > 0.7 {
                let titleText = Text(node.displayLabel)
                    .font(.system(size: 11))
                    .foregroundColor(HeirloomColors.charcoal)
                    .lineLimit(2)

                context.draw(
                    titleText,
                    at: CGPoint(x: position.x, y: position.y + nodeRadius + 15)
                )
            }
        }
    }

    // MARK: - Layout Calculation

    private func calculateLayout(in size: CGSize) {
        switch layoutAlgorithm {
        case .hierarchical:
            nodePositions = LineageLayoutEngine.hierarchicalLayout(tree: tree, in: size)
        case .timeline:
            nodePositions = LineageLayoutEngine.timelineLayout(tree: tree, in: size)
        case .force:
            nodePositions = LineageLayoutEngine.hierarchicalLayout(tree: tree, in: size) // Fallback
        }
    }
}

// MARK: - Preview

#Preview {
    // Create sample tree
    let rootRecipe = Recipe(title: "Original Chocolate Chip Cookies", sourceType: .manual)
    rootRecipe.provenance = ProvenanceMetadata(
        sourceType: .userCreated,
        generation: 0
    )

    let child1 = Recipe(title: "Mom's Variation", sourceType: .family)
    child1.provenance = ProvenanceMetadata(
        sourceType: .shared,
        generation: 1
    )

    let child2 = Recipe(title: "Gluten-Free Version", sourceType: .family)
    child2.provenance = ProvenanceMetadata(
        sourceType: .shared,
        generation: 1
    )

    let grandchild = Recipe(title: "Vegan Adaptation", sourceType: .family)
    grandchild.provenance = ProvenanceMetadata(
        sourceType: .shared,
        generation: 2
    )

    let nodes = [
        LineageNode(
            recipe: rootRecipe,
            generation: 0,
            position: .zero,
            stats: NodeStats(cookCount: 42, shareCount: 15, viewCount: 250, rating: 4.8),
            isCurrentUser: false
        ),
        LineageNode(
            recipe: child1,
            generation: 1,
            position: .zero,
            stats: NodeStats(cookCount: 23, shareCount: 8, viewCount: 120, rating: 4.5),
            isCurrentUser: true
        ),
        LineageNode(
            recipe: child2,
            generation: 1,
            position: .zero,
            stats: NodeStats(cookCount: 15, shareCount: 5, viewCount: 89, rating: 4.3),
            isCurrentUser: false
        ),
        LineageNode(
            recipe: grandchild,
            generation: 2,
            position: .zero,
            stats: NodeStats(cookCount: 8, shareCount: 2, viewCount: 45, rating: 4.0),
            isCurrentUser: false
        )
    ]

    let edges = [
        LineageEdge(fromID: rootRecipe.id, toID: child1.id, label: "Forked", createdAt: Date()),
        LineageEdge(fromID: rootRecipe.id, toID: child2.id, label: "Adapted", createdAt: Date()),
        LineageEdge(fromID: child1.id, toID: grandchild.id, label: "Remixed", createdAt: Date())
    ]

    let tree = LineageTree(root: rootRecipe, nodes: nodes, edges: edges)

    return NavigationStack {
        LineageGraphView(tree: tree) { recipe in
            print("Tapped: \(recipe.title)")
        }
        .navigationTitle("Recipe Lineage")
        .navigationBarTitleDisplayMode(.inline)
    }
}
