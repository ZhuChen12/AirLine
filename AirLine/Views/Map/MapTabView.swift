import SwiftData
import SwiftUI
import UIKit

/// 暗色世界地图：点亮城市 + 历史航迹，可缩放平移，点击看城市卡（SPEC §8）
struct MapTabView: View {
    let profile: PlayerProfile
    let isActive: Bool

    @Query private var visits: [CityVisit]
    @Query(filter: #Predicate<FlightRecord> { $0.statusRaw == 0 })
    private var completedFlights: [FlightRecord]

    @State private var zoom: CGFloat = 3
    @State private var centerPoint = CGPoint(
        x: MapRenderer.baseSize.width / 2,
        y: MapRenderer.baseSize.height / 2
    )
    @GestureState private var pinch: CGFloat = 1
    @GestureState private var drag: CGSize = .zero
    @State private var tappedVisit: CityVisit?

    private var currentAirport: Airport? { AirportStore.shared[profile.currentIata] }
    private var scopedVisits: [CityVisit] {
        visits.filter { $0.isDeveloper == profile.isDeveloper }
    }
    private var scopedCompletedFlights: [FlightRecord] {
        completedFlights.filter { $0.isDeveloper == profile.isDeveloper }
    }

    private var routePairs: [(String, String)] {
        var seen = Set<String>()
        var pairs: [(String, String)] = []
        for f in scopedCompletedFlights {
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
            let liveCenter = cameraCenter(
                from: centerPoint,
                translation: drag,
                scale: s
            )
            let labels = cityLabels(in: size, scale: s, center: liveCenter, zoom: liveZoom)

            ZStack {
                Theme.bg.ignoresSafeArea()
                Canvas { ctx, canvasSize in
                    for copy in -1...1 {
                        var world = ctx
                        world.translateBy(x: canvasSize.width / 2, y: canvasSize.height / 2)
                        world.scaleBy(x: s, y: s)
                        world.translateBy(
                            x: -liveCenter.x + CGFloat(copy) * MapRenderer.baseSize.width,
                            y: -liveCenter.y
                        )

                        MapRenderer.drawLand(world, totalScale: s)

                        let store = AirportStore.shared
                        for (o, d) in routePairs {
                            guard let a = store[o], let b = store[d] else { continue }
                            let path = MapRenderer.path(for: MapRenderer.routeSegments(from: a, to: b))
                            world.stroke(
                                path,
                                with: .color(Theme.track.opacity(0.4)),
                                style: StrokeStyle(
                                    lineWidth: max(0.4, 1.0 / s),
                                    lineCap: .round
                                )
                            )
                        }
                        for visit in scopedVisits {
                            let point = MapRenderer.basePoint(
                                lat: visit.latitude,
                                lon: visit.longitude
                            )
                            MapRenderer.drawGlowCity(world, at: point, totalScale: s)
                        }
                        if let currentAirport {
                            drawCurrentCity(currentAirport, in: world, scale: s)
                        }
                    }
                }
                .contentShape(Rectangle())
                .gesture(
                    DragGesture()
                        .updating($drag) { value, state, _ in state = value.translation }
                        .onEnded { value in
                            centerPoint = cameraCenter(
                                from: centerPoint,
                                translation: value.translation,
                                scale: fit * zoom
                            )
                        }
                )
                .simultaneousGesture(
                    MagnificationGesture()
                        .updating($pinch) { value, state, _ in state = value }
                        .onEnded { value in
                            zoom = min(max(zoom * value, 1), 16)
                        }
                )
                .onTapGesture(coordinateSpace: .local) { location in
                    tappedVisit = nearestVisit(
                        to: location,
                        size: size,
                        scale: s,
                        center: liveCenter
                    )
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
                    HStack {
                        statsPanel()
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    Spacer()
                    if scopedVisits.isEmpty {
                        Text("完成第一次飞行，点亮你的第一座城市")
                            .font(.footnote)
                            .foregroundStyle(Theme.textSecondary)
                            .padding(.bottom, 28)
                    }
                }
            }
            .onAppear {
                centerOnCurrentCity(in: size)
            }
            .onChange(of: isActive) { _, active in
                if active { centerOnCurrentCity(in: size) }
            }
            .onChange(of: profile.currentIata) { _, _ in
                centerOnCurrentCity(in: size)
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
                tappedVisit = scopedVisits.first
            }
        }
        #endif
    }

    private func statsPanel() -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("飞行总览")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(Theme.textSecondary)
                .tracking(0.8)
            HStack(spacing: 0) {
                statCell(value: "\(scopedVisits.count)", label: "城市")
                statDivider()
                statCell(value: "\(Set(scopedVisits.map(\.countryCode)).count)", label: "国家")
                statDivider()
                statCell(value: formatKm(profile.totalKm), label: "里程")
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .background(Theme.card.opacity(0.86), in: RoundedRectangle(cornerRadius: 18))
        .overlay {
            RoundedRectangle(cornerRadius: 18)
                .strokeBorder(Theme.landStroke.opacity(0.55), lineWidth: 0.8)
        }
    }

    private func statCell(value: String, label: String) -> some View {
        HStack(spacing: 5) {
            Text(value)
                .font(.system(.subheadline, design: .monospaced).bold())
                .foregroundStyle(Theme.glow)
            Text(label).font(.caption).foregroundStyle(Theme.textSecondary)
        }
        .frame(minWidth: 58, alignment: .leading)
    }

    private func statDivider() -> some View {
        Rectangle()
            .fill(Theme.landStroke.opacity(0.45))
            .frame(width: 1, height: 20)
            .padding(.horizontal, 12)
    }

    private func centerOnCurrentCity(in size: CGSize) {
        guard let currentAirport else { return }
        withAnimation(.easeInOut(duration: 0.28)) {
            centerPoint = MapRenderer.basePoint(
                lat: currentAirport.latitude,
                lon: currentAirport.longitude
            )
            let aspectZoom = size.height / max(size.width, 1) * 3.8
            zoom = min(max(aspectZoom, 7.6), 8.8)
        }
    }

    private func cameraCenter(from original: CGPoint, translation: CGSize,
                              scale: CGFloat) -> CGPoint {
        CGPoint(
            x: wrappedX(original.x - translation.width / max(scale, 0.001)),
            y: min(
                max(original.y - translation.height / max(scale, 0.001), 0),
                MapRenderer.baseSize.height
            )
        )
    }

    private func wrappedX(_ x: CGFloat) -> CGFloat {
        let width = MapRenderer.baseSize.width
        let remainder = x.truncatingRemainder(dividingBy: width)
        return remainder < 0 ? remainder + width : remainder
    }

    private func wrappedDeltaX(_ x: CGFloat, centerX: CGFloat) -> CGFloat {
        let width = MapRenderer.baseSize.width
        var delta = (x - centerX).truncatingRemainder(dividingBy: width)
        if delta > width / 2 { delta -= width }
        if delta < -width / 2 { delta += width }
        return delta
    }

    private func screenPoint(base: CGPoint, size: CGSize, scale: CGFloat,
                             center: CGPoint) -> CGPoint {
        CGPoint(
            x: size.width / 2 + wrappedDeltaX(base.x, centerX: center.x) * scale,
            y: size.height / 2 + (base.y - center.y) * scale
        )
    }

    private func drawCurrentCity(_ airport: Airport, in context: GraphicsContext,
                                 scale: CGFloat) {
        let point = MapRenderer.basePoint(lat: airport.latitude, lon: airport.longitude)
        let radius = 8 / scale
        context.stroke(
            Path(ellipseIn: CGRect(
                x: point.x - radius,
                y: point.y - radius,
                width: radius * 2,
                height: radius * 2
            )),
            with: .color(Theme.glow),
            lineWidth: 1.2 / scale
        )
    }

    private func formatKm(_ km: Int) -> String {
        guard km >= 10_000 else { return "\(km)" }
        return String(format: "%.1f万", Double(km) / 10_000)
    }

    /// 在屏幕坐标中布局城市名，按枢纽连通度优先并剔除相交标签。
    private func cityLabels(in size: CGSize, scale: CGFloat, center: CGPoint,
                            zoom: CGFloat) -> [MapCityLabel] {
        var sources = scopedVisits.map { visit in
            MapLabelSource(
                iata: visit.iata,
                name: visit.displayCity,
                latitude: visit.latitude,
                longitude: visit.longitude,
                routeCount: AirportStore.shared[visit.iata]?.routes.count ?? 0,
                isCurrent: visit.iata == profile.currentIata,
                arrivalCount: visit.arrivalCount
            )
        }
        if let currentAirport,
           !sources.contains(where: { $0.iata == currentAirport.icaoKey }) {
            sources.append(MapLabelSource(
                iata: currentAirport.icaoKey,
                name: currentAirport.displayCity,
                latitude: currentAirport.latitude,
                longitude: currentAirport.longitude,
                routeCount: currentAirport.routes.count,
                isCurrent: true,
                arrivalCount: 0
            ))
        }

        let visible = sources.compactMap { source -> (MapLabelSource, CGPoint)? in
            let base = MapRenderer.basePoint(lat: source.latitude, lon: source.longitude)
            let point = screenPoint(base: base, size: size, scale: scale, center: center)
            guard point.x >= 0, point.x <= size.width,
                  point.y >= 54, point.y <= size.height else { return nil }
            return (source, point)
        }
        .sorted {
            if $0.0.isCurrent != $1.0.isCurrent { return $0.0.isCurrent }
            if $0.0.routeCount != $1.0.routeCount {
                return $0.0.routeCount > $1.0.routeCount
            }
            return $0.0.arrivalCount > $1.0.arrivalCount
        }

        let minimumRouteCount = zoom < 2 ? 40 : (zoom < 5 ? 20 : 0)
        let major = visible.filter { $0.0.isCurrent || $0.0.routeCount >= minimumRouteCount }
        let candidates = major.isEmpty ? visible : major
        let limit = zoom < 2 ? 8 : (zoom < 5 ? 12 : 18)
        let safeBounds = CGRect(x: 6, y: 56, width: size.width - 12, height: size.height - 64)
        var occupied = [CGRect(x: 0, y: 0, width: size.width, height: 54)]
        var usedNames = Set<String>()
        var labels: [MapCityLabel] = []
        let font = UIFont.systemFont(ofSize: 11, weight: .semibold)

        for (source, point) in candidates {
            guard usedNames.insert(source.name).inserted else { continue }
            let displayName = source.isCurrent ? "\(source.name) · 当前" : source.name
            let measured = (displayName as NSString).size(withAttributes: [.font: font])
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

            labels.append(MapCityLabel(
                name: displayName,
                point: point,
                rect: rect
            ))
            occupied.append(rect)
            if labels.count >= limit { break }
        }
        return labels
    }

    private func nearestVisit(to location: CGPoint, size: CGSize, scale: CGFloat,
                              center: CGPoint) -> CityVisit? {
        var best: (CityVisit, CGFloat)?
        for v in scopedVisits {
            let base = MapRenderer.basePoint(lat: v.latitude, lon: v.longitude)
            let point = screenPoint(base: base, size: size, scale: scale, center: center)
            let d = hypot(point.x - location.x, point.y - location.y)
            if d < 22, d < (best?.1 ?? .infinity) {
                best = (v, d)
            }
        }
        return best?.0
    }
}

private struct MapLabelSource {
    let iata: String
    let name: String
    let latitude: Double
    let longitude: Double
    let routeCount: Int
    let isCurrent: Bool
    let arrivalCount: Int
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
