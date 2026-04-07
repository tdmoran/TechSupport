import SwiftUI

struct SparklineView: View {
    let dataPoints: [Double]

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let height = geo.size.height

            if dataPoints.count >= 2 {
                let linePath = buildLinePath(in: CGSize(width: width, height: height))
                let fillPath = buildFillPath(in: CGSize(width: width, height: height))

                ZStack {
                    fillPath
                        .fill(
                            LinearGradient(
                                colors: [
                                    Theme.Colors.accent.opacity(0.25),
                                    Theme.Colors.accent.opacity(0.02),
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )

                    linePath
                        .stroke(
                            Theme.Colors.accent.opacity(0.7),
                            style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round)
                        )
                }
            }
        }
        .frame(height: 40)
    }

    // MARK: - Path Builders

    private func buildLinePath(in size: CGSize) -> Path {
        Path { path in
            guard dataPoints.count >= 2 else { return }

            let stepX = size.width / CGFloat(dataPoints.count - 1)

            for (index, value) in dataPoints.enumerated() {
                let x = CGFloat(index) * stepX
                let y = size.height - (CGFloat(clamp(value)) / 100.0) * size.height

                if index == 0 {
                    path.move(to: CGPoint(x: x, y: y))
                } else {
                    path.addLine(to: CGPoint(x: x, y: y))
                }
            }
        }
    }

    private func buildFillPath(in size: CGSize) -> Path {
        Path { path in
            guard dataPoints.count >= 2 else { return }

            let stepX = size.width / CGFloat(dataPoints.count - 1)

            // Start at bottom-left
            path.move(to: CGPoint(x: 0, y: size.height))

            // Draw line across the top
            for (index, value) in dataPoints.enumerated() {
                let x = CGFloat(index) * stepX
                let y = size.height - (CGFloat(clamp(value)) / 100.0) * size.height
                path.addLine(to: CGPoint(x: x, y: y))
            }

            // Close along the bottom
            path.addLine(to: CGPoint(x: size.width, y: size.height))
            path.closeSubpath()
        }
    }

    private func clamp(_ value: Double) -> Double {
        min(max(value, 0), 100)
    }
}
