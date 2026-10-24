import SwiftUI

struct ContentView: View {
    @AppStorage("face") private var face = FaceID.turq.rawValue

    var body: some View {
        TabView(selection: $face) {
            ForEach(FaceID.allCases) { f in
                FacePage(face: f).tag(f.rawValue)
            }
            SettingsView().tag("settings")
        }
        .tabViewStyle(.verticalPage)
    }
}

struct FacePage: View {
    let face: FaceID
    var body: some View {
        TimelineView(.everyMinute) { tl in
            let t = Int64(tl.date.timeIntervalSince1970 * 1000)
            VStack(spacing: 2) {
                FaceView(face: face)
                if let p = Arc.path(t) {
                    Text(t < p.S.s ? "\(Arc.SESS[p.S.q]) \(Arc.hhmm(p.S.s)) NY · in \(Arc.dur(p.S.s - t))" : "\(Arc.SESS[p.S.q]) NOW · \(Arc.dur(p.S.e - t)) left")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Color(hex: GOLD))
                        .lineLimit(1).minimumScaleFactor(0.7)
                }
            }
        }
        .navigationTitle(face.title)
    }
}

struct SettingsView: View {
    @AppStorage("alerts") private var alerts = true
    @AppStorage("fri") private var fri = true
    @State private var pending = 0

    var body: some View {
        List {
            Section {
                Toggle("High - Low alerts", isOn: $alerts)
                Text("15, 5 and 1 min before each predicted session").font(.footnote).foregroundStyle(.secondary)
            }
            Section {
                Toggle("Friday predictions", isOn: $fri)
                Text("Friday counts as weekly Q1").font(.footnote).foregroundStyle(.secondary)
            }
            Section {
                Button("Update alerts now") { Task { Arc.fridayWrap = fri; pending = await Notifier.schedule() } }
                if pending > 0 { Text("\(pending) alerts set").font(.footnote) }
            }
        }
        .navigationTitle("Settings")
        .onChange(of: alerts) { _, _ in Task { pending = await Notifier.schedule() } }
        .onChange(of: fri) { _, v in Arc.fridayWrap = v; Task { pending = await Notifier.schedule() } }
    }
}
