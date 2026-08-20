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
        ZStack {
            LinearGradient(
                colors: [PlanetTheme.surface, PlanetTheme.background],
                startPoint: .top,
                endPoint: .bottom
            )
            Starfield(
                primaryColor: PlanetTheme.lavender,
                accentColor: PlanetTheme.sky,
                starCount: 18,
                opacity: 0.09
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

extension View {
    func planetPanel(padding: CGFloat = 16) -> some View {
        modifier(PlanetPanelModifier(padding: padding))
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
    let undo: () -> Void
    let dismiss: () -> Void

    @State private var visible = false

    var body: some View {
        ZStack {
            Color.black.opacity(0.30)
                .ignoresSafeArea()
                .onTapGesture(perform: dismiss)
            VStack(spacing: 18) {
                MascotView(mood: .celebrating, size: 148)
                VStack(spacing: 6) {
                    Text("今日星光已点亮")
                        .font(.title2.weight(.heavy))
                    Text(habit.title)
                        .font(.body)
                        .foregroundStyle(PlanetTheme.secondaryText)
                }
                HStack(spacing: 12) {
                    Button("撤销", action: undo)
                        .buttonStyle(.bordered)
                        .tint(PlanetTheme.violet)
                    Button("太棒了", action: dismiss)
                        .buttonStyle(.borderedProminent)
                        .tint(PlanetTheme.violet)
                }
            }
            .padding(28)
            .background(PlanetTheme.surface)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(PlanetTheme.separator, lineWidth: 1)
            }
            .padding(28)
            .scaleEffect(visible ? 1 : 0.94)
            .opacity(visible ? 1 : 0)
        }
        .transition(.opacity)
        .task {
            withAnimation(.easeOut(duration: reduceMotion ? 0.20 : 0.75)) {
                visible = true
            }
        }
    }
}
