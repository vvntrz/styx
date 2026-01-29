//
//  StyxConfigHandler.swift
//  styx
//
//  Created by VVinters on 2026-01-27.
//
import Foundation

class StyxConfigHandler {
    let fm = FileManager.default
    var cbool: ObjCBool = true
    let configDirectoryURL: URL = {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSupport.appendingPathComponent("Styx")
    }()

    func runChecks() {
        var isDir: ObjCBool = true
            
        if fm.fileExists(atPath: configDirectoryURL.path, isDirectory: &isDir) {
        } else {
            try? setup()
            }
        }
        
        func setup() throws {
            try fm.createDirectory(
                at: configDirectoryURL,
                withIntermediateDirectories: true,
                attributes: nil
            )
            try fm.createDirectory(
                at: configDirectoryURL.appendingPathComponent("Widgets"),
                withIntermediateDirectories: true,
                attributes: nil
            )
            
            let fileURL = configDirectoryURL.appendingPathComponent("styx.json")
            
            if let data = "".data(using: .utf8) {
                try data.write(to: fileURL)
            }
        }
    
    /*
     I need to implement the reader for the config, it should support importing preset configs (along with fetching from repo),
     */
}
