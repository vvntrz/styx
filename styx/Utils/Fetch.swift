//
//  Fetch.swift
//  styx
//
//  Created by VVinters on 2026-01-26.
//

import ObjectiveC
import Foundation

class Fetch: NSObject, URLSessionDownloadDelegate {
    var progress: Double = 0
     func getFN(from string: String) -> String {
        if let theRange = string.range(of: ".", options: .backwards),
            let i = string[theRange.upperBound...] as Substring? {
            return String(i)
        } else {
            return ""
        }
    }
    func download(from url: URL) async throws {
        let (downloadURL, response) = try await URLSession.shared.download(
            from: url,
            delegate: self
        )
        let destinationURL = URL.downloadsDirectory
            .appending(path: "download")
            .appendingPathExtension(getFN(from: url.absoluteString))
        try FileManager.default.moveItem(at: downloadURL, to: destinationURL)
    }
    nonisolated func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        Task {
            await MainActor.run {
                progress = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
            }
        }
    }

    nonisolated func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
    }
    // Last two functions are redundant for this really.
}
