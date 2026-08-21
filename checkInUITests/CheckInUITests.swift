import XCTest

final class CheckInUITests: XCTestCase {
    func testFirstLaunchShowsOnboarding() {
        let app = launchWithFreshOnboarding()

        XCTAssertTrue(app.otherElements["onboarding.carousel"].waitForExistence(timeout: 5))
        XCTAssertTrue(
            app.buttons["开始打卡之旅"].exists
                || app.buttons["下一步"].exists
                || app.buttons["开始体验"].exists
        )
    }

    func testPrimaryActionAdvancesOnboardingCarousel() {
        let app = launchWithFreshOnboarding()
        let primaryAction = app.buttons["onboarding.primaryAction"]

        XCTAssertTrue(primaryAction.waitForExistence(timeout: 5))
        XCTAssertEqual(primaryAction.label, "开始打卡之旅")

        primaryAction.tap()
        XCTAssertEqual(primaryAction.label, "下一步")

        primaryAction.tap()
        XCTAssertEqual(primaryAction.label, "下一步")

        primaryAction.tap()
        XCTAssertEqual(primaryAction.label, "开始体验")
    }

    func testSwipeAdvancesOnboardingCarousel() {
        let app = launchWithFreshOnboarding()
        let primaryAction = app.buttons["onboarding.primaryAction"]

        XCTAssertTrue(primaryAction.waitForExistence(timeout: 5))
        XCTAssertEqual(primaryAction.label, "开始打卡之旅")

        app.otherElements["onboarding.carousel"].swipeLeft()
        XCTAssertEqual(primaryAction.label, "下一步")
    }

    func testEnglishOnboardingUsesNaturalCopy() {
        let app = launchWithFreshOnboarding(language: "en", locale: "en_US")
        let primaryAction = app.buttons["onboarding.primaryAction"]

        XCTAssertTrue(primaryAction.waitForExistence(timeout: 5))
        XCTAssertEqual(primaryAction.label, "Get Started")

        primaryAction.tap()
        XCTAssertEqual(primaryAction.label, "Next")
    }

    private func launchWithFreshOnboarding(
        language: String = "zh-Hans",
        locale: String = "zh_CN"
    ) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = [
            "-ui-testing",
            "-reset-onboarding",
            "-AppleLanguages", "(\(language))",
            "-AppleLocale", locale
        ]
        app.launch()
        return app
    }
}
