//
//  ImageSegmenter.swift
//  styx
//
//  Created by VVinters on 2026-01-25.
//


import Vision
import CoreImage
import CoreImage.CIFilterBuiltins
import AppKit

class ImageSegmenter {
    static func liftSubject(from inputImage: NSImage) -> NSImage? {
        guard let cgImage = inputImage.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return nil }
        
        let request = VNGenerateForegroundInstanceMaskRequest()
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        
        do {
            try handler.perform([request])
            guard let result = request.results?.first,
                  let maskPixelBuffer = try? result.generateScaledMaskForImage(forInstances: result.allInstances, from: handler) else { return nil }
            
            let maskImage = CIImage(cvPixelBuffer: maskPixelBuffer)
            let originalImage = CIImage(cgImage: cgImage)
            
            let blendFilter = CIFilter.blendWithMask()
            blendFilter.inputImage = originalImage
            blendFilter.maskImage = maskImage
            
            guard let outputCIImage = blendFilter.outputImage else { return nil }
            
            let rep = NSCIImageRep(ciImage: outputCIImage)
            let nsImage = NSImage(size: rep.size)
            nsImage.addRepresentation(rep)
            return nsImage
        } catch {
            print("Vision Error: \(error)")
            return nil
        }
    }
}
