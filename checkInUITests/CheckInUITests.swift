import XCTest

final class CheckInUITests: XCTestCase {
    func testFirstLaunchShowsOnboarding() {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing", "-reset-onboarding"]
        app.launch()

        XCTAssertTrue(app.otherElements["onboarding"].waitForExistence(timeout: 5))
        XCTAssertTrue(
            app.buttons["开始打卡之旅"].exists
                || app.buttons["下一步"].exists
                || app.buttons["开始体验"].exists
        )
    }
}
