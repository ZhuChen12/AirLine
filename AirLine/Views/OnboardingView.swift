import SwiftData
import SwiftUI

/// 首次启动：乘客姓名 + 主场机场（SPEC §3.3）
struct OnboardingView: View {
    @Environment(\.modelContext) private var context
    @State private var name = ""
    @State private var search = ""
    @State private var selected: Airport?

    private var results: [Airport] { AirportStore.shared.search(search, limit: 20) }

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 6) {
                    AirLineBrandLockup()
                    Text("每一次专注，都是一段真实的飞行。")
                        .font(.subheadline)
                        .foregroundStyle(Theme.textSecondary)
                }
                .padding(.top, 40)

                VStack(alignment: .leading, spacing: 8) {
                    Text("乘客姓名").font(.caption).foregroundStyle(Theme.textSecondary)
                    TextField("将印在你的登机牌上", text: $name)
                        .textFieldStyle(.plain)
                        .padding(12)
                        .background(Theme.card, in: RoundedRectangle(cornerRadius: 10))
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("选择主场机场").font(.caption).foregroundStyle(Theme.textSecondary)
                    TextField("搜索城市 / 机场 / 三字码", text: $search)
                        .textFieldStyle(.plain)
                        .padding(12)
                        .background(Theme.card, in: RoundedRectangle(cornerRadius: 10))

                    ScrollView {
                        LazyVStack(spacing: 2) {
                            ForEach(results) { airport in
                                Button {
                                    selected = airport
                                } label: {
                                    HStack {
                                        Text(airport.icaoKey)
                                            .font(.system(.subheadline, design: .monospaced).bold())
                                            .foregroundStyle(Theme.glow)
                                            .frame(width: 52, alignment: .leading)
                                        VStack(alignment: .leading) {
                                            Text(airport.displayCity).foregroundStyle(Theme.textPrimary)
                                            Text("\(airport.name) · \(airport.country)")
                                                .font(.caption2).foregroundStyle(Theme.textSecondary)
                                                .lineLimit(1)
                                        }
                                        Spacer()
                                        if selected?.icaoKey == airport.icaoKey {
                                            Image(systemName: "checkmark.circle.fill")
                                                .foregroundStyle(Theme.glow)
                                        }
                                    }
                                    .padding(.vertical, 8)
                                    .padding(.horizontal, 10)
                                    .background(
                                        selected?.icaoKey == airport.icaoKey ? Theme.card : .clear,
                                        in: RoundedRectangle(cornerRadius: 8))
                                }
                            }
                        }
                    }
                }

                Button {
                    guard let home = selected else { return }
                    let trimmed = name.trimmingCharacters(in: .whitespaces)
                    context.insert(PlayerProfile(name: trimmed.isEmpty ? "TRAVELER" : trimmed,
                                                 homeIata: home.icaoKey))
                    try? context.save()
                } label: {
                    Text("办理入会")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(selected == nil ? Theme.card : Theme.glow,
                                    in: RoundedRectangle(cornerRadius: 12))
                        .foregroundStyle(selected == nil ? Theme.textSecondary : Theme.bg)
                }
                .disabled(selected == nil)
                .padding(.bottom, 12)
            }
            .padding(.horizontal, 24)
        }
    }
}
