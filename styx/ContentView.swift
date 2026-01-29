
import SwiftUI

struct ContentView: View {
    @ObservedObject var delegate = AppDelegate()
    
    let desktopSize = CGSize(width: 1920, height: 1080)
    
    var body: some View {
        VStack(spacing: 0) {
            GeometryReader { geo in
                let scale = min(geo.size.width / desktopSize.width, geo.size.height / desktopSize.height)
                let scaledSize = CGSize(width: desktopSize.width * scale, height: desktopSize.height * scale)
                let offset = CGPoint(
                    x: (geo.size.width - scaledSize.width) / 2,
                    y: (geo.size.height - scaledSize.height) / 2
                )
                
                ZStack {
                    Color.black.ignoresSafeArea()
                    
                    ZStack(alignment: .topLeading) {
                        if let url = delegate.backgroundURL {
                            AsyncImage(url: url) { phase in
                                switch phase {
                                case .success(let image):
                                    image.resizable().scaledToFill()
                                default:
                                    Color.black
                                }
                            }
                        } else {
                            MoviePlayerView(player: delegate.videoPlayer)
                        }
                        
                        ForEach(delegate.activeWidgets) { widget in
                            WidgetWrapperView_Refined(
                                widget: widget,
                                isEditable: true,
                                parentSize: desktopSize,
                                scale: scale
                            )
                        }
                        
                        if let fg = delegate.foregroundImage {
                            Image(nsImage: fg).resizable().scaledToFill()
                        }
                    }
                    .frame(width: desktopSize.width, height: desktopSize.height)
                    .clipped()
                    .scaleEffect(scale, anchor: .topLeading)
                    .offset(x: offset.x, y: offset.y)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            VStack(spacing: 0) {
                Divider()
                
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Desktop Manager")
                            .font(.system(size: 16, weight: .bold))
                        Text("Configure your active widgets and wallpaper settings.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    HStack(spacing: 12) {
                        Button(action: {/* fix */ }) {
                            Label("Add Widget", systemImage: "plus")
                        }
                        .buttonStyle(.bordered)
                        Button(action: {
                            AppDelegate().promptForWidgetFolder()
                        }) {
                            Label("Import Widget", systemImage: "plus")
                        }
                        
                        Button(action: { /* Refresh logic */ }) {
                            Image(systemName: "arrow.clockwise")
                        }
                        .buttonStyle(.bordered)
                    }
                }
                .padding(.horizontal, 25)
                .frame(height: 150)
                .background(.ultraThinMaterial)
            }
        }
        .ignoresSafeArea(.all, edges: .top)
    }
}
