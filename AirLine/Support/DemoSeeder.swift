import Foundation
import SwiftData

#if DEBUG
/// Debug 演示模式：通过启动参数快速构造状态，供模拟器演示/截图/UI 验证。
///
/// 用法（simctl）:
///   xcrun simctl launch booted app.airline.focus --demo-reset --demo-profile --demo-history
///
/// 参数（可组合，按下列顺序生效）:
///   --demo-reset    清空全部本地数据
///   --demo-profile  若无档案则创建（CHEN YU / 主场 PVG）
///   --demo-history  预置三段已完成飞行（PVG→NRT→SIN→LHR），点亮城市+护照
///   --demo-journey  预置一段接力旅程停在检查点（LHR→JFK，已飞 60 分钟）
///   --demo-flying   立即开始一段 1 分钟的专注段（快速看专注页/灵动岛/落地结算）
@MainActor
enum DemoSeeder {
    static func runIfRequested(context: ModelContext) {
        let args = ProcessInfo.processInfo.arguments
        guard args.contains(where: { $0.hasPrefix("--demo-") }) else { return }

        if args.contains("--demo-reset") { reset(context) }
        if args.contains("--demo-profile") { seedProfile(context) }
        if args.contains("--demo-history") { seedHistory(context) }
        if args.contains("--demo-journey") { seedRelayJourney(context) }
        try? context.save()

        if args.contains("--demo-flying") { startFlyingSegment(context) }
    }

    private static func reset(_ context: ModelContext) {
        try? context.delete(model: ActiveJourney.self)
        try? context.delete(model: FlightRecord.self)
        try? context.delete(model: CityVisit.self)
        try? context.delete(model: PassportStamp.self)
        try? context.delete(model: PlayerProfile.self)
    }

    private static func seedProfile(_ context: ModelContext) {
        let existing = (try? context.fetch(FetchDescriptor<PlayerProfile>()))?.first
        guard existing == nil else { return }
        context.insert(PlayerProfile(name: "CHEN YU", homeIata: "PVG"))
    }

    private static func seedHistory(_ context: ModelContext) {
        guard let profile = (try? context.fetch(FetchDescriptor<PlayerProfile>()))?.first else { return }
        let legs = [("PVG", "NRT"), ("NRT", "SIN"), ("SIN", "LHR")]
        let store = AirportStore.shared
        var when = Date().addingTimeInterval(-6 * 86_400)

        for (o, d) in legs {
            guard let origin = store[o], let dest = store[d] else { continue }
            // 数据集中不一定有直飞边，找不到就按大圆距离造一条演示边
            let edge = origin.routes.first(where: { $0.destIata == d })
                ?? RouteEdge(destIata: d,
                             km: Int(GreatCircle.centralAngle(
                                φ1: origin.latitude * .pi / 180, λ1: origin.longitude * .pi / 180,
                                φ2: dest.latitude * .pi / 180, λ2: dest.longitude * .pi / 180) * 6371),
                             realMinutes: 0, carrierCodes: ["MU"])
            let realMin = edge.realMinutes > 0 ? edge.realMinutes : max(60, edge.km / 12)
            let carrier = edge.carrierCodes.first ?? "MU"

            let journey = ActiveJourney(origin: origin, dest: dest,
                                        edge: RouteEdge(destIata: d, km: edge.km,
                                                        realMinutes: realMin,
                                                        carrierCodes: edge.carrierCodes),
                                        carrierCode: carrier,
                                        carrierName: store.carrierNames[carrier] ?? carrier,
                                        cabin: profile.cabin)
            journey.completedFocusMinutes = journey.focusMinutes
            journey.creditedKm = journey.totalKm
            journey.checkInAt = when

            let record = FlightRecord(journey: journey, status: .completed,
                                      endedAt: when.addingTimeInterval(3600))
            context.insert(record)

            let iata = dest.icaoKey
            var visitFetch = FetchDescriptor<CityVisit>(predicate: #Predicate { $0.iata == iata })
            visitFetch.fetchLimit = 1
            if (try? context.fetch(visitFetch))?.first == nil {
                context.insert(CityVisit(airport: dest, at: when))
            }
            let cc = dest.countryCode
            var stampFetch = FetchDescriptor<PassportStamp>(predicate: #Predicate { $0.countryCode == cc })
            stampFetch.fetchLimit = 1
            if (try? context.fetch(stampFetch))?.first == nil {
                context.insert(PassportStamp(countryCode: cc, country: dest.country,
                                             firstCity: dest.displayCity, stampedAt: when))
            }

            profile.totalKm += journey.totalKm
            profile.totalFocusMinutes += journey.focusMinutes
            profile.currentIata = iata
            if profile.pathHistory.last != iata { profile.pathHistory.append(iata) }
            when = when.addingTimeInterval(2 * 86_400)
        }
    }

    private static func seedRelayJourney(_ context: ModelContext) {
        guard let profile = (try? context.fetch(FetchDescriptor<PlayerProfile>()))?.first,
              (try? context.fetch(FetchDescriptor<ActiveJourney>()))?.first == nil else { return }
        let store = AirportStore.shared
        let o = profile.currentIata
        guard let origin = store[o],
              let (edge, _) = store.routes(from: o)
                .filter({ TimeMapping.isRelayEligible(focusMinutes: TimeMapping.focusMinutes(forRealMinutes: $0.edge.realMinutes)) })
                .max(by: { $0.edge.km < $1.edge.km }),
              let dest = store[edge.destIata] else { return }
        let carrier = edge.carrierCodes.first ?? "MU"
        let journey = ActiveJourney(origin: origin, dest: dest, edge: edge,
                                    carrierCode: carrier,
                                    carrierName: store.carrierNames[carrier] ?? carrier,
                                    cabin: profile.cabin)
        journey.completedFocusMinutes = min(60, journey.focusMinutes / 2)
        journey.creditedKm = Int(Double(journey.totalKm) * journey.checkpointFraction)
        context.insert(journey)
    }

    private static func startFlyingSegment(_ context: ModelContext) {
        guard let profile = (try? context.fetch(FetchDescriptor<PlayerProfile>()))?.first else { return }
        let store = AirportStore.shared
        let landing = ProcessInfo.processInfo.arguments.contains("--demo-landing")
        let segMinutes = ProcessInfo.processInfo.arguments.contains("--demo-long-segment") ? 15 : 1
        if let journey = (try? context.fetch(FetchDescriptor<ActiveJourney>()))?.first {
            if landing { journey.completedFocusMinutes = journey.focusMinutes - 1 }
            FlightEngine.shared.startSegment(journey, minutes: segMinutes)
        } else if let (edge, dest) = store.routes(from: profile.currentIata)
                    .min(by: { $0.edge.km < $1.edge.km }),
                  let origin = store[profile.currentIata] {
            let carrier = edge.carrierCodes.first ?? "MU"
            let journey = ActiveJourney(origin: origin, dest: dest, edge: edge,
                                        carrierCode: carrier,
                                        carrierName: store.carrierNames[carrier] ?? carrier,
                                        cabin: profile.cabin)
            // --demo-landing: 只剩最后 1 分钟，落地后直接看点亮结算
            if landing { journey.completedFocusMinutes = journey.focusMinutes - 1 }
            context.insert(journey)
            FlightEngine.shared.startSegment(journey, minutes: segMinutes)
        }
        try? context.save()
    }
}
#endif
