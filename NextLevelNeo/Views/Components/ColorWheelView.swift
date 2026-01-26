import SwiftUI

struct ColorWheelView: View {
    @Binding var selectedColor: Color
    var onColorChanged: ((Color) -> Void)?

    @State private var selectorPosition: CGPoint = .zero
    @State private var isDragging = false

    var body: some View {
        GeometryReader { geometry in
            let size = min(geometry.size.width, geometry.size.height)
            let center = CGPoint(x: size / 2, y: size / 2)
            let radius = size / 2

            ZStack {
                // Color wheel
                Circle()
                    .fill(
                        AngularGradient(
                            gradient: Gradient(colors: [
                                Color(hue: 0, saturation: 1, brightness: 1),
                                Color(hue: 0.1, saturation: 1, brightness: 1),
                                Color(hue: 0.2, saturation: 1, brightness: 1),
                                Color(hue: 0.3, saturation: 1, brightness: 1),
                                Color(hue: 0.4, saturation: 1, brightness: 1),
                                Color(hue: 0.5, saturation: 1, brightness: 1),
                                Color(hue: 0.6, saturation: 1, brightness: 1),
                                Color(hue: 0.7, saturation: 1, brightness: 1),
                                Color(hue: 0.8, saturation: 1, brightness: 1),
                                Color(hue: 0.9, saturation: 1, brightness: 1),
                                Color(hue: 1.0, saturation: 1, brightness: 1)
                            ]),
                            center: .center
                        )
                    )
                    .frame(width: size, height: size)
                    .overlay(
                        RadialGradient(
                            gradient: Gradient(colors: [.white, .clear]),
                            center: .center,
                            startRadius: 0,
                            endRadius: radius
                        )
                    )
                    .clipShape(Circle())

                // Selector
                Circle()
                    .fill(selectedColor)
                    .frame(width: 30, height: 30)
                    .overlay(Circle().stroke(Color.black, lineWidth: 3))
                    .overlay(Circle().stroke(Color.white, lineWidth: 2))
                    .position(selectorPosition == .zero ? center : selectorPosition)
                    .shadow(radius: 3)
            }
            .frame(width: size, height: size)
            .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        let location = value.location
                        let adjustedLocation = CGPoint(
                            x: location.x - (geometry.size.width - size) / 2,
                            y: location.y - (geometry.size.height - size) / 2
                        )
                        updateColor(at: adjustedLocation, center: center, radius: radius)
                    }
            )
            .onAppear {
                selectorPosition = center
            }
        }
    }

    private func updateColor(at point: CGPoint, center: CGPoint, radius: CGFloat) {
        let dx = point.x - center.x
        let dy = point.y - center.y
        let distance = sqrt(dx * dx + dy * dy)
        let maxDistance = radius

        // Clamp to circle
        var clampedPoint = point
        if distance > maxDistance {
            let angle = atan2(dy, dx)
            clampedPoint = CGPoint(
                x: center.x + maxDistance * cos(angle),
                y: center.y + maxDistance * sin(angle)
            )
        }

        selectorPosition = clampedPoint

        // Calculate color
        let clampedDx = clampedPoint.x - center.x
        let clampedDy = clampedPoint.y - center.y
        let clampedDistance = sqrt(clampedDx * clampedDx + clampedDy * clampedDy)

        var angle = atan2(clampedDy, clampedDx)
        if angle < 0 { angle += 2 * .pi }

        let hue = angle / (2 * .pi)
        let saturation = min(1.0, clampedDistance / maxDistance)

        let color = Color(hue: hue, saturation: saturation, brightness: 1.0)
        selectedColor = color
        onColorChanged?(color)
    }
}

#Preview {
    ColorWheelView(selectedColor: .constant(.red))
        .frame(width: 250, height: 250)
        .background(Color.black)
}
