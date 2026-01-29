import SwiftUI

struct ContentView: View {
    @ObservedObject var delegate: AppDelegate
    
    let desktopSize = CGSize(width: 1920, height: 1080)
    @State private var selectedWidgetURL: URL? = nil
    
    var body: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 20) {
                Text("Styx")
                    .font(.system(size: 24, weight: .black))
                    .padding(.bottom, 10)
                
                Group {
                    Text("BACKGROUND").font(.caption).fontWeight(.bold).foregroundColor(.secondary)
                    
                    Button(action: { delegate.promptForVideo() }) {
                        Label("Live Video", systemImage: "play.rectangle.fill")
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.bordered)
                    
                    Button(action: { delegate.promptForPhoto() }) {
                        Label("Depth Photo", systemImage: "photo.fill")
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.bordered)
                }
                
                Divider()
                
                Group {
                    Text("WIDGETS").font(.caption).fontWeight(.bold).foregroundColor(.secondary)
                    
                    Button(action: { delegate.promptForWidgetFolder() }) {
                        Label("Import Folder", systemImage: "folder.badge.plus")
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.bordered)
                    
                    Button(action: { delegate.clearWidgets() }) {
                        Label("Remove All", systemImage: "trash")
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.bordered)
                    .foregroundColor(.red)
                }
                Divider()
                Group {
                    Text("SETTINGS").font(.caption).fontWeight(.bold).foregroundColor(.secondary)
                    Toggle("Snap to Grid", isOn: $delegate.isSnappingEnabled)
                        .padding(.vertical, 5)
                        .toggleStyle(.switch)
                }
                Spacer()
                
                Button(action: { delegate.saveConfiguration() }) {
                    Text("Apply & Save")
                        .fontWeight(.bold)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
            .padding(20)
            .frame(width: 200)
            .background(.ultraThinMaterial)
            
            VStack(spacing: 0) {
                GeometryReader { geo in
                    let scale = min(geo.size.width / desktopSize.width, geo.size.height / desktopSize.height) * 0.95
                    let offset = CGPoint(
                        x: (geo.size.width - (desktopSize.width * scale)) / 2,
                        y: (geo.size.height - (desktopSize.height * scale)) / 2
                    )
                    
                    ZStack {
                        ZStack(alignment: .topLeading) {
                            if let url = delegate.backgroundURL {
                                AsyncImage(url: url) { phase in
                                    if let image = phase.image { image.resizable().scaledToFill() }
                                    else { Color.black }
                                }
                            } else {
                                MoviePlayerView(player: delegate.videoPlayer)
                            }
                            
                            ForEach(delegate.activeWidgets) { widget in
                                WidgetWrapperView_Refined(
                                    widget: widget,
                                    delegate: delegate,
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
                        .background(Color.black)
                        .cornerRadius(10 / scale)
                        .shadow(radius: 20)
                        .scaleEffect(scale, anchor: .topLeading)
                        .offset(x: offset.x, y: offset.y)
                    }
                }
                .background(Color(nsColor: .windowBackgroundColor))
                .cornerRadius(10)
                
                HStack {
                    Picker("Add Widget", selection: $selectedWidgetURL) {
                        Text("Select library widget...").tag(URL?.none)
                        ForEach(getAvailableWidgetURLs(), id: \.self) { url in
                            Text(getWidgetName(from: url)).tag(URL?.some(url))
                        }
                    }
                    .labelsHidden()
                    .frame(width: 250)
                    
                    Button("Add to Desktop") {
                        if let url = selectedWidgetURL { delegate.loadWidget(from: url) }
                    }
                    .disabled(selectedWidgetURL == nil)
                    
                    Spacer()
                    
                    Text("Canvas: 1920 x 1080")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(.ultraThinMaterial)
            }
        }
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
