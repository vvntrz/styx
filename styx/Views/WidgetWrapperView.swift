import SwiftUI

struct WidgetWrapperView_Refined: View {
    @StateObject var widget: WidgetModel
    @StateObject var delegate: AppDelegate
    let isEditable: Bool
    let parentSize: CGSize
    let scale: CGFloat

    @State private var initialRect: CGRect? = nil
    @GestureState private var dragOffset: CGSize = .zero
    
    private let gridSize: CGFloat = 200.0


    private func snap(_ value: CGFloat) -> CGFloat {
        guard delegate.isSnappingEnabled else { return value }
        return round(value / gridSize) * gridSize
    }

    var body: some View {
        let width = widget.config.width
        let height = widget.config.height
        let currentPos = RootOverlay.calculatePoint(screen: parentSize, widget: widget)

        ZStack {
            if (widget.config.doShow ?? true) {
                StyxWebView(widget: widget)
                    .allowsHitTesting(!isEditable)
            }

            if isEditable && (widget.config.doShow ?? true) {
                RoundedRectangle(cornerRadius: 4)
                    .stroke(Color.blue, lineWidth: 2)
                    .background(Color.blue.opacity(0.05))
                
                Color.white.opacity(0.001)
                    .gesture(
                        DragGesture(coordinateSpace: .global)
                            .updating($dragOffset) { value, state, _ in
                                state = CGSize(
                                    width: value.translation.width / scale,
                                    height: value.translation.height / scale
                                )
                            }
                            .onEnded { value in
                                let deltaX = value.translation.width / scale
                                let deltaY = value.translation.height / scale
                                
                                let finalCenterX = currentPos.x + deltaX
                                let finalCenterY = currentPos.y + deltaY
                                
                                // Snap top-left corner
                                let newX = snap(finalCenterX - (width / 2))
                                let newY = snap(finalCenterY - (height / 2))
                                
                                widget.config.x = newX
                                widget.config.y = newY
                                widget.config.position = .custom
                            }
                    )

                // Resize Handle
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Circle()
                            .fill(Color.blue)
                            .frame(width: 12, height: 12)
                            .overlay(Circle().stroke(Color.white, lineWidth: 2))
                            .padding(4)
                            .contentShape(Rectangle())
                            .gesture(
                                DragGesture()
                                    .onChanged { value in
                                        if initialRect == nil {
                                            initialRect = CGRect(x: 0, y: 0, width: width, height: height)
                                        }
                                        guard let start = initialRect else { return }

                                        let newW = snap(max(50, start.width + value.translation.width / scale))
                                        let newH = snap(max(50, start.height + value.translation.height / scale))

                                        widget.config.width = newW
                                        widget.config.height = newH
                                    }
                                    .onEnded { _ in initialRect = nil }
                            )
                    }
                }
            }
        }
        .frame(width: width, height: height)
        .contextMenu {
            Button(role: .destructive) {
                widget.config.doShow = false
            } label: {
                Label("Delete Widget", systemImage: "trash")
            }
            
            Divider()
            
            Menu("Snap to Alignment") {
                ForEach(StyxPosition.allCases.filter { $0 != .custom }, id: \.self) { pos in
                    Button(pos.rawValue.capitalized) {
                        widget.config.x = 0
                        widget.config.y = 0
                        widget.config.position = pos
                    }
                }
            }
        }
        .position(
            x: currentPos.x + dragOffset.width,
            y: currentPos.y + dragOffset.height
        )
    }
}
