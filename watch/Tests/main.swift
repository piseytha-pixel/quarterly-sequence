import Foundation
// Compares the Swift port with values computed by Arcana (the web app). Run: swiftc Shared/Arc.swift Tests/main.swift -o arctest && ./arctest Tests/vectors.json
let data = try! Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[1]))
let v = try! JSONSerialization.jsonObject(with: data) as! [[String: Any]]
var bad = 0
func I(_ x: Any?) -> Int? { (x as? NSNumber)?.intValue }
func L(_ x: Any?) -> [Int64]? { (x as? [NSNumber])?.map { $0.int64Value } }
func check(_ ok: Bool, _ msg: @autoclosure () -> String) { if !ok { bad += 1; if bad < 25 { print("MISMATCH", msg()) } } }
for o in v {
    let t = (o["t"] as! NSNumber).int64Value
    let c = Arc.clock(t)
    for (k, x) in o["c"] as! [String: Any] { check(I(x) == (c[k] ?? nil), "t=\(t) clock \(k) js=\(String(describing: I(x))) swift=\(String(describing: c[k] ?? nil))") }
    let f = Arc.focus(t)
    for (k, x) in o["f"] as! [String: Any] { check(I(x) == f[k], "t=\(t) focus \(k) js=\(String(describing: I(x))) swift=\(String(describing: f[k]))") }
    for key in ["day", "week", "month", "m90", "micro"] { check(L(o[key]) == Arc.bounds(key, t), "t=\(t) bounds \(key)") }
    let p = Arc.path(t)
    check(L(o["P"]) == p.map { [$0.S.s, Int64($0.S.q), $0.M.s, Int64($0.M.q), $0.C.s, Int64($0.C.q), Int64($0.Na.q), Int64($0.Pi.q)] }, "t=\(t) path")
    let y = Arc.yrOf(t).flatMap { Arc.yearPlan($0) }
    check(L(o["Y"]) == y.map { [Int64($0.q), $0.s, $0.e] }, "t=\(t) year")
    let q = Arc.qtrPlan(Arc.ybIdx(t))
    check(L(o["Q"]) == q.map { [Int64($0.q), $0.s, $0.e] }, "t=\(t) quarter")
    let m = Arc.monPlan(t)
    check(L(o["M"]) == m.map { [Int64($0.q), $0.s, $0.e] }, "t=\(t) month")
}
print("checked \(v.count) moments, \(bad) mismatches")
exit(bad == 0 ? 0 : 1)
