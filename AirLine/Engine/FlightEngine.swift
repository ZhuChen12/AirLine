import ActivityKit
import Foundation
import SwiftData
import SwiftUI
import UserNotifications

/// 落地/检查点/备降 的结算结果，供 UI 呈现
struct FlightOutcome: Identifiable {
    enum Kind { case arrived, checkpoint, diverted, abandoned }
    let id = UUID()
    let kind: Kind
    let destIata: String
    let destCity: String
    let creditedKmDelta: Int
    let focusMinutesDelta: Int
    let isNewCity: Bool
    let isNewCountry: Bool
    let cabinBefore: CabinClass
    let cabinAfter: CabinClass
    let remainingFocusMinutes: Int
}

/// 核心状态机：值机 → 专注段 → 落地/检查点/备降/返航（SPEC §3）
@MainActor
@Observable
final class FlightEngine {
    static let shared = FlightEngine()

    /// 待 UI 展示的结算结果
    var pendingOutcome: FlightOutcome?

    /// 破戒宽限期（秒）
    static let graceSeconds: TimeInterval = 60

    private let defaults = UserDefaults.standard
    private let awayStartKey = "engine.awayStart"
    private let lockedKey = "engine.locked"

    private init() {}

    // MARK: - 值机与开段

    func checkIn(origin: Airport, edge: RouteEdge, dest: Airport,
                 carrierCode: String, segmentMinutes: Int, relayMode: Bool,
                 profile: PlayerProfile, context: ModelContext) {
        let carrierName = AirportStore.shared.carrierNames[carrierCode] ?? carrierCode
        let journey = ActiveJourney(origin: origin, dest: dest, edge: edge,
                                    carrierCode: carrierCode, carrierName: carrierName,
                                    cabin: profile.cabin,
                                    isDeveloper: profile.isDeveloper)
        journey.relayMode = relayMode
        context.insert(journey)
        startSegment(journey, minutes: segmentMinutes)
        try? context.save()
        requestNotificationPermission()
    }

    func startSegment(_ journey: ActiveJourney, minutes: Int) {
        let progressMinutes = TimeMapping.progressMinutes(
            forTimer: minutes,
            remaining: journey.remainingFocusMinutes
        )
        journey.segmentMinutes = journey.remainingFocusMinutes < TimeMapping.minimumTimerMinutes
            ? TimeMapping.minimumTimerMinutes
            : progressMinutes
        journey.segmentProgressMinutes = progressMinutes
        journey.segmentTimerSeconds = journey.isDeveloper ? 2 : 0
        journey.segmentStartAt = Date()
        clearAwayState()
        startLiveActivity(for: journey)
        scheduleLandingNotification(for: journey)
    }

    // MARK: - 前后台与锁屏（SPEC §3.2）

    func handleScenePhase(_ phase: ScenePhase, context: ModelContext) {
        switch phase {
        case .inactive, .background:
            guard hasActiveSegment(context) else { return }
            if !defaults.bool(forKey: lockedKey),
               defaults.object(forKey: awayStartKey) == nil {
                defaults.set(Date().timeIntervalSince1970, forKey: awayStartKey)
            }
        case .active:
            evaluateOnForeground(context: context)
        default:
            break
        }
    }

    /// 设备锁屏（有密码的设备会触发）：锁屏不算破戒
    func handleDeviceLocked() {
        defaults.set(true, forKey: lockedKey)
        defaults.removeObject(forKey: awayStartKey)
    }

    /// 设备解锁：若 App 仍在后台，从解锁时刻起算宽限
    func handleDeviceUnlocked(isAppActive: Bool) {
        defaults.set(false, forKey: lockedKey)
        if !isAppActive {
            defaults.set(Date().timeIntervalSince1970, forKey: awayStartKey)
        }
    }

    /// 回到前台/冷启动时结算：备降 or 落地 or 继续
    func evaluateOnForeground(context: ModelContext) {
        guard let journey = activeJourney(context), let start = journey.segmentStartAt else {
            clearAwayState()
            return
        }
        let end = start.addingTimeInterval(TimeInterval(journey.segmentDurationSeconds))
        let now = Date()

        // 破戒时刻 = 离开时刻 + 宽限。锁屏不记离开时间，不受影响。
        var breachAt: Date?
        if let t = defaults.object(forKey: awayStartKey) as? Double {
            breachAt = Date(timeIntervalSince1970: t + Self.graceSeconds)
        }
        clearAwayState()

        if let breach = breachAt, breach < min(now, end) {
            // 段结束前就已离开超过宽限：破戒在先，即使段已自然到期也判备降
            divert(journey, context: context)
        } else if now >= end {
            completeDueSegment(context: context)
        }
    }

    /// 冷启动恢复：若存在进行中的段
    func recoverOnLaunch(context: ModelContext) {
        guard let journey = activeJourney(context), let start = journey.segmentStartAt else { return }
        let end = start.addingTimeInterval(TimeInterval(journey.segmentDurationSeconds))
        if Date() >= end {
            completeDueSegment(context: context)
        } else {
            // App 中途被杀（用户上划杀掉或系统回收），视为离开
            divert(journey, context: context)
        }
    }

    // MARK: - 结算

    /// 段时间到：入账并推进（若整程完成则落地）
    func completeDueSegment(context: ModelContext) {
        guard let journey = activeJourney(context), let start = journey.segmentStartAt else { return }
        let end = start.addingTimeInterval(TimeInterval(journey.segmentDurationSeconds))
        guard Date() >= end else { return }

        let profile = fetchProfile(context)
        let cabinBefore = profile?.cabin ?? .economy

        let timerMin = journey.segmentMinutes
        let progressMin = journey.effectiveSegmentProgressMinutes
        journey.completedFocusMinutes += progressMin
        let isFinal = journey.completedFocusMinutes >= journey.focusMinutes
        let kmDelta: Int
        if isFinal {
            kmDelta = journey.totalKm - journey.creditedKm
        } else {
            kmDelta = Int((Double(journey.totalKm) * Double(progressMin) / Double(journey.focusMinutes)).rounded())
        }
        journey.creditedKm += kmDelta
        journey.segmentStartAt = nil
        journey.segmentMinutes = 0
        journey.segmentProgressMinutes = 0
        journey.segmentTimerSeconds = 0

        profile?.totalKm += kmDelta
        profile?.totalFocusMinutes += timerMin

        if isFinal {
            finalizeArrival(journey, kmDelta: kmDelta, segMin: timerMin,
                            cabinBefore: cabinBefore, profile: profile, context: context)
        } else {
            endLiveActivity()
            pendingOutcome = FlightOutcome(
                kind: .checkpoint,
                destIata: journey.destIata,
                destCity: AirportStore.shared[journey.destIata]?.displayCity ?? journey.destIata,
                creditedKmDelta: kmDelta,
                focusMinutesDelta: timerMin,
                isNewCity: false, isNewCountry: false,
                cabinBefore: cabinBefore,
                cabinAfter: profile?.cabin ?? cabinBefore,
                remainingFocusMinutes: journey.remainingFocusMinutes
            )
        }
        try? context.save()
    }

    private func finalizeArrival(_ journey: ActiveJourney, kmDelta: Int, segMin: Int,
                                 cabinBefore: CabinClass, profile: PlayerProfile?, context: ModelContext) {
        let now = Date()
        let record = FlightRecord(journey: journey, status: .completed, endedAt: now)
        context.insert(record)

        var isNewCity = false
        var isNewCountry = false
        if let dest = AirportStore.shared[journey.destIata] {
            let destIata = journey.destIata
            let isDeveloper = journey.isDeveloper
            var visitFetch = FetchDescriptor<CityVisit>(
                predicate: #Predicate { $0.iata == destIata && $0.isDeveloper == isDeveloper }
            )
            visitFetch.fetchLimit = 1
            if let visit = (try? context.fetch(visitFetch))?.first {
                visit.arrivalCount += 1
            } else {
                context.insert(CityVisit(airport: dest, at: now, isDeveloper: isDeveloper))
                isNewCity = true
            }
            let cc = dest.countryCode
            var stampFetch = FetchDescriptor<PassportStamp>(
                predicate: #Predicate { $0.countryCode == cc && $0.isDeveloper == isDeveloper }
            )
            stampFetch.fetchLimit = 1
            if (try? context.fetch(stampFetch))?.first == nil {
                context.insert(PassportStamp(countryCode: cc, country: dest.country,
                                             firstCity: dest.displayCity, stampedAt: now,
                                             isDeveloper: isDeveloper))
                isNewCountry = true
            }
        }

        profile?.currentIata = journey.destIata
        if profile?.pathHistory.last != journey.destIata {
            profile?.pathHistory.append(journey.destIata)
        }

        pendingOutcome = FlightOutcome(
            kind: .arrived,
            destIata: journey.destIata,
            destCity: AirportStore.shared[journey.destIata]?.displayCity ?? journey.destIata,
            creditedKmDelta: kmDelta,
            focusMinutesDelta: segMin,
            isNewCity: isNewCity, isNewCountry: isNewCountry,
            cabinBefore: cabinBefore,
            cabinAfter: profile?.cabin ?? cabinBefore,
            remainingFocusMinutes: 0
        )
        context.delete(journey)
        endLiveActivity()
        cancelLandingNotification()
    }

    /// 备降：作废当前段；非接力旅程整程结束（SPEC §3.2 §3.4）
    func divert(_ journey: ActiveJourney, context: ModelContext) {
        let profile = fetchProfile(context)
        let cabin = profile?.cabin ?? .economy
        journey.segmentStartAt = nil
        journey.segmentMinutes = 0
        journey.segmentProgressMinutes = 0
        journey.segmentTimerSeconds = 0

        let isRelayJourney = journey.isRelayJourney
        let destIata = journey.destIata
        let destCity = AirportStore.shared[destIata]?.displayCity ?? destIata
        let remaining = isRelayJourney ? journey.remainingFocusMinutes : 0

        if !isRelayJourney {
            let record = FlightRecord(journey: journey, status: .diverted, endedAt: Date())
            context.insert(record)
            context.delete(journey)
        }
        pendingOutcome = FlightOutcome(
            kind: .diverted,
            destIata: destIata,
            destCity: destCity,
            creditedKmDelta: 0, focusMinutesDelta: 0,
            isNewCity: false, isNewCountry: false,
            cabinBefore: cabin, cabinAfter: cabin,
            remainingFocusMinutes: remaining
        )
        endLiveActivity()
        cancelLandingNotification()
        try? context.save()
    }

    /// 返航：主动放弃接力旅程，已入账里程保留
    func abandon(_ journey: ActiveJourney, context: ModelContext) {
        let record = FlightRecord(journey: journey, status: .abandoned, endedAt: Date())
        context.insert(record)
        context.delete(journey)
        endLiveActivity()
        cancelLandingNotification()
        try? context.save()
    }

    /// 调机兜底：免费回上一个途经枢纽（SPEC §3.3）
    func reposition(profile: PlayerProfile, context: ModelContext) {
        let history = profile.pathHistory
        if let idx = history.lastIndex(of: profile.currentIata), idx > 0 {
            profile.currentIata = history[idx - 1]
        } else {
            profile.currentIata = profile.homeIata
        }
        try? context.save()
    }

    // MARK: - 查询

    func activeJourney(_ context: ModelContext) -> ActiveJourney? {
        let isDeveloper = DeveloperAccess.isActive
        var descriptor = FetchDescriptor<ActiveJourney>(
            predicate: #Predicate { $0.isDeveloper == isDeveloper }
        )
        descriptor.fetchLimit = 1
        return (try? context.fetch(descriptor))?.first
    }

    func hasActiveSegment(_ context: ModelContext) -> Bool {
        activeJourney(context)?.segmentStartAt != nil
    }

    private func fetchProfile(_ context: ModelContext) -> PlayerProfile? {
        let isDeveloper = DeveloperAccess.isActive
        var descriptor = FetchDescriptor<PlayerProfile>(
            predicate: #Predicate { $0.isDeveloper == isDeveloper }
        )
        descriptor.fetchLimit = 1
        return (try? context.fetch(descriptor))?.first
    }

    private func clearAwayState() {
        defaults.removeObject(forKey: awayStartKey)
        defaults.set(false, forKey: lockedKey)
    }

    // MARK: - Live Activity

    private var activity: Activity<FlightActivityAttributes>?

    private func startLiveActivity(for journey: ActiveJourney) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled,
              let start = journey.segmentStartAt else { return }
        let store = AirportStore.shared
        let attrs = FlightActivityAttributes(
            originCode: journey.originIata,
            destCode: journey.destIata,
            originCity: store[journey.originIata]?.displayCity ?? journey.originIata,
            destCity: store[journey.destIata]?.displayCity ?? journey.destIata,
            flightNumber: journey.flightNumber,
            carrierName: journey.carrierName,
            cabinCode: journey.cabin.code
        )
        let end = start.addingTimeInterval(TimeInterval(journey.segmentDurationSeconds))
        let state = FlightActivityAttributes.ContentState(
            segmentStart: start, segmentEnd: end,
            fractionStart: journey.checkpointFraction,
            fractionEnd: journey.segmentEndFraction
        )
        endLiveActivity()
        activity = try? Activity.request(
            attributes: attrs,
            content: .init(state: state, staleDate: end.addingTimeInterval(300))
        )
    }

    private func endLiveActivity() {
        guard let act = activity else {
            // 兜底：清掉遗留的活动（如冷启动恢复场景）
            for a in Activity<FlightActivityAttributes>.activities {
                Task { await a.end(nil, dismissalPolicy: .immediate) }
            }
            return
        }
        activity = nil
        Task { await act.end(nil, dismissalPolicy: .immediate) }
    }

    // MARK: - 本地通知

    private let notifId = "airline.landing"

    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    private func scheduleLandingNotification(for journey: ActiveJourney) {
        guard let end = journey.segmentEndAt else { return }
        let content = UNMutableNotificationContent()
        let isFinal = journey.completedFocusMinutes + journey.effectiveSegmentProgressMinutes >= journey.focusMinutes
        let destCity = AirportStore.shared[journey.destIata]?.displayCity ?? journey.destIata
        content.title = isFinal ? "已抵达 \(destCity)" : "本段飞行完成"
        content.body = isFinal ? "航班 \(journey.flightNumber) 平稳落地，回来点亮城市、领取里程。"
                               : "旅程已保存至检查点，回来查看进度。"
        content.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: max(1, end.timeIntervalSinceNow), repeats: false)
        let req = UNNotificationRequest(identifier: notifId, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(req)
    }

    private func cancelLandingNotification() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [notifId])
    }
}
