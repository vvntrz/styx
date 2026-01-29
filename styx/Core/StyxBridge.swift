//
//  StyxBridge.swift
//  styx
//
//  Created by VVinters on 2026-01-25.
//

import WebKit
import UserNotifications // <--- NEW FRAMEWORK

class StyxBridge: NSObject, WKScriptMessageHandler {
    
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard let webView = message.webView else { return }
        
        guard let dict = message.body as? [String: Any],
              let type = dict["type"] as? String,
              let id = dict["id"] as? String else { return }
        
        let payload = dict["payload"] as? String ?? ""
        
        switch type {
            
        case "cmd:exec":
            runCommand(payload) { res in self.reply(to: webView, id: id, result: res) }
            
        case "fs:read":
            readFile(path: payload) { res in self.reply(to: webView, id: id, result: res) }
            
        case "fs:write":
            writeFile(json: payload) { res in self.reply(to: webView, id: id, result: res) }
            
        case "sys:open":
            openURL(url: payload) { res in self.reply(to: webView, id: id, result: res) }
            
        case "sys:notify":
            sendNotification(json: payload) { res in self.reply(to: webView, id: id, result: res) }
            
        default:
            print("Unknown Styx command: \(type)")
            self.reply(to: webView, id: id, result: "Error: Unknown command")
        }
    }
    
    
    private func runCommand(_ cmd: String, completion: @escaping (String) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            let task = Process(); let pipe = Pipe()
            task.standardOutput = pipe; task.standardError = pipe
            task.arguments = ["-l", "-c", cmd]; task.launchPath = "/bin/zsh"
            try? task.run()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            completion(String(data: data, encoding: .utf8)?.trimmingCharacters(in: .newlines) ?? "")
        }
    }
    
    private func readFile(path: String, completion: @escaping (String) -> Void) {
        DispatchQueue.global(qos: .default).async {
            do {
                let content = try String(contentsOfFile: path, encoding: .utf8)
                completion(content)
            } catch {
                completion("Error: \(error.localizedDescription)")
            }
        }
    }
    
    private func writeFile(json: String, completion: @escaping (String) -> Void) {
        DispatchQueue.global(qos: .default).async {
            guard let data = json.data(using: .utf8),
                  let dict = try? JSONSerialization.jsonObject(with: data) as? [String: String],
                  let path = dict["path"],
                  let content = dict["content"] else {
                completion("Error: Invalid JSON payload")
                return
            }
            
            do {
                try content.write(toFile: path, atomically: true, encoding: .utf8)
                completion("Success")
            } catch {
                completion("Error: \(error.localizedDescription)")
            }
        }
    }
    
    private func openURL(url: String, completion: @escaping (String) -> Void) {
        DispatchQueue.main.async {
            if let u = URL(string: url) {
                NSWorkspace.shared.open(u)
                completion("Opened")
            } else {
                completion("Error: Invalid URL")
            }
        }
    }
    
    private func sendNotification(json: String, completion: @escaping (String) -> Void) {
        guard let data = json.data(using: .utf8),
              let dict = try? JSONSerialization.jsonObject(with: data) as? [String: String],
              let title = dict["title"],
              let body = dict["body"] else {
            completion("Error: Invalid Payload")
            return
        }
        
        let center = UNUserNotificationCenter.current()
        
        center.requestAuthorization(options: [.alert, .sound]) { granted, error in
            guard granted else {
                completion("Error: Permission Denied")
                return
            }
            
            let content = UNMutableNotificationContent()
            content.title = title
            content.body = body
            content.sound = UNNotificationSound.default
            
            let uuid = UUID().uuidString
            let request = UNNotificationRequest(identifier: uuid, content: content, trigger: nil)
            
            center.add(request) { error in
                if let e = error {
                    completion("Error: \(e.localizedDescription)")
                } else {
                    completion("Sent")
                }
            }
        }
    }

    private func reply(to webView: WKWebView?, id: String, result: String) {
        let clean = result.replacingOccurrences(of: "\n", with: "\\n").replacingOccurrences(of: "'", with: "\\'")
        let js = "window.styx._resolve('\(id)', '\(clean)')"
        DispatchQueue.main.async { webView?.evaluateJavaScript(js) }
    }
}
