import SwiftData
import SwiftUI

/// 一张候选航线
struct RouteCandidate: Identifiable {
    let edge: RouteEdge
    let dest: Airport
    let focusMinutes: Int
    let requiredCabin: CabinClass
    let isBaseRoute: Bool
    let visited: Bool

    var id: String { dest.icaoKey }
    var hubRouteCount: Int { dest.routes.count }
    var relayCapable: Bool {
        TimeMapping.isRelayCapable(
            focusMinutes: focusMinutes,
            routeKey: "\(edge.destIata)-\(edge.km)-\(edge.realMinutes)"
        )
    }
    func isLocked(for cabin: CabinClass) -> Bool { requiredCabin > cabin }
    func isRelayLocked(for cabin: CabinClass) -> Bool { relayCapable && !cabin.relayUnlocked }
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
        case .relay: return c.relayCapable
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
    @State private var searchText = ""

    private var scopedVisits: [CityVisit] {
        visits.filter { $0.isDeveloper == profile.isDeveloper }
    }

    private var directCandidates: [RouteCandidate] {
        let visitedSet = Set(scopedVisits.map(\.iata))
        let routes = AirportStore.shared.routes(from: profile.currentIata)
        // 防止小机场被高等级枢纽包围：每个出发地至少保留 6 条基础航路。
        let baseRouteIatas = Set(routes
            .sorted {
                if $0.dest.routes.count != $1.dest.routes.count {
                    return $0.dest.routes.count < $1.dest.routes.count
                }
                return $0.edge.km < $1.edge.km
            }
            .prefix(6)
            .map { $0.dest.icaoKey })
        var seenDestinations = Set<String>()
        return routes.compactMap { edge, dest in
            guard seenDestinations.insert(dest.icaoKey).inserted else { return nil }
            let isBase = baseRouteIatas.contains(dest.icaoKey)
                || dest.icaoKey == profile.homeIata
            return RouteCandidate(
                edge: edge,
                dest: dest,
                focusMinutes: TimeMapping.focusMinutes(forRealMinutes: edge.realMinutes),
                requiredCabin: isBase
                    ? .economy
                    : CabinClass.required(forHubRouteCount: dest.routes.count),
                isBaseRoute: isBase,
                visited: visitedSet.contains(dest.icaoKey)
            )
        }
    }

    private var candidates: [RouteCandidate] {
        let cabin = profile.cabin
        var items = directCandidates
        // 未点亮优先，其次按距离；锁定枢纽穿插展示升级方向。
        items.sort {
            if $0.visited != $1.visited { return !$0.visited }
            return $0.edge.km < $1.edge.km
        }
        let unlocked = items.filter { !$0.isLocked(for: cabin) }
        let locked = items.filter { $0.isLocked(for: cabin) }.prefix(12)
        var merged = unlocked
        for (i, card) in locked.enumerated() {
            merged.insert(card, at: min(merged.count, (i + 1) * 7))
        }
        return merged
    }

    private var normalizedSearch: String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var searchResults: [Airport] {
        guard !normalizedSearch.isEmpty else { return [] }
        return AirportStore.shared.search(normalizedSearch, limit: AirportStore.shared.airports.count)
    }

    private var directCandidatesByIata: [String: RouteCandidate] {
        var indexed: [String: RouteCandidate] = [:]
        for candidate in directCandidates where indexed[candidate.dest.icaoKey] == nil {
            indexed[candidate.dest.icaoKey] = candidate
        }
        return indexed
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.bg.ignoresSafeArea()
                VStack(spacing: 0) {
                    searchField

                    HStack(spacing: 8) {
                        Image(systemName: "lightbulb.fill")
                            .foregroundStyle(Theme.glow)
                        Text("Tips：升级解锁更多城市")
                            .font(.caption)
                            .foregroundStyle(Theme.textSecondary)
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 10)

                    if normalizedSearch.isEmpty {
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
                                            .background(
                                                filter == f ? Theme.glow.opacity(0.18) : Theme.card,
                                                in: Capsule()
                                            )
                                            .foregroundStyle(
                                                filter == f ? Theme.glow : Theme.textSecondary
                                            )
                                    }
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                        }
                    }

                    if normalizedSearch.isEmpty {
                        routeList(candidates.filter { filter.matches($0) })
                    } else if searchResults.isEmpty {
                        emptyState("无匹配结果")
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 10) {
                                ForEach(searchResults) { airport in
                                    if let candidate = directCandidatesByIata[airport.icaoKey] {
                                        Button { selected = candidate } label: {
                                            RouteCardRow(
                                                candidate: candidate,
                                                cabin: profile.cabin
                                            )
                                        }
                                        .buttonStyle(.plain)
                                    } else {
                                        UnavailableDestinationRow(
                                            airport: airport,
                                            isCurrent: airport.icaoKey == profile.currentIata
                                        )
                                    }
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.bottom, 24)
                        }
                    }
                }
            }
            .navigationTitle("选择目的地")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                }
            }
            .onAppear {
                #if DEBUG
                let args = ProcessInfo.processInfo.arguments
                if args.contains("--demo-checkin") {
                    Task {
                        try? await Task.sleep(for: .milliseconds(700))
                        selected = candidates.first { !$0.isLocked(for: profile.cabin) }
                    }
                }
                if args.contains("--demo-checkin-relay") {
                    Task {
                        try? await Task.sleep(for: .milliseconds(700))
                        selected = directCandidates.first {
                            $0.relayCapable && !$0.isLocked(for: profile.cabin)
                        }
                    }
                }
                if let searchArgument = args.first(where: { $0.hasPrefix("--demo-search=") }) {
                    searchText = String(searchArgument.dropFirst("--demo-search=".count))
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

    private var searchField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(Theme.textSecondary)
            TextField("搜索国家、城市或机场", text: $searchText)
                .textFieldStyle(.plain)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(Theme.textSecondary)
                }
            }
        }
        .padding(12)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal, 16)
        .padding(.top, 10)
    }

    @ViewBuilder
    private func routeList(_ shown: [RouteCandidate]) -> some View {
        if shown.isEmpty {
            emptyState("该时长下暂无可选航线\n试试其他档位或调机")
        } else {
            ScrollView {
                LazyVStack(spacing: 10) {
                    ForEach(shown) { candidate in
                        Button { selected = candidate } label: {
                            RouteCardRow(candidate: candidate, cabin: profile.cabin)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
        }
    }

    private func emptyState(_ text: String) -> some View {
        VStack {
            Spacer()
            Text(text)
                .multilineTextAlignment(.center)
                .foregroundStyle(Theme.textSecondary)
            Spacer()
        }
    }
}

private struct UnavailableDestinationRow: View {
    let airport: Airport
    let isCurrent: Bool

    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 2)
                .fill(Theme.textSecondary.opacity(0.3))
                .frame(width: 4, height: 52)
            CityLandmarkThumbnail(iata: airport.icaoKey, isDimmed: true)
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(airport.displayCity)
                        .font(.headline)
                        .foregroundStyle(Theme.textPrimary)
                    Text(airport.icaoKey)
                        .font(.system(.caption, design: .monospaced).bold())
                        .foregroundStyle(Theme.glowDim)
                }
                Text("\(airport.displayCountry) · \(airport.name)")
                    .font(.caption2)
                    .foregroundStyle(Theme.textSecondary)
                    .lineLimit(1)
            }
            Spacer()
            Text(isCurrent ? "当前所在城市" : "无法直飞\n继续探索")
                .font(.caption2)
                .multilineTextAlignment(.trailing)
                .foregroundStyle(Theme.textSecondary)
        }
        .padding(14)
        .background(Theme.card.opacity(0.72), in: RoundedRectangle(cornerRadius: 14))
    }
}

/// 卡片墙中的单行迷你登机牌
struct RouteCardRow: View {
    let candidate: RouteCandidate
    let cabin: CabinClass

    private var locked: Bool { candidate.isLocked(for: cabin) }
    private var relayLocked: Bool { candidate.isRelayLocked(for: cabin) }
    private var accent: Color { Theme.cabinColor(candidate.requiredCabin) }

    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 2)
                .fill(locked ? Theme.textSecondary.opacity(0.4) : accent)
                .frame(width: 4, height: 52)

            CityLandmarkThumbnail(
                iata: candidate.dest.icaoKey,
                isDimmed: locked || relayLocked
            )

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
                    if candidate.relayCapable {
                        Image(systemName: "point.topleft.down.to.point.bottomright.curvepath")
                            .font(.system(size: 10))
                            .foregroundStyle(relayLocked ? Theme.textSecondary : Theme.track)
                    }
                }
                Text("\(candidate.dest.displayCountry) · \(candidate.edge.km) km · 航程 \(TimeMapping.formatMinutes(candidate.edge.realMinutes))")
                    .font(.caption2)
                    .foregroundStyle(Theme.textSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }
            Spacer()
            if locked {
                VStack(alignment: .trailing, spacing: 3) {
                    Image(systemName: "lock.fill").foregroundStyle(Theme.textSecondary)
                    Text("\(candidate.requiredCabin.nameZh)解锁枢纽")
                        .font(.system(size: 9))
                        .foregroundStyle(Theme.textSecondary)
                }
            } else if relayLocked {
                VStack(alignment: .trailing, spacing: 3) {
                    Image(systemName: "lock.fill").foregroundStyle(Theme.textSecondary)
                    Text("优选经济舱\n可接力")
                        .font(.system(size: 9))
                        .multilineTextAlignment(.trailing)
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
        .opacity(locked || relayLocked ? 0.62 : 1)
    }
}

private struct CityLandmarkThumbnail: View {
    let iata: String
    var isDimmed = false

    private var image: UIImage? {
        CitySceneryService.shared.image(for: iata)
    }

    var body: some View {
        if let image {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: 76, height: 54)
                .clipped()
                .saturation(isDimmed ? 0.25 : 0.9)
                .brightness(isDimmed ? -0.08 : 0)
                .overlay {
                    LinearGradient(
                        colors: [.clear, Theme.bg.opacity(0.18)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                }
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
    }
}

/// 值机页：目的地小传 + 登机牌预览 + 段长选择（SPEC §4 §3.4）
struct CheckInSheet: View {
    let candidate: RouteCandidate
    let profile: PlayerProfile
    var onCheckedIn: () -> Void

    @Environment(\.modelContext) private var context
    @State private var bioService = CityBioService.shared
    @State private var showInitialSegmentPicker = false
    @State private var didOfferInitialSegmentPicker = false

    private var locked: Bool { candidate.isLocked(for: profile.cabin) }
    private var relayAvailable: Bool { candidate.relayCapable && profile.cabin.relayUnlocked }
    private var relayLockedByCabin: Bool { candidate.isRelayLocked(for: profile.cabin) }

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
                    if relayLockedByCabin {
                        Text("本航线可一次坐完；达到优选经济舱后可拆分为多段接力。")
                            .font(.footnote)
                            .foregroundStyle(Theme.textSecondary)
                    }
                    checkInButton
                }
            }
            .padding(16)
        }
        .background(Theme.bgElevated)
        .task {
            guard relayAvailable, !didOfferInitialSegmentPicker else { return }
            didOfferInitialSegmentPicker = true
            try? await Task.sleep(for: .milliseconds(650))
            showInitialSegmentPicker = true
        }
        .sheet(isPresented: $showInitialSegmentPicker) {
            SegmentDurationSheet(
                title: "选择首段 \(profile.currentIata) → \(candidate.dest.icaoKey)",
                remaining: candidate.focusMinutes,
                actionTitle: "值机并起飞"
            ) { minutes in
                checkIn(segmentMinutes: minutes, relayMode: true)
            }
            .presentationDetents([.medium])
            .presentationBackground(Theme.bgElevated)
        }
    }

    private var lockedBanner: some View {
        HStack {
            Image(systemName: "lock.fill")
            VStack(alignment: .leading, spacing: 3) {
                Text("\(candidate.requiredCabin.nameZh)可解锁 \(candidate.dest.displayCity)")
                    .font(.subheadline.bold())
                Text("该机场连接 \(candidate.hubRouteCount) 座城市 · 还需 \(max(0, candidate.requiredCabin.thresholdKm - profile.totalKm)) km")
                    .font(.caption)
                    .foregroundStyle(Theme.textSecondary)
            }
            Spacer()
        }
        .foregroundStyle(Theme.textPrimary)
        .padding(16)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 14))
    }

    private var checkInButton: some View {
        Button {
            if relayAvailable {
                showInitialSegmentPicker = true
            } else {
                checkIn(segmentMinutes: candidate.focusMinutes, relayMode: false)
            }
        } label: {
            HStack {
                Image(systemName: "airplane.departure")
                Text(
                    relayAvailable
                        ? "选择本段时间"
                        : "值机并起飞 · 专注 \(TimeMapping.formatMinutes(candidate.focusMinutes))"
                )
            }
            .font(.headline)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Theme.glow, in: RoundedRectangle(cornerRadius: 12))
            .foregroundStyle(Theme.bg)
        }
    }

    private func checkIn(segmentMinutes: Int, relayMode: Bool) {
        guard let origin = AirportStore.shared[profile.currentIata],
              let carrier = candidate.edge.carrierCodes.first else { return }
        FlightEngine.shared.checkIn(
            origin: origin,
            edge: candidate.edge,
            dest: candidate.dest,
            carrierCode: carrier,
            segmentMinutes: segmentMinutes,
            relayMode: relayMode,
            profile: profile,
            context: context
        )
        onCheckedIn()
    }
}
