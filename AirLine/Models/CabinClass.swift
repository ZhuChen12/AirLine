import Foundation

/// 舱位 = 等级（SPEC §7）。数值为草案，集中在此便于调优。
enum CabinClass: Int, CaseIterable, Comparable, Codable {
    case economy = 0
    case premium = 1
    case business = 2
    case first = 3

    static func < (l: CabinClass, r: CabinClass) -> Bool { l.rawValue < r.rawValue }

    /// 累计里程门槛（km）
    var thresholdKm: Int {
        switch self {
        case .economy: return 0
        case .premium: return 5_000
        case .business: return 25_000
        case .first: return 100_000
        }
    }

    /// 可飞的单条航线距离上限（km）
    var maxRouteKm: Int {
        switch self {
        case .economy: return 2_500
        case .premium: return 5_000
        case .business, .first: return .max
        }
    }

    /// 是否已解锁接力
    var relayUnlocked: Bool { self >= .premium }

    var code: String {
        switch self {
        case .economy: return "Y"
        case .premium: return "W"
        case .business: return "C"
        case .first: return "F"
        }
    }

    var nameZh: String {
        switch self {
        case .economy: return "经济舱"
        case .premium: return "优选经济"
        case .business: return "公务舱"
        case .first: return "头等舱"
        }
    }

    static func current(totalKm: Int) -> CabinClass {
        allCases.last { totalKm >= $0.thresholdKm } ?? .economy
    }

    var next: CabinClass? { CabinClass(rawValue: rawValue + 1) }

    /// 解锁某条航线所需的最低舱位
    static func required(forRouteKm km: Int) -> CabinClass {
        allCases.first { km <= $0.maxRouteKm } ?? .business
    }
}
