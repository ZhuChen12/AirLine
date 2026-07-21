import ActivityKit
import SwiftUI
import WidgetKit

@main
struct AirLineWidgetBundle: WidgetBundle {
    var body: some Widget {
        FlightLiveActivity()
    }
}

/// Widget 侧独立配色（不依赖主 App 源码）
private enum WTheme {
    static let bg = Color(red: 0.04, green: 0.055, blue: 0.10)
    static let gold = Color(red: 0.91, green: 0.78, blue: 0.48)
    static let text = Color(red: 0.91, green: 0.93, blue: 0.96)
    static let dim = Color(red: 0.55, green: 0.58, blue: 0.66)
}

struct FlightLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: FlightActivityAttributes.self) { context in
            LockScreenFlightCard(context: context)
                .activityBackgroundTint(WTheme.bg)
                .activitySystemActionForegroundColor(WTheme.gold)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(context.attributes.originCode)
                            .font(.system(.title2, design: .monospaced).bold())
                            .foregroundStyle(WTheme.text)
                        Text(context.attributes.originCity)
                            .font(.caption2)
                            .foregroundStyle(WTheme.dim)
                    }
                    .padding(.leading, 4)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(context.attributes.destCode)
                            .font(.system(.title2, design: .monospaced).bold())
                            .foregroundStyle(WTheme.text)
                        Text(context.attributes.destCity)
                            .font(.caption2)
                            .foregroundStyle(WTheme.dim)
                    }
                    .padding(.trailing, 4)
                }
                DynamicIslandExpandedRegion(.center) {
                    Image(systemName: "airplane")
                        .foregroundStyle(WTheme.gold)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(spacing: 6) {
                        ProgressView(timerInterval: context.state.segmentStart...context.state.segmentEnd,
                                     countsDown: false, label: { EmptyView() },
                                     currentValueLabel: { EmptyView() })
                            .progressViewStyle(.linear)
                            .tint(WTheme.gold)
                        HStack {
                            Text("\(context.attributes.carrierName) \(context.attributes.flightNumber)")
                                .font(.caption2)
                                .foregroundStyle(WTheme.dim)
                            Spacer()
                            HStack(spacing: 4) {
                                Text("预计落地")
                                    .font(.caption2)
                                    .foregroundStyle(WTheme.dim)
                                Text(context.state.segmentEnd, style: .time)
                                    .font(.system(.caption2, design: .monospaced).bold())
                                    .foregroundStyle(WTheme.text)
                            }
                        }
                    }
                    .padding(.horizontal, 4)
                }
            } compactLeading: {
                HStack(spacing: 3) {
                    Image(systemName: "airplane")
                        .font(.system(size: 11))
                        .foregroundStyle(WTheme.gold)
                    Text("\(context.attributes.originCode)→\(context.attributes.destCode)")
                        .font(.system(size: 11, design: .monospaced).bold())
                        .foregroundStyle(WTheme.text)
                }
            } compactTrailing: {
                Text(timerInterval: context.state.segmentStart...context.state.segmentEnd,
                     countsDown: true)
                    .font(.system(size: 12, design: .monospaced).bold())
                    .foregroundStyle(WTheme.gold)
                    .frame(maxWidth: 52)
                    .multilineTextAlignment(.trailing)
                    .monospacedDigit()
            } minimal: {
                Image(systemName: "airplane")
                    .foregroundStyle(WTheme.gold)
            }
            .keylineTint(WTheme.gold)
        }
    }
}

/// 锁屏：横向登机牌式卡片（SPEC §9.2）
struct LockScreenFlightCard: View {
    let context: ActivityViewContext<FlightActivityAttributes>

    var body: some View {
        VStack(spacing: 10) {
            HStack {
                Text("\(context.attributes.carrierName) \(context.attributes.flightNumber)")
                    .font(.caption.bold())
                    .foregroundStyle(WTheme.gold)
                Spacer()
                Text("\(context.attributes.cabinCode) 舱")
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundStyle(WTheme.dim)
            }
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(context.attributes.originCode)
                        .font(.system(size: 26, weight: .black, design: .monospaced))
                        .foregroundStyle(WTheme.text)
                    Text(context.attributes.originCity)
                        .font(.caption2)
                        .foregroundStyle(WTheme.dim)
                }
                VStack(spacing: 3) {
                    Image(systemName: "airplane")
                        .font(.system(size: 13))
                        .foregroundStyle(WTheme.gold)
                    Text(timerInterval: context.state.segmentStart...context.state.segmentEnd,
                         countsDown: true)
                        .font(.system(.footnote, design: .monospaced).bold())
                        .foregroundStyle(WTheme.gold)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 70)
                        .monospacedDigit()
                }
                .frame(maxWidth: .infinity)
                VStack(alignment: .trailing, spacing: 2) {
                    Text(context.attributes.destCode)
                        .font(.system(size: 26, weight: .black, design: .monospaced))
                        .foregroundStyle(WTheme.text)
                    Text(context.attributes.destCity)
                        .font(.caption2)
                        .foregroundStyle(WTheme.dim)
                }
            }
            ProgressView(timerInterval: context.state.segmentStart...context.state.segmentEnd,
                         countsDown: false, label: { EmptyView() },
                         currentValueLabel: { EmptyView() })
                .progressViewStyle(.linear)
                .tint(WTheme.gold)
        }
        .padding(14)
    }
}
