import SwiftData
import SwiftUI

/// 专注飞行：航图模式 + 大号倒计时（SPEC §9.1）
struct FocusFlightView: View {
    let journey: ActiveJourney
    @Environment(\.modelContext) private var context
    @State private var showDivertConfirm = false

    private var origin: Airport? { AirportStore.shared[journey.originIata] }
    private var dest: Airport? { AirportStore.shared[journey.destIata] }

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()
            VStack(spacing: 0) {
                header
                    .padding(.top, 18)
                Spacer()
                if let start = journey.segmentStartAt, let end = journey.segmentEndAt {
                    Text(timerInterval: start...end, countsDown: true)
                        .font(.system(size: 68, weight: .black, design: .monospaced))
                        .foregroundStyle(Theme.textPrimary)
                        .monospacedDigit()
                    Text("本段专注 \(TimeMapping.formatMinutes(journey.segmentMinutes))")
                        .font(.footnote)
                        .foregroundStyle(Theme.textSecondary)
                        .padding(.top, 4)
                }
                Spacer()
                routeMap
                    .frame(height: 300)
                    .padding(.horizontal, 12)
                Spacer()
                progressSection
                Button {
                    showDivertConfirm = true
                } label: {
                    Text("申请备降")
                        .font(.subheadline)
                        .foregroundStyle(Theme.danger.opacity(0.85))
                        .padding(.vertical, 12)
                        .padding(.horizontal, 28)
                        .background(Theme.card.opacity(0.6), in: Capsule())
                }
                .padding(.bottom, 26)
            }
        }
        .confirmationDialog("确定备降？", isPresented: $showDivertConfirm, titleVisibility: .visible) {
            Button("备降（本段作废）", role: .destructive) {
                FlightEngine.shared.divert(journey, context: context)
            }
            Button("继续飞行", role: .cancel) {}
        } message: {
            Text(TimeMapping.isRelayEligible(focusMinutes: journey.focusMinutes)
                 ? "当前段将作废，已完成的检查点会保留。"
                 : "本次飞行将作废，目的地不会点亮。")
        }
        .task {
            #if DEBUG
            if ProcessInfo.processInfo.arguments.contains("--demo-divert") {
                try? await Task.sleep(for: .seconds(3))
                FlightEngine.shared.divert(journey, context: context)
                return
            }
            #endif
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                if let end = journey.segmentEndAt, Date() >= end {
                    FlightEngine.shared.completeDueSegment(context: context)
                    break
                }
            }
        }
    }

    private var header: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                Text(journey.carrierName)
                Text(journey.flightNumber).fontDesign(.monospaced)
                Text(journey.cabin.nameZh)
                    .foregroundStyle(Theme.cabinColor(journey.cabin))
            }
            .font(.footnote)
            .foregroundStyle(Theme.textSecondary)

            HStack(spacing: 14) {
                VStack(spacing: 2) {
                    Text(journey.originIata)
                        .font(.system(.title, design: .monospaced).bold())
                    Text(origin?.displayCity ?? "")
                        .font(.caption2).foregroundStyle(Theme.textSecondary)
                }
                Image(systemName: "airplane")
                    .foregroundStyle(Theme.glow)
                VStack(spacing: 2) {
                    Text(journey.destIata)
                        .font(.system(.title, design: .monospaced).bold())
                    Text(dest?.displayCity ?? "")
                        .font(.caption2).foregroundStyle(Theme.textSecondary)
                }
            }
            .foregroundStyle(Theme.textPrimary)
        }
    }

    /// 局部航图：大圆航线 + 实时推进的飞机
    private var routeMap: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 15.0)) { timeline in
            let flightFraction = currentFraction(at: timeline.date)
            Canvas { ctx, size in
                guard let o = origin, let d = dest else { return }
                let segments = MapRenderer.routeSegments(from: o, to: d)
                let allPoints = segments.flatMap { $0 }
                guard !allPoints.isEmpty else { return }

                var minX = allPoints[0].x, maxX = allPoints[0].x
                var minY = allPoints[0].y, maxY = allPoints[0].y
                for p in allPoints {
                    minX = min(minX, p.x); maxX = max(maxX, p.x)
                    minY = min(minY, p.y); maxY = max(maxY, p.y)
                }
                let pad: CGFloat = 30
                let bbox = CGRect(x: minX - pad, y: minY - pad,
                                  width: max(maxX - minX + pad * 2, 60),
                                  height: max(maxY - minY + pad * 2, 60))
                let s = min(size.width / bbox.width, size.height / bbox.height)
                ctx.translateBy(x: (size.width - bbox.width * s) / 2 - bbox.minX * s,
                                y: (size.height - bbox.height * s) / 2 - bbox.minY * s)
                ctx.scaleBy(x: s, y: s)

                MapRenderer.drawLand(ctx, totalScale: s)

                // 全程虚线（未飞段虔诚暗淡）
                let full = MapRenderer.path(for: segments)
                ctx.stroke(full, with: .color(Theme.track.opacity(0.25)),
                           style: StrokeStyle(lineWidth: 1.6 / s, dash: [4 / s, 4 / s]))

                // 已飞段高亮
                let done = doneSegments(from: o, to: d, fraction: flightFraction)
                ctx.stroke(MapRenderer.path(for: done), with: .color(Theme.glow),
                           style: StrokeStyle(lineWidth: 2.2 / s, lineCap: .round))

                // 起降点
                MapRenderer.drawGlowCity(ctx, at: MapRenderer.basePoint(lat: o.latitude, lon: o.longitude),
                                         totalScale: s, intensity: 0.8)
                MapRenderer.drawGlowCity(ctx, at: MapRenderer.basePoint(lat: d.latitude, lon: d.longitude),
                                         totalScale: s, intensity: 0.8)

                // 飞机（自绘镖形，机头朝 +x 后按航向旋转）
                let pos = GreatCircle.interpolate(lat1: o.latitude, lon1: o.longitude,
                                                  lat2: d.latitude, lon2: d.longitude,
                                                  f: flightFraction)
                let ahead = GreatCircle.interpolate(lat1: o.latitude, lon1: o.longitude,
                                                    lat2: d.latitude, lon2: d.longitude,
                                                    f: min(1, flightFraction + 0.01))
                let p0 = MapRenderer.basePoint(lat: pos.lat, lon: pos.lon)
                let p1 = MapRenderer.basePoint(lat: ahead.lat, lon: ahead.lon)
                let heading = Angle(radians: atan2(p1.y - p0.y, p1.x - p0.x))
                var planeCtx = ctx
                planeCtx.translateBy(x: p0.x, y: p0.y)
                planeCtx.rotate(by: heading)
                let u = 7.0 / s
                var dart = Path()
                dart.move(to: CGPoint(x: u * 1.4, y: 0))
                dart.addLine(to: CGPoint(x: -u, y: -u * 0.9))
                dart.addLine(to: CGPoint(x: -u * 0.45, y: 0))
                dart.addLine(to: CGPoint(x: -u, y: u * 0.9))
                dart.closeSubpath()
                var glowCtx = planeCtx
                glowCtx.addFilter(.blur(radius: 3.0 / s))
                glowCtx.fill(dart, with: .color(Theme.glow.opacity(0.7)))
                planeCtx.fill(dart, with: .color(Theme.glow))
            }
        }
    }

    private func currentFraction(at date: Date = Date()) -> Double {
        guard let start = journey.segmentStartAt else { return journey.checkpointFraction }
        let total = TimeInterval(journey.segmentMinutes * 60)
        guard total > 0 else { return journey.checkpointFraction }
        let elapsed = min(max(date.timeIntervalSince(start), 0), total)
        let segSpan = journey.segmentEndFraction - journey.checkpointFraction
        return journey.checkpointFraction + segSpan * (elapsed / total)
    }

    private func doneSegments(from o: Airport, to d: Airport, fraction: Double) -> [[CGPoint]] {
        guard fraction > 0.001 else { return [] }
        let n = 72
        let count = max(2, Int(Double(n) * fraction))
        let pts = (0...count).map { i in
            GreatCircle.interpolate(lat1: o.latitude, lon1: o.longitude,
                                    lat2: d.latitude, lon2: d.longitude,
                                    f: fraction * Double(i) / Double(count))
        }
        var segments: [[CGPoint]] = []
        var current: [CGPoint] = []
        var prevLon: Double?
        for p in pts {
            if let prev = prevLon, abs(p.lon - prev) > 180 {
                if current.count > 1 { segments.append(current) }
                current = []
            }
            current.append(MapRenderer.basePoint(lat: p.lat, lon: p.lon))
            prevLon = p.lon
        }
        if current.count > 1 { segments.append(current) }
        return segments
    }

    private var progressSection: some View {
        VStack(spacing: 6) {
            TimelineView(.periodic(from: .now, by: 5)) { _ in
                ProgressView(value: currentFraction())
                    .tint(Theme.glow)
            }
            HStack {
                Text("全程 \(journey.totalKm) km")
                Spacer()
                if TimeMapping.isRelayEligible(focusMinutes: journey.focusMinutes) {
                    Text("接力旅程 · 检查点 \(TimeMapping.formatMinutes(journey.completedFocusMinutes))")
                }
            }
            .font(.caption2)
            .foregroundStyle(Theme.textSecondary)
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 16)
    }
}
