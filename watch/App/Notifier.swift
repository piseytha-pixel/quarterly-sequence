import Foundation
import UserNotifications

/// Local alerts before each predicted High - Low session (15, 5 and 1 min before), for about the next two weeks.
enum Notifier {
    @discardableResult
    static func schedule() async -> Int {
        let c = UNUserNotificationCenter.current()
        let ok = (try? await c.requestAuthorization(options: [.alert, .sound])) ?? false
        c.removeAllPendingNotificationRequests()
        guard ok, UserDefaults.standard.object(forKey: "alerts") as? Bool ?? true else { return 0 }
        let now = Arc.now()
        var n = now, count = 0
        for _ in 0..<16 {
            guard let p = Arc.path(n) else { break }
            let day = Arc.WD[Arc.z(p.S.s + 1000).wd]
            let body = "\(day) \(Arc.hhmm(p.S.s))–\(Arc.hhmm(p.S.e)) NY · 90 min Q\(p.M.q) \(Arc.hhmm(p.M.s)) · Micro Q\(p.C.q) \(Arc.hhmm(p.C.s)). Wait for the SSMT, enter on the tCISD."
            for m in [15, 5, 1] {
                let at = p.S.s - Int64(m) * Arc.MIN
                guard at > now + 5000, count < 60 else { continue }
                let content = UNMutableNotificationContent()
                content.title = "\(Arc.SESS[p.S.q]) High - Low in \(m) min"
                content.body = body
                content.sound = .default
                let trigger = UNTimeIntervalNotificationTrigger(timeInterval: Double(at - now) / 1000, repeats: false)
                try? await c.add(UNNotificationRequest(identifier: "hl-\(p.S.s)-\(m)", content: content, trigger: trigger))
                count += 1
            }
            n = p.S.e + 1000
        }
        return count
    }
}
