import Foundation
import CryptoKit
import SwiftData

/// 玩家档案（单例记录）
@Model
final class PlayerProfile {
    var name: String = ""
    var homeIata: String = ""
    var currentIata: String = ""
    /// 途经机场历史（调机兜底用）
    var pathHistory: [String] = []
    var totalKm: Int = 0
    var totalFocusMinutes: Int = 0
    var createdAt: Date = Date()
    var isDeveloper: Bool = false

    init(name: String, homeIata: String, isDeveloper: Bool = false) {
        self.name = name
        self.homeIata = homeIata
        self.currentIata = homeIata
        self.pathHistory = [homeIata]
        self.isDeveloper = isDeveloper
    }

    var cabin: CabinClass { CabinClass.current(totalKm: totalKm) }
}

@MainActor
enum DeveloperAccess {
    static let developerHomeIata = "PVG"
    private static let modeKey = "developerAccess.active"
    private static let passphraseSalt = "AirLineDeveloperAccess:v1:"
    private static let passphraseDigest: [UInt8] = [
        0xae, 0xaf, 0xbb, 0x9b, 0xce, 0xf8, 0x9e, 0x15,
        0x7f, 0xd7, 0x4c, 0xc0, 0xb5, 0xd5, 0xc0, 0xff,
        0x7d, 0xe4, 0x76, 0xfd, 0x1b, 0x5b, 0x6d, 0x39,
        0xbe, 0x79, 0x5d, 0x02, 0x54, 0x7b, 0x20, 0x4d,
    ]

    static var isActive: Bool {
        get { UserDefaults.standard.bool(forKey: modeKey) }
        set { UserDefaults.standard.set(newValue, forKey: modeKey) }
    }

    static func selectedProfile(from profiles: [PlayerProfile]) -> PlayerProfile? {
        if isActive {
            if let developer = profiles.first(where: \.isDeveloper) {
                return developer
            }
            isActive = false
        }
        return profiles.first { !$0.isDeveloper }
    }

    @discardableResult
    static func ensureDeveloperProfile(context: ModelContext) -> PlayerProfile {
        var descriptor = FetchDescriptor<PlayerProfile>(
            predicate: #Predicate { $0.isDeveloper == true }
        )
        descriptor.fetchLimit = 1
        if let existing = (try? context.fetch(descriptor))?.first {
            InitialCityLighting.ensureHomeCity(for: existing, context: context)
            try? context.save()
            return existing
        }

        let profile = PlayerProfile(
            name: "DEVELOPER",
            homeIata: developerHomeIata,
            isDeveloper: true
        )
        context.insert(profile)
        InitialCityLighting.ensureHomeCity(for: profile, context: context)
        try? context.save()
        return profile
    }

    private static func activate(context: ModelContext) {
        ensureDeveloperProfile(context: context)
        isActive = true
    }

    static func activate(passphrase: String, context: ModelContext) -> Bool {
        guard verify(passphrase: passphrase) else { return false }
        activate(context: context)
        return true
    }

    static func deactivate() {
        isActive = false
    }

    private static func verify(passphrase: String) -> Bool {
        let normalized = passphrase.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let data = (passphraseSalt + normalized).data(using: .utf8) else { return false }
        let digest = SHA256.hash(data: data)
        return Array(digest) == passphraseDigest
    }
}

enum FlightStatus: Int, Codable {
    case completed = 0
    case diverted = 1   // 备降（破戒）
    case abandoned = 2  // 返航（主动放弃接力旅程）
}

/// 飞行日志：每一段旅程一条（登机牌可回看）
@Model
final class FlightRecord {
    var originIata: String = ""
    var destIata: String = ""
    var carrierCode: String = ""
    var carrierName: String = ""
    var flightNumber: String = ""
    var cabinRaw: Int = 0
    var seat: String = ""
    var gate: String = ""
    var totalKm: Int = 0
    var realMinutes: Int = 0
    var focusMinutes: Int = 0
    /// 实际入账（接力返航时小于全程）
    var creditedKm: Int = 0
    var creditedFocusMinutes: Int = 0
    var statusRaw: Int = 0
    var checkInAt: Date = Date()
    var endedAt: Date = Date()
    var isDeveloper: Bool = false

    init(journey: ActiveJourney, status: FlightStatus, endedAt: Date) {
        originIata = journey.originIata
        destIata = journey.destIata
        carrierCode = journey.carrierCode
        carrierName = journey.carrierName
        flightNumber = journey.flightNumber
        cabinRaw = journey.cabinRaw
        seat = journey.seat
        gate = journey.gate
        totalKm = journey.totalKm
        realMinutes = journey.realMinutes
        focusMinutes = journey.focusMinutes
        creditedKm = journey.creditedKm
        creditedFocusMinutes = journey.completedFocusMinutes
        statusRaw = status.rawValue
        checkInAt = journey.checkInAt
        self.endedAt = endedAt
        isDeveloper = journey.isDeveloper
    }

    var status: FlightStatus { FlightStatus(rawValue: statusRaw) ?? .completed }
    var cabin: CabinClass { CabinClass(rawValue: cabinRaw) ?? .economy }
}

/// 点亮的城市（按机场记）
@Model
final class CityVisit {
    var iata: String = ""
    var city: String = ""
    var cityZh: String = ""
    var country: String = ""
    var countryCode: String = ""
    var latitude: Double = 0
    var longitude: Double = 0
    var firstArrivalAt: Date = Date()
    var arrivalCount: Int = 1
    var isDeveloper: Bool = false

    init(airport: Airport, at date: Date, isDeveloper: Bool = false) {
        iata = airport.icaoKey
        city = airport.city
        cityZh = airport.cityZh
        country = airport.country
        countryCode = airport.countryCode
        latitude = airport.latitude
        longitude = airport.longitude
        firstArrivalAt = date
        self.isDeveloper = isDeveloper
    }

    var displayCity: String {
        AirportStore.shared[iata]?.displayCity ?? (cityZh.isEmpty ? "未知城市" : cityZh)
    }
}

/// 护照盖章（按国家首次落地）
@Model
final class PassportStamp {
    var countryCode: String = ""
    var country: String = ""
    var firstCity: String = ""
    var stampedAt: Date = Date()
    var isDeveloper: Bool = false

    init(countryCode: String, country: String, firstCity: String, stampedAt: Date,
         isDeveloper: Bool = false) {
        self.countryCode = countryCode
        self.country = country
        self.firstCity = firstCity
        self.stampedAt = stampedAt
        self.isDeveloper = isDeveloper
    }
}

@MainActor
enum InitialCityLighting {
    static func ensureHomeCity(for profile: PlayerProfile, context: ModelContext) {
        let homeIata = profile.homeIata.isEmpty ? profile.currentIata : profile.homeIata
        guard let home = AirportStore.shared[homeIata] else { return }
        let isDeveloper = profile.isDeveloper

        var visitFetch = FetchDescriptor<CityVisit>(
            predicate: #Predicate { $0.iata == homeIata && $0.isDeveloper == isDeveloper }
        )
        visitFetch.fetchLimit = 1
        if (try? context.fetch(visitFetch))?.first == nil {
            context.insert(CityVisit(airport: home, at: profile.createdAt, isDeveloper: isDeveloper))
        }

        let countryCode = home.countryCode
        var stampFetch = FetchDescriptor<PassportStamp>(
            predicate: #Predicate { $0.countryCode == countryCode && $0.isDeveloper == isDeveloper }
        )
        stampFetch.fetchLimit = 1
        if (try? context.fetch(stampFetch))?.first == nil {
            context.insert(PassportStamp(
                countryCode: countryCode,
                country: home.country,
                firstCity: home.displayCity,
                stampedAt: profile.createdAt,
                isDeveloper: isDeveloper
            ))
        }
    }
}

/// 当前唯一的未完成旅程（含进行中的专注段）
@Model
final class ActiveJourney {
    var originIata: String = ""
    var destIata: String = ""
    var carrierCode: String = ""
    var carrierName: String = ""
    var flightNumber: String = ""
    var cabinRaw: Int = 0
    var seat: String = ""
    var gate: String = ""
    var totalKm: Int = 0
    var realMinutes: Int = 0
    /// 全程专注总时长（压缩映射结果）
    var focusMinutes: Int = 0
    /// 本次旅程是否按接力模式值机。只有接力模式才会保留检查点。
    var relayMode: Bool = false
    var isDeveloper: Bool = false
    /// 已完成段累计（检查点）
    var completedFocusMinutes: Int = 0
    var creditedKm: Int = 0
    var checkInAt: Date = Date()
    /// 进行中的段（nil = 停在检查点）
    var segmentStartAt: Date? = nil
    /// 本段实际倒计时时长；末段不足 15 分钟时仍计时 15 分钟。
    var segmentMinutes: Int = 0
    /// 本段推进旅程的计划分钟数，通常与倒计时相同。
    var segmentProgressMinutes: Int = 0
    /// 实际倒计时秒数。0 表示按 segmentMinutes 的正常分钟数计时。
    var segmentTimerSeconds: Int = 0

    init(origin: Airport, dest: Airport, edge: RouteEdge, carrierCode: String,
         carrierName: String, cabin: CabinClass, isDeveloper: Bool = false) {
        originIata = origin.icaoKey
        destIata = dest.icaoKey
        self.carrierCode = carrierCode
        self.carrierName = carrierName
        flightNumber = Generators.flightNumber(carrier: carrierCode, origin: origin.icaoKey, dest: dest.icaoKey)
        cabinRaw = cabin.rawValue
        let now = Date()
        seat = Generators.seat(cabin: cabin, seed: "\(origin.icaoKey)-\(dest.icaoKey)-\(now.timeIntervalSince1970)")
        gate = Generators.gate(origin: origin.icaoKey, dest: dest.icaoKey, date: now)
        totalKm = edge.km
        realMinutes = edge.realMinutes
        focusMinutes = TimeMapping.focusMinutes(forRealMinutes: edge.realMinutes)
        self.isDeveloper = isDeveloper
        checkInAt = now
    }

    var cabin: CabinClass { CabinClass(rawValue: cabinRaw) ?? .economy }
    var isRelayJourney: Bool { relayMode }
    var remainingFocusMinutes: Int { max(0, focusMinutes - completedFocusMinutes) }
    /// 检查点处的航线进度
    var checkpointFraction: Double {
        focusMinutes > 0 ? Double(completedFocusMinutes) / Double(focusMinutes) : 0
    }
    var segmentEndAt: Date? {
        segmentStartAt?.addingTimeInterval(TimeInterval(segmentDurationSeconds))
    }
    var segmentDurationSeconds: Int {
        segmentTimerSeconds > 0 ? segmentTimerSeconds : max(0, segmentMinutes * 60)
    }
    var effectiveSegmentProgressMinutes: Int {
        segmentProgressMinutes > 0
            ? segmentProgressMinutes
            : min(segmentMinutes, remainingFocusMinutes)
    }
    /// 本段结束时的航线进度
    var segmentEndFraction: Double {
        focusMinutes > 0
            ? Double(min(completedFocusMinutes + effectiveSegmentProgressMinutes, focusMinutes)) / Double(focusMinutes)
            : 1
    }
}
