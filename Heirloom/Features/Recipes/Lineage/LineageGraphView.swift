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
    @State private var lastDragValue: CGSize = .zero

    private let nodeCardWidth: CGFloat = 110
    private let nodeCardHeight: CGFloat = 90

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                HeirloomColors.appBackground
                    .ignoresSafeArea()

                // Canvas for edges only
                Canvas { context, size in
                    context.translateBy(x: offset.width, y: offset.height)
                    context.scaleBy(x: scale, y: scale)
                    drawEdges(context: context, size: size)
                }

                // SwiftUI node cards overlay
                ForEach(tree.nodes, id: \.id) { node in
                    if let pos = nodePositions[node.recipe.id] {
                        LineageNodeCard(
                            node: node,
                            isSelected: node.recipe.id == selectedNodeID
                        )
                        .position(
                            x: pos.x * scale + offset.width,
                            y: pos.y * scale + offset.height
                        )
                        .onTapGesture {
                            withAnimation(.spring(response: 0.3)) {
                                selectedNodeID = node.recipe.id
                            }
                            onTapNode(node.recipe)
                        }
                    }
                }

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
            .contentShape(Rectangle())
            .gesture(
                SimultaneousGesture(
                    MagnificationGesture()
                        .onChanged { value in
                            scale = min(max(value, 0.5), 3.0)
                        },
                    DragGesture()
                        .onChanged { value in
                            offset = CGSize(
                                width: lastDragValue.width + value.translation.width,
                                height: lastDragValue.height + value.translation.height
                            )
                        }
                        .onEnded { _ in
                            lastDragValue = offset
                        }
                )
            )
            .onAppear {
                calculateLayout(in: geometry.size)
            }
            .onChange(of: layoutAlgorithm) { _, _ in
                withAnimation(.spring(response: 0.4)) {
                    calculateLayout(in: geometry.size)
                }
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
                    lastDragValue = .zero
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

                HStack(spacing: HeirloomSpacing.sm) {
                    AsyncRecipeImage(
                        imageFileName: selectedNode.recipe.imageFileName,
                        firebaseImageURL: selectedNode.recipe.firebaseImageURL,
                        placeholder: selectedNode.recipe.sourceType?.iconName ?? "fork.knife"
                    )
                    .frame(width: 40, height: 40)
                    .clipShape(RoundedRectangle(cornerRadius: 6))

                    VStack(alignment: .leading, spacing: 2) {
                        Text(selectedNode.recipe.title)
                            .font(HeirloomFonts.bodyBold)
                            .foregroundStyle(HeirloomColors.primaryText)
                            .lineLimit(1)

                        Text(selectedNode.generationBadge)
                            .font(HeirloomFonts.caption2)
                            .foregroundStyle(selectedNode.generationColor)
                    }
                }

                if let contributor = selectedNode.contributor {
                    HStack(spacing: HeirloomSpacing.xs) {
                        Image(systemName: "person.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(HeirloomColors.secondaryText)
                        Text(contributor.displayName)
                            .font(HeirloomFonts.caption2)
                            .foregroundStyle(HeirloomColors.secondaryText)
                    }
                }

                Text(selectedNode.stats.displayStats)
                    .font(HeirloomFonts.caption2)
                    .foregroundStyle(HeirloomColors.secondaryText)
            }
        }
        .padding(HeirloomSpacing.md)
        .background(
            RoundedRectangle(cornerRadius: HeirloomSpacing.cardCornerRadius)
                .fill(.white)
                .shadow(color: .black.opacity(0.1), radius: 10, y: 5)
        )
    }

    // MARK: - Edge Drawing

    private func drawEdges(context: GraphicsContext, size: CGSize) {
        for edge in tree.edges {
            guard let fromPos = nodePositions[edge.fromID],
                  let toPos = nodePositions[edge.toID] else {
                continue
            }

            // Draw curved line
            var path = Path()
            path.move(to: fromPos)

            // Use a quadratic curve for nicer visual
            let midY = (fromPos.y + toPos.y) / 2
            path.addCurve(
                to: toPos,
                control1: CGPoint(x: fromPos.x, y: midY),
                control2: CGPoint(x: toPos.x, y: midY)
            )

            context.stroke(
                path,
                with: .color(edge.edgeType.color.opacity(0.4)),
                lineWidth: 2.5
            )

            // Draw arrow near target
            drawArrow(context: context, from: fromPos, to: toPos, color: edge.edgeType.color)
        }
    }

    private func drawArrow(context: GraphicsContext, from: CGPoint, to: CGPoint, color: Color) {
        let arrowSize: CGFloat = 8
        let dx = to.x - from.x
        let dy = to.y - from.y
        let distance = sqrt(dx * dx + dy * dy)

        guard distance > 0 else { return }

        // Stop arrow before the node card edge
        let stopDistance = nodeCardHeight / 2 + 5
        let ratio = (distance - stopDistance) / distance
        let arrowPos = CGPoint(
            x: from.x + dx * ratio,
            y: from.y + dy * ratio
        )

        let angle = atan2(dy, dx)

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

        context.stroke(arrowPath, with: .color(color.opacity(0.6)), lineWidth: 2)
    }

    // MARK: - Layout Calculation

    private func calculateLayout(in size: CGSize) {
        switch layoutAlgorithm {
        case .hierarchical:
            nodePositions = LineageLayoutEngine.hierarchicalLayout(tree: tree, in: size)
        case .timeline:
            nodePositions = LineageLayoutEngine.timelineLayout(tree: tree, in: size)
        case .force:
            nodePositions = LineageLayoutEngine.hierarchicalLayout(tree: tree, in: size)
        }
    }
}

// MARK: - Node Card View

private struct LineageNodeCard: View {
    let node: LineageNode
    let isSelected: Bool

    var body: some View {
        VStack(spacing: 4) {
            // Recipe image or contributor initials
            AsyncRecipeImage(
                imageFileName: node.recipe.imageFileName,
                firebaseImageURL: node.recipe.firebaseImageURL,
                placeholder: node.recipe.sourceType?.iconName ?? "fork.knife"
            )
            .frame(width: 32, height: 32)
            .clipShape(RoundedRectangle(cornerRadius: 6))

            // Recipe title
            Text(node.recipe.title)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(HeirloomColors.primaryText)
                .lineLimit(1)
                .frame(maxWidth: .infinity)

            // Contributor name
            if let contributor = node.contributor {
                Text(contributor.displayName)
                    .font(.system(size: 9))
                    .foregroundStyle(HeirloomColors.secondaryText)
                    .lineLimit(1)
            }

            // Generation badge pill
            Text(node.generationBadge)
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(
                    Capsule().fill(node.generationColor)
                )
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .frame(width: 110)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(.white)
                .shadow(color: isSelected ? HeirloomColors.tomato.opacity(0.3) : .black.opacity(0.08), radius: isSelected ? 8 : 4, y: 2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(isSelected ? HeirloomColors.tomato : .clear, lineWidth: 2.5)
        )
    }
}

// MARK: - Preview

#Preview {
    let rootRecipe = Recipe(title: "Original Chocolate Chip Cookies", sourceType: .manual)
    let child1 = Recipe(title: "Mom's Variation", sourceType: .family)
    let child2 = Recipe(title: "Gluten-Free Version", sourceType: .family)
    let grandchild = Recipe(title: "Vegan Adaptation", sourceType: .family)

    let nodes = [
        LineageNode(
            recipe: rootRecipe,
            generation: 0,
            position: .zero,
            stats: NodeStats(cookCount: 42, shareCount: 15, viewCount: 250, rating: 4.8),
            isCurrentUser: false,
            contributor: nil
        ),
        LineageNode(
            recipe: child1,
            generation: 1,
            position: .zero,
            stats: NodeStats(cookCount: 23, shareCount: 8, viewCount: 120, rating: 4.5),
            isCurrentUser: true,
            contributor: nil
        ),
        LineageNode(
            recipe: child2,
            generation: 1,
            position: .zero,
            stats: NodeStats(cookCount: 15, shareCount: 5, viewCount: 89, rating: 4.3),
            isCurrentUser: false,
            contributor: nil
        ),
        LineageNode(
            recipe: grandchild,
            generation: 2,
            position: .zero,
            stats: NodeStats(cookCount: 8, shareCount: 2, viewCount: 45, rating: 4.0),
            isCurrentUser: false,
            contributor: nil
        )
    ]

    let edges = [
        LineageEdge(fromID: rootRecipe.id, toID: child1.id, label: "Forked", createdAt: Date()),
        LineageEdge(fromID: rootRecipe.id, toID: child2.id, label: "Adapted", createdAt: Date()),
        LineageEdge(fromID: child1.id, toID: grandchild.id, label: "Remixed", createdAt: Date())
    ]

    let tree = LineageTree(root: rootRecipe, nodes: nodes, edges: edges)

    NavigationStack {
        LineageGraphView(tree: tree) { recipe in
            Log.debug("Preview: Lineage graph recipe tapped", category: .ui, metadata: ["title": recipe.title])
        }
        .navigationTitle("Recipe Lineage")
        .navigationBarTitleDisplayMode(.inline)
    }
}
