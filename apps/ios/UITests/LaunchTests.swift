import XCTest
import UIKit
final class LaunchTests:XCTestCase {
    func testLocalInterfaceStartsWithoutHostedServer() {
        let app = XCUIApplication();app.launch()
        XCTAssertTrue(app.webViews.firstMatch.waitForExistence(timeout:30),"Local server should start the bundled interface")
        XCTAssertTrue(app.webViews.buttons["Поиск"].firstMatch.waitForExistence(timeout:20))
        // The intro overlays the page for several seconds; wait for it to finish
        // before tapping a control underneath it.
        // The skip control is not consistently exposed by WKWebView's
        // accessibility tree, so allow the startup animation to finish.
        sleep(6)
        // WebKit can report a hittable point outside this circular button's clipped corners.
        app.webViews.buttons["Поиск"].firstMatch.coordinate(withNormalizedOffset:CGVector(dx:0.5,dy:0.5)).tap()
        XCTAssertTrue(app.webViews.textFields.firstMatch.waitForExistence(timeout:5))
        let screenshot = XCTAttachment(screenshot:app.screenshot());screenshot.name = "CineGram on iPhone simulator";screenshot.lifetime = .keepAlways;add(screenshot)
    }
}

extension LaunchTests {
    func testIPhoneGlassNavigationKeepsCollectionsAndProfileScreensReachable() throws {
        try XCTSkipIf(UIDevice.current.userInterfaceIdiom == .pad, "The floating glass navigation is specific to iPhone")
        let app = XCUIApplication()
        app.launch()
        let web = app.webViews.firstMatch
        XCTAssertTrue(web.waitForExistence(timeout: 30))
        XCTAssertTrue(app.buttons["Подборки"].firstMatch.waitForExistence(timeout: 20))
        // Let the startup overlay finish before interacting with controls below it.
        sleep(6)

        for label in ["Главная", "Подборки", "Профиль", "Поиск"] {
            XCTAssertTrue(app.buttons.matching(identifier: label).allElementsBoundByIndex.contains { $0.isHittable }, "Missing visible navigation button: \(label)")
        }

        tapVisibleButton("Подборки", in: app)
        XCTAssertTrue(web.buttons["Закрыть"].firstMatch.waitForExistence(timeout: 5))
        XCTAssertTrue(web.buttons["Триллер"].firstMatch.waitForExistence(timeout: 5), "Collections should expose the existing genre choices")
        tapVisibleButton("Закрыть", in: web)

        for (destination, screenMarker) in [("Настройки", "Светлая тема"), ("История", "История"), ("Мой список", "Мой список")] {
            tapVisibleButton("Профиль", in: app)
            XCTAssertTrue(web.buttons[destination].firstMatch.waitForExistence(timeout: 5))
            tapVisibleButton(destination, in: web)
            XCTAssertTrue(web.staticTexts[screenMarker].firstMatch.waitForExistence(timeout: 5), "Profile should open \(destination)")
            tapVisibleButton("Главная", in: app)
        }

        tapVisibleButton("Поиск", in: app)
        XCTAssertTrue(web.textFields.firstMatch.waitForExistence(timeout: 5), "Floating search should open the search field")
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "iPhone glass navigation search"
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }

    private func tapVisibleButton(_ label: String, in web: XCUIElement, file: StaticString = #filePath, line: UInt = #line) {
        let matches = web.buttons.matching(identifier: label)
        guard let button = matches.allElementsBoundByIndex.first(where: { $0.isHittable }) else {
            XCTFail("No hittable button named \(label)", file: file, line: line)
            return
        }
        // Center taps avoid clipped corners of circular WebKit buttons.
        button.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
    }
}
