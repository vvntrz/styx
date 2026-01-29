
//
//  RootOverlayView.swift
//  styx
//
//  Created by VVinters on 2026-01-25.
//


import SwiftUI

import AVKit


struct RootOverlay {
    @ObservedObject var delegate: AppDelegate


    // Helper for widget positioning
    static func calculatePoint(screen: CGSize, widget: WidgetModel) -> CGPoint {
        let w = widget.config.width
        let h = widget.config.height
        let offX = widget.config.x ?? 0
        let offY = widget.config.y ?? 0

        switch widget.config.position ?? .center {
        case .topLeft:
            return CGPoint(x: (w/2) + offX, y: (h/2) + offY)
        case .topCenter:
            return CGPoint(x: (screen.width/2) + offX, y: (h/2) + offY)
        case .topRight:
            return CGPoint(x: screen.width - (w/2) + offX, y: (h/2) + offY)
        case .centerLeft:
            return CGPoint(x: (w/2) + offX, y: (screen.height/2) + offY)
        case .center:
            return CGPoint(x: (screen.width/2) + offX, y: (screen.height/2) + offY)
        case .centerRight:
            return CGPoint(x: screen.width - (w/2) + offX, y: (screen.height/2) + offY)
        case .bottomLeft:
            return CGPoint(x: (w/2) + offX, y: screen.height - (h/2) + offY)
        case .bottomCenter:
            return CGPoint(x: (screen.width/2) + offX, y: screen.height - (h/2) + offY)
        case .bottomRight:
            return CGPoint(x: screen.width - (w/2) + offX, y: screen.height - (h/2) + offY)
        case .custom:
            return CGPoint(x: (w/2) + offX, y: (h/2) + offY)
        }
    }
}
