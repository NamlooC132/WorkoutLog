import UIKit

/// Shrinks photos before they are stored – thumbnails only need a few hundred pixels,
/// which keeps the database and JSON backups small.
enum ImageService {
    static func thumbnailData(from image: UIImage, maxDimension: CGFloat = 400) -> Data? {
        let longest = max(image.size.width, image.size.height)
        guard longest > 0 else { return nil }
        let scale = min(1, maxDimension / longest)
        let size = CGSize(width: (image.size.width * scale).rounded(), height: (image.size.height * scale).rounded())

        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let resized = UIGraphicsImageRenderer(size: size, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: size)) // also fixes camera orientation
        }
        return resized.jpegData(compressionQuality: 0.8)
    }
}
