import SwiftUI
import AVKit
import Combine
import ScreenCaptureKit

class AppDelegate: NSObject, NSApplicationDelegate, ObservableObject {
    
    @Published var activeWidgets: [WidgetModel] = []
    @Published var backgroundURL: URL?
    @Published var foregroundImage: NSImage?
    var vidUrl: URL?
    var fullScreenFlag = false
    var checker: Timer?
    
    
    struct ScreenWindowSet {
        let screen: NSScreen
        let background: NSWindow
        let widget: NSWindow
        let foreground: NSWindow
        
        func closeAll() {
            background.close()
            widget.close()
            foreground.close()
        }
    }
    
    var screenWindows: [ScreenWindowSet] = []
    var editorWindow: NSWindow?
    var statusItem: NSStatusItem?
    private var cancellables = Set<AnyCancellable>()
    
    let videoPlayer: AVPlayer = {
        let p = AVPlayer(); p.actionAtItemEnd = .none; p.isMuted = true; return p
    }()
    @objc func updateFullscreenFlag() {
       
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            let isFS = NSWorkspace.shared.isAnySpaceFullScreen()
            print("DEBUG: Fullscreen Check -> \(isFS)")
            
            if isFS != self.fullScreenFlag {
                self.fullScreenFlag = isFS
                if isFS {
                    print("ACTION: Pausing Video")
                    self.videoPlayer.pause()
                } else {
                    print("ACTION: Playing Video")
                    self.videoPlayer.play()
                }
            }
        }
    }
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        setupWindows()
        setupMenuBar()
        setupLooping()
        StyxConfigHandler().runChecks()
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screenConfigurationChanged),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
        let wsCenter = NSWorkspace.shared.notificationCenter
            
            wsCenter.addObserver(
                self,
                selector: #selector(updateFullscreenFlag),
                name: NSWorkspace.activeSpaceDidChangeNotification,
                object: nil
            )
            
            wsCenter.addObserver(
                self,
                selector: #selector(updateFullscreenFlag),
                name: NSWorkspace.didActivateApplicationNotification,
                object: nil
            )
        loadConfiguration()
        updateFullscreenFlag()

    }
    

    

    
    @objc func screenConfigurationChanged() {
        print("Displays changed. Rebuilding windows...")
        setupWindows()
    }

    func setupWindows() {
        screenWindows.forEach { $0.closeAll() }
        screenWindows.removeAll()
        
        for screen in NSScreen.screens {
            buildStack(for: screen)
        }
    }
    
    func buildStack(for screen: NSScreen) {
        let level = Int(CGWindowLevelForKey(.desktopWindow))
        
        // Layer 1: Background
        let bg = createBorderlessWindow(level: level, rect: screen.frame)
        bg.contentView = NSHostingView(rootView: BackgroundView(player: videoPlayer, imageURL: backgroundURL))
        
        // Layer 2: Widgets
        let wdg = createBorderlessWindow(level: level + 1, rect: screen.frame)
        wdg.contentView = NSHostingView(rootView: WidgetLayerView(delegate: self))
        wdg.ignoresMouseEvents = false
        
        // Layer 3: Foreground (Depth)
        let fg = createBorderlessWindow(level: level + 2, rect: screen.frame)
        fg.contentView = NSHostingView(rootView: ForegroundView(image: foregroundImage))
        fg.ignoresMouseEvents = true
        
        bg.makeKeyAndOrderFront(nil)
        wdg.makeKeyAndOrderFront(nil)
        fg.makeKeyAndOrderFront(nil)
        
        screenWindows.append(ScreenWindowSet(screen: screen, background: bg, widget: wdg, foreground: fg))
    }
    
    func createBorderlessWindow(level: Int, rect: NSRect) -> NSWindow {
        let w = NSWindow(contentRect: rect, styleMask: .borderless, backing: .buffered, defer: false)
        w.backgroundColor = .clear
        w.isOpaque = false
        w.hasShadow = false
        w.level = NSWindow.Level(rawValue: level)
        w.collectionBehavior = [.stationary, .canJoinAllSpaces, .ignoresCycle]
        w.setFrame(rect, display: true)
        return w
    }

    
    @objc func promptForPhoto() {
        let p = NSOpenPanel(); p.allowedContentTypes = [.image]; p.canChooseDirectories = false
        p.begin { response in
            if response == .OK, let url = p.url { self.processImage(url) }
        }
    }
    
    func processImage(_ url: URL) {
        DispatchQueue.main.async {
            self.videoPlayer.pause()
            self.vidUrl = nil
            self.backgroundURL = url
            
            for set in self.screenWindows {
                set.background.contentView = NSHostingView(rootView: BackgroundView(player: self.videoPlayer, imageURL: url))
                set.foreground.contentView = NSHostingView(rootView: ForegroundView(image: nil))
            }
        }
        
        DispatchQueue.global(qos: .userInitiated).async {
            guard let nsImage = NSImage(contentsOf: url) else { return }
            if let cutout = ImageSegmenter.liftSubject(from: nsImage) {
                DispatchQueue.main.async {
                    self.foregroundImage = cutout
                    for set in self.screenWindows {
                        set.foreground.contentView = NSHostingView(rootView: ForegroundView(image: cutout))
                    }
                }
            }
        }
    }

    @objc func promptForVideo() {
        let p = NSOpenPanel(); p.allowedContentTypes = [.movie]; p.canChooseDirectories = false
        p.begin { response in
            if response == .OK, let url = p.url {
                DispatchQueue.main.async {
                    self.backgroundURL = nil
                    self.foregroundImage = nil
                    
                    self.videoPlayer.replaceCurrentItem(with: AVPlayerItem(url: url))
                    self.vidUrl = url
                    self.videoPlayer.play()
                    
                    for set in self.screenWindows {
                        set.background.contentView = NSHostingView(rootView: BackgroundView(player: self.videoPlayer, imageURL: nil))
                        set.foreground.contentView = NSHostingView(rootView: ForegroundView(image: nil))
                    }
                }
            }
        }
    }

    func setupLooping() {
        NotificationCenter.default.publisher(for: .AVPlayerItemDidPlayToEndTime)
            .sink { [weak self] _ in self?.videoPlayer.seek(to: .zero); self?.videoPlayer.play() }
            .store(in: &cancellables)
    }
    

    // Modified to allow passing explicit X/Y coordinates when loading
    func loadWidget(from folderURL: URL, overrideX: CGFloat? = nil, overrideY: CGFloat? = nil) {
            let configURL = folderURL.appendingPathComponent("styx.json")
            do {
                let data = try Data(contentsOf: configURL)
                var config = try JSONDecoder().decode(StyxConfig.self, from: data)
                
                // Apply saved overrides
                if let x = overrideX, let y = overrideY {
                                config.x = x
                                config.y = y
                                config.position = .custom // <--- Crucial!
                            }
                
                DispatchQueue.main.async {
                    print("Loaded Widget: \(config.name) at (\(config.x ?? 0), \(config.y ?? 0))")
                    
                    self.objectWillChange.send()
                    
                    self.activeWidgets.append(WidgetModel(folderURL: folderURL, config: config))
                }
            } catch {
                DispatchQueue.main.async {
                    print("Widget load error: \(error)")
                }
            }
        }
    
    @objc func promptForWidgetFolder() {
        NSApp.activate(ignoringOtherApps: true)
        let p = NSOpenPanel()
        p.title = "Select Widget Folder"
        p.canChooseDirectories = true
        p.canChooseFiles = false
        p.begin { response in
            if response == .OK, let url = p.url { self.loadWidget(from: url) }
        }
    }
    
    @objc func clearWidgets() { activeWidgets.removeAll() }
    @objc func quitApp() { NSApplication.shared.terminate(nil) }
    

    struct SavedWidgetData: Codable {
        let url: String
        let x: CGFloat
        let y: CGFloat
    }
    
    struct State: Codable {
        let widgets: [SavedWidgetData]
        let img: String?
        let vid: String?
    }
    
    @objc func saveConfiguration() {
        let widgetDataList = activeWidgets.compactMap { widget -> SavedWidgetData? in
            return SavedWidgetData(
                url: widget.folderURL.absoluteString,
                x: widget.config.x ?? 100,
                y: widget.config.y ?? 100
            )
        }
        
        let state = State(widgets: widgetDataList, img: backgroundURL?.absoluteString, vid: vidUrl?.absoluteString)
        
        if let data = try? JSONEncoder().encode(state) {
            let home = FileManager.default.homeDirectoryForCurrentUser
            let url = home.appendingPathComponent(".styx.json")
            try? data.write(to: url)
            print("Saved state with positions to \(url.path)")
        }
    }
    
    @objc func loadConfiguration() {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let url = home.appendingPathComponent(".styx.json")
        guard let data = try? Data(contentsOf: url),
              let state = try? JSONDecoder().decode(State.self, from: data) else { return }
        
        self.activeWidgets.removeAll()
        
        for widgetData in state.widgets {
            if let url = URL(string: widgetData.url) {
                loadWidget(from: url, overrideX: widgetData.x, overrideY: widgetData.y)
            }
        }
        
        if let imgString = state.img, let imgUrl = URL(string: imgString) {
            processImage(imgUrl)
        } else if let vidString = state.vid, let vidUrl = URL(string: vidString) {
            DispatchQueue.main.async {
                self.backgroundURL = nil
                self.foregroundImage = nil
                self.videoPlayer.replaceCurrentItem(with: AVPlayerItem(url: vidUrl))
                self.vidUrl = vidUrl
                self.videoPlayer.play()
                
                for set in self.screenWindows {
                    set.background.contentView = NSHostingView(rootView: BackgroundView(player: self.videoPlayer, imageURL: nil))
                    set.foreground.contentView = NSHostingView(rootView: ForegroundView(image: nil))
                }
            }
        }
    }


    func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "cpu", accessibilityDescription: nil)
        }
        let menu = NSMenu()
        menu.addItem(withTitle: "Select Video...", action: #selector(promptForVideo), keyEquivalent: "o")
        menu.addItem(withTitle: "Select Image (Depth)...", action: #selector(promptForPhoto), keyEquivalent: "i")
        menu.addItem(withTitle: "Add Widget...", action: #selector(promptForWidgetFolder), keyEquivalent: "w")
        menu.addItem(withTitle: "Clear Widgets", action: #selector(clearWidgets), keyEquivalent: "k")
        menu.addItem(withTitle: "Save Config", action: #selector(saveConfiguration), keyEquivalent: "s")
        menu.addItem(withTitle: "Load Config", action: #selector(loadConfiguration), keyEquivalent: "l")
        menu.addItem(withTitle: "Open Editor", action: #selector(showEditor), keyEquivalent: "e")
        menu.addItem(withTitle: "Quit", action: #selector(quitApp), keyEquivalent: "q")
        statusItem?.menu = menu
    }
    
    @objc func showEditor() {
        if editorWindow == nil {
            let screen = NSScreen.main?.visibleFrame ?? .zero
            let rect = NSRect(x: screen.midX - 350, y: screen.midY - 200, width: 700, height: 400)
            let w = NSWindow(contentRect: rect, styleMask: [.titled, .closable, .resizable], backing: .buffered, defer: false)
            w.title = "Styx Editor"
            w.contentView = NSHostingView(rootView: ContentView(delegate: self))
            w.isReleasedWhenClosed = false
            editorWindow = w
        }
        editorWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
