import SwiftData
import SwiftUI

/// 首次启动：乘客姓名 + 主场机场（SPEC §3.3）
struct OnboardingView: View {
    var onDeveloperModeChanged: () -> Void = {}

    @Environment(\.modelContext) private var context
    @State private var name = ""
    @State private var search = ""
    @State private var selected: Airport?
    @State private var developerPassphrase = ""
    @State private var showDeveloperUnlock = false
    @State private var developerUnlockFailed = false

    private var results: [Airport] { AirportStore.shared.search(search, limit: 20) }

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 6) {
                    AirLineBrandLockup()
                        .onTapGesture(count: 5) {
                            developerPassphrase = ""
                            developerUnlockFailed = false
                            showDeveloperUnlock = true
                        }
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
                                            Text("\(airport.name) · \(airport.displayCountry)")
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
                    let profile = PlayerProfile(
                        name: trimmed.isEmpty ? "TRAVELER" : trimmed,
                        homeIata: home.icaoKey
                    )
                    context.insert(profile)
                    InitialCityLighting.ensureHomeCity(for: profile, context: context)
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
        .sheet(isPresented: $showDeveloperUnlock) {
            DeveloperUnlockSheet(
                passphrase: $developerPassphrase,
                failed: developerUnlockFailed
            ) {
                if DeveloperAccess.activate(passphrase: developerPassphrase, context: context) {
                    showDeveloperUnlock = false
                    onDeveloperModeChanged()
                } else {
                    developerUnlockFailed = true
                }
            }
            .presentationDetents([.height(260)])
            .presentationBackground(Theme.bgElevated)
        }
    }
}

struct DeveloperUnlockSheet: View {
    @Binding var passphrase: String
    let failed: Bool
    let onConfirm: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("验证身份")
                    .font(.headline)
                    .foregroundStyle(Theme.textPrimary)
                Spacer()
                Button("取消") { dismiss() }
                    .font(.caption)
                    .foregroundStyle(Theme.textSecondary)
            }

            SecureField("输入密钥", text: $passphrase)
                .keyboardType(.numberPad)
                .textContentType(.oneTimeCode)
                .padding(12)
                .background(Theme.card, in: RoundedRectangle(cornerRadius: 10))

            if failed {
                Text("密钥错误")
                    .font(.caption)
                    .foregroundStyle(Theme.danger)
            } else {
                Text("开发者模式仅用于本机测试。")
                    .font(.caption)
                    .foregroundStyle(Theme.textSecondary)
            }

            Button {
                onConfirm()
            } label: {
                Text("进入开发者模式")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                    .background(Theme.glow, in: RoundedRectangle(cornerRadius: 12))
                    .foregroundStyle(Theme.bg)
            }
        }
        .padding(20)
        .background(Theme.bgElevated)
    }
}
