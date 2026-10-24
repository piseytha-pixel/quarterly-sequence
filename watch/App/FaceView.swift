import SwiftUI

enum FaceID: String, CaseIterable, Identifiable {
    case turq, diver, dress, pilot, chrono, champ, digital
    var id: String { rawValue }
    var title: String {
        switch self {
        case .turq: return "Prediction Chrono"; case .diver: return "Diver GMT"; case .dress: return "Dress"
        case .pilot: return "Pilot"; case .chrono: return "Chronograph"; case .champ: return "Champagne"; case .digital: return "Arcana Digital"
        }
    }
    var dial: String? { self == .digital ? nil : "dial_" + rawValue }
}

/// One Arcana face: the dial picture plus everything that moves, drawn on an 800 × 800 grid.
struct FaceView: View {
    let face: FaceID
    @Environment(\.isLuminanceReduced) private var dim

    var body: some View {
        TimelineView(.periodic(from: .now, by: dim ? 60 : 1)) { tl in
            let t = Int64(tl.date.timeIntervalSince1970 * 1000)
            ZStack {
                if !dim, let d = face.dial { Image(d).resizable().scaledToFit() }
                Canvas { ctx, size in
                    let s = min(size.width, size.height) / 800
                    ctx.translateBy(x: (size.width - 800 * s) / 2, y: (size.height - 800 * s) / 2)
                    ctx.scaleBy(x: s, y: s)
                    var d = Painter(ctx: ctx, t: t, now: tl.date)
                    if face == .digital { d.digital(ambient: dim) }
                    else if dim { d.ambient() }
                    else { d.analog(face) }
                }
            }
            .aspectRatio(1, contentMode: .fit)
        }
    }
}

struct Painter {
    var ctx: GraphicsContext
    let t: Int64
    let now: Date
    let CX: CGFloat = 400, CY: CGFloat = 400

    func px(_ r: CGFloat, _ a: Double, _ cx: CGFloat = 400) -> CGFloat { cx + r * CGFloat(sin(a)) }
    func py(_ r: CGFloat, _ a: Double, _ cy: CGFloat = 400) -> CGFloat { cy - r * CGFloat(cos(a)) }
    func P(_ r: CGFloat, _ a: Double, _ cx: CGFloat = 400, _ cy: CGFloat = 400) -> CGPoint { CGPoint(x: px(r, a, cx), y: py(r, a, cy)) }

    func annulus(_ cx: CGFloat, _ cy: CGFloat, _ r0: CGFloat, _ r1: CGFloat, _ a0: Double, _ a1: Double) -> Path {
        var p = Path(); let n = max(6, Int((a1 - a0) / 0.03))
        for i in 0...n { let a = a0 + (a1 - a0) * Double(i) / Double(n); i == 0 ? p.move(to: P(r1, a, cx, cy)) : p.addLine(to: P(r1, a, cx, cy)) }
        for i in stride(from: n, through: 0, by: -1) { let a = a0 + (a1 - a0) * Double(i) / Double(n); p.addLine(to: P(r0, a, cx, cy)) }
        p.closeSubpath(); return p
    }
    func circle(_ cx: CGFloat, _ cy: CGFloat, _ r: CGFloat) -> Path { Path(ellipseIn: CGRect(x: cx - r, y: cy - r, width: 2 * r, height: 2 * r)) }
    func line(_ a: CGPoint, _ b: CGPoint, _ col: Color, _ w: CGFloat, round: Bool = true) {
        var p = Path(); p.move(to: a); p.addLine(to: b)
        ctx.stroke(p, with: .color(col), style: StrokeStyle(lineWidth: w, lineCap: round ? .round : .butt))
    }
    func text(_ s: String, _ x: CGFloat, _ baseline: CGFloat, _ size: CGFloat, _ col: Color, tracking: CGFloat = 0, mono: Bool = false) {
        ctx.draw(Text(s).font(.system(size: size, weight: .bold, design: mono ? .monospaced : .default)).tracking(tracking).foregroundColor(col),
                 at: CGPoint(x: x, y: baseline - size * 0.35), anchor: .center)
    }

    // ── analog faces ──
    mutating func analog(_ f: FaceID) {
        switch f {
        case .diver:
            band(320, 334, HL, 0.45); date(548, 380, "#f7f7f2", "#141a22", true)
            sub(CX, CY + 168, 62, "micro", "90 MIN"); gmtDiver(); diverHands()
        case .dress:
            band(326, 342, "#b8862f", 0.55); date(560, 380, "#ffffff", "#1f2a3a", false)
            sub(CX, CY + 160, 64, "micro", "90 MIN", bg: "#f3eee0", rim: "#b9ab88", hl: "#b8862f", dimA: 0.35, hand: "#1d3b8f", lab: "#6b7280")
            hands(Hand(shape: .dauphine, fill: "#1d3b8f", stroke: "#0c1d4a", sec: "#1d3b8f", cap: "#1d3b8f", hw: 20, mw: 15))
        case .pilot:
            band(334, 350, HL, 0.5); date(568, 380, "#0d0f12", "#f2f2ee", false)
            sub(CX, CY + 150, 62, "micro", "90 MIN"); gmt(330, HL)
            hands(Hand(shape: .sword, fill: "#f2f2ee", stroke: "#1a1d22", sec: "#f2f2ee", cap: "#1a1d22", lume: "#cfe8b8", hl: 165, ml: 262))
        case .chrono:
            band(322, 334, HL, 0.55)
            sub(CX - 140, CY, 74, "day", "DAY", bg: "#1a1f26", rim: "#7d8794")
            sub(CX + 140, CY, 74, "m90", "SESSION", bg: "#1a1f26", rim: "#7d8794")
            sub(CX, CY + 150, 74, "micro", "90 MIN", bg: "#1a1f26", rim: "#7d8794")
            hands(Hand(shape: .baton, fill: "#f6f7f9", stroke: "#1d232b", sec: "#e5484d", cap: "#1d232b", lume: "#1d232b", hw: 16, mw: 12, hl: 175, ml: 265))
        case .champ:
            band(308, 322, "#7a5414", 0.42); date(548, 380, "#fffdf5", "#2a2010", true)
            sub(CX, CY + 158, 60, "micro", "90 MIN", bg: "#e9d7a8", rim: "#8a6420", hl: "#7a5414", dimA: 0.35, hand: "#4a3510", lab: "#6b5220")
            gmt(318, "#7a5414")
            hands(Hand(shape: .baton, fill: "#f6e2a6", stroke: "#7a5a1c", sec: "#7a5414", cap: "#d8b260", lume: "#fff6dc", hw: 18, mw: 13))
        case .turq: turq()
        case .digital: break
        }
    }

    /// the four sessions of the New York trading day as a ring (18:00 at the top), the predicted one lit
    func band(_ r0: CGFloat, _ r1: CGFloat, _ hl: String, _ dimA: Double) {
        let b = Arc.bounds("day", t), f = Arc.focus(b[0] + 1000)["day"]
        let ang = { (x: Int64) in Double(x - b[0]) / Double(24 * Arc.HOUR) * 2 * .pi }
        for q in 1...4 {
            ctx.fill(annulus(CX, CY, r0, r1, ang(b[q - 1]) + 0.008, ang(b[q]) - 0.008), with: .color(q == f ? Color(hex: hl, 0.95) : Color(hex: QC[q], dimA)))
        }
    }

    /// a sub-dial: the 4 quarters of one cycle, the predicted one lit, a hand at now
    func sub(_ cx: CGFloat, _ cy: CGFloat, _ R: CGFloat, _ key: String, _ label: String,
             bg: String = "#070a0e", rim: String = "#3a4350", hl: String = HL, dimA: Double = 0.45, hand: String = "#f2f4f7", lab: String = "#9aa7b8") {
        let b = Arc.bounds(key, t), f = Arc.focus(b[0] + 1000)[key]
        let ang = { (x: Int64) in Double(x - b[0]) / Double(b[4] - b[0]) * 2 * .pi }
        ctx.fill(circle(cx, cy, R), with: .color(Color(hex: bg)))
        ctx.stroke(circle(cx, cy, R), with: .color(Color(hex: rim)), lineWidth: 2)
        for q in 1...4 {
            ctx.fill(annulus(cx, cy, R * 0.64, R * 0.9, ang(b[q - 1]) + 0.05, ang(b[q]) - 0.05), with: .color(q == f ? Color(hex: hl, 0.95) : Color(hex: QC[q], dimA)))
        }
        let a = ang(t)
        line(CGPoint(x: cx, y: cy), P(R * 0.72, a, cx, cy), Color(hex: hand), 3)
        ctx.fill(circle(cx, cy, 4.5), with: .color(Color(hex: hand)))
        let sz = max(8, R * 0.16)
        text(label, cx, cy + R * 0.42 + sz * 0.35, sz, Color(hex: lab), tracking: 1)
    }

    func date(_ x: CGFloat, _ y: CGFloat, _ bg: String, _ fg: String, _ day: Bool) {
        let c = Calendar.current.dateComponents([.weekday, .day], from: now)
        let w: CGFloat = day ? 118 : 54
        let r = Path(roundedRect: CGRect(x: x, y: y, width: w, height: 40), cornerRadius: 4)
        ctx.fill(r, with: .color(Color(hex: bg))); ctx.stroke(r, with: .color(Color(hex: "#9aa3ad")), lineWidth: 2.5)
        if day {
            line(CGPoint(x: x + 64, y: y + 1), CGPoint(x: x + 64, y: y + 39), Color(hex: "#b9c0c8"), 2, round: false)
            text(Arc.WD[(c.weekday ?? 1) - 1], x + 32, y + 28, 21, Color(hex: fg))
            text("\(c.day ?? 1)", x + 91, y + 28, 22, Color(hex: fg))
        } else { text("\(c.day ?? 1)", x + 27, y + 28, 22, Color(hex: fg)) }
    }

    /// the GMT hand: where the New York trading day is on the 24-hour scale
    func gmt(_ len: CGFloat, _ col: String) {
        let b = Arc.bounds("day", t), a = Double(t - b[0]) / Double(24 * Arc.HOUR) * 2 * .pi
        line(CGPoint(x: CX, y: CY), P(len - 20, a), Color(hex: col), 3.5, round: false)
        var p = Path(); p.move(to: P(len, a)); p.addLine(to: P(len - 22, a - 0.035)); p.addLine(to: P(len - 22, a + 0.035)); p.closeSubpath()
        ctx.fill(p, with: .color(Color(hex: col)))
    }
    func gmtDiver() {
        let b = Arc.bounds("day", t), a = Double(t - b[0]) / Double(24 * Arc.HOUR) * 2 * .pi
        line(CGPoint(x: CX, y: CY), P(296, a), Color(hex: HL), 4, round: false)
        var p = Path(); p.move(to: P(318, a)); p.addLine(to: P(296, a - 0.035)); p.addLine(to: P(296, a + 0.035)); p.closeSubpath()
        ctx.fill(p, with: .color(Color(hex: HL))); ctx.stroke(p, with: .color(Color(hex: "#5a3010")), lineWidth: 1.5)
    }

    enum Shape { case sword, dauphine, baton }
    struct Hand {
        var shape: Shape, fill: String, stroke: String, sec: String?, cap: String, lume: String? = nil
        var hw: CGFloat = 24, mw: CGFloat = 17, hl: CGFloat = 170, ml: CGFloat = 255, sl: CGFloat = 275
    }
    func handPath(_ a: Double, _ len: CGFloat, _ w: CGFloat, _ tail: CGFloat, _ shape: Shape) -> Path {
        func pt(_ r: CGFloat, _ side: CGFloat) -> CGPoint { CGPoint(x: px(r, a) + side * w / 2 * CGFloat(cos(a)), y: py(r, a) + side * w / 2 * CGFloat(sin(a))) }
        let pts: [CGPoint]
        switch shape {
        case .dauphine: pts = [P(-tail, a), pt(len * 0.12, -1), P(len, a), pt(len * 0.12, 1)]
        case .baton: pts = [pt(-tail, -1), pt(len, -1), pt(len, 1), pt(-tail, 1)]
        case .sword: pts = [P(-tail, a), pt(0, -1), pt(len * 0.8, -1), P(len, a), pt(len * 0.8, 1), pt(0, 1)]
        }
        var p = Path(); p.addLines(pts); p.closeSubpath(); return p
    }
    func oneHand(_ a: Double, _ len: CGFloat, _ w: CGFloat, _ tail: CGFloat, _ h: Hand) {
        let p = handPath(a, len, w, tail, h.shape)
        ctx.fill(p, with: .color(Color(hex: h.fill)))
        ctx.stroke(p, with: .color(Color(hex: h.stroke)), style: StrokeStyle(lineWidth: 1.5, lineJoin: .round))
        if let l = h.lume { line(P(len * 0.25, a), P(len * 0.75, a), Color(hex: l), w * 0.42) }
    }
    func angles() -> (Double, Double, Double) {
        let c = Calendar.current.dateComponents([.hour, .minute, .second], from: now)
        let h = Double((c.hour ?? 0) % 12) + Double(c.minute ?? 0) / 60, m = Double(c.minute ?? 0) + Double(c.second ?? 0) / 60
        return (h / 12 * 2 * .pi, m / 60 * 2 * .pi, Double(c.second ?? 0) / 60 * 2 * .pi)
    }
    func hands(_ h: Hand) {
        let (ha, ma, sa) = angles()
        oneHand(ha, h.hl, h.hw, 28, h); oneHand(ma, h.ml, h.mw, 32, h)
        if let s = h.sec { line(P(-55, sa), P(h.sl, sa), Color(hex: s), 3) }
        ctx.fill(circle(CX, CY, 12), with: .color(Color(hex: h.cap)))
        ctx.stroke(circle(CX, CY, 12), with: .color(Color(hex: "#30353c")), lineWidth: 2)
        ctx.fill(circle(CX, CY, 4.5), with: .color(Color(hex: h.sec ?? "#30353c")))
    }
    func diverHands() {
        let (ha, ma, sa) = angles(); let lume = "#e9f2d2", red = "#e5484d"
        let h = Hand(shape: .sword, fill: "#dfe3e8", stroke: "#30353c", sec: nil, cap: "#c9ced6", lume: lume)
        oneHand(ha, 170, 26, 30, h); oneHand(ma, 262, 18, 34, h)
        line(P(-60, sa), P(282, sa), Color(hex: red), 3.5)
        ctx.fill(circle(px(206, sa), py(206, sa), 11), with: .color(Color(hex: lume)))
        ctx.stroke(circle(px(206, sa), py(206, sa), 11), with: .color(Color(hex: red)), lineWidth: 4)
        ctx.fill(circle(CX, CY, 14), with: .color(Color(hex: "#c9ced6")))
        ctx.stroke(circle(CX, CY, 14), with: .color(Color(hex: "#30353c")), lineWidth: 2)
        ctx.fill(circle(CX, CY, 5), with: .color(Color(hex: red)))
    }

    // ── Prediction Chrono ──
    func turq() {
        band(300, 312, GOLD, 0.55)
        let p = Arc.path(t)
        subV(CX - 128, CY, 76, "week", p.map { $0.d0 + 7 * Arc.HOUR } ?? t, "WEEK") { q, _ in q < Arc.DAYS.count ? Arc.DAYS[q] : "Q\(q)" }
        subV(CX + 128, CY, 76, "day", p.map { $0.d0 + 1000 } ?? t, "DAY") { q, _ in Arc.SESS_S[q] }
        subV(CX, CY + 130, 76, "m90", p.map { $0.S.s + 1000 } ?? t, p.map { Arc.SESS[$0.S.q] + " 90 MIN" } ?? "90 MIN") { q, b in "Q\(q) " + Arc.hhmm(b[q - 1]) }
        text(Arc.higher(t), CX, CY - 100, 12, Color(hex: "#13403f"), tracking: 2)
        if let p = p {
            text("NEXT HIGH - LOW  " + Arc.WD[Arc.z(p.S.s + 1000).wd] + "  " + Arc.SESS[p.S.q] + "  " + Arc.hhmm(p.S.s) + " NY", CX, CY + 240, 12, Color(hex: "#0f2a2a"), tracking: 2)
        }
        gmt(300, GOLD)
        hands(Hand(shape: .baton, fill: "#e8c97a", stroke: "#8a6420", sec: "#e8c97a", cap: "#d8b260", lume: "#f6f3e8", hw: 16, mw: 12, hl: 168, ml: 258, sl: 280))
    }
    func subV(_ cx: CGFloat, _ cy: CGFloat, _ R: CGFloat, _ key: String, _ T: Int64, _ lab: String, _ vf: (Int, [Int64]) -> String) {
        let b = Arc.bounds(key, T), f = Arc.focus(b[0] + 1000)[key]
        let ang = { (x: Int64) in max(0, min(1, Double(x - b[0]) / Double(b[4] - b[0]))) * 2 * .pi }
        let rim = Color(hex: "#c9a24a")
        ctx.fill(circle(cx, cy, R), with: .color(Color(hex: "#0b0d10")))
        ctx.stroke(circle(cx, cy, R), with: .color(rim), lineWidth: 3)
        for i in 0..<40 {
            let a = Double(i) / 40 * 2 * .pi, r0 = i % 10 != 0 ? R * 0.93 : R * 0.86
            line(P(R * 0.98, a, cx, cy), P(r0, a, cx, cy), rim, i % 10 != 0 ? 1 : 2, round: false)
        }
        for q in 1...4 {
            ctx.fill(annulus(cx, cy, R * 0.6, R * 0.82, ang(b[q - 1]) + 0.05, ang(b[q]) - 0.05), with: .color(q == f ? Color(hex: GOLD, 0.95) : Color(hex: QC[q], 0.4)))
        }
        let hc = Color(hex: "#e9c46a")
        if t >= b[0] && t < b[4] { line(CGPoint(x: cx, y: cy), P(R * 0.74, ang(t), cx, cy), hc, 3) }
        ctx.fill(circle(cx, cy, 5), with: .color(hc))
        if let f = f { text(vf(f, b), cx, cy - R * 0.22 + R * 0.21 * 0.35, R * 0.21, Color(hex: "#f4e3b0")) }
        text(lab, cx, cy + R * 0.4 + R * 0.15 * 0.35, R * 0.15, rim, tracking: 1.5)
    }

    // ── always-on: black, outlines only ──
    func ambient() {
        let grey = Color(hex: "#7a7a7a")
        for i in 0..<12 { let a = Double(i) / 12 * 2 * .pi; line(P(i % 3 == 0 ? 300 : 316, a), P(336, a), grey, 3) }
        let b = Arc.bounds("day", t), f = Arc.focus(b[0] + 1000)["day"]
        let ang = { (x: Int64) in Double(x - b[0]) / Double(24 * Arc.HOUR) * 2 * .pi }
        for q in 1...4 {
            var p = Path(); let a0 = ang(b[q - 1]) + 0.02, a1 = ang(b[q]) - 0.02
            for i in 0...30 { let a = a0 + (a1 - a0) * Double(i) / 30; i == 0 ? p.move(to: P(360, a)) : p.addLine(to: P(360, a)) }
            ctx.stroke(p, with: .color(q == f ? .white : Color(hex: "#3a3a3a")), lineWidth: q == f ? 8 : 4)
        }
        if let p = Arc.path(t) {
            text("NEXT HIGH - LOW", CX, CY + 160, 16, grey)
            text(Arc.SESS[p.S.q] + "  " + Arc.hhmm(p.S.s) + " NY", CX, CY + 190, 24, grey)
        }
        let (ha, ma, _) = angles()
        for (a, len, w) in [(ha, CGFloat(170), CGFloat(22)), (ma, 262, 16)] {
            ctx.stroke(handPath(a, len, w, 24, .sword), with: .color(.white), lineWidth: 3)
        }
        ctx.fill(circle(CX, CY, 10), with: .color(.black)); ctx.stroke(circle(CX, CY, 10), with: .color(.white), lineWidth: 3)
    }

    // ── Arcana Digital ──
    func digital(ambient: Bool) {
        let muted = Color(hex: "#8c8c8c")
        let b = Arc.bounds("day", t), fd = Arc.focus(b[0] + 1000)["day"]
        let ang = { (x: Int64) in Double(x - b[0]) / Double(24 * Arc.HOUR) * 2 * .pi }
        if !ambient {
            ctx.fill(circle(CX, CY, 400), with: .color(Color(hex: "#0b0b0b")))
            for q in 1...4 { ctx.fill(annulus(CX, CY, 370, 392, ang(b[q - 1]) + 0.01, ang(b[q]) - 0.01), with: .color(q == fd ? Color(hex: GOLD, 0.95) : Color(hex: QC[q], 0.45))) }
            ctx.fill(circle(px(381, ang(t)), py(381, ang(t)), 9), with: .color(.white))
        } else {
            for q in 1...4 {
                var p = Path(); let a0 = ang(b[q - 1]) + 0.02, a1 = ang(b[q]) - 0.02
                for i in 0...30 { let a = a0 + (a1 - a0) * Double(i) / 30; i == 0 ? p.move(to: P(380, a)) : p.addLine(to: P(380, a)) }
                ctx.stroke(p, with: .color(q == fd ? .white : Color(hex: "#3a3a3a")), lineWidth: 3)
            }
        }
        text("ARCANA", CX, 150, 24, muted, tracking: 6)
        let c = Calendar.current.dateComponents([.hour, .minute], from: now)
        text(String(format: "%02d:%02d", c.hour ?? 0, c.minute ?? 0), CX, 300, 150, .white, mono: true)
        let ny = Arc.z(t)
        text(String(format: "NY %02d:%02d  ·  %@ %d", ny.hour, ny.minute, Arc.WD[ny.wd], ny.day), CX, 350, 28, muted)
        guard let p = Arc.path(t) else { return }
        if !ambient {
            let items = [("Day", p.S.q), ("Session", p.M.q), ("90 min", p.C.q), ("Micro", p.Na.q), ("Nano", p.Pi.q)]
            for (i, it) in items.enumerated() {
                let x = 150 + CGFloat(i) * 125
                text("Q\(it.1)", x, 440, 46, Color(hex: QC[it.1]), mono: true)
                text(it.0, x, 466, 17, muted)
                if i < items.count - 1 { text("›", x + 62, 432, 30, Color(hex: "#555555")) }
            }
            let wq = Arc.focus(Arc.bounds("week", p.d0 + 7 * Arc.HOUR)[0] + 1000)["week"].map { "Q\($0)" } ?? "—"
            text(Arc.higher(t) + " · WEEK " + wq, CX, 520, 20, muted, tracking: 1)
        }
        text("NEXT HIGH - LOW", CX, 580, 20, ambient ? muted : Color(hex: "#bdbdbd"), tracking: 3)
        text(Arc.WD[Arc.z(p.S.s + 1000).wd] + "  " + Arc.SESS[p.S.q] + "  " + Arc.hhmm(p.S.s), CX, 622, 34, ambient ? .white : Color(hex: GOLD))
        text(t < p.S.s ? "in " + Arc.dur(p.S.s - t) : "NOW · " + Arc.dur(p.S.e - t) + " left", CX, 660, 24, muted)
    }
}
