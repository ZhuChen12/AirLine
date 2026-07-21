import Foundation

/// 大圆航线数学（球面插值）
enum GreatCircle {
    /// 球面线性插值：f ∈ [0,1]，返回 (lat, lon)（度）
    static func interpolate(lat1: Double, lon1: Double, lat2: Double, lon2: Double, f: Double) -> (lat: Double, lon: Double) {
        let φ1 = lat1 * .pi / 180, λ1 = lon1 * .pi / 180
        let φ2 = lat2 * .pi / 180, λ2 = lon2 * .pi / 180

        let Δ = centralAngle(φ1: φ1, λ1: λ1, φ2: φ2, λ2: λ2)
        if Δ < 1e-9 { return (lat1, lon1) }

        let a = sin((1 - f) * Δ) / sin(Δ)
        let b = sin(f * Δ) / sin(Δ)
        let x = a * cos(φ1) * cos(λ1) + b * cos(φ2) * cos(λ2)
        let y = a * cos(φ1) * sin(λ1) + b * cos(φ2) * sin(λ2)
        let z = a * sin(φ1) + b * sin(φ2)
        return (atan2(z, sqrt(x * x + y * y)) * 180 / .pi, atan2(y, x) * 180 / .pi)
    }

    static func centralAngle(φ1: Double, λ1: Double, φ2: Double, λ2: Double) -> Double {
        let dφ = φ2 - φ1, dλ = λ2 - λ1
        let h = sin(dφ / 2) * sin(dφ / 2) + cos(φ1) * cos(φ2) * sin(dλ / 2) * sin(dλ / 2)
        return 2 * asin(min(1, sqrt(h)))
    }

    /// 采样 n+1 个点的大圆路径
    static func path(from a: Airport, to b: Airport, samples n: Int = 64) -> [(lat: Double, lon: Double)] {
        (0...n).map { i in
            interpolate(lat1: a.latitude, lon1: a.longitude, lat2: b.latitude, lon2: b.longitude, f: Double(i) / Double(n))
        }
    }

    /// 航向角（度，用于机头朝向）
    static func bearing(lat1: Double, lon1: Double, lat2: Double, lon2: Double) -> Double {
        let φ1 = lat1 * .pi / 180, φ2 = lat2 * .pi / 180
        let dλ = (lon2 - lon1) * .pi / 180
        let y = sin(dλ) * cos(φ2)
        let x = cos(φ1) * sin(φ2) - sin(φ1) * cos(φ2) * cos(dλ)
        return atan2(y, x) * 180 / .pi
    }
}
