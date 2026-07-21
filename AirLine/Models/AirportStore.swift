import Foundation

struct RouteEdge: Decodable, Hashable {
    let destIata: String
    let km: Int
    let realMinutes: Int
    let carrierCodes: [String]

    enum CodingKeys: String, CodingKey {
        case destIata = "d", km = "k", realMinutes = "m", carrierCodes = "c"
    }
}

struct Airport: Decodable, Identifiable, Hashable {
    let name: String
    let city: String
    let cityZh: String
    let country: String
    let countryCode: String
    let continent: String
    let latitude: Double
    let longitude: Double
    let timezone: String
    let routes: [RouteEdge]

    var id: String { icaoKey }
    /// 由 store 填充的 IATA 码
    var icaoKey: String = ""

    enum CodingKeys: String, CodingKey {
        case name = "n", city = "c", cityZh = "zh", country = "co", countryCode = "cc"
        case continent = "ct", latitude = "la", longitude = "lo", timezone = "tz", routes = "r"
    }

    /// 产品界面只展示中文城市名；构建期会校验 cityZh 全量存在。
    var displayCity: String { cityZh.isEmpty ? "未知城市" : cityZh }
    var displayCountry: String {
        Locale(identifier: "zh_Hans").localizedString(forRegionCode: countryCode) ?? country
    }
    var tz: TimeZone { TimeZone(identifier: timezone) ?? .current }
}

/// 全离线机场/航线图（构建期打包的 airports.min.json）
final class AirportStore {
    static let shared = AirportStore()

    let airports: [String: Airport]
    let carrierNames: [String: String]
    /// 按连通度降序的机场（用于主场推荐/搜索排序）
    let byDegree: [Airport]

    private init() {
        struct Blob: Decodable {
            let carriers: [String: String]
            let airports: [String: Airport]
        }
        guard let url = Bundle.main.url(forResource: "airports.min", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let blob = try? JSONDecoder().decode(Blob.self, from: data) else {
            fatalError("airports.min.json missing or corrupt")
        }
        var dict = blob.airports
        for (key, var a) in dict {
            a.icaoKey = key
            dict[key] = a
        }
        airports = dict
        carrierNames = blob.carriers
        byDegree = dict.values.sorted { $0.routes.count > $1.routes.count }
    }

    subscript(iata: String) -> Airport? { airports[iata] }

    func routes(from iata: String) -> [(edge: RouteEdge, dest: Airport)] {
        guard let a = airports[iata] else { return [] }
        return a.routes.compactMap { e in
            guard let d = airports[e.destIata] else { return nil }
            return (e, d)
        }
    }

    func search(_ text: String, limit: Int = 30) -> [Airport] {
        let q = text.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return Array(byDegree.prefix(limit)) }
        let lower = q.lowercased()
        let upper = q.uppercased()
        let compact = lower.replacingOccurrences(of: " ", with: "")
        var hits: [Airport] = []
        for a in byDegree {
            if a.icaoKey == upper
                || a.city.lowercased().contains(lower)
                || a.cityZh.contains(q)
                || a.name.lowercased().contains(lower)
                || a.country.lowercased().contains(lower)
                || a.displayCountry.contains(q)
                || a.countryCode.uppercased() == upper
                || a.city.lowercased().replacingOccurrences(of: " ", with: "").contains(compact) {
                hits.append(a)
                if hits.count >= limit { break }
            }
        }
        return hits
    }
}
