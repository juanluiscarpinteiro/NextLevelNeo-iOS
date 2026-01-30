import Foundation

struct DeviceItem: Identifiable, Codable, Hashable {
    var id: String { address }  // MAC address as identifier

    let address: String         // Bluetooth identifier (UUID on iOS)
    var deviceName: String      // Original device name from scanner
    var customName: String?     // User-customizable name

    // Controller type (auto-detected from device name)
    var controllerType: ControllerType = .sp105e

    // Last known state
    var lastBrightness: Int = 128
    var lastMode: Int = 1
    var lastSpeed: Int = 128
    var lastRed: Int = 255
    var lastGreen: Int = 255
    var lastBlue: Int = 255
    var colorOrder: Int = 0     // 0 = RGB, 1 = RGBW

    // Favorite colors (packed as Int, -1 = empty)
    var favoriteColors: [Int] = Array(repeating: -1, count: 6)
    var favoriteColorNames: [String?] = Array(repeating: nil, count: 6)

    // Favorite modes (-1 = empty)
    var favoriteModes: [Int] = Array(repeating: -1, count: 6)
    var favoriteModeNames: [String?] = Array(repeating: nil, count: 6)

    var displayName: String {
        customName ?? deviceName
    }

    var lastColor: (red: Int, green: Int, blue: Int) {
        (lastRed, lastGreen, lastBlue)
    }

    /// Get the appropriate protocol for this device
    var ledProtocol: LEDProtocol {
        LEDProtocolFactory.protocolFor(type: controllerType)
    }

    /// Check if this device supports effect modes
    var supportsEffectModes: Bool {
        controllerType == .sp105e
    }

    /// Check if this device supports speed control
    var supportsSpeedControl: Bool {
        controllerType == .sp105e
    }

    init(address: String, deviceName: String, customName: String? = nil) {
        self.address = address
        self.deviceName = deviceName
        self.customName = customName
        // Auto-detect controller type from device name
        self.controllerType = LEDProtocolFactory.detectControllerType(deviceName: deviceName)
    }

    // Helper to pack RGB into single Int
    static func packColor(red: Int, green: Int, blue: Int) -> Int {
        return (red << 16) | (green << 8) | blue
    }

    // Helper to unpack color
    static func unpackColor(_ packed: Int) -> (red: Int, green: Int, blue: Int) {
        let red = (packed >> 16) & 0xFF
        let green = (packed >> 8) & 0xFF
        let blue = packed & 0xFF
        return (red, green, blue)
    }
}
