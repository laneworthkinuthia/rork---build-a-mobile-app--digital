import CoreImage
import CoreImage.CIFilterBuiltins
import SwiftUI
import UIKit

/// Renders a scannable QR code for a card payload.
struct QRCodeImage: View {
    let payload: String
    var size: CGFloat = 220

    private var image: UIImage? {
        QRCodeRenderer.shared.image(for: payload)
    }

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .interpolation(.none)
                    .resizable()
                    .scaledToFit()
            } else {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Theme.surfaceHigh)
                    .overlay {
                        Image(systemName: "qrcode")
                            .font(.system(size: size * 0.4))
                            .foregroundStyle(Theme.textTertiary)
                    }
            }
        }
        .frame(width: size, height: size)
        .accessibilityLabel("Exchange code")
    }
}

/// Caches the CoreImage pipeline so repeated renders stay cheap.
final class QRCodeRenderer {
    static let shared = QRCodeRenderer()

    private let context = CIContext()
    private let filter = CIFilter.qrCodeGenerator()
    private var cache: [String: UIImage] = [:]

    private init() {}

    func image(for payload: String) -> UIImage? {
        if let cached = cache[payload] { return cached }

        filter.message = Data(payload.utf8)
        filter.correctionLevel = "M"

        guard let output = filter.outputImage else { return nil }
        let scaled = output.transformed(by: CGAffineTransform(scaleX: 12, y: 12))
        guard let cgImage = context.createCGImage(scaled, from: scaled.extent) else { return nil }

        let image = UIImage(cgImage: cgImage)
        cache[payload] = image
        return image
    }
}
