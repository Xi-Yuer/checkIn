import ACarousel
import SwiftUI

struct OnboardingView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let onComplete: () -> Void

    @State private var selectedPage = 0

    private let pages = OnboardingPage.all

    var body: some View {
        ZStack(alignment: .bottom) {
            ACarousel(
                pages,
                index: $selectedPage,
                spacing: 0,
                headspace: 0,
                sidesScaling: 1,
                isWrap: false
            ) { page in
                OnboardingPageView(page: page)
            }
            .ignoresSafeArea()
            .accessibilityIdentifier("onboarding.carousel")

            Button(action: advance) {
                Text(L10n.text(currentPage.buttonTitle))
            }
            .buttonStyle(
                OnboardingActionButtonStyle(
                    fill: currentPage.buttonFill,
                    foreground: currentPage.buttonForeground
                )
            )
            .accessibilityIdentifier("onboarding.primaryAction")
            .padding(.horizontal, 28)
            .padding(.bottom, 28)
        }
        .background(currentPage.fallbackBackground.ignoresSafeArea())
        .animation(reduceMotion ? nil : .easeOut(duration: 0.28), value: selectedPage)
    }

    private var currentPage: OnboardingPage {
        pages[selectedPage]
    }

    private func advance() {
        guard selectedPage < pages.count - 1 else {
            onComplete()
            return
        }
        if reduceMotion {
            selectedPage += 1
        } else {
            withAnimation(.easeOut(duration: 0.32)) {
                selectedPage += 1
            }
        }
    }
}

private struct OnboardingPage: Identifiable {
    let id: Int
    let asset: String
    let buttonTitle: String
    let buttonFill: Color
    let buttonForeground: Color
    let fallbackBackground: Color
    let accessibilityLabel: String

    static let yellowFill = Color(hex: "#FDDD6D")
    static let purpleFill = Color(hex: "#9372F4")
    static let yellowForeground = Color(hex: "#3B1F72")

    static let all: [OnboardingPage] = [
        OnboardingPage(
            id: 0,
            asset: "OnboardingGuide1",
            buttonTitle: "开始打卡之旅",
            buttonFill: yellowFill,
            buttonForeground: yellowForeground,
            fallbackBackground: Color(hex: "#5B3BC4"),
            accessibilityLabel: "打卡小星球，养成好习惯，每天进步一点点"
        ),
        OnboardingPage(
            id: 1,
            asset: "OnboardingGuide2",
            buttonTitle: "下一步",
            buttonFill: purpleFill,
            buttonForeground: .white,
            fallbackBackground: Color(hex: "#F8F3EE"),
            accessibilityLabel: "制定目标，设定你的目标，让每一天更有方向"
        ),
        OnboardingPage(
            id: 2,
            asset: "OnboardingGuide3",
            buttonTitle: "下一步",
            buttonFill: purpleFill,
            buttonForeground: .white,
            fallbackBackground: Color(hex: "#F8F3EE"),
            accessibilityLabel: "坚持打卡，每天完成打卡，积累小小的成就"
        ),
        OnboardingPage(
            id: 3,
            asset: "OnboardingGuide4",
            buttonTitle: "开始体验",
            buttonFill: purpleFill,
            buttonForeground: .white,
            fallbackBackground: Color(hex: "#F8F3EE"),
            accessibilityLabel: "收获成长，见证你的蜕变，成为更好的自己"
        )
    ]
}

private struct OnboardingPageView: View {
    let page: OnboardingPage

    var body: some View {
        GeometryReader { proxy in
            Image(page.asset)
                .resizable()
                .scaledToFill()
                .frame(width: proxy.size.width, height: proxy.size.height)
                .clipped()
        }
        .ignoresSafeArea()
        .accessibilityElement()
        .accessibilityLabel(L10n.text(page.accessibilityLabel))
        .accessibilityIdentifier("onboarding.page.\(page.id)")
    }
}

private struct OnboardingActionButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let fill: Color
    let foreground: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(.title2, design: .rounded, weight: .bold))
            .foregroundStyle(foreground)
            .frame(maxWidth: .infinity, minHeight: 108)
            .background(fill)
            .clipShape(Capsule())
            .opacity(configuration.isPressed ? 0.86 : 1)
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.985 : 1)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.16), value: configuration.isPressed)
    }
}
