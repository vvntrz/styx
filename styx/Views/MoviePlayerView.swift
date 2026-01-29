//
//  MoviePlayerView.swift
//  styx
//
//  Created by VVinters on 2026-01-25.
//


import SwiftUI
import AVKit

struct MoviePlayerView: NSViewRepresentable {
    let player: AVPlayer
    func makeNSView(context: Context) -> AVPlayerView {
        let v = AVPlayerView()
        v.controlsStyle = .none
        v.videoGravity = .resizeAspect
        v.player = player
        return v
    }
    
    func updateNSView(_ nsView: AVPlayerView, context: Context) {}
}
