import Foundation
import SwiftUI

/// 自绘矢量世界地图的基础几何：裁切极区的紧凑 Miller 圆柱投影，基准空间 720×360。
enum MapRenderer {
    static let baseSize = CGSize(width: 720, height: 360)
    private static let minVisibleLatitude = -60.0
    private static let maxVisibleLatitude = 82.0
    private static let millerWeight = 0.68
    private static let millerTop = millerY(for: maxVisibleLatitude)
    private static let millerBottom = millerY(for: minVisibleLatitude)

    static func basePoint(lat: Double, lon: Double) -> CGPoint {
        let clampedLat = min(max(lat, minVisibleLatitude), maxVisibleLatitude)
        let projectedY = millerY(for: clampedLat)
        let millerNormalized = (millerTop - projectedY) / (millerTop - millerBottom)
        let linearNormalized = (maxVisibleLatitude - clampedLat) / (maxVisibleLatitude - minVisibleLatitude)
        let normalizedY = millerNormalized * millerWeight
            + linearNormalized * (1 - millerWeight)
        return CGPoint(
            x: (lon + 180) / 360 * baseSize.width,
            y: normalizedY * baseSize.height
        )
    }

    private static func millerY(for latitude: Double) -> Double {
        let radians = latitude * .pi / 180
        return 1.25 * log(tan(.pi / 4 + 0.4 * radians))
    }

    /// 构建期打包的陆地轮廓（world_land.min.json → 单个 Path，只构建一次）
    static let landPath: Path = {
        guard let url = Bundle.main.url(forResource: "world_land.min", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let rings = try? JSONDecoder().decode([[[Double]]].self, from: data) else {
            return Path()
        }
        var path = Path()
        for ring in rings {
            guard ring.count > 2 else { continue }
            guard !ring.allSatisfy({ $0[1] < minVisibleLatitude }) else { continue }
            path.move(to: basePoint(lat: ring[0][1], lon: ring[0][0]))
            for pt in ring.dropFirst() {
                path.addLine(to: basePoint(lat: pt[1], lon: pt[0]))
            }
            path.closeSubpath()
        }
        return path
    }()

    /// 大圆航线在基准空间中的折线段（跨日界线时拆分）
    static func routeSegments(from a: Airport, to b: Airport, samples: Int = 72) -> [[CGPoint]] {
        let pts = GreatCircle.path(from: a, to: b, samples: samples)
        var segments: [[CGPoint]] = []
        var current: [CGPoint] = []
        var prevLon: Double?
        for p in pts {
            if let prev = prevLon, abs(p.lon - prev) > 180 {
                if current.count > 1 { segments.append(current) }
                current = []
            }
            current.append(basePoint(lat: p.lat, lon: p.lon))
            prevLon = p.lon
        }
        if current.count > 1 { segments.append(current) }
        return segments
    }

    static func path(for segments: [[CGPoint]]) -> Path {
        var p = Path()
        for seg in segments {
            p.move(to: seg[0])
            for pt in seg.dropFirst() { p.addLine(to: pt) }
        }
        return p
    }

    /// 画陆地（在已应用变换的上下文中调用；lineWidth 按总缩放补偿）
    static func drawLand(_ ctx: GraphicsContext, totalScale: CGFloat) {
        ctx.fill(landPath, with: .color(Theme.land))
        ctx.stroke(landPath, with: .color(Theme.landStroke), lineWidth: max(0.3, 0.8 / totalScale))
    }

    /// 画一个辉光城市点（在已应用变换的上下文中调用）
    static func drawGlowCity(_ ctx: GraphicsContext, at p: CGPoint, totalScale: CGFloat, intensity: Double = 1.0) {
        let r = 5.0 / totalScale
        var halo = ctx
        halo.addFilter(.blur(radius: r * 1.6))
        halo.fill(Path(ellipseIn: CGRect(x: p.x - r * 2, y: p.y - r * 2, width: r * 4, height: r * 4)),
                  with: .color(Theme.glow.opacity(0.55 * intensity)))
        let core = 1.6 / totalScale
        ctx.fill(Path(ellipseIn: CGRect(x: p.x - core, y: p.y - core, width: core * 2, height: core * 2)),
                 with: .color(Theme.glow.opacity(min(1, 0.9 * intensity + 0.1))))
    }
}
