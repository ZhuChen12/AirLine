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
                            colors: [Theme.bgElevated, Theme.card],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay {
                        RoundedRectangle(cornerRadius: unit * 0.24, style: .continuous)
                            .strokeBorder(Theme.glow.opacity(0.22), lineWidth: max(1, unit * 0.018))
                    }

                Canvas { context, canvasSize in
                    let w = canvasSize.width
                    let h = canvasSize.height

                    var route = Path()
                    route.move(to: CGPoint(x: w * 0.15, y: h * 0.73))
                    route.addCurve(
                        to: CGPoint(x: w * 0.77, y: h * 0.30),
                        control1: CGPoint(x: w * 0.35, y: h * 0.76),
                        control2: CGPoint(x: w * 0.61, y: h * 0.52)
                    )
                    context.stroke(
                        route,
                        with: .linearGradient(
                            Gradient(colors: [Theme.track.opacity(0.35), Theme.track]),
                            startPoint: CGPoint(x: w * 0.15, y: h * 0.73),
                            endPoint: CGPoint(x: w * 0.77, y: h * 0.30)
                        ),
                        style: StrokeStyle(lineWidth: max(1.5, w * 0.035), lineCap: .round)
                    )

                    let originRadius = w * 0.035
                    context.fill(
                        Path(ellipseIn: CGRect(
                            x: w * 0.15 - originRadius,
                            y: h * 0.73 - originRadius,
                            width: originRadius * 2,
                            height: originRadius * 2
                        )),
                        with: .color(Theme.glow.opacity(0.8))
                    )

                    var wing = Path()
                    wing.move(to: CGPoint(x: w * 0.84, y: h * 0.17))
                    wing.addLine(to: CGPoint(x: w * 0.70, y: h * 0.57))
                    wing.addLine(to: CGPoint(x: w * 0.62, y: h * 0.39))
                    wing.addLine(to: CGPoint(x: w * 0.44, y: h * 0.32))
                    wing.closeSubpath()

                    var glow = context
                    glow.addFilter(.blur(radius: max(2, w * 0.04)))
                    glow.fill(wing, with: .color(Theme.glow.opacity(0.45)))
                    context.fill(
                        wing,
                        with: .linearGradient(
                            Gradient(colors: [Theme.glow, Theme.glowDim]),
                            startPoint: CGPoint(x: w * 0.82, y: h * 0.18),
                            endPoint: CGPoint(x: w * 0.52, y: h * 0.48)
                        )
                    )
                }
                .padding(unit * 0.06)
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
