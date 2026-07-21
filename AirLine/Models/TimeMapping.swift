import Foundation

/// 压缩映射：专注时长 ≈ 真实航程 ÷ 5，吸附友好档位（SPEC §3.1）
enum TimeMapping {
    static let slots: [Int] = [15, 20, 25, 30, 35, 40, 45, 50, 60, 75, 90, 120, 150, 180]
    /// 接力段最短时长
    static let minSegmentMinutes = 25
    /// 压缩后超过此时长的航线可接力
    static let relayThresholdMinutes = 60

    static func focusMinutes(forRealMinutes real: Int) -> Int {
        let raw = Double(real) / 5.0
        var best = slots[0]
        var bestDiff = Double.greatestFiniteMagnitude
        for s in slots {
            let d = abs(Double(s) - raw)
            if d < bestDiff { bestDiff = d; best = s }
        }
        return best
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
