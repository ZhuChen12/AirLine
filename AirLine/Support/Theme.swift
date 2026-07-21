import SwiftUI

/// 全局视觉：暗色、典雅、克制
enum Theme {
    /// 近黑深蓝底
    static let bg = Color(hex: 0x0A0E1A)
    static let bgElevated = Color(hex: 0x111827)
    static let card = Color(hex: 0x151C2E)
    /// 大陆填充与描边
    static let land = Color(hex: 0x18213A)
    static let landStroke = Color(hex: 0x2E3E63)
    /// 点亮城市的暖金辉光
    static let glow = Color(hex: 0xE8C87A)
    static let glowDim = Color(hex: 0x8A7A4D)
    /// 航迹
    static let track = Color(hex: 0x6FA8DC)
    static let textPrimary = Color(hex: 0xE9EDF5)
    static let textSecondary = Color(hex: 0x8B94A8)
    static let danger = Color(hex: 0xC96A6A)

    static func cabinColor(_ cabin: CabinClass) -> Color {
        switch cabin {
        case .economy: return Color(hex: 0x7FA6C9)
        case .premium: return Color(hex: 0x9AC9A8)
        case .business: return Color(hex: 0xC9A86A)
        case .first: return Color(hex: 0xE3D3A3)
        }
    }
}

extension Color {
    init(hex: UInt32) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255.0,
            green: Double((hex >> 8) & 0xFF) / 255.0,
            blue: Double(hex & 0xFF) / 255.0,
            opacity: 1.0
        )
    }
}
