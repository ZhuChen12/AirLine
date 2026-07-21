import SwiftData
import SwiftUI

/// 暗色世界地图：点亮城市 + 历史航迹，可缩放平移，点击看城市卡（SPEC §8）
struct MapTabView: View {
    @Query private var visits: [CityVisit]
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
            let s = fit * min(max(zoom * pinch, 1), 16)
            let off = CGSize(width: offset.width + drag.width, height: offset.height + drag.height)

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
                            offset.width += value.translation.width
                            offset.height += value.translation.height
                        }
                )
                .simultaneousGesture(
                    MagnificationGesture()
                        .updating($pinch) { value, state, _ in state = value }
                        .onEnded { value in zoom = min(max(zoom * value, 1), 16) }
                )
                .onTapGesture(coordinateSpace: .local) { location in
                    tappedVisit = nearestVisit(to: location, size: size, scale: s, offset: off)
                }

                VStack {
                    HStack(spacing: 14) {
                        statChip(value: visits.count, label: "城市")
                        statChip(value: Set(visits.map(\.countryCode)).count, label: "国家")
                        Spacer()
                        if zoom > 1.01 || offset != .zero {
                            Button {
                                withAnimation(.spring(duration: 0.4)) {
                                    zoom = 1
                                    offset = .zero
                                }
                            } label: {
                                Image(systemName: "arrow.counterclockwise")
                                    .padding(8)
                                    .background(Theme.card.opacity(0.8), in: Circle())
                            }
                        }
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

    private func statChip(value: Int, label: String) -> some View {
        HStack(spacing: 5) {
            Text("\(value)")
                .font(.system(.subheadline, design: .monospaced).bold())
                .foregroundStyle(Theme.glow)
            Text(label).font(.caption).foregroundStyle(Theme.textSecondary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Theme.card.opacity(0.8), in: Capsule())
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
