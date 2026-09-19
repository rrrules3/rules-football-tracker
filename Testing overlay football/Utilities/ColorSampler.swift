//
//  ColorSampler.swift
//  Testing overlay football
//
//  Created by Rohan Rajesh on 08/04/26.
//

import AppKit
import CoreImage
import SwiftUI

@MainActor
class ColorSampler {
    static let shared = ColorSampler()

    private var cache: [String: Color] = [:]

    func dominantColor(from urlString: String) async -> Color {
        if let cached = cache[urlString] {
            return cached
        }

        guard let url = URL(string: urlString) else { return .blue }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            guard let nsImage = NSImage(data: data),
                  let cgImage = nsImage.cgImage(forProposedRect: nil, context: nil, hints: nil)
            else { return .blue }

            // Render badge at a small fixed size for fast pixel sampling
            let size = 40
            var pixels = [UInt8](repeating: 0, count: size * size * 4)
            guard let ctx = CGContext(
                data: &pixels,
                width: size, height: size,
                bitsPerComponent: 8, bytesPerRow: size * 4,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) else { return .blue }

            ctx.draw(cgImage, in: CGRect(x: 0, y: 0, width: size, height: size))

            // Accumulate only pixels that are clearly saturated (not white, black, or grey).
            // White/transparent backgrounds and dark shadows are excluded so the actual
            // shirt/badge colour dominates the average.
            var rSum: Double = 0, gSum: Double = 0, bSum: Double = 0
            var count: Int = 0

            for i in stride(from: 0, to: pixels.count, by: 4) {
                let alpha = Double(pixels[i + 3]) / 255.0
                guard alpha > 0.5 else { continue }   // skip transparent pixels

                let r = Double(pixels[i])     / 255.0
                let g = Double(pixels[i + 1]) / 255.0
                let b = Double(pixels[i + 2]) / 255.0

                // Convert to HSB to filter near-whites, near-blacks, and near-greys
                var h: CGFloat = 0, s: CGFloat = 0, v: CGFloat = 0, a: CGFloat = 0
                NSColor(red: r, green: g, blue: b, alpha: 1).getHue(&h, saturation: &s, brightness: &v, alpha: &a)

                guard s > 0.25,          // must have meaningful colour (not grey/white)
                      v > 0.15,          // not too dark / black
                      v < 0.97           // not too bright / white
                else { continue }

                rSum += r; gSum += g; bSum += b
                count += 1
            }

            // Fall back to a plain average if no saturated pixels found (e.g. monochrome badge)
            if count == 0 {
                for i in stride(from: 0, to: pixels.count, by: 4) {
                    guard Double(pixels[i + 3]) / 255.0 > 0.5 else { continue }
                    rSum += Double(pixels[i]) / 255.0
                    gSum += Double(pixels[i + 1]) / 255.0
                    bSum += Double(pixels[i + 2]) / 255.0
                    count += 1
                }
            }

            guard count > 0 else { return .blue }

            let r = CGFloat(rSum / Double(count))
            let g = CGFloat(gSum / Double(count))
            let b = CGFloat(bSum / Double(count))

            // Boost saturation so the bar colour is vivid rather than pastel
            var h: CGFloat = 0, s: CGFloat = 0, v: CGFloat = 0, a: CGFloat = 0
            NSColor(red: r, green: g, blue: b, alpha: 1).getHue(&h, saturation: &s, brightness: &v, alpha: &a)
            let color = Color(hue: Double(h), saturation: Double(min(1.0, s * 1.5)), brightness: Double(min(1.0, v)))

            cache[urlString] = color
            return color
        } catch {
            return .blue
        }
    }
}
