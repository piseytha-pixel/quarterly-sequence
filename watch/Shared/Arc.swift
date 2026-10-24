import Foundation

/// QS Kingdom's Arcana prediction (sum rule, "QS Bright"), ported from the web app.
/// All cycle times are New York time. Q = ((A + B + C - 1) mod 4) + 1.
enum Arc {
    static let ny = TimeZone(identifier: "America/New_York")!
    static let cal: Calendar = { var c = Calendar(identifier: .gregorian); c.timeZone = ny; return c }()
    static let MIN: Int64 = 60_000, HOUR: Int64 = 3_600_000, DAY: Int64 = 86_400_000
    static let MICRO: Int64 = 1_350_000, NANO: Int64 = 337_500, PICO: Int64 = 84_375
    static var fridayWrap = true

    struct Z { let year, month, day, hour, minute, second, wd: Int }   // wd: 0 = Sunday … 6 = Saturday
    struct D { let y, m, d: Int }

    static func now() -> Int64 { Int64((Date().timeIntervalSince1970 * 1000).rounded(.down)) }
    static func date(_ t: Int64) -> Date { Date(timeIntervalSince1970: Double(t) / 1000) }
    static func z(_ t: Int64) -> Z {
        let c = cal.dateComponents([.year, .month, .day, .hour, .minute, .second, .weekday], from: date(t))
        return Z(year: c.year!, month: c.month!, day: c.day!, hour: c.hour!, minute: c.minute!, second: c.second!, wd: c.weekday! - 1)
    }
    static func ms(_ y: Int, _ mo: Int, _ d: Int, _ h: Int, _ mi: Int = 0, _ s: Int = 0) -> Int64 {
        var dc = DateComponents(); dc.year = y; dc.month = mo; dc.day = d; dc.hour = h; dc.minute = mi; dc.second = s
        return Int64((cal.date(from: dc)!.timeIntervalSince1970 * 1000).rounded())
    }
    static func ms(_ d: D, _ h: Int) -> Int64 { ms(d.y, d.m, d.d, h) }
    /// a calendar date plus n days
    static func add(_ d: D, _ n: Int) -> D {
        var u = Calendar(identifier: .gregorian); u.timeZone = TimeZone(identifier: "UTC")!
        let base = u.date(from: DateComponents(year: d.y, month: d.m, day: d.d, hour: 12))!
        let c = u.dateComponents([.year, .month, .day], from: u.date(byAdding: .day, value: n, to: base)!)
        return D(y: c.year!, m: c.month!, d: c.day!)
    }
    static func dayOf(_ x: Z) -> D { D(y: x.year, m: x.month, d: x.day) }
    static func weekday(_ d: D) -> Int { // 0 = Sunday
        var u = Calendar(identifier: .gregorian); u.timeZone = TimeZone(identifier: "UTC")!
        return u.component(.weekday, from: u.date(from: DateComponents(year: d.y, month: d.m, day: d.d, hour: 12))!) - 1
    }

    static func cmeWeekSunday(_ t: Int64) -> Int64 {
        let x = z(t); let back = x.wd == 0 ? (x.hour >= 18 ? 0 : 7) : x.wd
        return ms(add(dayOf(x), -back), 18)
    }
    static func cmeWeekMonday(_ t: Int64) -> Int64 { cmeWeekSunday(t) + 6 * HOUR }
    static func addWeeks(_ t: Int64, _ w: Int) -> Int64 { ms(add(dayOf(z(t)), 7 * w), 18) }
    static func firstSunday(_ yr: Int, _ mo: Int) -> Int64 {
        for d in 1...7 where weekday(D(y: yr, m: mo, d: d)) == 0 { return ms(yr, mo, d, 18) }
        fatalError("no sunday")
    }

    // ── calendar anchors ──
    final class YB { let ts: Int64, q: Int, yr: Int; var qb: [Int64]? = nil; init(_ ts: Int64, _ q: Int, _ yr: Int) { self.ts = ts; self.q = q; self.yr = yr } }
    struct YS { let ts: Int64, yr: Int }
    static var anchorYear = 0
    static var yearStarts: [YS] = []
    static var yearly: [YB] = []

    static func anchors(_ t: Int64) {
        let y0 = z(t).year
        if y0 == anchorYear { return }
        var ys: [YS] = [], yb: [YB] = []
        for yr in (y0 - 24)...(y0 + 24) {
            ys.append(YS(ts: firstSunday(yr, 1), yr: yr))
            for (i, mo) in [1, 4, 7, 10].enumerated() { yb.append(YB(firstSunday(yr, mo), i + 1, yr)) }
        }
        ys.sort { $0.ts < $1.ts }; yb.sort { $0.ts < $1.ts }
        for i in 0..<(yb.count - 1) {
            let a = yb[i].ts, n = yb[i + 1].ts
            var qb: [Int64] = [a, 0, 0, 0, n]
            let w = [0, 3, 6, 9]
            for k in 1...3 { let x = addWeeks(a, w[k]); qb[k] = x < n ? x : n }
            yb[i].qb = qb
        }
        yearStarts = ys; yearly = yb; anchorYear = y0
    }
    static func bIdx(_ keys: [Int64], _ ts: Int64) -> Int {
        if keys.isEmpty || ts < keys[0] { return -1 }
        var lo = 0, hi = keys.count - 1
        while lo < hi { let m = (lo + hi + 1) >> 1; if keys[m] <= ts { lo = m } else { hi = m - 1 } }
        return lo
    }
    static func ybIdx(_ t: Int64) -> Int { anchors(t); return bIdx(yearly.map { $0.ts }, t) }
    static func ysIdx(_ t: Int64) -> Int { anchors(t); return bIdx(yearStarts.map { $0.ts }, t) }

    static func quadQ(_ yr: Int) -> Int { (((yr - 2023) % 4) + 4) % 4 + 1 }
    static func weeklyQ(_ t: Int64) -> Int { let x = z(t); let cd = x.hour >= 18 ? (x.wd + 1) % 7 : x.wd; return (1...4).contains(cd) ? cd : 0 }
    static func monthlyQ(_ t: Int64) -> Int { let d = z(cmeWeekMonday(t)).day; return d <= 7 ? 1 : d <= 14 ? 2 : d <= 21 ? 3 : 4 }
    static func yearlyQ(_ t: Int64) -> Int { let i = ybIdx(t); return i < 0 ? 0 : yearly[i].q }
    static func quarterlyQ(_ t: Int64) -> Int {
        let i = ybIdx(t); if i < 0 { return 0 }
        guard let qb = yearly[i].qb else { return 0 }
        for k in stride(from: 3, through: 1, by: -1) where t >= qb[k] { return k + 1 }
        return 1
    }
    static func quadrennialQ(_ t: Int64) -> Int { let i = ysIdx(t); return i < 0 ? 0 : quadQ(yearStarts[i].yr) }

    /// the current quarter of every level (nil = no quarter, e.g. Friday on the weekly cycle)
    static func clock(_ t: Int64) -> [String: Int?] {
        let x = z(t), h = x.hour
        let session = h >= 18 ? 1 : h < 6 ? 2 : h < 12 ? 3 : 4
        let sh = h >= 18 ? 18 : h < 6 ? 0 : h < 12 ? 6 : 12
        var rem = t - ms(x.year, x.month, x.day, sh)
        let b90 = Int(rem / (90 * MIN)); let m90 = min(b90 + 1, 4); rem -= Int64(b90) * 90 * MIN
        let bMi = Int(rem / MICRO); rem -= Int64(bMi) * MICRO
        let bNa = Int(rem / NANO); rem -= Int64(bNa) * NANO
        let bPi = Int(rem / PICO)
        func n(_ v: Int) -> Int? { v == 0 ? nil : v }
        return ["quad": n(quadrennialQ(t)), "yearly": n(yearlyQ(t)), "quarterly": n(quarterlyQ(t)),
                "monthly": n(monthlyQ(t)), "weekly": n(weeklyQ(t)), "session": session, "m90": m90,
                "micro": min(bMi + 1, 4), "nano": min(bNa + 1, 4), "pico": min(bPi + 1, 4)]
    }

    /// start of each quarter of one level + its end: [s1, s2, s3, s4, end]
    static func bounds(_ key: String, _ t: Int64) -> [Int64] {
        let x = z(t), h = x.hour
        let sh = h >= 18 ? 18 : h < 6 ? 0 : h < 12 ? 6 : 12
        let sess = ms(x.year, x.month, x.day, sh)
        let b90 = min(Int((t - sess) / (90 * MIN)), 3); let m90 = sess + Int64(b90) * 90 * MIN
        let bmi = min(Int((t - m90) / MICRO), 3); let mic = m90 + Int64(bmi) * MICRO
        let bna = min(Int((t - mic) / NANO), 3); let nan = mic + Int64(bna) * NANO
        func lin(_ s: Int64, _ u: Int64) -> [Int64] { (0...4).map { s + Int64($0) * u } }
        switch key {
        case "pico": return lin(nan, PICO)
        case "nano": return lin(mic, NANO)
        case "micro": return lin(m90, MICRO)
        case "m90": return lin(sess, 90 * MIN)
        case "day":
            let c = h >= 18 ? dayOf(x) : add(dayOf(x), -1); let s = ms(c, 18)
            return (0...4).map { s + Int64($0) * 6 * HOUR }
        case "week":
            let sun = dayOf(z(cmeWeekSunday(t)))
            return (0...4).map { ms(add(sun, $0), 18) }
        case "month":
            let mon = z(cmeWeekMonday(t)); let s = monthCycleStart(mon.year, mon.month)
            let nyy = mon.month == 12 ? mon.year + 1 : mon.year, nm = mon.month == 12 ? 1 : mon.month + 1
            return [s, addWeeks(s, 1), addWeeks(s, 2), addWeeks(s, 3), monthCycleStart(nyy, nm)]
        default: fatalError(key)
        }
    }
    static func monthCycleStart(_ yr: Int, _ mo: Int) -> Int64 {
        for d in 1...7 where weekday(D(y: yr, m: mo, d: d)) == 1 { return cmeWeekSunday(ms(yr, mo, d, 12)) }
        fatalError("no monday")
    }

    static let ROWS: [(String, [String])] = [
        ("month", ["quad", "yearly", "quarterly"]),
        ("week", ["yearly", "quarterly", "monthly"]),
        ("day", ["quarterly", "monthly", "weekly"]),
        ("m90", ["monthly", "weekly", "@day"]),
        ("micro", ["weekly", "@day", "@m90"]),
        ("nano", ["@day", "@m90", "@micro"]),
        ("pico", ["@m90", "@micro", "@nano"])]

    static func friDay(_ t: Int64) -> Bool { z(bounds("day", t)[0] + 7 * HOUR).wd == 5 }

    /// the predicted High - Low quarter of every level (sum rule)
    static func focus(_ t: Int64) -> [String: Int] {
        var c = clock(t)
        if fridayWrap, (c["weekly"] ?? nil) == nil, (c["monthly"] ?? nil) != nil, friDay(t) { c["weekly"] = 1 }
        var out: [String: Int] = [:]
        for (key, ins) in ROWS {
            var sum = 0, ok = true
            for k in ins {
                let v: Int? = k.hasPrefix("@") ? out[String(k.dropFirst())] : (c[k] ?? nil)
                if let v = v { sum += v } else { ok = false }
            }
            if ok { out[key] = ((sum - 1) % 4) + 1 }
        }
        return out
    }

    struct Blk { let s: Int64, e: Int64, q: Int, b: [Int64] }
    struct PathP { let d0: Int64, day: [Int64], S: Blk, M: Blk, C: Blk, Na: Blk, Pi: Blk }

    /// the next (or current) predicted day: session → 90 min → Micro → Nano → Pico
    static func path(_ n: Int64) -> PathP? {
        var d0 = bounds("day", n)[0]
        for _ in 0..<10 {
            let b = bounds("day", d0 + 1000)
            if let f = focus(d0 + 1000)["day"], b[f] > n {
                let S = Blk(s: b[f - 1], e: b[f], q: f, b: b)
                func sub(_ key: String, _ p: Blk) -> Blk {
                    let bb = bounds(key, p.s + 1000); let q = focus(bb[0] + 1000)[key] ?? 1
                    return Blk(s: bb[q - 1], e: bb[q], q: q, b: bb)
                }
                let M = sub("m90", S), C = sub("micro", M), Na = sub("nano", C), Pi = sub("pico", Na)
                return PathP(d0: d0, day: b, S: S, M: M, C: C, Na: Na, Pi: Pi)
            }
            d0 = bounds("day", b[4] + 1000)[0]
        }
        return nil
    }

    // ── Year / Quarter / Month (16-year and 64-year cycles above the 4-year, anchored at 2023) ──
    static func fdiv(_ a: Int, _ b: Int) -> Int { Int((Double(a) / Double(b)).rounded(.down)) }
    static func c16Q(_ yr: Int) -> Int { ((fdiv(yr - 2023, 4) % 4) + 4) % 4 + 1 }
    static func c64Q(_ yr: Int) -> Int { ((fdiv(yr - 2023, 16) % 4) + 4) % 4 + 1 }
    static func sumQ(_ a: Int, _ b: Int, _ c: Int) -> Int { ((a + b + c - 1) % 4) + 1 }
    static func yrOf(_ t: Int64) -> Int? { let i = ysIdx(t); return i < 0 ? nil : yearStarts[i].yr }
    static func yrBounds(_ yr: Int) -> [Int64]? {
        let b = yearly.filter { $0.yr == yr }.sorted { $0.ts < $1.ts }
        guard b.count == 4, let n = yearly.first(where: { $0.yr == yr + 1 && $0.q == 1 }) else { return nil }
        return [b[0].ts, b[1].ts, b[2].ts, b[3].ts, n.ts]
    }
    static func yearPlan(_ yr: Int) -> Blk? { guard let b = yrBounds(yr) else { return nil }; let q = sumQ(c64Q(yr), c16Q(yr), quadQ(yr)); return Blk(s: b[q - 1], e: b[q], q: q, b: b) }
    static func qtrPlan(_ i: Int) -> Blk? {
        guard i >= 0, i < yearly.count, let b = yearly[i].qb else { return nil }
        let y = yearly[i]; let q = sumQ(c16Q(y.yr), quadQ(y.yr), y.q); return Blk(s: b[q - 1], e: b[q], q: q, b: b)
    }
    static func monPlan(_ t: Int64) -> Blk? { let b = bounds("month", t); guard let q = focus(b[0] + 1000)["month"] else { return nil }; return Blk(s: b[q - 1], e: b[q], q: q, b: b) }

    static let SESS = ["", "ASIA", "LONDON", "NY AM", "NY PM"]
    static let SESS_S = ["", "ASIA", "LDN", "NY AM", "NY PM"]
    static let DAYS = ["", "MON", "TUE", "WED", "THU"]
    static let WD = ["SUN", "MON", "TUE", "WED", "THU", "FRI", "SAT"]
    static func hhmm(_ t: Int64) -> String { let x = z(t); return String(format: "%02d:%02d", x.hour, x.minute) }
    static func higher(_ t: Int64) -> String {
        var out: [String] = []
        if let yr = yrOf(t), let y = yearPlan(yr) { out.append("YEAR Q\(y.q)") }
        if let q = qtrPlan(ybIdx(t)) { out.append("QTR Q\(q.q)") }
        if let m = monPlan(t) { out.append("MONTH Q\(m.q)") }
        return out.joined(separator: " · ")
    }
    static func dur(_ ms: Int64) -> String {
        let m = ms / MIN, h = m / 60, d = h / 24
        return m < 60 ? "\(m)m" : h < 24 ? "\(h)h \(m % 60)m" : "\(d)d \(h % 24)h"
    }
}
