import SwiftUI
#if os(iOS)
import UIKit
#endif

/// Hareketin iki karesini art arda göstererek nasıl yapıldığını canlandırır.
struct ExerciseAnimationView: View {
    let exercise: Exercise
    var interval: Double = 1.0

    var body: some View {
        let urls = exercise.imageURLs
        TimelineView(.periodic(from: .now, by: interval)) { context in
            let index = urls.isEmpty ? 0 : Int(context.date.timeIntervalSinceReferenceDate / interval) % urls.count
            ZStack {
                ForEach(Array(urls.enumerated()), id: \.offset) { offset, url in
                    RemoteImage(url: url)
                        .opacity(offset == index ? 1 : 0)
                }
            }
            .animation(.easeInOut(duration: 0.35), value: index)
        }
        .aspectRatio(4 / 3, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

struct RemoteImage: View {
    let url: URL?

    var body: some View {
        AsyncImage(url: url) { phase in
            switch phase {
            case .success(let image):
                image.resizable().scaledToFill()
            case .failure:
                placeholder(icon: "wifi.exclamationmark")
            default:
                placeholder(icon: nil)
            }
        }
    }

    private func placeholder(icon: String?) -> some View {
        ZStack {
            Rectangle().fill(Color.secondary.opacity(0.12))
            if let icon {
                Image(systemName: icon).foregroundStyle(.secondary)
            } else {
                ProgressView()
            }
        }
    }
}

struct ExerciseThumbnail: View {
    let exercise: Exercise?
    var size: CGFloat = 52

    var body: some View {
        Group {
            if let url = exercise?.thumbnailURL {
                RemoteImage(url: url)
            } else {
                ZStack {
                    Rectangle().fill(Color.accentColor.opacity(0.15))
                    Image(systemName: "dumbbell.fill").foregroundStyle(Color.accentColor)
                }
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

struct Card<Content: View>: View {
    let title: String?
    let systemImage: String?
    let content: Content

    init(_ title: String? = nil, systemImage: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.systemImage = systemImage
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let title {
                if let systemImage {
                    Label(title, systemImage: systemImage).font(.headline)
                } else {
                    Text(title).font(.headline)
                }
            }
            content
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 16))
    }
}

struct StatTile: View {
    let title: String
    let value: String
    var systemImage: String
    var tint: Color = .accentColor

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: systemImage)
                .foregroundStyle(tint)
                .font(.title3)
            Text(value)
                .font(.title2.bold())
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))
    }
}

struct Chip: View {
    let text: String
    var tint: Color = .accentColor

    var body: some View {
        Text(text)
            .font(.caption.weight(.medium))
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(tint.opacity(0.15), in: Capsule())
            .foregroundStyle(tint)
    }
}

/// Basit akış düzeni (çipleri satırlara sarar).
struct FlowLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, rowHeight: CGFloat = 0, widest: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x + size.width > maxWidth, x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            x += size.width + spacing
            widest = max(widest, x - spacing)
            rowHeight = max(rowHeight, size.height)
        }
        return CGSize(width: widest, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, rowHeight: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX, x > bounds.minX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            view.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

extension View {
    @ViewBuilder
    func inlineNavigationTitle() -> some View {
        #if os(iOS)
        navigationBarTitleDisplayMode(.inline)
        #else
        self
        #endif
    }

    @ViewBuilder
    func decimalKeyboard() -> some View {
        #if os(iOS)
        keyboardType(.decimalPad)
        #else
        self
        #endif
    }

    @ViewBuilder
    func numberKeyboard() -> some View {
        #if os(iOS)
        keyboardType(.numberPad)
        #else
        self
        #endif
    }
}

@MainActor
enum Haptics {
    static func success() {
        #if os(iOS)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        #endif
    }

    static func tap() {
        #if os(iOS)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        #endif
    }
}
