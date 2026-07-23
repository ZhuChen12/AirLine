import SwiftData
import SwiftUI

/// 飞行 Tab：当前位置 + 未完成旅程 + 发起新飞行（SPEC §10）
struct FlyHomeView: View {
    let profile: PlayerProfile
    @Environment(\.modelContext) private var context
    @Query private var journeys: [ActiveJourney]
    @State private var showBoard = false
    @State private var showAbandonConfirm = false
    @State private var showSegmentPicker = false
    @State private var showCabinRules = false
    private let sceneryService = CitySceneryService.shared

    private var journey: ActiveJourney? {
        journeys.first { $0.isDeveloper == profile.isDeveloper }
    }
    private var currentAirport: Airport? { AirportStore.shared[profile.currentIata] }
    private var hasUnlockedRoutes: Bool {
        !AirportStore.shared.routes(from: profile.currentIata).isEmpty
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                Theme.bg.ignoresSafeArea()
                if let currentAirport,
                   let image = sceneryService.image(for: currentAirport.icaoKey) {
                    CitySceneryBackdrop(
                        image: image
                    )
                    .frame(height: 390)
                    .ignoresSafeArea(edges: .top)
                }
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        locationHeader
                        cabinCard
                        if let j = journey {
                            journeyCard(j)
                        } else {
                            startButton
                            if !hasUnlockedRoutes {
                                repositionCard
                            }
                        }
                    }
                    .padding(16)
                }
            }
            .navigationTitle("飞行")
            .navigationBarTitleDisplayMode(.inline)
        }
        #if DEBUG
        .onAppear {
            if ProcessInfo.processInfo.arguments.contains("--demo-board") { showBoard = true }
            if ProcessInfo.processInfo.arguments.contains("--demo-segment-picker") {
                Task {
                    try? await Task.sleep(for: .milliseconds(600))
                    showSegmentPicker = true
                }
            }
        }
        #endif
        .fullScreenCover(isPresented: $showBoard) {
            RouteBoardView(profile: profile)
        }
        .sheet(isPresented: $showSegmentPicker) {
            if let j = journey {
                SegmentDurationSheet(
                    title: "继续飞行 \(j.originIata) → \(j.destIata)",
                    remaining: j.remainingFocusMinutes,
                    actionTitle: "起飞"
                ) { minutes in
                    FlightEngine.shared.startSegment(j, minutes: minutes)
                }
                    .presentationDetents([.medium])
                    .presentationBackground(Theme.bgElevated)
            }
        }
        .sheet(isPresented: $showCabinRules) {
            CabinRulesView(totalKm: profile.totalKm)
        }
        .confirmationDialog("确认返航？", isPresented: $showAbandonConfirm, titleVisibility: .visible) {
            Button("放弃旅程并返航", role: .destructive) {
                if let j = journey {
                    FlightEngine.shared.abandon(j, context: context)
                }
            }
            Button("继续飞", role: .cancel) {}
        } message: {
            Text("已入账的里程会保留，但目的地不会点亮。")
        }
    }

    private var locationHeader: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("当前位置")
                .font(.caption)
                .foregroundStyle(Theme.textSecondary)
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(currentAirport?.displayCity ?? profile.currentIata)
                    .font(.system(size: 34, weight: .black))
                    .foregroundStyle(Theme.textPrimary)
                Text(profile.currentIata)
                    .font(.system(.title3, design: .monospaced).bold())
                    .foregroundStyle(Theme.glow)
            }
            Text(currentAirport?.name ?? "")
                .font(.footnote)
                .foregroundStyle(Theme.textSecondary)
        }
        .padding(.top, 8)
        .shadow(color: Theme.bg.opacity(0.9), radius: 8, y: 2)
    }

    private var cabinCard: some View {
        let cabin = profile.cabin
        let next = cabin.next
        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(cabin.nameZh)
                    .font(.subheadline.bold())
                    .foregroundStyle(Theme.cabinColor(cabin))
                Text(cabin.code)
                    .font(.system(.caption, design: .monospaced).bold())
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(Theme.cabinColor(cabin).opacity(0.15), in: Capsule())
                    .foregroundStyle(Theme.cabinColor(cabin))
                Spacer()
                Text("\(profile.totalKm) km")
                    .font(.system(.subheadline, design: .monospaced))
                    .foregroundStyle(Theme.textPrimary)
            }
            if let next {
                ProgressView(value: Double(profile.totalKm - cabin.thresholdKm),
                             total: Double(next.thresholdKm - cabin.thresholdKm))
                    .tint(Theme.cabinColor(next))
                Text("距 \(next.nameZh) 还需 \(max(0, next.thresholdKm - profile.totalKm)) km")
                    .font(.caption2)
                    .foregroundStyle(Theme.textSecondary)
            } else {
                Text("已达最高舱位")
                    .font(.caption2)
                    .foregroundStyle(Theme.textSecondary)
            }
            Divider()
                .overlay(Theme.landStroke)
                .padding(.top, 2)
            Button {
                showCabinRules = true
            } label: {
                HStack {
                    Label("查看升级规则与权益", systemImage: "list.star")
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption2)
                }
                .font(.caption)
                .foregroundStyle(Theme.textPrimary)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 14))
    }

    private func journeyCard(_ j: ActiveJourney) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("旅程进行中", systemImage: "airplane")
                    .font(.subheadline.bold())
                    .foregroundStyle(Theme.glow)
                Spacer()
                Text(j.flightNumber)
                    .font(.system(.subheadline, design: .monospaced))
                    .foregroundStyle(Theme.textSecondary)
            }
            HStack(spacing: 10) {
                Text(j.originIata)
                    .font(.system(.title2, design: .monospaced).bold())
                Image(systemName: "arrow.right")
                    .foregroundStyle(Theme.textSecondary)
                Text(j.destIata)
                    .font(.system(.title2, design: .monospaced).bold())
                Spacer()
                Text(AirportStore.shared[j.destIata]?.displayCity ?? "")
                    .font(.subheadline)
                    .foregroundStyle(Theme.textSecondary)
            }
            .foregroundStyle(Theme.textPrimary)

            ProgressView(value: j.checkpointFraction)
                .tint(Theme.glow)
            Text("已飞 \(TimeMapping.formatMinutes(j.completedFocusMinutes)) / 全程 \(TimeMapping.formatMinutes(j.focusMinutes)) · 剩余 \(TimeMapping.formatMinutes(j.remainingFocusMinutes))")
                .font(.caption)
                .foregroundStyle(Theme.textSecondary)

            Label(
                "请先完成当前接力旅程；如需改飞其他航线，须返航至\(AirportStore.shared[j.originIata]?.displayCity ?? "原城市")。",
                systemImage: "info.circle"
            )
            .font(.caption2)
            .foregroundStyle(Theme.textSecondary)

            HStack(spacing: 10) {
                Button {
                    showSegmentPicker = true
                } label: {
                    Label("继续飞行", systemImage: "play.fill")
                        .font(.subheadline.bold())
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Theme.glow, in: RoundedRectangle(cornerRadius: 10))
                        .foregroundStyle(Theme.bg)
                }
                Button {
                    showAbandonConfirm = true
                } label: {
                    Text("返航")
                        .font(.subheadline)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 12)
                        .background(Theme.card, in: RoundedRectangle(cornerRadius: 10))
                        .foregroundStyle(Theme.danger)
                }
            }
        }
        .padding(16)
        .background(Theme.card.opacity(0.6), in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Theme.glow.opacity(0.3)))
    }

    private var startButton: some View {
        Button {
            showBoard = true
        } label: {
            HStack {
                Image(systemName: "airplane.departure")
                Text("选择航线")
            }
            .font(.headline)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Theme.glow, in: RoundedRectangle(cornerRadius: 14))
            .foregroundStyle(Theme.bg)
        }
    }

    private var repositionCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("当前机场没有你可飞的航线", systemImage: "exclamationmark.triangle")
                .font(.subheadline)
                .foregroundStyle(Theme.textSecondary)
            Button {
                FlightEngine.shared.reposition(profile: profile, context: context)
            } label: {
                Text("调机返回上一枢纽（不计里程）")
                    .font(.subheadline.bold())
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Theme.card, in: RoundedRectangle(cornerRadius: 10))
                    .foregroundStyle(Theme.textPrimary)
            }
        }
        .padding(16)
        .background(Theme.card.opacity(0.5), in: RoundedRectangle(cornerRadius: 14))
    }
}

private struct CitySceneryBackdrop: View {
    let image: UIImage

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .clipped()
                    .saturation(0.82)
                    .contrast(1.02)
                    .brightness(-0.05)

                Color(hex: 0x07101F)
                    .opacity(0.30)

                LinearGradient(
                    stops: [
                        .init(color: Theme.bg.opacity(0.08), location: 0),
                        .init(color: Theme.bg.opacity(0.28), location: 0.34),
                        .init(color: Theme.bg.opacity(0.86), location: 0.76),
                        .init(color: Theme.bg, location: 1),
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// 首段与后续接力共用的时长选择界面。
struct SegmentDurationSheet: View {
    let title: String
    let remaining: Int
    let actionTitle: String
    let onConfirm: (Int) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var minutes: Int = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text(title)
                .font(.headline)
                .foregroundStyle(Theme.textPrimary)
            Text("剩余 \(TimeMapping.formatMinutes(remaining))")
                .font(.subheadline)
                .foregroundStyle(Theme.textSecondary)

            let opts = TimeMapping.segmentOptions(remaining: remaining)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 90))], spacing: 10) {
                ForEach(opts, id: \.self) { m in
                    Button {
                        minutes = m
                    } label: {
                        VStack(spacing: 2) {
                            Text(TimeMapping.formatMinutes(m)).font(.subheadline.bold())
                            if TimeMapping.progressMinutes(forTimer: m, remaining: remaining) == remaining {
                                Text(
                                    m > remaining
                                        ? "完成剩余 \(remaining) 分钟"
                                        : "飞完全程"
                                )
                                .font(.system(size: 9))
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(minutes == m ? Theme.glow.opacity(0.2) : Theme.card,
                                    in: RoundedRectangle(cornerRadius: 10))
                        .foregroundStyle(minutes == m ? Theme.glow : Theme.textSecondary)
                    }
                }
            }

            Button {
                onConfirm(minutes)
                dismiss()
            } label: {
                Text("\(actionTitle) · 本段 \(TimeMapping.formatMinutes(minutes))")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Theme.glow, in: RoundedRectangle(cornerRadius: 12))
                    .foregroundStyle(Theme.bg)
            }
            Spacer()
        }
        .padding(20)
        .background(Theme.bgElevated)
        .onAppear {
            let options = TimeMapping.segmentOptions(remaining: remaining)
            minutes = options.contains(45) ? 45 : (options.first ?? remaining)
        }
    }
}
