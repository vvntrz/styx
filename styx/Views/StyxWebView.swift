//
//  StyxWebView.swift
//  styx
//
//  Created by VVinters on 2026-01-25.
//


import SwiftUI
import WebKit

struct StyxWebView: NSViewRepresentable {
    let widget: WidgetModel
    
    // The Core JS API
    private let polyfill = """
    window.styx = {
        config: {},
        _callbacks: {},
        
        // Internal Sender
        _send: function(type, payload) {
            return new Promise((resolve, reject) => {
                const id = Math.random().toString(36).substr(2,9);
                this._callbacks[id] = resolve;
                
                const safePayload = (typeof payload === 'object') ? JSON.stringify(payload) : payload;
                
                window.webkit.messageHandlers.styx.postMessage({
                    type: type, 
                    payload: safePayload, 
                    id: id
                });
            });
        },
        
        _resolve: function(id, data) { 
            if(this._callbacks[id]) { 
                this._callbacks[id](data); 
                delete this._callbacks[id]; 
            } 
        },

        
        cmd: function(command) { return this._send('cmd:exec', command); },

        fs: {
            read: function(path) { return window.styx._send('fs:read', path); },
            write: function(path, content) { 
                return window.styx._send('fs:write', { path: path, content: content }); 
            }
        },

        sys: {
            open: function(url) { return window.styx._send('sys:open', url); },
            notify: function(title, body) { 
                return window.styx._send('sys:notify', { title: title, body: body }); 
            }
        }
    };
    """

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        let controller = WKUserContentController()
        
        let bridge = StyxBridge()
        context.coordinator.bridge = bridge
        controller.add(bridge, name: "styx")
        
        controller.addUserScript(WKUserScript(source: polyfill, injectionTime: .atDocumentStart, forMainFrameOnly: true))
        
        if let properties = widget.config.properties {
            let configScript = generateConfigScript(from: properties)
            controller.addUserScript(WKUserScript(source: configScript, injectionTime: .atDocumentStart, forMainFrameOnly: true))
        }
        
        config.userContentController = controller
        config.preferences.setValue(true, forKey: "allowFileAccessFromFileURLs")
        
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.setValue(false, forKey: "drawsBackground")
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        let entryFile = widget.folderURL.appendingPathComponent(widget.config.entry)
        if webView.url != entryFile {
            webView.loadFileURL(entryFile, allowingReadAccessTo: widget.folderURL)
        }
    }
    
    func makeCoordinator() -> Coordinator { Coordinator() }
    class Coordinator { var bridge: StyxBridge? }
    
    private func generateConfigScript(from properties: [String: StyxProperty]) -> String {
        var js = "window.styx.config = {"
        var css = ":root {"
        
        for (key, prop) in properties {
            let value = prop.value.value
            if let stringVal = value as? String { js += "'\(key)': '\(stringVal)'," }
            else { js += "'\(key)': \(value)," }
            css += "--\(key): \(value);"
        }
        
        js += "};"
        css += "}"
        
        return "\(js); var style = document.createElement('style'); style.innerHTML = `\(css)`; document.head.appendChild(style);"
    }
}
