import SwiftUI

/// 等级规则与权益总览，在飞行页和个人页共用。
struct CabinRulesView: View {
    let totalKm: Int
    @Environment(\.dismiss) private var dismiss

    private var current: CabinClass { CabinClass.current(totalKm: totalKm) }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.bg.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        summary
                        ForEach(CabinClass.allCases, id: \.rawValue) { cabin in
                            tierCard(cabin)
                        }
                        Text("枢纽规模按该机场拥有的真实直飞航线数量计算。主场机场和每座机场的基础航路不受等级限制。")
                            .font(.caption2)
                            .foregroundStyle(Theme.textSecondary)
                            .lineSpacing(3)
                            .padding(.horizontal, 4)
                    }
                    .padding(16)
                    .padding(.bottom, 20)
                }
            }
            .navigationTitle("等级与权益")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { dismiss() }
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private var summary: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("当前等级")
                        .font(.caption)
                        .foregroundStyle(Theme.textSecondary)
                    Text(current.nameZh)
                        .font(.title2.bold())
                        .foregroundStyle(Theme.cabinColor(current))
                }
                Spacer()
                Text("\(totalKm) km")
                    .font(.system(.headline, design: .monospaced).bold())
                    .foregroundStyle(Theme.textPrimary)
            }

            if let next = current.next {
                ProgressView(
                    value: Double(totalKm - current.thresholdKm),
                    total: Double(next.thresholdKm - current.thresholdKm)
                )
                .tint(Theme.cabinColor(next))
                Text("再飞 \(max(0, next.thresholdKm - totalKm)) km，解锁\(next.hubAccessName)")
                    .font(.caption)
                    .foregroundStyle(Theme.textSecondary)
            } else {
                Label("全部枢纽城市已开放", systemImage: "checkmark.seal.fill")
                    .font(.caption)
                    .foregroundStyle(Theme.glow)
            }

            Text("累计里程决定等级。所有等级都能选择长距离航线，升级只扩展可进入的枢纽城市与飞行权益。")
                .font(.footnote)
                .foregroundStyle(Theme.textSecondary)
                .lineSpacing(4)
        }
        .padding(16)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 16))
    }

    private func tierCard(_ cabin: CabinClass) -> some View {
        let unlocked = totalKm >= cabin.thresholdKm
        let isCurrent = cabin == current
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(cabin.code)
                    .font(.system(.headline, design: .monospaced).bold())
                    .frame(width: 34, height: 34)
                    .background(Theme.cabinColor(cabin).opacity(0.16), in: Circle())
                    .foregroundStyle(Theme.cabinColor(cabin))
                VStack(alignment: .leading, spacing: 2) {
                    Text(cabin.nameZh)
                        .font(.headline)
                        .foregroundStyle(Theme.textPrimary)
                    Text(cabin.thresholdKm == 0 ? "入会即享" : "累计 \(cabin.thresholdKm) km")
                        .font(.caption2)
                        .foregroundStyle(Theme.textSecondary)
                }
                Spacer()
                if isCurrent {
                    Text("当前")
                        .font(.caption2.bold())
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Theme.cabinColor(cabin).opacity(0.16), in: Capsule())
                        .foregroundStyle(Theme.cabinColor(cabin))
                } else {
                    Image(systemName: unlocked ? "checkmark.circle.fill" : "lock.circle")
                        .foregroundStyle(unlocked ? Theme.glow : Theme.textSecondary)
                }
            }

            Text(cabin.hubRuleDescription)
                .font(.subheadline)
                .foregroundStyle(Theme.textPrimary)

            VStack(alignment: .leading, spacing: 7) {
                ForEach(cabin.rights, id: \.self) { right in
                    Label(right, systemImage: "checkmark")
                        .font(.caption)
                        .foregroundStyle(unlocked ? Theme.textPrimary : Theme.textSecondary)
                }
            }
        }
        .padding(16)
        .background(
            LinearGradient(
                colors: [Theme.card, Theme.cabinColor(cabin).opacity(isCurrent ? 0.10 : 0.03)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 16)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(
                    Theme.cabinColor(cabin).opacity(isCurrent ? 0.45 : 0.16),
                    lineWidth: isCurrent ? 1.2 : 0.8
                )
        }
        .opacity(unlocked || isCurrent ? 1 : 0.76)
    }
}
