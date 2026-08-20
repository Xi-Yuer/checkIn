import SwiftUI
import UIKit

enum PlanetTheme {
    static let violet = Color(hex: "#7C3AED")
    static let lavender = Color(hex: "#A788FA")
    static let softViolet = Color(hex: "#EEE7FF")
    static let gold = Color(hex: "#FDBA74")
    static let yellow = Color(hex: "#FDE68A")
    static let mint = Color(hex: "#34D399")
    static let coral = Color(hex: "#FB7185")
    static let sky = Color(hex: "#7DD3FC")

    static let background = Color.dynamic(
        light: UIColor(red: 0.973, green: 0.965, blue: 0.996, alpha: 1),
        dark: UIColor(red: 0.059, green: 0.047, blue: 0.122, alpha: 1)
    )
    static let surface = Color.dynamic(
        light: UIColor(red: 0.998, green: 0.996, blue: 1, alpha: 1),
        dark: UIColor(red: 0.105, green: 0.086, blue: 0.190, alpha: 1)
    )
    static let elevatedSurface = Color.dynamic(
        light: UIColor(red: 0.958, green: 0.944, blue: 0.992, alpha: 1),
        dark: UIColor(red: 0.153, green: 0.122, blue: 0.258, alpha: 1)
    )
    static let mutedSurface = Color.dynamic(
        light: UIColor(red: 0.976, green: 0.968, blue: 0.996, alpha: 1),
        dark: UIColor(red: 0.124, green: 0.102, blue: 0.216, alpha: 1)
    )
    static let primaryText = Color.dynamic(
        light: UIColor(red: 0.105, green: 0.078, blue: 0.190, alpha: 1),
        dark: UIColor(red: 0.965, green: 0.949, blue: 0.996, alpha: 1)
    )
    static let secondaryText = Color.dynamic(
        light: UIColor(red: 0.357, green: 0.314, blue: 0.482, alpha: 1),
        dark: UIColor(red: 0.719, green: 0.682, blue: 0.824, alpha: 1)
    )
    static let separator = Color.dynamic(
        light: UIColor(red: 0.858, green: 0.823, blue: 0.941, alpha: 1),
        dark: UIColor(red: 0.251, green: 0.216, blue: 0.373, alpha: 1)
    )

    enum Radius {
        static let card: CGFloat = 26
        static let nest: CGFloat = 22
        static let bubble: CGFloat = 18
        static let chip: CGFloat = 16
    }
}

extension Color {
    init(hex: String) {
        let value = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var integer: UInt64 = 0
        Scanner(string: value).scanHexInt64(&integer)
        let red, green, blue: UInt64
        switch value.count {
        case 3:
            (red, green, blue) = ((integer >> 8) * 17, (integer >> 4 & 0xF) * 17, (integer & 0xF) * 17)
        default:
            (red, green, blue) = (integer >> 16, integer >> 8 & 0xFF, integer & 0xFF)
        }
        self.init(.sRGB, red: Double(red) / 255, green: Double(green) / 255, blue: Double(blue) / 255)
    }

    static func dynamic(light: UIColor, dark: UIColor) -> Color {
        Color(UIColor { traits in traits.userInterfaceStyle == .dark ? dark : light })
    }
}

struct PlanetBackground: View {
    var body: some View {
        PlanetAtmosphere()
    }
}

struct PlanetAtmosphere: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [PlanetTheme.elevatedSurface, PlanetTheme.background, PlanetTheme.surface],
                startPoint: .top,
                endPoint: .bottom
            )

            Circle()
                .fill(PlanetTheme.lavender.opacity(0.22))
                .frame(width: 240, height: 240)
                .blur(radius: 42)
                .offset(x: 150, y: -90)
                .accessibilityHidden(true)

            Circle()
                .fill(PlanetTheme.yellow.opacity(0.16))
                .frame(width: 170, height: 170)
                .blur(radius: 46)
                .offset(x: -140, y: 70)
                .accessibilityHidden(true)

            Starfield(
                primaryColor: PlanetTheme.lavender,
                accentColor: PlanetTheme.yellow,
                starCount: 12,
                opacity: 0.16
            )
        }
        .ignoresSafeArea()
    }
}

struct PlanetPanelModifier: ViewModifier {
    var padding: CGFloat = 16

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(PlanetTheme.surface)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(PlanetTheme.separator.opacity(0.75), lineWidth: 1)
            }
    }
}

struct SoftCardModifier: ViewModifier {
    var radius: CGFloat = PlanetTheme.Radius.card
    var fill: Color = PlanetTheme.surface
    var shadowOpacity: Double = 0.10

    func body(content: Content) -> some View {
        content
            .background(fill)
            .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
            .shadow(color: PlanetTheme.violet.opacity(shadowOpacity), radius: 18, y: 8)
    }
}

struct QCardModifier: ViewModifier {
    var padding: CGFloat = 18

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(PlanetTheme.surface.opacity(0.97))
            .clipShape(RoundedRectangle(cornerRadius: PlanetTheme.Radius.card, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: PlanetTheme.Radius.card, style: .continuous)
                    .stroke(PlanetTheme.separator.opacity(0.4), lineWidth: 1)
            }
            .shadow(color: PlanetTheme.violet.opacity(0.08), radius: 18, y: 8)
    }
}

extension View {
    func planetPanel(padding: CGFloat = 16) -> some View {
        modifier(PlanetPanelModifier(padding: padding))
    }

    func softCard(
        radius: CGFloat = PlanetTheme.Radius.card,
        fill: Color = PlanetTheme.surface,
        shadowOpacity: Double = 0.10
    ) -> some View {
        modifier(SoftCardModifier(radius: radius, fill: fill, shadowOpacity: shadowOpacity))
    }

    func qCard(padding: CGFloat = 18) -> some View {
        modifier(QCardModifier(padding: padding))
    }
}

struct QActionButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(.headline, design: .rounded, weight: .bold))
            .foregroundStyle(Color.white)
            .frame(maxWidth: .infinity, minHeight: 52)
            .background(isEnabled ? PlanetTheme.violet : PlanetTheme.separator)
            .clipShape(Capsule())
            .shadow(color: isEnabled ? PlanetTheme.violet.opacity(0.22) : .clear, radius: 10, y: 4)
            .opacity(configuration.isPressed ? 0.86 : 1)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.easeOut(duration: 0.16), value: configuration.isPressed)
    }
}

struct PrimaryActionButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(Color.white)
            .frame(maxWidth: .infinity, minHeight: 52)
            .background(isEnabled ? PlanetTheme.violet : PlanetTheme.separator)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .opacity(configuration.isPressed ? 0.82 : 1)
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .animation(.easeOut(duration: 0.16), value: configuration.isPressed)
    }
}

struct ProgressRing: View {
    let progress: Double
    var lineWidth: CGFloat = 8
    var size: CGFloat = 68
    var color: Color = PlanetTheme.violet

    var body: some View {
        ZStack {
            Circle().stroke(color.opacity(0.16), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: max(0, min(1, progress)))
                .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Text(progress, format: .percent.precision(.fractionLength(0)))
                .font(.system(.caption, design: .rounded, weight: .bold))
                .foregroundStyle(PlanetTheme.primaryText)
        }
        .frame(width: size, height: size)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("完成进度")
        .accessibilityValue(Text(progress, format: .percent.precision(.fractionLength(0))))
    }
}

enum MascotMood {
    case ready
    case reading
    case resting
    case celebrating
    case charting
}

struct MascotView: View {
    let mood: MascotMood
    var size: CGFloat = 132

    private var assetName: String {
        switch mood {
        case .ready: "MascotReady"
        case .reading: "MascotReading"
        case .resting: "MascotResting"
        case .celebrating: "MascotCelebrating"
        case .charting: "MascotCharting"
        }
    }

    private var accessory: String {
        switch mood {
        case .ready: "star.fill"
        case .reading: "book.closed.fill"
        case .resting: "moon.stars.fill"
        case .celebrating: "trophy.fill"
        case .charting: "chart.bar.fill"
        }
    }

    var body: some View {
        ZStack {
            if let image = UIImage(named: assetName) {
                Image(uiImage: image)
                    .resizable()
                    .renderingMode(.original)
                    .scaledToFit()
                    .frame(width: size, height: size)
            } else {
                fallbackMascot
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }

    private var fallbackMascot: some View {
        ZStack {
            Ellipse()
                .fill(PlanetTheme.lavender.opacity(0.20))
                .frame(width: size * 0.95, height: size * 0.28)
                .offset(y: size * 0.34)
            Circle()
                .fill(PlanetTheme.violet.opacity(0.14))
                .frame(width: size * 0.86)
                .overlay {
                    Circle()
                        .stroke(PlanetTheme.lavender.opacity(0.65), lineWidth: 2)
                }
            Circle()
                .fill(Color(hex: "#FFF8ED"))
                .frame(width: size * 0.66)
                .overlay(alignment: .top) {
                    Capsule()
                        .fill(Color(hex: "#382343"))
                        .frame(width: size * 0.42, height: size * 0.16)
                        .offset(y: size * 0.12)
                }
                .overlay {
                    HStack(spacing: size * 0.16) {
                        Circle().fill(Color(hex: "#382343")).frame(width: size * 0.055)
                        Circle().fill(Color(hex: "#382343")).frame(width: size * 0.055)
                    }
                    .offset(y: size * 0.05)
                }
            Image(systemName: accessory)
                .font(.system(size: size * 0.24, weight: .bold))
                .symbolRenderingMode(.palette)
                .foregroundStyle(PlanetTheme.gold, PlanetTheme.violet)
                .offset(x: size * 0.33, y: -size * 0.28)
            Image(systemName: "sparkle")
                .font(.system(size: size * 0.13, weight: .bold))
                .foregroundStyle(PlanetTheme.yellow)
                .offset(x: -size * 0.40, y: -size * 0.30)
        }
    }
}

struct EmptyStateView: View {
    let mood: MascotMood
    let title: String
    let message: String
    var actionTitle: String?
    var action: (() -> Void)?

    var body: some View {
        VStack(spacing: 16) {
            MascotView(mood: mood, size: 124)
            VStack(spacing: 6) {
                Text(title)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(PlanetTheme.primaryText)
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(PlanetTheme.secondaryText)
                    .multilineTextAlignment(.center)
            }
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .buttonStyle(.borderedProminent)
                    .tint(PlanetTheme.violet)
                    .controlSize(.large)
            }
        }
        .frame(maxWidth: 360)
        .padding(.horizontal, 24)
        .padding(.vertical, 28)
    }
}

struct CelebrationOverlay: View {
    let habit: TaskDTO
    let reduceMotion: Bool
    let dismiss: () -> Void

    @State private var visible = false

    private let artAspect: CGFloat = 864 / 973

    var body: some View {
        ZStack {
            Color.black.opacity(0.38)
                .ignoresSafeArea()
                .onTapGesture(perform: dismiss)

            GeometryReader { geo in
                let fittedWidth = fittedArtWidth(in: geo.size)

                Image("CelebrationPopup")
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
                    .frame(width: fittedWidth)
                    .overlay { contentOverlay }
                    .position(x: geo.size.width / 2, y: geo.size.height / 2)
                    .scaleEffect(visible ? 1 : 0.94)
                    .opacity(visible ? 1 : 0)
            }
        }
        .transition(.opacity)
        .task {
            withAnimation(.easeOut(duration: reduceMotion ? 0.20 : 0.75)) {
                visible = true
            }
        }
    }

    private func fittedArtWidth(in size: CGSize) -> CGFloat {
        let inset: CGFloat = size.width >= 700 ? 96 : 24
        let maxWidth = min(size.width - inset * 2, 400)
        let maxHeight = max(size.height - 32, 240)
        return min(maxWidth, maxHeight * artAspect)
    }

    private var contentOverlay: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let height = geo.size.height
            let titleSize = clamped(width * 0.068, 16, 24)
            let nameSize = clamped(width * 0.045, 12, 17)
            let actionSize = clamped(width * 0.048, 14, 18)

            Text("今日星光已点亮")
                .font(.system(size: titleSize, weight: .heavy, design: .rounded))
                .foregroundStyle(PlanetTheme.primaryText)
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.75)
                .lineLimit(1)
                .frame(width: width * 0.64)
                .position(x: width * 0.48, y: height * 0.615)

            Text(habit.title)
                .font(.system(size: nameSize, weight: .medium, design: .rounded))
                .foregroundStyle(PlanetTheme.secondaryText)
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.7)
                .lineLimit(2)
                .frame(width: width * 0.62)
                .position(x: width * 0.48, y: height * 0.69)

            Button(action: dismiss) {
                Text("太棒了")
                    .font(.system(size: actionSize, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .frame(width: width * 0.50, height: height * 0.105)
                    .contentShape(Capsule())
            }
            .buttonStyle(.plain)
            .position(x: width * 0.485, y: height * 0.813)
            .accessibilityLabel("太棒了")
        }
        .allowsHitTesting(true)
    }

    private func clamped(_ value: CGFloat, _ minValue: CGFloat, _ maxValue: CGFloat) -> CGFloat {
        min(maxValue, max(minValue, value))
    }
}
