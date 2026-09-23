import SwiftUI

/// Process entry point.
///
/// Unit tests are hosted by the app bundle. When launched as a test host, the
/// app starts an empty scene so tests never trigger the real UI, network
/// discovery or disk access from application startup.
@main
enum AppEntryPoint {
    @MainActor
    static func main() {
        if ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil {
            TestHostApp.main()
        } else {
            LocalOSXAiApp.main()
        }
    }
}

private struct TestHostApp: App {
    var body: some Scene {
        Settings { EmptyView() }
    }
}
