import SwiftUI
import AVKit
import Combine
import ScreenCaptureKit

class AppDelegate: NSObject, NSApplicationDelegate, ObservableObject {
    @Published var activeWidgets: [WidgetModel] = []
    @Published var backgroundURL: URL?
    @Published var isSnappingEnabled: Bool = false
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
            if isFS != self.fullScreenFlag {
                self.fullScreenFlag = isFS
                if isFS {
                    self.videoPlayer.pause()
                } else {
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
        
        NotificationCenter.default.addObserver(self, selector: #selector(screenConfigurationChanged), name: NSApplication.didChangeScreenParametersNotification, object: nil)
        
        let wsCenter = NSWorkspace.shared.notificationCenter
        wsCenter.addObserver(self, selector: #selector(updateFullscreenFlag), name: NSWorkspace.activeSpaceDidChangeNotification, object: nil)
        wsCenter.addObserver(self, selector: #selector(updateFullscreenFlag), name: NSWorkspace.didActivateApplicationNotification, object: nil)
        
        loadConfiguration()
        updateFullscreenFlag()
    }
    
    @objc func screenConfigurationChanged() {
        // Only rebuild windows when screen configuration actually changes
        let currentScreens = Set(NSScreen.screens.map { $0.frame })
        let existingScreens = Set(screenWindows.map { $0.screen.frame })
        
        if currentScreens != existingScreens {
            teardownWindows()
            for screen in NSScreen.screens {
                buildStack(for: screen)
            }
        }
    }

    private func teardownWindows() {
        for windowSet in screenWindows {
            windowSet.background.orderOut(nil)
            windowSet.widget.orderOut(nil)
            windowSet.foreground.orderOut(nil)
            
            windowSet.background.contentView = nil
            windowSet.widget.contentView = nil
            windowSet.foreground.contentView = nil
        }
        screenWindows.removeAll()
    }

    @objc func setupWindows() {
        if screenWindows.isEmpty {
            for screen in NSScreen.screens {
                buildStack(for: screen)
            }
        } else {
            for windowSet in screenWindows {
                windowSet.background.contentView = NSHostingView(rootView: BackgroundView(player: videoPlayer, imageURL: backgroundURL))
                windowSet.widget.contentView = NSHostingView(rootView: WidgetLayerView(delegate: self))
                windowSet.foreground.contentView = NSHostingView(rootView: ForegroundView(image: foregroundImage))
            }
        }
    }
    
    func buildStack(for screen: NSScreen) {
        let level = Int(CGWindowLevelForKey(.desktopWindow))
        
        let bg = createBorderlessWindow(level: level, rect: screen.frame)
        bg.contentView = NSHostingView(rootView: BackgroundView(player: videoPlayer, imageURL: backgroundURL))
        
        let wdg = createBorderlessWindow(level: level + 1, rect: screen.frame)
        wdg.contentView = NSHostingView(rootView: WidgetLayerView(delegate: self))
        wdg.ignoresMouseEvents = false
        
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

    func loadWidget(from folderURL: URL, overrideX: CGFloat? = nil, overrideY: CGFloat? = nil, overrideWidth: CGFloat? = nil, overrideHeight: CGFloat? = nil, overridePosition: StyxPosition? = nil) {
        let configURL = folderURL.appendingPathComponent("styx.json")
        do {
            let data = try Data(contentsOf: configURL)
            var config = try JSONDecoder().decode(StyxConfig.self, from: data)
            if let pos = overridePosition {
                config.position = pos
                config.x = overrideX
                config.y = overrideY
            } else if let x = overrideX, let y = overrideY {
                config.x = x
                config.y = y
                config.position = .custom
            }
            if let w = overrideWidth { config.width = w }
            if let h = overrideHeight { config.height = h }
            DispatchQueue.main.async {
                self.objectWillChange.send()
                self.activeWidgets.append(WidgetModel(folderURL: folderURL, config: config))
            }
        } catch {
            print("Widget load error: \(error)")
        }
    }
    
    @objc func promptForWidgetFolder() {
        NSApp.activate(ignoringOtherApps: true)
        let p = NSOpenPanel()
        p.canChooseDirectories = true
        p.canChooseFiles = false
        p.begin { response in
            if response == .OK, let url = p.url {
                let dest = StyxConfigHandler().configDirectoryURL.appendingPathComponent("Widgets").appendingPathComponent(url.lastPathComponent)
                try? FileManager.default.copyItem(at: url, to: dest)
                self.loadWidget(from: dest)
            }
        }
    }
    
    @objc func clearWidgets() { activeWidgets.removeAll() }
    @objc func quitApp() { NSApplication.shared.terminate(nil) }

    struct SavedWidgetData: Codable {
        let url: String
        let x: CGFloat
        let y: CGFloat
        let width: CGFloat
        let height: CGFloat
        let position: StyxPosition
    }
    
    struct State: Codable {
        let widgets: [SavedWidgetData]
        let img: String?
        let vid: String?
    }
    
    private var configFileURL: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let styxDir = appSupport.appendingPathComponent("Styx")
        try? FileManager.default.createDirectory(at: styxDir, withIntermediateDirectories: true)
        return styxDir.appendingPathComponent("config.json")
    }
    
    @objc func saveConfiguration() {
        activeWidgets.removeAll { $0.config.doShow == false }
        
        let widgetDataList = activeWidgets.map { widget -> SavedWidgetData in
            print("Saving widget: x=\(widget.config.x ?? -1) y=\(widget.config.y ?? -1) pos=\(widget.config.position ?? .custom)")
            return SavedWidgetData(
                url: widget.folderURL.absoluteString,
                x: widget.config.x ?? 0,
                y: widget.config.y ?? 0,
                width: widget.config.width,
                height: widget.config.height,
                position: widget.config.position ?? .custom
            )
        }
        let state = State(widgets: widgetDataList, img: backgroundURL?.absoluteString, vid: vidUrl?.absoluteString)
        if let data = try? JSONEncoder().encode(state) {
            try? data.write(to: configFileURL)
            print("Saved config to: \(configFileURL.path)")
        }
        
        objectWillChange.send()
        for windowSet in screenWindows {
            windowSet.widget.contentView = NSHostingView(rootView: WidgetLayerView(delegate: self))
        }
    }
    
    @objc func loadConfiguration() {
        print("Loading config from: \(configFileURL.path)")
        print("File exists: \(FileManager.default.fileExists(atPath: configFileURL.path))")
        
        guard let data = try? Data(contentsOf: configFileURL) else {
            print("No config file found or couldn't read")
            return
        }
        
        guard let state = try? JSONDecoder().decode(State.self, from: data) else {
            print("Failed to decode config")
            return
        }
        
        print("Loaded \(state.widgets.count) widgets from config")
        self.activeWidgets.removeAll()
        for widgetData in state.widgets {
            print("  Widget: \(widgetData.url) at (\(widgetData.x), \(widgetData.y)) pos=\(widgetData.position)")
            if let url = URL(string: widgetData.url) {
                loadWidget(from: url, overrideX: widgetData.x, overrideY: widgetData.y, overrideWidth: widgetData.width, overrideHeight: widgetData.height, overridePosition: widgetData.position)
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
            if let logoImage = NSImage(named: "s") {
                logoImage.size = NSSize(width: 18, height: 18)
                logoImage.isTemplate = true
                button.image = logoImage
            } else {
                button.image = NSImage(systemSymbolName: "layers.fill", accessibilityDescription: nil)
            }
        }

        let menu = NSMenu()
        menu.addItem(withTitle: "Open Editor", action: #selector(showEditor), keyEquivalent: "e")
        menu.addItem(NSMenuItem.separator())
        menu.addItem(withTitle: "Force Reload Windows", action: #selector(setupWindows), keyEquivalent: "r")
        menu.addItem(withTitle: "Quit Styx", action: #selector(quitApp), keyEquivalent: "q")
        statusItem?.menu = menu
    }
    @objc func showEditor() {
        if editorWindow == nil {
            let screen = NSScreen.main?.visibleFrame ?? .zero
            let rect = NSRect(x: screen.midX - 450, y: screen.midY - 300, width: 900, height: 600)
            let w = NSWindow(contentRect: rect, styleMask: [.titled, .closable, .resizable, .fullSizeContentView], backing: .buffered, defer: false)
            w.titlebarAppearsTransparent = true
            w.title = ""
            w.contentView = NSHostingView(rootView: ContentView(delegate: self))
            w.isReleasedWhenClosed = false
            editorWindow = w
        }
        editorWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
