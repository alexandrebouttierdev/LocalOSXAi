import XCTest

/// Captures the main screens of the simulated app for visual review.
///
/// Not a regression test: it asserts only that each screen can be reached,
/// and attaches one screenshot per screen. `make ui-snapshots` exports them
/// as PNG files (the test runner is sandboxed and cannot write them itself).
@MainActor
final class UISnapshotTests: XCTestCase {

    func testDarkScreens() {
        capture(appearance: "dark")
    }

    func testLightScreens() {
        capture(appearance: "light")
    }

    private func capture(appearance: String) {
        let app = XCUIApplication()
        app.launchEnvironment["LOCALOSXAI_SIMULATED"] = "1"
        app.launchEnvironment["LOCALOSXAI_DEMO_PROJECT"] = ProcessInfo.processInfo.environment["DEMO_PROJECT"] ?? NSTemporaryDirectory()
        app.launchArguments = ["-appearance", appearance]
        app.launch()
        defer { app.terminate() }
        let window = app.windows.firstMatch
        XCTAssertTrue(window.waitForExistence(timeout: 10))
        save(window, "\(appearance)-0-launch")

        app.typeKey("n", modifierFlags: .command)
        let composer = window.textFields["Message"].firstMatch.exists
            ? window.textFields["Message"].firstMatch : window.textViews["Message"].firstMatch
        XCTAssertTrue(composer.waitForExistence(timeout: 5))
        save(window, "\(appearance)-1-new-session")

        composer.click()
        composer.typeText("Add a --dry-run flag to the export command\n")
        sleep(6)
        save(window, "\(appearance)-2-answer")

        let modelSettings = window.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Model Settings'")).firstMatch
        if modelSettings.waitForExistence(timeout: 3) {
            modelSettings.click()
            sleep(1)
            save(window, "\(appearance)-3-model-settings")
            app.typeKey(.escape, modifierFlags: [])
        }

        app.typeKey(",", modifierFlags: [.option, .command])
        sleep(1)
        save(window, "\(appearance)-4-project-settings")
        app.typeKey(.escape, modifierFlags: [])

        app.typeKey("k", modifierFlags: .command)
        sleep(1)
        save(window, "\(appearance)-5-palette")
        app.typeKey(.escape, modifierFlags: [])

        app.typeKey("3", modifierFlags: .command)
        sleep(1)
        save(window, "\(appearance)-6-changes")

        app.typeKey(",", modifierFlags: .command)
        let settings = app.windows.element(boundBy: 0)
        sleep(2)
        save(settings, "\(appearance)-7-settings-general")
        let providers = settings.toolbars.buttons["Providers"].exists
            ? settings.toolbars.buttons["Providers"] : settings.buttons["Providers"]
        if providers.waitForExistence(timeout: 2) {
            providers.click()
            sleep(1)
            save(settings, "\(appearance)-8-settings-providers")
        }
    }

    private func save(_ element: XCUIElement, _ name: String) {
        let screenshot = element.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
