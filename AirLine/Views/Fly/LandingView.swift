import SwiftUI

/// 落地/检查点/备降 结算页（SPEC §3）
struct LandingView: View {
    let outcome: FlightOutcome
    var onDone: () -> Void
    @State private var bioService = CityBioService.shared

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 20) {
                    switch outcome.kind {
                    case .arrived: arrivedContent
                    case .checkpoint: checkpointContent
                    case .diverted: divertedContent
                    case .abandoned: EmptyView()
                    }
                    Button {
                        onDone()
                    } label: {
                        Text(outcome.kind == .arrived ? "收下里程" : "好的")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Theme.glow, in: RoundedRectangle(cornerRadius: 12))
                            .foregroundStyle(Theme.bg)
                    }
                    .padding(.top, 6)
                }
                .padding(24)
                .padding(.top, 30)
            }
        }
    }

    private var arrivedContent: some View {
        VStack(spacing: 14) {
            Image(systemName: "airplane.arrival")
                .font(.system(size: 40))
                .foregroundStyle(Theme.glow)
                .padding(.top, 20)
            Text("已抵达")
                .font(.subheadline)
                .foregroundStyle(Theme.textSecondary)
            Text(outcome.destCity)
                .font(.system(size: 38, weight: .black))
                .foregroundStyle(Theme.textPrimary)

            HStack(spacing: 10) {
                chip("+\(outcome.creditedKmDelta) km", icon: "chart.line.uptrend.xyaxis")
                chip("+\(TimeMapping.formatMinutes(outcome.focusMinutesDelta)) 专注", icon: "timer")
            }

            if outcome.isNewCity {
                banner("新城市点亮", icon: "sparkles", color: Theme.glow)
            }
            if outcome.isNewCountry {
                banner("护照新增一枚国家印章", icon: "stamp", color: Theme.track)
            }
            if outcome.cabinAfter > outcome.cabinBefore {
                banner("升舱至\(outcome.cabinAfter.nameZh) · 解锁\(outcome.cabinAfter.hubAccessName)",
                       icon: "arrow.up.circle.fill", color: Theme.cabinColor(outcome.cabinAfter))
            }

            // 城市小传（无代理/断网时回退模板，联网后自动补全）
            Group {
                if let bio = bioService.bio(for: outcome.destIata) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("【\(bio.tag)】")
                            .font(.subheadline.bold())
                            .foregroundStyle(Theme.glow)
                        Text(bio.body)
                            .font(.subheadline)
                            .foregroundStyle(Theme.textPrimary.opacity(0.9))
                            .lineSpacing(5)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                    .background(Theme.card, in: RoundedRectangle(cornerRadius: 14))
                } else if let airport = AirportStore.shared[outcome.destIata] {
                    let fb = bioService.fallback(for: airport)
                    VStack(alignment: .leading, spacing: 8) {
                        Text("【\(fb.tag)】")
                            .font(.subheadline.bold())
                            .foregroundStyle(Theme.glow)
                        Text(fb.body)
                            .font(.subheadline)
                            .foregroundStyle(Theme.textPrimary.opacity(0.9))
                            .lineSpacing(5)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                    .background(Theme.card, in: RoundedRectangle(cornerRadius: 14))
                }
            }
            .padding(.top, 8)
        }
    }

    private var checkpointContent: some View {
        VStack(spacing: 14) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 40))
                .foregroundStyle(Theme.glow)
                .padding(.top, 30)
            Text("本段飞行完成")
                .font(.title2.bold())
                .foregroundStyle(Theme.textPrimary)
            Text("旅程已保存至检查点，剩余 \(TimeMapping.formatMinutes(outcome.remainingFocusMinutes))，随时继续。")
                .font(.subheadline)
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
            HStack(spacing: 10) {
                chip("+\(outcome.creditedKmDelta) km", icon: "chart.line.uptrend.xyaxis")
                chip("+\(TimeMapping.formatMinutes(outcome.focusMinutesDelta)) 专注", icon: "timer")
            }
            if outcome.cabinAfter > outcome.cabinBefore {
                banner("升舱至\(outcome.cabinAfter.nameZh) · 解锁\(outcome.cabinAfter.hubAccessName)",
                       icon: "arrow.up.circle.fill", color: Theme.cabinColor(outcome.cabinAfter))
            }
        }
    }

    private var divertedContent: some View {
        VStack(spacing: 14) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 40))
                .foregroundStyle(Theme.danger)
                .padding(.top, 30)
            Text("航班备降")
                .font(.title2.bold())
                .foregroundStyle(Theme.textPrimary)
            Text(outcome.remainingFocusMinutes > 0
                 ? "本段作废，但检查点进度已保留。稳住，随时可以继续这段旅程。"
                 : "离开机舱超过了宽限时间，本次飞行作废。\(outcome.destCity) 没有点亮，下次再来。")
                .font(.subheadline)
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
        }
    }

    private func chip(_ text: String, icon: String) -> some View {
        Label(text, systemImage: icon)
            .font(.system(.footnote, design: .monospaced).bold())
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Theme.card, in: Capsule())
            .foregroundStyle(Theme.textPrimary)
    }

    private func banner(_ text: String, icon: String, color: Color) -> some View {
        Label(text, systemImage: icon)
            .font(.subheadline.bold())
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(color.opacity(0.14), in: RoundedRectangle(cornerRadius: 12))
            .foregroundStyle(color)
    }
}
