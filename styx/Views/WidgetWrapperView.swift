import SwiftUI

struct WidgetWrapperView_Refined: View {
    @ObservedObject var widget: WidgetModel
    let isEditable: Bool
    let parentSize: CGSize
    let scale: CGFloat

    @State private var initialRect: CGRect? = nil

    @GestureState private var dragOffset: CGSize = .zero
    
    @State private var sel: String = ""

    var body: some View {
        let currentPos = RootOverlay.calculatePoint(screen: parentSize, widget: widget)

        ZStack {
            if (widget.config.doShow!) {
                StyxWebView(widget: widget)
                    .allowsHitTesting(!isEditable)
            }

            if isEditable && widget.config.doShow! {
                // Border

                RoundedRectangle(cornerRadius: 4)
                    .stroke(Color.blue, lineWidth: 2)
                Color.white.opacity(0.001)
                    .gesture(
                        DragGesture(coordinateSpace: .global)
                            .updating($dragOffset) { value, state, transaction in
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
                                
                               
                                let newX = finalCenterX - (widget.config.width / 2)
                                let newY = finalCenterY - (widget.config.height / 2)
                                
                                widget.config.x = newX
                                widget.config.y = newY
                                widget.config.position = .custom
                            }
                    )

                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Circle()
                            .fill(Color.blue)
                            .frame(width: 15, height: 15)
                            .padding(2)
                            .background(Circle().fill(Color.white))
                            .offset(x: 5, y: 5)
                            .gesture(
                                DragGesture()
                                    .onChanged { value in
                                        if initialRect == nil {
                                            initialRect = CGRect(x: 0, y: 0, width: widget.config.width, height: widget.config.height)
                                        }
                                        guard let start = initialRect else { return }

                                        let newW = max(50, start.width + value.translation.width)
                                        let newH = max(50, start.height + value.translation.height)

                                        widget.config.width = newW
                                        widget.config.height = newH
                                    }
                                    .onEnded { _ in initialRect = nil }
                            )
                    }
                }
            }
        }
        .frame(width: widget.config.width, height: widget.config.height)
        .contextMenu {
            let opts = ["topLeft", "topCenter", "topRight", "centerLeft", "center", "centerRight", "bottomLeft", "bottomCenter", "bottomRight"]
            VStack {
                Button("Delete Widget") {
                    widget.config.doShow = false
                }
                Picker("Align", selection: $sel) {
                    ForEach(opts, id: \.self) { opt in
                        Button(opt, action: {
                            widget.config.x = 0
                            widget.config.y = 0
                            widget.config.position = .center
                            print("moving center")
                        })
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
