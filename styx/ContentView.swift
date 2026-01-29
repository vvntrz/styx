import SwiftUI

struct ContentView: View {
    @ObservedObject var delegate = AppDelegate()
    
    let desktopSize = CGSize(width: 1920, height: 1080)
    @State private var selectedWidgetURL: URL? = nil
    
    var body: some View {
        VStack(spacing: 0) {
            GeometryReader { geo in
                let scale = min(geo.size.width / desktopSize.width, geo.size.height / desktopSize.height)
                let offset = CGPoint(
                    x: (geo.size.width - (desktopSize.width * scale)) / 2,
                    y: (geo.size.height - (desktopSize.height * scale)) / 2
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
                        Text("Styx Editor")
                            .font(.system(size: 16, weight: .bold))
                        Text("Configure active wallpapers and widgets.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    HStack(spacing: 12) {
                        Picker("Available Widgets", selection: $selectedWidgetURL) {
                            Text("Select a widget").tag(URL?.none)
                            ForEach(getAvailableWidgetURLs(), id: \.self) { url in
                                Text(getWidgetName(from: url)).tag(URL?.some(url))
                            }
                        }
                        .frame(width: 200)
                        
                        Button(action: {
                            if let url = selectedWidgetURL {
                                delegate.loadWidget(from: url)
                            }
                        }) {
                            Label("Add", systemImage: "plus")
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(selectedWidgetURL == nil)

                        Button(action: {
                            delegate.promptForWidgetFolder()
                        }) {
                            Label("Import", systemImage: "square.and.arrow.down")
                        }
                        .buttonStyle(.bordered)
                    }
                }
                .padding(.horizontal, 25)
                .frame(height: 100)
                .background(.ultraThinMaterial)
            }
        }
        .ignoresSafeArea(.all, edges: .top)
    }

    private func getAvailableWidgetURLs() -> [URL] {
        let widgetsFolder = StyxConfigHandler().configDirectoryURL.appendingPathComponent("Widgets")
        let content = try? FileManager.default.contentsOfDirectory(at: widgetsFolder, includingPropertiesForKeys: [.isDirectoryKey])
        return content?.filter { (try? $0.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true } ?? []
    }

    private func getWidgetName(from folderURL: URL) -> String {
        let configURL = folderURL.appendingPathComponent("styx.json")
        guard let data = try? Data(contentsOf: configURL),
              let config = try? JSONDecoder().decode(StyxConfig.self, from: data) else {
            return folderURL.lastPathComponent
        }
        return config.name
    }
}
