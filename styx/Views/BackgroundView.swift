//
//  BackgroundView.swift
//  styx
//
//  Created by VVinters on 2026-01-25.
//
import SwiftUI
import AVKit

struct BackgroundView: View {
    let player: AVPlayer
    var imageURL: URL?

    var body: some View {
        GeometryReader { geo in
            Group {
                if let imgURL = imageURL {
                    AsyncImage(url: imgURL) { phase in
                        if let image = phase.image {
                            image.resizable().aspectRatio(contentMode: .fill)
                        } else {
                            Color.black
                        }
                    }
                } else {
                    VideoPlayer(player: player)
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .ignoresSafeArea()
    }
}

struct WidgetLayerView: View {
    @ObservedObject var delegate: AppDelegate

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .topLeading) {
                ForEach(delegate.activeWidgets) { widget in
                    if widget.config.doShow ?? true {
                        StyxWebView(widget: widget)
                            .frame(width: widget.config.width, height: widget.config.height)
                            .position(RootOverlay.calculatePoint(screen: geo.size, widget: widget))
                    }
                }
            }
        }
        .ignoresSafeArea()
    }
}

struct ForegroundView: View {
    var image: NSImage?

    var body: some View {
        GeometryReader { geo in
            if let img = image {
                Image(nsImage: img)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: geo.size.width, height: geo.size.height)
            } else {
                Color.clear // Invisible if no image/video mode
            }
        }
        .ignoresSafeArea()
    }
}
