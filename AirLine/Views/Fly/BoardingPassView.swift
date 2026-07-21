import SwiftUI

/// 登机牌数据快照（供渲染，不依赖具体模型）
struct BoardingPassData {
    var passengerName: String
    var carrierName: String
    var flightNumber: String
    var cabin: CabinClass
    var originIata: String
    var originCity: String
    var destIata: String
    var destCity: String
    var realMinutes: Int
    var focusMinutes: Int
    var km: Int
    var seat: String
    var gate: String
    var date: Date
    var departureTZ: TimeZone = .current
    var arrivalTZ: TimeZone = .current
    var watermark: String? = nil // 备降 / 返航

    var departure: Date { date }
    var arrival: Date { date.addingTimeInterval(TimeInterval(realMinutes * 60)) }
}

extension BoardingPassData {
    init(journey: ActiveJourney, passengerName: String) {
        let store = AirportStore.shared
        self.init(
            passengerName: passengerName,
            carrierName: journey.carrierName,
            flightNumber: journey.flightNumber,
            cabin: journey.cabin,
            originIata: journey.originIata,
            originCity: store[journey.originIata]?.displayCity ?? journey.originIata,
            destIata: journey.destIata,
            destCity: store[journey.destIata]?.displayCity ?? journey.destIata,
            realMinutes: journey.realMinutes,
            focusMinutes: journey.focusMinutes,
            km: journey.totalKm,
            seat: journey.seat,
            gate: journey.gate,
            date: journey.checkInAt,
            departureTZ: store[journey.originIata]?.tz ?? .current,
            arrivalTZ: store[journey.destIata]?.tz ?? .current
        )
    }

    init(record: FlightRecord, passengerName: String) {
        let store = AirportStore.shared
        var mark: String?
        switch record.status {
        case .diverted: mark = "备降"
        case .abandoned: mark = "返航"
        case .completed: mark = nil
        }
        self.init(
            passengerName: passengerName,
            carrierName: record.carrierName,
            flightNumber: record.flightNumber,
            cabin: record.cabin,
            originIata: record.originIata,
            originCity: store[record.originIata]?.displayCity ?? record.originIata,
            destIata: record.destIata,
            destCity: store[record.destIata]?.displayCity ?? record.destIata,
            realMinutes: record.realMinutes,
            focusMinutes: record.focusMinutes,
            km: record.totalKm,
            seat: record.seat,
            gate: record.gate,
            date: record.checkInAt,
            departureTZ: store[record.originIata]?.tz ?? .current,
            arrivalTZ: store[record.destIata]?.tz ?? .current,
            watermark: mark
        )
    }
}

/// 全尺寸登机牌（SPEC §5：完全按真实登机牌版式，自研视觉，无航司 logo）
struct BoardingPassView: View {
    let data: BoardingPassData

    private var accent: Color { Theme.cabinColor(data.cabin) }

    var body: some View {
        VStack(spacing: 0) {
            // 头部：航司 + 航班号 + 舱位色带
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(data.carrierName.uppercased())
                        .font(.system(size: 13, weight: .heavy))
                        .kerning(1.5)
                    Text("BOARDING PASS · 登机牌")
                        .font(.system(size: 8))
                        .kerning(2)
                        .foregroundStyle(Theme.textSecondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text(data.flightNumber)
                        .font(.system(.headline, design: .monospaced).bold())
                        .foregroundStyle(accent)
                    Text("\(data.cabin.nameZh) \(data.cabin.code)")
                        .font(.system(size: 9))
                        .foregroundStyle(Theme.textSecondary)
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 12)
            .background(accent.opacity(0.12))

            // 主体：起降
            HStack(alignment: .center) {
                terminalBlock(code: data.originIata, city: data.originCity,
                              time: data.departure, tz: data.departureTZ, align: .leading)
                Spacer()
                VStack(spacing: 4) {
                    HStack(spacing: 4) {
                        line
                        Image(systemName: "airplane")
                            .font(.system(size: 14))
                            .foregroundStyle(accent)
                        line
                    }
                    Text(TimeMapping.formatMinutes(data.realMinutes))
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundStyle(Theme.textSecondary)
                    Text("专注 \(TimeMapping.formatMinutes(data.focusMinutes))")
                        .font(.system(size: 9))
                        .foregroundStyle(accent)
                }
                Spacer()
                terminalBlock(code: data.destIata, city: data.destCity,
                              time: data.arrival, tz: data.arrivalTZ, align: .trailing)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 14)

            // 撕票线
            HStack(spacing: 4) {
                ForEach(0..<40, id: \.self) { _ in
                    Rectangle().fill(Theme.landStroke).frame(height: 1)
                }
            }
            .padding(.horizontal, 10)
            .overlay(alignment: .leading) { notch }
            .overlay(alignment: .trailing) { notch.rotationEffect(.degrees(180)) }

            // 明细
            HStack(alignment: .top) {
                field("乘客", data.passengerName.uppercased())
                Spacer()
                field("日期", data.date.formatted(.dateTime.year().month(.twoDigits).day(.twoDigits)))
                Spacer()
                field("登机口", data.gate)
                Spacer()
                field("座位", data.seat)
                Spacer()
                field("里程", "\(data.km) KM")
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 12)

            // 条形码装饰
            Barcode(seed: data.flightNumber + data.originIata + data.destIata)
                .frame(height: 34)
                .padding(.horizontal, 18)
                .padding(.bottom, 14)
        }
        .background(Theme.card)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(accent.opacity(0.35), lineWidth: 1)
        )
        .overlay {
            if let mark = data.watermark {
                Text(mark)
                    .font(.system(size: 44, weight: .black))
                    .foregroundStyle(Theme.danger.opacity(0.35))
                    .rotationEffect(.degrees(-18))
            }
        }
    }

    private var line: some View {
        Rectangle().fill(Theme.landStroke).frame(width: 34, height: 1)
    }

    private var notch: some View {
        Circle().fill(Theme.bg).frame(width: 14, height: 14).offset(x: -7)
    }

    private func terminalBlock(code: String, city: String, time: Date, tz: TimeZone,
                               align: HorizontalAlignment) -> some View {
        return VStack(alignment: align, spacing: 3) {
            Text(code)
                .font(.system(size: 32, weight: .black, design: .monospaced))
                .foregroundStyle(Theme.textPrimary)
            Text(city)
                .font(.system(size: 11))
                .foregroundStyle(Theme.textSecondary)
            Text(formatClock(time, tz: tz))
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(accent)
                .monospacedDigit()
                .lineLimit(1)
        }
    }

    private func formatClock(_ date: Date, tz: TimeZone) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = tz
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }

    private func field(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label).font(.system(size: 8)).foregroundStyle(Theme.textSecondary)
            Text(value)
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundStyle(Theme.textPrimary)
                .lineLimit(1)
        }
    }
}

/// 确定性条形码装饰
struct Barcode: View {
    let seed: String

    var body: some View {
        Canvas { ctx, size in
            var h: UInt64 = 0xcbf29ce484222325
            for b in seed.utf8 { h ^= UInt64(b); h = h &* 0x100000001b3 }
            var x: CGFloat = 0
            var state = h
            while x < size.width {
                state = state &* 6364136223846793005 &+ 1442695040888963407
                let w = CGFloat(1 + (state >> 33) % 3)
                let gap = CGFloat(1 + (state >> 45) % 3)
                ctx.fill(Path(CGRect(x: x, y: 0, width: w, height: size.height)),
                         with: .color(Theme.textPrimary.opacity(0.75)))
                x += w + gap
            }
        }
    }
}
