import XCTest

final class CheckInUITests: XCTestCase {
    func testFirstLaunchShowsOnboarding() {
        let app = launchWithFreshOnboarding()

        XCTAssertTrue(app.otherElements["onboarding"].waitForExistence(timeout: 5))
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

        app.otherElements["onboarding"].swipeLeft()
        XCTAssertEqual(primaryAction.label, "下一步")
    }

    private func launchWithFreshOnboarding() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing", "-reset-onboarding"]
        app.launch()
        return app
    }
}
