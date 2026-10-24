import SwiftUI
import WidgetKit

struct Entry: TimelineEntry { let date: Date }

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> Entry { Entry(date: Date()) }
    func getSnapshot(in context: Context, completion: @escaping (Entry) -> Void) { completion(Entry(date: Date())) }
    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> Void) {
        let now = Date()
        let entries = (0..<48).map { Entry(date: now.addingTimeInterval(Double($0) * 15 * 60)) }   // every 15 min for 12 h
        completion(Timeline(entries: entries, policy: .atEnd))
    }
}

/// The four New York sessions as a ring, the predicted one lit.
struct SessionRing: View {
    let t: Int64
    var body: some View {
        let b = Arc.bounds("day", t), f = Arc.focus(b[0] + 1000)["day"]
        let at = Double(t - b[0]) / Double(24 * Arc.HOUR)
        ZStack {
            ForEach(1...4, id: \.self) { q in
                Circle()
                    .trim(from: Double(q - 1) / 4 + 0.012, to: Double(q) / 4 - 0.012)
                    .stroke(q == f ? Color(hex: "#e0b556") : Color(hex: QC[q], 0.45), style: StrokeStyle(lineWidth: q == f ? 6 : 4, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .widgetAccentable(q == f)
            }
            GeometryReader { g in
                let r = min(g.size.width, g.size.height) / 2 - 2, a = at * 2 * .pi
                Circle().fill(.white).frame(width: 5, height: 5)
                    .position(x: g.size.width / 2 + r * CGFloat(sin(a)), y: g.size.height / 2 - r * CGFloat(cos(a)))
            }
        }
    }
}

struct WidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: Entry

    var body: some View {
        let t = Int64(entry.date.timeIntervalSince1970 * 1000)
        let p = Arc.path(t)
        Group {
            switch family {
            case .accessoryCircular:
                ZStack {
                    SessionRing(t: t).padding(2)
                    VStack(spacing: 0) {
                        Text(p.map { Arc.SESS_S[$0.S.q] } ?? "—").font(.system(size: 11, weight: .bold)).widgetAccentable()
                        Text(p.map { Arc.hhmm($0.S.s) } ?? "").font(.system(size: 10, weight: .semibold)).foregroundStyle(.secondary)
                    }
                }
            case .accessoryRectangular:
                VStack(alignment: .leading, spacing: 1) {
                    Text("NEXT HIGH - LOW").font(.system(size: 11, weight: .semibold)).foregroundStyle(.secondary)
                    if let p = p {
                        Text("\(Arc.WD[Arc.z(p.S.s + 1000).wd]) \(Arc.SESS[p.S.q]) \(Arc.hhmm(p.S.s))").font(.system(size: 15, weight: .bold)).widgetAccentable()
                        HStack(spacing: 3) {
                            ForEach(Array([p.S.q, p.M.q, p.C.q, p.Na.q].enumerated()), id: \.offset) { i, q in
                                Text("Q\(q)").font(.system(size: 12, weight: .bold, design: .monospaced)).foregroundStyle(Color(hex: QC[q]))
                                if i < 3 { Text("›").font(.system(size: 11)).foregroundStyle(.secondary) }
                            }
                        }
                        if t < p.S.s {
                            Text(Arc.date(p.S.s), style: .relative).font(.system(size: 11)).foregroundStyle(.secondary)
                        } else {
                            Text("NOW · ends \(Arc.hhmm(p.S.e)) NY").font(.system(size: 11)).foregroundStyle(.secondary)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            case .accessoryInline:
                Text(p.map { "High - Low \(Arc.SESS[$0.S.q]) \(Arc.hhmm($0.S.s)) NY" } ?? "Arcana")
            case .accessoryCorner:
                Text(p.map { Arc.SESS_S[$0.S.q] } ?? "—").font(.system(size: 13, weight: .bold))
                    .widgetLabel { Text(p.map { "\(Arc.hhmm($0.S.s)) NY" } ?? "") }
            default:
                Text("Arcana")
            }
        }
        .containerBackground(for: .widget) { Color.clear }
    }
}

struct NextHighLow: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "arcana.next", provider: Provider()) { WidgetView(entry: $0) }
            .configurationDisplayName("Arcana High - Low")
            .description("The next predicted High - Low session")
            .supportedFamilies([.accessoryCircular, .accessoryRectangular, .accessoryInline, .accessoryCorner])
    }
}

@main
struct ArcanaWidgets: WidgetBundle {
    var body: some Widget { NextHighLow() }
}
