import SwiftData
import SwiftUI

/// 一张候选航线
struct RouteCandidate: Identifiable {
    let edge: RouteEdge
    let dest: Airport
    let focusMinutes: Int
    let requiredCabin: CabinClass
    let visited: Bool

    var id: String { dest.icaoKey }
    var relayEligible: Bool { TimeMapping.isRelayEligible(focusMinutes: focusMinutes) }
    func isLocked(for cabin: CabinClass) -> Bool { requiredCabin > cabin }
}

enum DurationFilter: String, CaseIterable, Identifiable {
    case all = "全部"
    case short = "≤30分"
    case medium = "31–60分"
    case long = ">60分"
    case relay = "可接力"
    var id: String { rawValue }

    func matches(_ c: RouteCandidate) -> Bool {
        switch self {
        case .all: return true
        case .short: return c.focusMinutes <= 30
        case .medium: return c.focusMinutes > 30 && c.focusMinutes <= 60
        case .long: return c.focusMinutes > 60
        case .relay: return c.relayEligible
        }
    }
}

/// 登机牌卡片墙：从当前城市可直飞的目的地中选择（SPEC §4）
struct RouteBoardView: View {
    let profile: PlayerProfile
    @Environment(\.dismiss) private var dismiss
    @Query private var visits: [CityVisit]
    @State private var filter: DurationFilter = .all
    @State private var selected: RouteCandidate?

    private var candidates: [RouteCandidate] {
        let visitedSet = Set(visits.map(\.iata))
        let cabin = profile.cabin
        var items: [RouteCandidate] = AirportStore.shared
            .routes(from: profile.currentIata)
            .map { edge, dest in
                RouteCandidate(edge: edge, dest: dest,
                               focusMinutes: TimeMapping.focusMinutes(forRealMinutes: edge.realMinutes),
                               requiredCabin: CabinClass.required(forRouteKm: edge.km),
                               visited: visitedSet.contains(dest.icaoKey))
            }
        // 未点亮优先，其次按距离；锁定卡自然混排（SPEC §4）
        items.sort {
            if $0.visited != $1.visited { return !$0.visited }
            return $0.edge.km < $1.edge.km
        }
        let unlocked = items.filter { !$0.isLocked(for: cabin) }.prefix(60)
        let locked = items.filter { $0.isLocked(for: cabin) }.prefix(3)
        var merged = Array(unlocked)
        for (i, card) in locked.enumerated() {
            merged.insert(card, at: min(merged.count, (i + 1) * 5))
        }
        return merged
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.bg.ignoresSafeArea()
                VStack(spacing: 0) {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(DurationFilter.allCases) { f in
                                Button {
                                    filter = f
                                } label: {
                                    Text(f.rawValue)
                                        .font(.footnote.weight(filter == f ? .bold : .regular))
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(filter == f ? Theme.glow.opacity(0.18) : Theme.card,
                                                    in: Capsule())
                                        .foregroundStyle(filter == f ? Theme.glow : Theme.textSecondary)
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                    }

                    let shown = candidates.filter { filter.matches($0) }
                    if shown.isEmpty {
                        Spacer()
                        Text("该时长下暂无可选航线\n试试其他档位或调机")
                            .multilineTextAlignment(.center)
                            .foregroundStyle(Theme.textSecondary)
                        Spacer()
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 10) {
                                ForEach(shown) { c in
                                    Button { selected = c } label: {
                                        RouteCardRow(candidate: c, cabin: profile.cabin)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.bottom, 24)
                        }
                    }
                }
            }
            .navigationTitle("\(AirportStore.shared[profile.currentIata]?.displayCity ?? profile.currentIata) 出发")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                }
            }
            .onAppear {
                #if DEBUG
                if ProcessInfo.processInfo.arguments.contains("--demo-checkin") {
                    selected = candidates.first { !$0.isLocked(for: profile.cabin) }
                }
                #endif
            }
            .sheet(item: $selected) { c in
                CheckInSheet(candidate: c, profile: profile) {
                    selected = nil
                    dismiss()
                }
                .presentationDetents([.large])
                .presentationBackground(Theme.bgElevated)
            }
        }
        .preferredColorScheme(.dark)
    }
}

/// 卡片墙中的单行迷你登机牌
struct RouteCardRow: View {
    let candidate: RouteCandidate
    let cabin: CabinClass

    private var locked: Bool { candidate.isLocked(for: cabin) }
    private var accent: Color { Theme.cabinColor(candidate.requiredCabin) }

    var body: some View {
        HStack(spacing: 14) {
            RoundedRectangle(cornerRadius: 2)
                .fill(locked ? Theme.textSecondary.opacity(0.4) : accent)
                .frame(width: 4, height: 46)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(candidate.dest.displayCity)
                        .font(.headline)
                        .foregroundStyle(Theme.textPrimary)
                    Text(candidate.dest.icaoKey)
                        .font(.system(.caption, design: .monospaced).bold())
                        .foregroundStyle(Theme.glow)
                    if candidate.visited {
                        Text("已点亮")
                            .font(.system(size: 9))
                            .padding(.horizontal, 5).padding(.vertical, 2)
                            .background(Theme.glow.opacity(0.14), in: Capsule())
                            .foregroundStyle(Theme.glowDim)
                    }
                    if candidate.relayEligible {
                        Image(systemName: "point.topleft.down.to.point.bottomright.curvepath")
                            .font(.system(size: 10))
                            .foregroundStyle(Theme.track)
                    }
                }
                Text("\(candidate.dest.country) · \(candidate.edge.km) km · 航程 \(TimeMapping.formatMinutes(candidate.edge.realMinutes))")
                    .font(.caption2)
                    .foregroundStyle(Theme.textSecondary)
            }
            Spacer()
            if locked {
                VStack(alignment: .trailing, spacing: 3) {
                    Image(systemName: "lock.fill").foregroundStyle(Theme.textSecondary)
                    Text("\(candidate.requiredCabin.nameZh)解锁")
                        .font(.system(size: 9))
                        .foregroundStyle(Theme.textSecondary)
                }
            } else {
                VStack(alignment: .trailing, spacing: 2) {
                    Text(TimeMapping.formatMinutes(candidate.focusMinutes))
                        .font(.system(.subheadline, design: .monospaced).bold())
                        .foregroundStyle(Theme.textPrimary)
                    Text("专注").font(.system(size: 9)).foregroundStyle(Theme.textSecondary)
                }
            }
        }
        .padding(14)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 14))
        .opacity(locked ? 0.62 : 1)
    }
}

/// 值机页：目的地小传 + 登机牌预览 + 段长选择（SPEC §4 §3.4）
struct CheckInSheet: View {
    let candidate: RouteCandidate
    let profile: PlayerProfile
    var onCheckedIn: () -> Void

    @Environment(\.modelContext) private var context
    @State private var bioService = CityBioService.shared
    @State private var segmentMinutes: Int = 0

    private var locked: Bool { candidate.isLocked(for: profile.cabin) }
    private var relayAvailable: Bool { candidate.relayEligible && profile.cabin.relayUnlocked }
    private var relayLockedByCabin: Bool { candidate.relayEligible && !profile.cabin.relayUnlocked }

    private var passPreview: BoardingPassData {
        let store = AirportStore.shared
        let origin = store[profile.currentIata]
        let carrier = candidate.edge.carrierCodes.first ?? "XX"
        return BoardingPassData(
            passengerName: profile.name,
            carrierName: store.carrierNames[carrier] ?? carrier,
            flightNumber: Generators.flightNumber(carrier: carrier, origin: profile.currentIata,
                                                  dest: candidate.dest.icaoKey),
            cabin: profile.cabin,
            originIata: profile.currentIata,
            originCity: origin?.displayCity ?? profile.currentIata,
            destIata: candidate.dest.icaoKey,
            destCity: candidate.dest.displayCity,
            realMinutes: candidate.edge.realMinutes,
            focusMinutes: candidate.focusMinutes,
            km: candidate.edge.km,
            seat: Generators.seat(cabin: profile.cabin, seed: "preview-\(candidate.dest.icaoKey)"),
            gate: Generators.gate(origin: profile.currentIata, dest: candidate.dest.icaoKey, date: Date()),
            date: Date(),
            departureTZ: origin?.tz ?? .current,
            arrivalTZ: candidate.dest.tz
        )
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                BoardingPassView(data: passPreview)

                // 目的地小传
                VStack(alignment: .leading, spacing: 8) {
                    Text("关于 \(candidate.dest.displayCity)")
                        .font(.caption)
                        .foregroundStyle(Theme.textSecondary)
                    let bio = bioService.bio(for: candidate.dest.icaoKey)
                        ?? bioService.fallback(for: candidate.dest)
                    Text("【\(bio.tag)】")
                        .font(.subheadline.bold())
                        .foregroundStyle(Theme.glow)
                    Text(bio.body)
                        .font(.subheadline)
                        .foregroundStyle(Theme.textPrimary.opacity(0.9))
                        .lineSpacing(5)
                }
                .padding(16)
                .background(Theme.card, in: RoundedRectangle(cornerRadius: 14))

                if locked {
                    lockedBanner
                } else {
                    if relayAvailable {
                        segmentPicker
                    } else if relayLockedByCabin {
                        Text("此航线需要接力飞行 · 优选经济（累计 5,000 km）解锁")
                            .font(.footnote)
                            .foregroundStyle(Theme.textSecondary)
                    }
                    checkInButton
                }
            }
            .padding(16)
        }
        .background(Theme.bgElevated)
        .onAppear {
            segmentMinutes = relayAvailable ? min(45, candidate.focusMinutes) : candidate.focusMinutes
        }
    }

    private var lockedBanner: some View {
        HStack {
            Image(systemName: "lock.fill")
            VStack(alignment: .leading, spacing: 3) {
                Text("\(candidate.requiredCabin.nameZh)可解锁本航线")
                    .font(.subheadline.bold())
                Text("还需 \(max(0, candidate.requiredCabin.thresholdKm - profile.totalKm)) km 里程")
                    .font(.caption)
                    .foregroundStyle(Theme.textSecondary)
            }
            Spacer()
        }
        .foregroundStyle(Theme.textPrimary)
        .padding(16)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 14))
    }

    private var segmentPicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("接力飞行 · 选择本段专注时长")
                .font(.caption)
                .foregroundStyle(Theme.textSecondary)
            let opts = TimeMapping.segmentOptions(remaining: candidate.focusMinutes)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(opts, id: \.self) { m in
                        Button {
                            segmentMinutes = m
                        } label: {
                            VStack(spacing: 2) {
                                Text(TimeMapping.formatMinutes(m)).font(.subheadline.bold())
                                if m == candidate.focusMinutes {
                                    Text("一次坐完").font(.system(size: 9))
                                }
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(segmentMinutes == m ? Theme.glow.opacity(0.2) : Theme.card,
                                        in: RoundedRectangle(cornerRadius: 10))
                            .foregroundStyle(segmentMinutes == m ? Theme.glow : Theme.textSecondary)
                        }
                    }
                }
            }
        }
        .padding(16)
        .background(Theme.card.opacity(0.5), in: RoundedRectangle(cornerRadius: 14))
    }

    private var checkInButton: some View {
        Button {
            guard let origin = AirportStore.shared[profile.currentIata],
                  let carrier = candidate.edge.carrierCodes.first else { return }
            FlightEngine.shared.checkIn(origin: origin, edge: candidate.edge, dest: candidate.dest,
                                        carrierCode: carrier, segmentMinutes: segmentMinutes,
                                        profile: profile, context: context)
            onCheckedIn()
        } label: {
            HStack {
                Image(systemName: "airplane.departure")
                Text(relayAvailable && segmentMinutes < candidate.focusMinutes
                     ? "值机并起飞 · 本段 \(TimeMapping.formatMinutes(segmentMinutes))"
                     : "值机并起飞 · 专注 \(TimeMapping.formatMinutes(candidate.focusMinutes))")
            }
            .font(.headline)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Theme.glow, in: RoundedRectangle(cornerRadius: 12))
            .foregroundStyle(Theme.bg)
        }
    }
}
