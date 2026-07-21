import SwiftData
import SwiftUI

/// 我的：统计总览 + 飞行日志 + 护照（SPEC §10）
struct MeView: View {
    let profile: PlayerProfile
    @Query(sort: \FlightRecord.endedAt, order: .reverse) private var records: [FlightRecord]
    @Query private var visits: [CityVisit]
    @Query(sort: \PassportStamp.stampedAt, order: .reverse) private var stamps: [PassportStamp]
    @State private var selectedRecord: FlightRecord?
    @State private var showCabinRules = false

    private var completedCount: Int { records.filter { $0.status == .completed }.count }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.bg.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        memberCard
                        statsGrid
                        passportSection
                        logbookSection
                    }
                    .padding(16)
                }
            }
            .navigationTitle("我的")
            .navigationBarTitleDisplayMode(.inline)
        }
        .sheet(item: $selectedRecord) { record in
            ScrollView {
                VStack(spacing: 16) {
                    BoardingPassView(data: BoardingPassData(record: record, passengerName: profile.name))
                    Text(record.endedAt.formatted(date: .long, time: .shortened))
                        .font(.caption)
                        .foregroundStyle(Theme.textSecondary)
                }
                .padding(20)
            }
            .presentationDetents([.medium, .large])
            .presentationBackground(Theme.bgElevated)
        }
        .sheet(isPresented: $showCabinRules) {
            CabinRulesView(totalKm: profile.totalKm)
        }
    }

    private var memberCard: some View {
        let cabin = profile.cabin
        return VStack(spacing: 12) {
            HStack(spacing: 12) {
                AirLineLogoMark()
                    .frame(width: 44, height: 44)
                VStack(alignment: .leading, spacing: 4) {
                    Text(profile.name.uppercased())
                        .font(.title3.bold())
                        .foregroundStyle(Theme.textPrimary)
                    Text("AIRLINE 常旅客 · 入会于 \(profile.createdAt.formatted(.dateTime.year().month()))")
                        .font(.caption2)
                        .foregroundStyle(Theme.textSecondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text(cabin.nameZh)
                        .font(.subheadline.bold())
                        .foregroundStyle(Theme.cabinColor(cabin))
                    Text(cabin.code)
                        .font(.system(.caption, design: .monospaced).bold())
                        .padding(.horizontal, 8).padding(.vertical, 2)
                        .background(Theme.cabinColor(cabin).opacity(0.15), in: Capsule())
                        .foregroundStyle(Theme.cabinColor(cabin))
                }
            }
            Divider().overlay(Theme.landStroke)
            Button {
                showCabinRules = true
            } label: {
                HStack {
                    Label("等级规则与升级权益", systemImage: "list.star")
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
        .padding(18)
        .background(
            LinearGradient(colors: [Theme.card, Theme.cabinColor(profile.cabin).opacity(0.10)],
                           startPoint: .topLeading, endPoint: .bottomTrailing),
            in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16)
            .strokeBorder(Theme.cabinColor(profile.cabin).opacity(0.3)))
    }

    private var statsGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
            statCell(value: formatHours(profile.totalFocusMinutes), label: "累计专注")
            statCell(value: "\(profile.totalKm) km", label: "累计里程")
            statCell(value: "\(completedCount)", label: "完成航段")
            statCell(value: "\(visits.count) 城 · \(stamps.count) 国", label: "点亮足迹")
        }
    }

    private func statCell(value: String, label: String) -> some View {
        VStack(spacing: 5) {
            Text(value)
                .font(.system(.title3, design: .monospaced).bold())
                .foregroundStyle(Theme.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(label)
                .font(.caption2)
                .foregroundStyle(Theme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 12))
    }

    private var passportSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("护照")
                .font(.headline)
                .foregroundStyle(Theme.textPrimary)
            if stamps.isEmpty {
                Text("首次落地一个新国家，就会盖下一枚印章。")
                    .font(.caption)
                    .foregroundStyle(Theme.textSecondary)
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 100))], spacing: 10) {
                    ForEach(stamps) { stamp in
                        VStack(spacing: 4) {
                            Text(stamp.countryCode)
                                .font(.system(.headline, design: .monospaced).bold())
                                .foregroundStyle(Theme.glow)
                            Text(stamp.country)
                                .font(.caption2)
                                .foregroundStyle(Theme.textPrimary)
                                .lineLimit(1)
                            Text(stamp.stampedAt.formatted(.dateTime.year().month(.twoDigits).day(.twoDigits)))
                                .font(.system(size: 8, design: .monospaced))
                                .foregroundStyle(Theme.textSecondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Theme.card, in: RoundedRectangle(cornerRadius: 10))
                        .overlay(RoundedRectangle(cornerRadius: 10)
                            .strokeBorder(Theme.glow.opacity(0.25), style: StrokeStyle(lineWidth: 1, dash: [3, 3])))
                        .rotationEffect(.degrees(Double(stamp.countryCode.unicodeScalars.reduce(0) { $0 + Int($1.value) } % 5) - 2))
                    }
                }
            }
        }
    }

    private var logbookSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("飞行日志")
                .font(.headline)
                .foregroundStyle(Theme.textPrimary)
            if records.isEmpty {
                Text("还没有飞行记录，去值机你的第一趟航班。")
                    .font(.caption)
                    .foregroundStyle(Theme.textSecondary)
            } else {
                ForEach(records) { record in
                    Button {
                        selectedRecord = record
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: iconFor(record.status))
                                .foregroundStyle(record.status == .completed ? Theme.glow : Theme.danger)
                                .frame(width: 22)
                            VStack(alignment: .leading, spacing: 3) {
                                Text("\(record.originIata) → \(record.destIata)")
                                    .font(.system(.subheadline, design: .monospaced).bold())
                                    .foregroundStyle(Theme.textPrimary)
                                Text("\(record.flightNumber) · \(record.carrierName)")
                                    .font(.caption2)
                                    .foregroundStyle(Theme.textSecondary)
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 3) {
                                Text(statusText(record.status))
                                    .font(.caption2.bold())
                                    .foregroundStyle(record.status == .completed ? Theme.glow : Theme.danger)
                                Text(record.endedAt.formatted(.dateTime.month(.twoDigits).day(.twoDigits)))
                                    .font(.system(.caption2, design: .monospaced))
                                    .foregroundStyle(Theme.textSecondary)
                            }
                        }
                        .padding(12)
                        .background(Theme.card, in: RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func iconFor(_ s: FlightStatus) -> String {
        switch s {
        case .completed: return "checkmark.circle.fill"
        case .diverted: return "exclamationmark.triangle.fill"
        case .abandoned: return "arrow.uturn.left.circle.fill"
        }
    }

    private func statusText(_ s: FlightStatus) -> String {
        switch s {
        case .completed: return "完成"
        case .diverted: return "备降"
        case .abandoned: return "返航"
        }
    }

    private func formatHours(_ minutes: Int) -> String {
        if minutes < 60 { return "\(minutes)m" }
        let h = minutes / 60, m = minutes % 60
        return m == 0 ? "\(h)h" : "\(h)h\(m)m"
    }
}
