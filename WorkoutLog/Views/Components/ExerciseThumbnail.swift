import SwiftUI

/// Small rounded exercise picture, or a dumbbell placeholder when there's no photo.
struct ExerciseThumbnail: View {
    let imageData: Data?
    var size: CGFloat = 44

    var body: some View {
        Group {
            if let imageData, let image = UIImage(data: imageData) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                ZStack {
                    Color.accentColor.opacity(0.15)
                    Image(systemName: "dumbbell.fill")
                        .font(.system(size: size * 0.42, weight: .semibold))
                        .foregroundStyle(Color.accentColor)
                }
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: size * 0.26, style: .continuous))
        .accessibilityHidden(true)
    }
}
