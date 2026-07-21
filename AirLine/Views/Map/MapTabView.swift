import SwiftData
import SwiftUI
import UIKit

/// 暗色世界地图：点亮城市 + 历史航迹，可缩放平移，点击看城市卡（SPEC §8）
struct MapTabView: View {
    @Query private var visits: [CityVisit]
    @Query private var profiles: [PlayerProfile]
    @Query(filter: #Predicate<FlightRecord> { $0.statusRaw == 0 })
    private var completedFlights: [FlightRecord]

    @State private var zoom: CGFloat = 1
    @State private var offset: CGSize = .zero
    @GestureState private var pinch: CGFloat = 1
    @GestureState private var drag: CGSize = .zero
    @State private var tappedVisit: CityVisit?

    private var routePairs: [(String, String)] {
        var seen = Set<String>()
        var pairs: [(String, String)] = []
        for f in completedFlights {
            let key = [f.originIata, f.destIata].sorted().joined(separator: "-")
            if seen.insert(key).inserted {
                pairs.append((f.originIata, f.destIata))
            }
        }
        return pairs
    }

    var body: some View {
        GeometryReader { geo in
            let size = geo.size
            let fit = size.width / MapRenderer.baseSize.width
            let liveZoom = min(max(zoom * pinch, 1), 16)
            let s = fit * liveZoom
            let off = CGSize(width: offset.width + drag.width, height: offset.height + drag.height)
            let labels = cityLabels(in: size, scale: s, offset: off, zoom: liveZoom)

            ZStack {
                Theme.bg.ignoresSafeArea()
                Canvas { ctx, canvasSize in
                    ctx.translateBy(x: canvasSize.width / 2 + off.width,
                                    y: canvasSize.height / 2 + off.height)
                    ctx.scaleBy(x: s, y: s)
                    ctx.translateBy(x: -MapRenderer.baseSize.width / 2,
                                    y: -MapRenderer.baseSize.height / 2)

                    MapRenderer.drawLand(ctx, totalScale: s)

                    let store = AirportStore.shared
                    for (o, d) in routePairs {
                        guard let a = store[o], let b = store[d] else { continue }
                        let p = MapRenderer.path(for: MapRenderer.routeSegments(from: a, to: b))
                        ctx.stroke(p, with: .color(Theme.track.opacity(0.4)),
                                   style: StrokeStyle(lineWidth: max(0.4, 1.0 / s), lineCap: .round))
                    }
                    for v in visits {
                        let p = MapRenderer.basePoint(lat: v.latitude, lon: v.longitude)
                        MapRenderer.drawGlowCity(ctx, at: p, totalScale: s)
                    }
                }
                .contentShape(Rectangle())
                .gesture(
                    DragGesture()
                        .updating($drag) { value, state, _ in state = value.translation }
                        .onEnded { value in
                            let proposed = CGSize(
                                width: offset.width + value.translation.width,
                                height: offset.height + value.translation.height
                            )
                            offset = constrainedOffset(proposed, size: size, zoom: zoom)
                        }
                )
                .simultaneousGesture(
                    MagnificationGesture()
                        .updating($pinch) { value, state, _ in state = value }
                        .onEnded { value in
                            let target = min(max(zoom * value, 1), 16)
                            zoom = target
                            offset = constrainedOffset(offset, size: size, zoom: target)
                        }
                )
                .onTapGesture(coordinateSpace: .local) { location in
                    tappedVisit = nearestVisit(to: location, size: size, scale: s, offset: off)
                }

                Canvas { context, _ in
                    for label in labels {
                        var leader = Path()
                        leader.move(to: label.point)
                        leader.addLine(to: CGPoint(x: label.rect.midX, y: label.rect.midY))
                        context.stroke(
                            leader,
                            with: .color(Theme.glow.opacity(0.28)),
                            lineWidth: 0.7
                        )
                        context.fill(
                            Path(roundedRect: label.rect, cornerRadius: 6),
                            with: .color(Theme.bgElevated.opacity(0.88))
                        )
                        let text = context.resolve(
                            Text(label.name)
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(Theme.textPrimary)
                        )
                        context.draw(
                            text,
                            at: CGPoint(x: label.rect.midX, y: label.rect.midY),
                            anchor: .center
                        )
                    }
                }
                .allowsHitTesting(false)

                VStack {
                    HStack(spacing: 14) {
                        statChip(value: "\(visits.count)", label: "城市")
                        statChip(value: "\(Set(visits.map(\.countryCode)).count)", label: "国家")
                        statChip(value: formatKm(profiles.first?.totalKm ?? 0), label: "里程")
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    Spacer()
                    if visits.isEmpty {
                        Text("完成第一次飞行，点亮你的第一座城市")
                            .font(.footnote)
                            .foregroundStyle(Theme.textSecondary)
                            .padding(.bottom, 28)
                    }
                }

                zoomControls(size: size)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                    .padding(.trailing, 16)
                    .padding(.bottom, 24)
            }
        }
        .sheet(item: $tappedVisit) { visit in
            CityCardView(visit: visit)
                .presentationDetents([.medium])
                .presentationBackground(Theme.bgElevated)
        }
        #if DEBUG
        .onAppear {
            if ProcessInfo.processInfo.arguments.contains("--demo-citycard") {
                tappedVisit = visits.first
            }
        }
        #endif
    }

    private func statChip(value: String, label: String) -> some View {
        HStack(spacing: 5) {
            Text(value)
                .font(.system(.subheadline, design: .monospaced).bold())
                .foregroundStyle(Theme.glow)
            Text(label).font(.caption).foregroundStyle(Theme.textSecondary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Theme.card.opacity(0.8), in: Capsule())
    }

    private func zoomControls(size: CGSize) -> some View {
        VStack(spacing: 0) {
            Text("\(Int((zoom * 100).rounded()))%")
                .font(.system(size: 9, weight: .semibold, design: .monospaced))
                .foregroundStyle(Theme.textSecondary)
                .frame(width: 44, height: 24)
            Divider().overlay(Theme.landStroke)
            zoomButton("plus") {
                setZoom(min(16, zoom * 1.6), size: size)
            }
            Divider().overlay(Theme.landStroke)
            zoomButton("minus") {
                setZoom(max(1, zoom / 1.6), size: size)
            }
            Divider().overlay(Theme.landStroke)
            zoomButton("arrow.counterclockwise") {
                withAnimation(.spring(duration: 0.35)) {
                    zoom = 1
                    offset = .zero
                }
            }
        }
        .background(Theme.card.opacity(0.92), in: RoundedRectangle(cornerRadius: 12))
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(Theme.landStroke.opacity(0.8))
        }
    }

    private func zoomButton(_ systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.textPrimary)
                .frame(width: 44, height: 38)
                .contentShape(Rectangle())
        }
    }

    private func setZoom(_ target: CGFloat, size: CGSize) {
        withAnimation(.easeInOut(duration: 0.22)) {
            zoom = target
            offset = constrainedOffset(offset, size: size, zoom: target)
        }
    }

    private func constrainedOffset(_ proposed: CGSize, size: CGSize, zoom: CGFloat) -> CGSize {
        let mapWidth = size.width * zoom
        let mapHeight = size.width * zoom / 2
        let maxX = max(0, (mapWidth - size.width) / 2)
        let maxY = max(0, (mapHeight - size.height) / 2)
        return CGSize(
            width: min(max(proposed.width, -maxX), maxX),
            height: min(max(proposed.height, -maxY), maxY)
        )
    }

    private func formatKm(_ km: Int) -> String {
        guard km >= 10_000 else { return "\(km)" }
        return String(format: "%.1f万", Double(km) / 10_000)
    }

    /// 在屏幕坐标中布局城市名，按枢纽连通度优先并剔除相交标签。
    private func cityLabels(in size: CGSize, scale: CGFloat, offset: CGSize,
                            zoom: CGFloat) -> [MapCityLabel] {
        let visible = visits.compactMap { visit -> (CityVisit, CGPoint, Int)? in
            let base = MapRenderer.basePoint(lat: visit.latitude, lon: visit.longitude)
            let point = CGPoint(
                x: (base.x - MapRenderer.baseSize.width / 2) * scale + size.width / 2 + offset.width,
                y: (base.y - MapRenderer.baseSize.height / 2) * scale + size.height / 2 + offset.height
            )
            guard point.x >= 0, point.x <= size.width,
                  point.y >= 54, point.y <= size.height else { return nil }
            let routeCount = AirportStore.shared[visit.iata]?.routes.count ?? 0
            return (visit, point, routeCount)
        }
        .sorted {
            if $0.2 != $1.2 { return $0.2 > $1.2 }
            return $0.0.arrivalCount > $1.0.arrivalCount
        }

        let minimumRouteCount = zoom < 2 ? 40 : (zoom < 5 ? 20 : 0)
        let major = visible.filter { $0.2 >= minimumRouteCount }
        let candidates = major.isEmpty ? visible : major
        let limit = zoom < 2 ? 8 : (zoom < 5 ? 12 : 18)
        let safeBounds = CGRect(x: 6, y: 56, width: size.width - 12, height: size.height - 64)
        var occupied = [
            CGRect(x: 0, y: 0, width: size.width, height: 54),
            CGRect(x: size.width - 70, y: size.height - 180, width: 70, height: 180),
        ]
        var usedNames = Set<String>()
        var labels: [MapCityLabel] = []
        let font = UIFont.systemFont(ofSize: 11, weight: .semibold)

        for (visit, point, _) in candidates {
            let name = visit.displayCity
            guard usedNames.insert(name).inserted else { continue }
            let measured = (name as NSString).size(withAttributes: [.font: font])
            let labelSize = CGSize(width: min(150, ceil(measured.width) + 14), height: 22)
            let gap: CGFloat = 8
            let options = [
                CGRect(x: point.x + gap, y: point.y - labelSize.height - 3,
                       width: labelSize.width, height: labelSize.height),
                CGRect(x: point.x - labelSize.width - gap, y: point.y - labelSize.height - 3,
                       width: labelSize.width, height: labelSize.height),
                CGRect(x: point.x + gap, y: point.y + 3,
                       width: labelSize.width, height: labelSize.height),
                CGRect(x: point.x - labelSize.width - gap, y: point.y + 3,
                       width: labelSize.width, height: labelSize.height),
            ]
            guard let rect = options.first(where: { candidate in
                safeBounds.contains(candidate)
                    && !occupied.contains(where: { $0.insetBy(dx: -4, dy: -3).intersects(candidate) })
            }) else { continue }

            labels.append(MapCityLabel(name: name, point: point, rect: rect))
            occupied.append(rect)
            if labels.count >= limit { break }
        }
        return labels
    }

    private func nearestVisit(to location: CGPoint, size: CGSize, scale: CGFloat, offset: CGSize) -> CityVisit? {
        var best: (CityVisit, CGFloat)?
        for v in visits {
            let base = MapRenderer.basePoint(lat: v.latitude, lon: v.longitude)
            let sx = (base.x - MapRenderer.baseSize.width / 2) * scale + size.width / 2 + offset.width
            let sy = (base.y - MapRenderer.baseSize.height / 2) * scale + size.height / 2 + offset.height
            let d = hypot(sx - location.x, sy - location.y)
            if d < 22, d < (best?.1 ?? .infinity) {
                best = (v, d)
            }
        }
        return best?.0
    }
}

private struct MapCityLabel {
    let name: String
    let point: CGPoint
    let rect: CGRect
}

/// 城市卡：小传 + 到访信息
struct CityCardView: View {
    let visit: CityVisit
    @State private var bioService = CityBioService.shared

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .firstTextBaseline) {
                    Text(visit.displayCity)
                        .font(.title2.bold())
                        .foregroundStyle(Theme.textPrimary)
                    Text(visit.city)
                        .font(.subheadline)
                        .foregroundStyle(Theme.textSecondary)
                    Spacer()
                    Text(visit.iata)
                        .font(.system(.headline, design: .monospaced))
                        .foregroundStyle(Theme.glow)
                }

                if let airport = AirportStore.shared[visit.iata] {
                    let bio = bioService.bio(for: visit.iata) ?? bioService.fallback(for: airport)
                    Text("【\(bio.tag)】")
                        .font(.subheadline.bold())
                        .foregroundStyle(Theme.glow)
                    Text(bio.body)
                        .font(.subheadline)
                        .foregroundStyle(Theme.textPrimary.opacity(0.9))
                        .lineSpacing(5)
                }

                HStack {
                    Label("首次抵达 \(visit.firstArrivalAt.formatted(date: .abbreviated, time: .omitted))",
                          systemImage: "airplane.arrival")
                    Spacer()
                    Text("飞抵 \(visit.arrivalCount) 次")
                }
                .font(.caption)
                .foregroundStyle(Theme.textSecondary)
                .padding(.top, 6)
            }
            .padding(20)
        }
    }
}
