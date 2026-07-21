import Foundation

/// 分段压缩映射：让大多数真实航线落在 30–60 分钟的有效专注区间。
enum TimeMapping {
    static let slots: [Int] = [15, 20, 30, 40, 50, 60, 75, 90, 120, 150]
    /// 任何一次实际专注倒计时都不得短于 15 分钟。
    static let minimumTimerMinutes = 15
    /// 接力段最短时长
    static let minSegmentMinutes = 15
    /// 压缩后超过此时长的航线属于长航线。
    static let relayThresholdMinutes = 60
    /// 压缩后达到 2 小时的航线一定可接力。
    static let guaranteedRelayMinutes = 120

    static func focusMinutes(forRealMinutes real: Int) -> Int {
        switch max(0, real) {
        case ...35: return 15
        case ...75: return 20
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

    static func isRelayCapable(focusMinutes: Int, routeKey: String) -> Bool {
        if focusMinutes >= guaranteedRelayMinutes { return true }
        guard focusMinutes > relayThresholdMinutes else { return false }
        return stableHash(routeKey) % 2 == 0
    }

    /// 接力时本段可选时长（含"一次坐完"由调用方另行提供）
    static func segmentOptions(remaining: Int) -> [Int] {
        if remaining < minimumTimerMinutes { return [minimumTimerMinutes] }
        if remaining <= minSegmentMinutes { return [remaining] }
        var opts = [15, 30, 45, 60, 90, 120].filter { $0 >= minSegmentMinutes && $0 < remaining }
        opts.append(remaining)
        return opts
    }

    static func progressMinutes(forTimer timerMinutes: Int, remaining: Int) -> Int {
        min(timerMinutes, remaining)
    }

    static func formatMinutes(_ m: Int) -> String {
        if m < 60 { return "\(m)分钟" }
        let h = m / 60, r = m % 60
        return r == 0 ? "\(h)小时" : "\(h)小时\(r)分"
    }

    private static func stableHash(_ s: String) -> UInt64 {
        var h: UInt64 = 0xcbf29ce484222325
        for b in s.utf8 {
            h ^= UInt64(b)
            h = h &* 0x100000001b3
        }
        return h
    }
}
