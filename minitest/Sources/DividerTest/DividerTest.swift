import SwiftUI
import AppKit

// ============================================================
// MINIMAL TEST: Resizable Divider in SwiftUI
// ============================================================
// This tests if a divider can be dragged left/right to resize
// two adjacent frames (left panel and right panel).

struct DividerTestView: View {
    // Layout constants
    private let minLeftWidth: CGFloat = 200
    private let minRightWidth: CGFloat = 200
    private let dividerWidth: CGFloat = 20  // Hit area
    private let defaultLeftWidth: CGFloat = 400

    // State
    @State private var leftPanelWidth: CGFloat = 400
    @State private var isDragging: Bool = false
    @State private var isHovering: Bool = false

    var body: some View {
        GeometryReader { geometry in
            let totalWidth = geometry.size.width
            let maxLeftWidth = totalWidth - minRightWidth - dividerWidth
            let effectiveLeftWidth = max(minLeftWidth, min(maxLeftWidth, leftPanelWidth))
            let rightPanelWidth = totalWidth - effectiveLeftWidth - dividerWidth

            HStack(spacing: 0) {
                // LEFT PANEL
                VStack {
                    Text("LEFT PANEL")
                        .font(.title)
                        .bold()
                    Text("\(Int(effectiveLeftWidth))px")
                        .foregroundStyle(.secondary)
                    Rectangle()
                        .fill(Color.blue.opacity(0.2))
                        .overlay(
                            Text(" resizable")
                                .foregroundStyle(.blue)
                        )
                }
                .frame(width: effectiveLeftWidth)
                .background(Color.gray.opacity(0.1))

                // DRAGGABLE DIVIDER
                dividerView
                    .frame(width: dividerWidth)
                    .background(Color.yellow.opacity(0.3))
                    .overlay(
                        Text("↔")
                            .foregroundStyle(isDragging ? .red : .primary)
                    )

                // RIGHT PANEL
                VStack {
                    Text("RIGHT PANEL")
                        .font(.title)
                        .bold()
                    Text("\(Int(rightPanelWidth))px")
                        .foregroundStyle(.secondary)
                    Rectangle()
                        .fill(Color.green.opacity(0.2))
                        .overlay(
                            Text(" resizable")
                                .foregroundStyle(.green)
                        )
                }
                .frame(width: rightPanelWidth)
                .background(Color.gray.opacity(0.1))
            }
        }
        .frame(height: 400)
        .padding()
        .onAppear {
            leftPanelWidth = defaultLeftWidth
        }
    }

    // MARK: - Divider View
    private var dividerView: some View {
        ZStack {
            // Visible line
            Rectangle()
                .fill(isDragging ? Color.red : Color.gray)
                .frame(width: isDragging ? 4 : 2)

            // Grip dots
            if isHovering || isDragging {
                VStack(spacing: 6) {
                    ForEach(0..<5, id: \.self) { _ in
                        Circle()
                            .fill(Color.black)
                            .frame(width: 4, height: 4)
                    }
                }
            }

            // DEBUG: Invisible hit testing layer
            Color.clear
        }
        .frame(width: dividerWidth)
        .onHover { hovering in
            isHovering = hovering
            if hovering {
                NSCursor.resizeLeftRight.push()
                print("DEBUG: Hover START")
            } else {
                NSCursor.pop()
                print("DEBUG: Hover END")
            }
        }
        .gesture(
            DragGesture(minimumDistance: 1, coordinateSpace: .local)
                .onChanged { value in
                    print("DEBUG: Drag changed - translation: \(value.translation.width)")
                    if !isDragging {
                        isDragging = true
                        print("DEBUG: Drag START")
                    }
                    let delta = value.translation.width
                    let newWidth = leftPanelWidth + delta
                    let maxW = CGFloat(600)
                    leftPanelWidth = max(minLeftWidth, min(maxW, newWidth))
                    print("DEBUG: New width: \(leftPanelWidth)")
                }
                .onEnded { value in
                    isDragging = false
                    print("DEBUG: Drag END - final translation: \(value.translation.width)")
                }
        )
    }
}

// ============================================================
// TEST APP ENTRY POINT
// ============================================================
@main
struct DividerTestApp: App {
    var body: some Scene {
        WindowGroup {
            DividerTestView()
                .frame(minWidth: 800, minHeight: 500)
        }
        .windowStyle(.hiddenTitleBar)
    }
}

// ============================================================
// COMPILATION TEST
// ============================================================
// Compile with: swiftc -o DividerTest DividerTest.swift
// Or run as Swift Package
