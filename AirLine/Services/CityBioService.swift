import Foundation

struct CityBio: Codable, Equatable {
    let tag: String   // 【】里的标签
    let body: String  // 正文
}

/// 城市小传：全量内置 city_bios.json（3691 座机场），按 IATA 检索（SPEC §6）
@MainActor
@Observable
final class CityBioService {
    static let shared = CityBioService()

    /// key = IATA
    private(set) var bios: [String: CityBio] = [:]

    private init() {
        if let url = Bundle.main.url(forResource: "city_bios", withExtension: "json"),
           let data = try? Data(contentsOf: url),
           let all = try? JSONDecoder().decode([String: CityBio].self, from: data) {
            bios = all
        }
    }

    func bio(for iata: String) -> CityBio? { bios[iata] }

    /// 极端兜底（全量覆盖后理论上不应走到）
    func fallback(for airport: Airport) -> CityBio {
        CityBio(tag: airport.country,
                body: "\(airport.displayCity)（\(airport.city)），\(airport.country)。经由 \(airport.name)（\(airport.icaoKey)）抵达。")
    }
}
