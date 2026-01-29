//
//  PlayerLogicGate.swift
//  styx
//
//  Created by VVinters on 2026-01-28.
//

import Cocoa

extension NSWorkspace {
    // Currently broken.
    func isAnySpaceFullScreen() -> Bool {
        let options = NSApp.currentSystemPresentationOptions
        if options.contains(.fullScreen) || options.contains(.autoHideMenuBar) {
            return true
        }

        let windowOptions = CGWindowListOption([.optionOnScreenOnly, .excludeDesktopElements])
        guard let windowList = CGWindowListCopyWindowInfo(windowOptions, kCGNullWindowID) as? [[String: Any]] else {
            return false
        }

        for window in windowList {
            if let isFS = window["kCGWindowIsFullScreen"] as? Bool, isFS == true {
                return true
            }
            
          
            if let boundsDict = window[kCGWindowBounds as String] as? [String: Any],
               let bounds = CGRect(dictionaryRepresentation: boundsDict as CFDictionary),
               let layer = window[kCGWindowLayer as String] as? Int, layer == 0 {
                
                for screen in NSScreen.screens {
                    if abs(bounds.width - screen.frame.width) < 2 &&
                       abs(bounds.height - screen.frame.height) < 2 {
                        return true
                    }
                }
            }
        }
        return false
    }
}
