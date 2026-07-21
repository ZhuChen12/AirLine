import Foundation

/// 分段压缩映射：让大多数真实航线落在 30–60 分钟的有效专注区间。
enum TimeMapping {
    static let slots: [Int] = [15, 25, 30, 40, 50, 60, 75, 90, 120, 150]
    /// 接力段最短时长
    static let minSegmentMinutes = 25
    /// 压缩后超过此时长的航线可接力
    static let relayThresholdMinutes = 60

    static func focusMinutes(forRealMinutes real: Int) -> Int {
        switch max(0, real) {
        case ...35: return 15
        case ...75: return 25
        case ...120: return 30
        case ...180: return 40
        case ...270: return 50
        case ...390: return 60
        case ...510: return 75
        case ...660: return 90
        case ...840: return 120
        default: return 150
        }
    }

    static func isRelayEligible(focusMinutes: Int) -> Bool {
        focusMinutes > relayThresholdMinutes
    }

    /// 接力时本段可选时长（含"一次坐完"由调用方另行提供）
    static func segmentOptions(remaining: Int) -> [Int] {
        if remaining <= minSegmentMinutes { return [remaining] }
        var opts = [25, 30, 45, 60, 90, 120].filter { $0 >= minSegmentMinutes && $0 < remaining }
        opts.append(remaining)
        return opts
    }

    static func formatMinutes(_ m: Int) -> String {
        if m < 60 { return "\(m)分钟" }
        let h = m / 60, r = m % 60
        return r == 0 ? "\(h)小时" : "\(h)小时\(r)分"
    }
}
