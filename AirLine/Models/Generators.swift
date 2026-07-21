import Foundation

/// 确定性生成器：航班号/登机口/座位（SPEC §5.1）
enum Generators {
    private static func fnv(_ s: String) -> UInt64 {
        var h: UInt64 = 0xcbf29ce484222325
        for b in s.utf8 {
            h ^= UInt64(b)
            h = h &* 0x100000001b3
        }
        return h
    }

    /// 同一航司同一航线的航班号稳定可复现
    static func flightNumber(carrier: String, origin: String, dest: String) -> String {
        let h = fnv("\(carrier)-\(origin)-\(dest)")
        let n = 100 + Int(h % 8900)
        return "\(carrier)\(n)"
    }

    /// 登机口按天变化
    static func gate(origin: String, dest: String, date: Date) -> String {
        let day = Int(date.timeIntervalSince1970 / 86_400)
        let h = fnv("\(origin)-\(dest)-\(day)")
        let letters = ["A", "B", "C", "D", "E", "F"]
        return "\(letters[Int(h % 6)])\(1 + Int((h >> 8) % 30))"
    }

    /// 座位区间随舱位
    static func seat(cabin: CabinClass, seed: String) -> String {
        let h = fnv("seat-\(seed)")
        switch cabin {
        case .first:
            return "\(1 + Int(h % 3))\(["A", "F"][Int((h >> 8) % 2)])"
        case .business:
            return "\(4 + Int(h % 9))\(["A", "C", "D", "F"][Int((h >> 8) % 4)])"
        case .premium:
            return "\(31 + Int(h % 10))\(["A", "B", "C", "D", "E", "F"][Int((h >> 8) % 6)])"
        case .economy:
            return "\(41 + Int(h % 20))\(["A", "B", "C", "D", "E", "F"][Int((h >> 8) % 6)])"
        }
    }
}
