import SwiftUI

/// 原创品牌标记：上升航迹与飞翼，延续地图的深蓝、航迹蓝和暖金配色。
struct AirLineLogoMark: View {
    var body: some View {
        GeometryReader { geo in
            let size = geo.size
            let unit = min(size.width, size.height)

            ZStack {
                RoundedRectangle(cornerRadius: unit * 0.24, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Theme.bgElevated,
                                Theme.card,
                                Theme.bg.opacity(0.96),
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay {
                        RoundedRectangle(cornerRadius: unit * 0.24, style: .continuous)
                            .strokeBorder(
                                LinearGradient(
                                    colors: [
                                        Theme.glow.opacity(0.42),
                                        Theme.track.opacity(0.16),
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: max(1, unit * 0.014)
                            )
                    }
                    .overlay {
                        Circle()
                            .stroke(Theme.track.opacity(0.10), lineWidth: max(1, unit * 0.012))
                            .padding(unit * 0.18)
                    }

                Canvas { context, canvasSize in
                    let w = canvasSize.width
                    let h = canvasSize.height
                    let routeStart = CGPoint(x: w * 0.22, y: h * 0.66)
                    let routeControl1 = CGPoint(x: w * 0.38, y: h * 0.68)
                    let routeControl2 = CGPoint(x: w * 0.58, y: h * 0.52)
                    let routeEnd = CGPoint(x: w * 0.75, y: h * 0.36)
                    func cubic(_ t: CGFloat, _ a: CGFloat, _ b: CGFloat,
                               _ c: CGFloat, _ d: CGFloat) -> CGFloat {
                        let u = 1 - t
                        return u * u * u * a
                            + 3 * u * u * t * b
                            + 3 * u * t * t * c
                            + t * t * t * d
                    }
                    func cubicDerivative(_ t: CGFloat, _ a: CGFloat, _ b: CGFloat,
                                         _ c: CGFloat, _ d: CGFloat) -> CGFloat {
                        let u = 1 - t
                        return 3 * u * u * (b - a)
                            + 6 * u * t * (c - b)
                            + 3 * t * t * (d - c)
                    }

                    var route = Path()
                    route.move(to: routeStart)
                    route.addCurve(
                        to: routeEnd,
                        control1: routeControl1,
                        control2: routeControl2
                    )
                    var routeGlow = context
                    routeGlow.addFilter(.blur(radius: max(2, w * 0.025)))
                    routeGlow.stroke(
                        route,
                        with: .color(Theme.track.opacity(0.28)),
                        style: StrokeStyle(
                            lineWidth: max(3, w * 0.06),
                            lineCap: .round
                        )
                    )
                    context.stroke(
                        route,
                        with: .linearGradient(
                            Gradient(colors: [Theme.track.opacity(0.35), Theme.track]),
                            startPoint: routeStart,
                            endPoint: routeEnd
                        ),
                        style: StrokeStyle(
                            lineWidth: max(1.5, w * 0.028),
                            lineCap: .round
                        )
                    )

                    let originRadius = w * 0.022
                    context.stroke(
                        Path(ellipseIn: CGRect(
                            x: w * 0.22 - originRadius * 2.1,
                            y: h * 0.66 - originRadius * 2.1,
                            width: originRadius * 4.2,
                            height: originRadius * 4.2
                        )),
                        with: .color(Theme.glow.opacity(0.24)),
                        lineWidth: max(1, w * 0.012)
                    )
                    context.fill(
                        Path(ellipseIn: CGRect(
                            x: w * 0.22 - originRadius,
                            y: h * 0.66 - originRadius,
                            width: originRadius * 2,
                            height: originRadius * 2
                        )),
                        with: .color(Theme.glow.opacity(0.8))
                    )

                    var planeContext = context
                    let planeT: CGFloat = 0.94
                    let planePoint = CGPoint(
                        x: cubic(planeT, routeStart.x, routeControl1.x, routeControl2.x, routeEnd.x),
                        y: cubic(planeT, routeStart.y, routeControl1.y, routeControl2.y, routeEnd.y)
                    )
                    let tangent = CGPoint(
                        x: cubicDerivative(planeT, routeStart.x, routeControl1.x, routeControl2.x, routeEnd.x),
                        y: cubicDerivative(planeT, routeStart.y, routeControl1.y, routeControl2.y, routeEnd.y)
                    )
                    planeContext.translateBy(x: planePoint.x, y: planePoint.y)
                    planeContext.rotate(by: .radians(atan2(tangent.y, tangent.x) + .pi / 2))
                    let u = w * 0.078
                    var plane = Path()
                    plane.move(to: CGPoint(x: 0, y: -u * 1.45))
                    plane.addCurve(
                        to: CGPoint(x: u * 0.16, y: -u * 0.24),
                        control1: CGPoint(x: u * 0.11, y: -u * 1.20),
                        control2: CGPoint(x: u * 0.15, y: -u * 0.55)
                    )
                    plane.addLine(to: CGPoint(x: u * 1.03, y: u * 0.26))
                    plane.addLine(to: CGPoint(x: u * 0.93, y: u * 0.48))
                    plane.addLine(to: CGPoint(x: u * 0.18, y: u * 0.20))
                    plane.addLine(to: CGPoint(x: u * 0.16, y: u * 0.76))
                    plane.addLine(to: CGPoint(x: u * 0.47, y: u * 1.02))
                    plane.addLine(to: CGPoint(x: u * 0.35, y: u * 1.15))
                    plane.addLine(to: CGPoint(x: 0, y: u * 0.91))
                    plane.addLine(to: CGPoint(x: -u * 0.35, y: u * 1.15))
                    plane.addLine(to: CGPoint(x: -u * 0.47, y: u * 1.02))
                    plane.addLine(to: CGPoint(x: -u * 0.16, y: u * 0.76))
                    plane.addLine(to: CGPoint(x: -u * 0.18, y: u * 0.20))
                    plane.addLine(to: CGPoint(x: -u * 0.93, y: u * 0.48))
                    plane.addLine(to: CGPoint(x: -u * 1.03, y: u * 0.26))
                    plane.addLine(to: CGPoint(x: -u * 0.16, y: -u * 0.24))
                    plane.addCurve(
                        to: CGPoint(x: 0, y: -u * 1.45),
                        control1: CGPoint(x: -u * 0.15, y: -u * 0.55),
                        control2: CGPoint(x: -u * 0.11, y: -u * 1.20)
                    )
                    plane.closeSubpath()

                    var planeGlow = planeContext
                    planeGlow.addFilter(.blur(radius: max(2, w * 0.035)))
                    planeGlow.fill(plane, with: .color(Theme.glow.opacity(0.38)))
                    planeContext.fill(
                        plane,
                        with: .linearGradient(
                            Gradient(colors: [Theme.glow, Theme.glowDim]),
                            startPoint: CGPoint(x: 0, y: -u * 1.5),
                            endPoint: CGPoint(x: 0, y: u * 1.2)
                        )
                    )
                    planeContext.stroke(
                        plane,
                        with: .color(Theme.glow.opacity(0.48)),
                        lineWidth: max(0.6, w * 0.007)
                    )
                }
                .padding(unit * 0.055)
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityHidden(true)
    }
}

struct AirLineBrandLockup: View {
    var body: some View {
        HStack(spacing: 14) {
            AirLineLogoMark()
                .frame(width: 62, height: 62)
            VStack(alignment: .leading, spacing: 2) {
                Text("AIRLINE")
                    .font(.system(size: 28, weight: .black, design: .serif))
                    .foregroundStyle(Theme.glow)
                    .kerning(5)
                Text("FOCUS FLIGHT")
                    .font(.system(size: 9, weight: .semibold, design: .monospaced))
                    .foregroundStyle(Theme.textSecondary)
                    .kerning(2.4)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("AirLine Focus Flight")
    }
}
