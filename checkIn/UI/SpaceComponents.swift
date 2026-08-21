import SwiftUI

struct Starfield: View {
    var primaryColor: Color = Color.white
    var accentColor: Color = PlanetTheme.yellow
    var starCount = 24
    var opacity = 0.78

    var body: some View {
        GeometryReader { proxy in
            ForEach(0..<clampedStarCount, id: \.self) { index in
                Image(systemName: symbolName(for: index))
                    .font(.system(size: symbolSize(for: index), weight: .bold))
                    .foregroundStyle(index.isMultiple(of: 5) ? accentColor : primaryColor)
                    .opacity(starOpacity(for: index))
                    .rotationEffect(.degrees(Double((index * 29) % 90)))
                    .position(
                        x: normalizedPosition(index: index, multiplier: 37, offset: 13) * proxy.size.width,
                        y: normalizedPosition(index: index, multiplier: 53, offset: 7) * proxy.size.height
                    )
            }
        }
        .opacity(opacity)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private var clampedStarCount: Int {
        max(0, min(starCount, 48))
    }

    private func symbolName(for index: Int) -> String {
        index.isMultiple(of: 6) ? "sparkle" : "circle.fill"
    }

    private func symbolSize(for index: Int) -> CGFloat {
        index.isMultiple(of: 6) ? CGFloat(8 + index % 5) : CGFloat(2 + index % 3)
    }

    private func starOpacity(for index: Int) -> Double {
        0.42 + Double(index % 4) * 0.16
    }

    private func normalizedPosition(index: Int, multiplier: Int, offset: Int) -> CGFloat {
        CGFloat((index * multiplier + offset) % 97 + 2) / 100
    }
}

struct SpaceHeader: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let title: String
    let subtitle: String?
    let mood: MascotMood
    let accent: Color

    init(
        title: String,
        subtitle: String? = nil,
        mood: MascotMood = .ready,
        accent: Color = PlanetTheme.yellow
    ) {
        self.title = title
        self.subtitle = subtitle
        self.mood = mood
        self.accent = accent
    }

    var body: some View {
        ZStack {
            Color(hex: "#352071")

            Starfield(
                primaryColor: Color(hex: "#F8F4FF"),
                accentColor: accent,
                starCount: 16,
                opacity: 0.64
            )

            Circle()
                .stroke(Color.white.opacity(0.10), lineWidth: 18)
                .frame(width: 142, height: 142)
                .offset(x: 116, y: -60)
                .accessibilityHidden(true)

            headerContent
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
        }
        .frame(maxWidth: .infinity, minHeight: dynamicTypeSize.isAccessibilitySize ? 220 : 132)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        }
    }

    @ViewBuilder
    private var headerContent: some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: 12) {
                copy
                MascotView(mood: mood, size: 92)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
        } else {
            HStack(spacing: 16) {
                copy
                Spacer(minLength: 4)
                MascotView(mood: mood, size: 96)
            }
        }
    }

    private var copy: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(L10n.text(title))
                .font(.system(.title2, design: .rounded, weight: .heavy))
                .foregroundStyle(Color(hex: "#FFF9EE"))
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)

            if let subtitle, !subtitle.isEmpty {
                Text(L10n.text(subtitle))
                    .font(.subheadline)
                    .foregroundStyle(Color(hex: "#E5DAFF"))
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
    }
}
