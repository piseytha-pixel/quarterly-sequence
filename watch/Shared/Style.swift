import SwiftUI

extension Color {
    init(hex: String, _ alpha: Double = 1) {
        var v: UInt64 = 0; Scanner(string: hex.replacingOccurrences(of: "#", with: "")).scanHexInt64(&v)
        self.init(.sRGB, red: Double((v >> 16) & 255) / 255, green: Double((v >> 8) & 255) / 255, blue: Double(v & 255) / 255, opacity: alpha)
    }
}

let QC = ["#000000", "#939fae", "#f67584", "#10b562", "#5aa4e4"]
let HL = "#ef8a47", GOLD = "#e0b556"

