import SwiftUI
import WatchKit

@main
struct ArcanaApp: App {
    @Environment(\.scenePhase) private var phase
    @AppStorage("fri") private var fri = true

    var body: some Scene {
        WindowGroup { ContentView() }
            .onChange(of: phase) { _, p in
                guard p == .active else { return }
                Arc.fridayWrap = fri
                if !UserDefaults.standard.bool(forKey: "noPrompt") { Task { await Notifier.schedule() } }
                Refresh.plan()
            }
            .backgroundTask(.appRefresh) { _ in
                await Notifier.schedule()
                Refresh.plan()
            }
    }
}

/// Wakes the app now and then to keep the alerts scheduled ahead.
enum Refresh {
    static func plan() {
        WKApplication.shared().scheduleBackgroundRefresh(withPreferredDate: Date().addingTimeInterval(6 * 3600), userInfo: nil) { _ in }
    }
}
