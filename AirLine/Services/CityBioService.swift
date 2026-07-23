import Foundation
import UIKit

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
        CityBio(tag: airport.displayCountry,
                body: "\(airport.displayCity)，位于\(airport.displayCountry)。经由 \(airport.name)（\(airport.icaoKey)）抵达。")
    }
}

/// 经过人工审核的 Top 140 城市地标图，仅从 App Bundle 读取。
@MainActor
final class CitySceneryService {
    static let shared = CitySceneryService()

    private let cache = NSCache<NSString, UIImage>()
    private let airportMapping: [String: String]

    private init() {
        guard let url = Bundle.main.url(
            forResource: "manifest",
            withExtension: "json",
            subdirectory: "CityLandmarks"
        ),
        let data = try? Data(contentsOf: url),
        let manifest = try? JSONDecoder().decode(Manifest.self, from: data) else {
            airportMapping = [:]
            return
        }
        airportMapping = manifest.airportMapping
        cache.countLimit = 16
    }

    func hasImage(for iata: String) -> Bool {
        airportMapping[iata] != nil
    }

    func image(for iata: String) -> UIImage? {
        guard let key = airportMapping[iata] else { return nil }
        if let cached = cache.object(forKey: key as NSString) {
            return cached
        }
        guard let url = Bundle.main.url(
            forResource: key,
            withExtension: "jpg",
            subdirectory: "CityLandmarks"
        ),
        let image = UIImage(contentsOfFile: url.path) else {
            return nil
        }
        cache.setObject(image, forKey: key as NSString)
        return image
    }

    private struct Manifest: Decodable {
        let airportMapping: [String: String]
    }
}
