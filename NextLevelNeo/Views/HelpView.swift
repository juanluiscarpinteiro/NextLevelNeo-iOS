import SwiftUI

struct HelpView: View {
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    helpSection(title: "QUICK COLORS", content: """
                        Tap any of the preset color buttons to instantly change the LED strip color.
                        """)

                    helpSection(title: "COLOR WHEEL", content: """
                        Touch and drag on the color wheel to select any color. The center is white, and colors get more saturated towards the edge.
                        """)

                    helpSection(title: "EFFECT MODES", content: """
                        Use the mode selector to choose from various lighting effects. Use the arrow buttons to quickly cycle through modes.

                        Static Color (Mode 0) is automatically selected when you pick a color from the wheel.
                        """)

                    helpSection(title: "BRIGHTNESS & SPEED", content: """
                        Use the sliders or +/- buttons to adjust brightness and effect speed.

                        Note: The SP105E uses relative commands (up/down), so the slider position is approximate.
                        """)

                    helpSection(title: "POWER", content: """
                        Tap the power icon in the top right to toggle the LED strip on/off.
                        """)

                    helpSection(title: "STRIP TYPE (RGB/RGBW)", content: """
                        Access Settings (gear icon) to change the strip type. Only change this if your LED strip requires a different mode.

                        ⚠️ Incorrect strip type settings may cause wrong colors or no output.
                        """)

                    helpSection(title: "TROUBLESHOOTING", content: """
                        • Connection fails: Make sure Bluetooth is enabled and the device is in range
                        • Wrong colors: Check the strip type setting
                        • No response: Try toggling power or reconnecting
                        • Device not found: Ensure the controller is powered on
                        """)
                }
                .padding()
            }
            .background(Color.black)
            .navigationTitle("Help")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func helpSection(title: String, content: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
                .foregroundColor(.orange)

            Text(content)
                .foregroundColor(.white)
        }
    }
}

#Preview {
    HelpView()
}
