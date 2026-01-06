//
//  CustomizationOverlayView.swift
//  Heirloom
//
//  Created by Claude on 1/5/26.
//

import SwiftUI

/// Renders all customizations above a recipe card
struct CustomizationOverlayView: View {
    // MARK: - Properties
    let customizations: [Customization]
    let cardSize: CGSize

    @Binding var selectedCustomization: Customization?

    let onMove: (Customization, CGPoint) -> Void
    let onResize: (Customization, CGSize) -> Void
    let onRotate: (Customization, Double) -> Void
    let onDelete: (Customization) -> Void

    // MARK: - Body
    var body: some View {
        ZStack {
            // Render customizations in z-index order
            ForEach(sortedCustomizations, id: \.id) { customization in
                CustomizationItemView(
                    customization: customization,
                    cardSize: cardSize,
                    isSelected: selectedCustomization?.id == customization.id
                )
                .onTapGesture {
                    selectedCustomization = customization
                }
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            let normalizedPosition = CGPoint(
                                x: value.location.x / cardSize.width,
                                y: value.location.y / cardSize.height
                            )
                            onMove(customization, normalizedPosition)
                        }
                )
            }
        }
        .overlay {
            // Selection handles
            if let selected = selectedCustomization {
                SelectionHandlesView(
                    customization: selected,
                    cardSize: cardSize,
                    onResize: { size in
                        onResize(selected, size)
                    },
                    onRotate: { angle in
                        onRotate(selected, angle)
                    },
                    onDelete: {
                        onDelete(selected)
                    }
                )
            }
        }
    }

    // MARK: - Computed Properties
    private var sortedCustomizations: [Customization] {
        customizations
            .filter { !$0.isDeleted }
            .sorted { $0.zIndex < $1.zIndex }
    }
}

// MARK: - Customization Item View

struct CustomizationItemView: View {
    let customization: Customization
    let cardSize: CGSize
    let isSelected: Bool

    var body: some View {
        Group {
            switch customization.content {
            case .sticker(let assetId, let tintColor):
                StickerView(assetId: assetId, tintColor: tintColor)

            case .drawing(let path, let strokeColor, let strokeWidth):
                DrawingView(path: path, strokeColor: strokeColor, strokeWidth: strokeWidth)

            case .text(let content, let font, let fontSize, let color):
                TextView(content: content, font: font, fontSize: fontSize, color: color)

            case .photo(let imageId, let opacity):
                PhotoView(imageId: imageId, opacity: opacity)

            case .shape(let shapeType, let fillColor, let strokeColor):
                ShapeView(shapeType: shapeType, fillColor: fillColor, strokeColor: strokeColor)
            }
        }
        .frame(
            width: customization.size.width * cardSize.width,
            height: customization.size.height * cardSize.height
        )
        .rotationEffect(.radians(customization.rotation))
        .position(
            x: customization.position.x * cardSize.width,
            y: customization.position.y * cardSize.height
        )
        .overlay {
            if isSelected {
                Rectangle()
                    .stroke(Color.blue, lineWidth: 2)
            }
        }
    }
}

// MARK: - Selection Handles View

struct SelectionHandlesView: View {
    let customization: Customization
    let cardSize: CGSize
    let onResize: (CGSize) -> Void
    let onRotate: (Double) -> Void
    let onDelete: () -> Void

    @State private var isDraggingHandle = false

    var body: some View {
        let position = CGPoint(
            x: customization.position.x * cardSize.width,
            y: customization.position.y * cardSize.height
        )
        let size = CGSize(
            width: customization.size.width * cardSize.width,
            height: customization.size.height * cardSize.height
        )

        ZStack {
            // Corner handles for resize
            ForEach([
                (CGPoint(x: -1, y: -1), "topLeft"),
                (CGPoint(x: 1, y: -1), "topRight"),
                (CGPoint(x: -1, y: 1), "bottomLeft"),
                (CGPoint(x: 1, y: 1), "bottomRight")
            ], id: \.1) { offset, id in
                Circle()
                    .fill(Color.blue)
                    .frame(width: 16, height: 16)
                    .position(
                        x: position.x + (size.width / 2) * offset.x,
                        y: position.y + (size.height / 2) * offset.y
                    )
                    .gesture(
                        DragGesture()
                            .onChanged { _ in
                                isDraggingHandle = true
                            }
                            .onEnded { _ in
                                isDraggingHandle = false
                            }
                    )
            }

            // Delete button
            Button(action: onDelete) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.red)
                    .background(Circle().fill(Color.white))
            }
            .position(
                x: position.x + size.width / 2 + 20,
                y: position.y - size.height / 2 - 20
            )

            // Rotation handle
            Circle()
                .fill(Color.green)
                .frame(width: 16, height: 16)
                .position(
                    x: position.x,
                    y: position.y - size.height / 2 - 30
                )
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            let center = position
                            let angle = atan2(
                                value.location.y - center.y,
                                value.location.x - center.x
                            )
                            onRotate(Double(angle))
                        }
                )
        }
    }
}

// MARK: - Content Type Views

struct StickerView: View {
    let assetId: String
    let tintColor: String?

    var body: some View {
        // TODO: Load sticker from asset catalog
        Image(systemName: "star.fill")
            .resizable()
            .foregroundColor(tintColor.flatMap { Color(hex: $0) } ?? .primary)
    }
}

struct DrawingView: View {
    let path: DrawingPath
    let strokeColor: String
    let strokeWidth: Double

    var body: some View {
        Path { p in
            let points = path.cgPoints
            guard !points.isEmpty else { return }

            p.move(to: points[0])
            for point in points.dropFirst() {
                p.addLine(to: point)
            }
        }
        .stroke(Color(hex: strokeColor), lineWidth: strokeWidth)
    }
}

struct TextView: View {
    let content: String
    let font: String
    let fontSize: Double
    let color: String

    var body: some View {
        Text(content)
            .font(.system(size: fontSize))
            .foregroundColor(Color(hex: color))
    }
}

struct PhotoView: View {
    let imageId: UUID
    let opacity: Double

    var body: some View {
        // TODO: Load photo from ImageStorageService
        Rectangle()
            .fill(Color.gray)
            .opacity(opacity)
            .overlay {
                Text("Photo")
                    .foregroundColor(.white)
            }
    }
}

struct ShapeView: View {
    let shapeType: ShapeType
    let fillColor: String
    let strokeColor: String

    var body: some View {
        Group {
            switch shapeType {
            case .heart:
                HeartShape()
                    .fill(Color(hex: fillColor))
                    .overlay {
                        HeartShape()
                            .stroke(Color(hex: strokeColor), lineWidth: 2)
                    }
            case .star:
                StarShape()
                    .fill(Color(hex: fillColor))
                    .overlay {
                        StarShape()
                            .stroke(Color(hex: strokeColor), lineWidth: 2)
                    }
            case .circle:
                Circle()
                    .fill(Color(hex: fillColor))
                    .overlay {
                        Circle()
                            .stroke(Color(hex: strokeColor), lineWidth: 2)
                    }
            case .rectangle:
                Rectangle()
                    .fill(Color(hex: fillColor))
                    .overlay {
                        Rectangle()
                            .stroke(Color(hex: strokeColor), lineWidth: 2)
                    }
            case .arrow:
                ArrowShape()
                    .fill(Color(hex: fillColor))
                    .overlay {
                        ArrowShape()
                            .stroke(Color(hex: strokeColor), lineWidth: 2)
                    }
            }
        }
    }
}

// MARK: - Shape Definitions

struct HeartShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let width = rect.width
        let height = rect.height

        path.move(to: CGPoint(x: width / 2, y: height))
        path.addCurve(
            to: CGPoint(x: 0, y: height / 4),
            control1: CGPoint(x: width / 2, y: height * 0.75),
            control2: CGPoint(x: 0, y: height / 2)
        )
        path.addArc(
            center: CGPoint(x: width / 4, y: height / 4),
            radius: width / 4,
            startAngle: .degrees(180),
            endAngle: .degrees(0),
            clockwise: false
        )
        path.addArc(
            center: CGPoint(x: width * 3 / 4, y: height / 4),
            radius: width / 4,
            startAngle: .degrees(180),
            endAngle: .degrees(0),
            clockwise: false
        )
        path.addCurve(
            to: CGPoint(x: width / 2, y: height),
            control1: CGPoint(x: width, y: height / 2),
            control2: CGPoint(x: width / 2, y: height * 0.75)
        )

        return path
    }
}

struct StarShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2

        for i in 0..<5 {
            let angle = (CGFloat(i) * 2 * .pi / 5) - .pi / 2
            let point = CGPoint(
                x: center.x + radius * CGFloat(cos(angle)),
                y: center.y + radius * CGFloat(sin(angle))
            )
            if i == 0 {
                path.move(to: point)
            } else {
                path.addLine(to: point)
            }
        }
        path.closeSubpath()

        return path
    }
}

struct ArrowShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let width = rect.width
        let height = rect.height

        path.move(to: CGPoint(x: 0, y: height / 2))
        path.addLine(to: CGPoint(x: width * 0.7, y: height / 2))
        path.addLine(to: CGPoint(x: width * 0.7, y: 0))
        path.addLine(to: CGPoint(x: width, y: height / 2))
        path.addLine(to: CGPoint(x: width * 0.7, y: height))
        path.addLine(to: CGPoint(x: width * 0.7, y: height / 2))

        return path
    }
}

// MARK: - Color Extension

