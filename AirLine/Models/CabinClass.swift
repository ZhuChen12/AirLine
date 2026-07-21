import Foundation

/// 舱位 = 等级。航线距离不设限，等级用于逐步开放高连通度交通枢纽。
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
        case .business: return 20_000
        case .first: return 50_000
        }
    }

    /// 可进入的目的地机场最大直飞航线数，用机场连通度刻画枢纽规模。
    var maxHubRouteCount: Int {
        switch self {
        case .economy: return 39
        case .premium: return 79
        case .business: return 119
        case .first: return .max
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
        case .premium: return "优选经济舱"
        case .business: return "公务舱"
        case .first: return "头等舱"
        }
    }

    var hubAccessName: String {
        switch self {
        case .economy: return "普通城市"
        case .premium: return "区域枢纽"
        case .business: return "大型国际枢纽"
        case .first: return "全球超级枢纽"
        }
    }

    var rights: [String] {
        switch self {
        case .economy:
            return ["所有距离航线", "每座机场的基础航路", "标准登机牌"]
        case .premium:
            return ["解锁区域枢纽", "长航线接力飞行", "优选经济舱座位"]
        case .business:
            return ["解锁大型国际枢纽", "公务舱登机牌", "公务舱座位"]
        case .first:
            return ["解锁全球超级枢纽", "全部目的地城市", "头等舱登机牌与座位"]
        }
    }

    var hubRuleDescription: String {
        switch self {
        case .economy: return "开放普通城市，并保证每座机场至少 6 条基础航路"
        case .premium: return "开放拥有 40–79 条直飞航线的区域枢纽"
        case .business: return "开放拥有 80–119 条直飞航线的大型国际枢纽"
        case .first: return "开放拥有 120 条以上直飞航线的全球超级枢纽"
        }
    }

    static func current(totalKm: Int) -> CabinClass {
        allCases.last { totalKm >= $0.thresholdKm } ?? .economy
    }

    var next: CabinClass? { CabinClass(rawValue: rawValue + 1) }

    /// 解锁目的地所需的最低舱位；只看枢纽规模，不看航线距离。
    static func required(forHubRouteCount routeCount: Int) -> CabinClass {
        allCases.first { routeCount <= $0.maxHubRouteCount } ?? .first
    }
}
