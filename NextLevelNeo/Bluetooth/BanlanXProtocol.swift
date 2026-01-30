import Foundation

/// BanlanX LED Controller Protocol Implementation
/// Used by SP63x series (SP630E-SP639E) PWM RGB/RGBW controllers
///
/// Protocol captured from BanlanX app via HCI snoop log
///
/// Frame format: 53 [CMD] [CHECKSUM] 01 00 [LEN] [DATA...]
/// - CMD 0x50 = Power
/// - CMD 0x51 = Brightness
/// - CMD 0x52 = Color
struct BanlanXProtocol: LEDProtocol {

    var name: String { "BanlanX" }

    /// BanlanX uses write without response
    var usesWriteWithoutResponse: Bool { true }

    // MARK: - Power Commands

    func powerOn() -> Data {
        // Captured: 53 50 5E 01 00 01 12
        print("[BANLANX] powerOn: 53 50 5E 01 00 01 12")
        return Data([0x53, 0x50, 0x5E, 0x01, 0x00, 0x01, 0x12])
    }

    func powerOff() -> Data {
        // Captured: 53 50 F4 01 00 01 B9
        print("[BANLANX] powerOff: 53 50 F4 01 00 01 B9")
        return Data([0x53, 0x50, 0xF4, 0x01, 0x00, 0x01, 0xB9])
    }

    func powerToggle() -> Data {
        // No toggle command, return power on
        return powerOn()
    }

    // MARK: - Color Commands

    func setColor(red: UInt8, green: UInt8, blue: UInt8) -> Data {
        print("[BANLANX] setColor called: R=\(red) G=\(green) B=\(blue)")

        let r = Int(red)
        let g = Int(green)
        let b = Int(blue)

        // PRIMARY COLORS
        // Pure RED
        if r >= 200 && g <= 50 && b <= 50 {
            print("[BANLANX] Using RED command")
            return BanlanXProtocol.colorRed
        }
        // Pure GREEN
        if r <= 50 && g >= 200 && b <= 50 {
            print("[BANLANX] Using GREEN command")
            return BanlanXProtocol.colorGreen
        }
        // Pure BLUE
        if r <= 50 && g <= 50 && b >= 200 {
            print("[BANLANX] Using BLUE command")
            return BanlanXProtocol.colorBlue
        }

        // SECONDARY COLORS
        // YELLOW (R+G)
        if r >= 200 && g >= 200 && b <= 50 {
            print("[BANLANX] Using YELLOW command")
            return BanlanXProtocol.colorYellow
        }
        // CYAN (G+B)
        if r <= 50 && g >= 200 && b >= 200 {
            print("[BANLANX] Using CYAN command")
            return BanlanXProtocol.colorCyan
        }
        // MAGENTA (R+B)
        if r >= 200 && g <= 50 && b >= 200 {
            print("[BANLANX] Using MAGENTA command")
            return BanlanXProtocol.colorMagenta
        }

        // WHITE (all channels high)
        if r >= 200 && g >= 200 && b >= 200 {
            print("[BANLANX] Using WHITE command")
            return BanlanXProtocol.colorWhite
        }

        // ORANGE (R high, G medium, B low)
        if r >= 200 && g >= 80 && g <= 180 && b <= 50 {
            print("[BANLANX] Using ORANGE command")
            return BanlanXProtocol.colorOrange
        }

        // PURPLE (R medium, G low, B high)
        if r >= 100 && r <= 180 && g <= 50 && b >= 200 {
            print("[BANLANX] Using PURPLE command")
            return BanlanXProtocol.colorPurple
        }

        // Find closest color match
        print("[BANLANX] Finding closest color match")

        let max = Swift.max(r, Swift.max(g, b))
        let min = Swift.min(r, Swift.min(g, b))

        // Balanced colors -> white
        if max - min < 60 && max > 150 {
            print("[BANLANX] Balanced color -> using WHITE")
            return BanlanXProtocol.colorWhite
        }

        // Check secondary color patterns
        if r > 150 && g > 150 && b < 100 {
            return BanlanXProtocol.colorYellow
        }
        if r < 100 && g > 150 && b > 150 {
            return BanlanXProtocol.colorCyan
        }
        if r > 150 && g < 100 && b > 150 {
            return BanlanXProtocol.colorMagenta
        }
        if r > 180 && g > 50 && g < 150 && b < 80 {
            return BanlanXProtocol.colorOrange
        }
        if r > 80 && r < 180 && g < 80 && b > 180 {
            return BanlanXProtocol.colorPurple
        }

        // Use dominant primary
        if r >= g && r >= b {
            print("[BANLANX] Falling back to RED (dominant)")
            return BanlanXProtocol.colorRed
        } else if g >= r && g >= b {
            print("[BANLANX] Falling back to GREEN (dominant)")
            return BanlanXProtocol.colorGreen
        } else {
            print("[BANLANX] Falling back to BLUE (dominant)")
            return BanlanXProtocol.colorBlue
        }
    }

    // MARK: - Brightness Commands

    /// Captured brightness levels from BanlanX app (sorted dim to bright)
    /// Format: 53 51 [checksum] 01 00 02 [byte1] [byte2]
    private static let brightnessLevels: [Data] = [
        Data([0x53, 0x51, 0x7b, 0x01, 0x00, 0x02, 0x36, 0x30]),        // Level 0 (dimmest) ~0%
        Data([0x53, 0x51, 0xb4, 0x01, 0x00, 0x02, 0xf9, 0xe3]),        // Level 1 ~11%
        Data([0x53, 0x51, 0x3b, 0x01, 0x00, 0x02, 0x76, 0x4c]),        // Level 2 ~22%
        Data([0x53, 0x51, 0x46, 0x01, 0x00, 0x02, 0x0b, 0x65]),        // Level 3 ~33%
        Data([0x53, 0x51, 0xb4, 0x01, 0x00, 0x02, 0xf9, 0x7c]),        // Level 4 ~44%
        Data([0x53, 0x51, 0xa0, 0x01, 0x00, 0x02, 0xed, 0x73]),        // Level 5 ~55%
        Data([0x53, 0x51, 0xdb, 0x01, 0x00, 0x02, 0x96, 0x29]),        // Level 6 ~66%
        Data([0x53, 0x51, 0xcd, 0x01, 0x00, 0x02, 0x80, 0x55]),        // Level 7 ~77%
        Data([0x53, 0x51, 0xba, 0x01, 0x00, 0x02, 0xf7, 0x19]),        // Level 8 ~88%
        Data([0x53, 0x51, 0x1e, 0x01, 0x00, 0x02, 0x53, 0xa8]),        // Level 9 (brightest) ~100%
    ]

    /// Set brightness using absolute value (0-255)
    /// Maps to one of the 10 captured brightness levels
    func setBrightnessAbsolute(_ brightness: Int) -> Data {
        let level = (brightness * (BanlanXProtocol.brightnessLevels.count - 1)) / 255
        let clampedLevel = Swift.max(0, Swift.min(level, BanlanXProtocol.brightnessLevels.count - 1))
        print("[BANLANX] setBrightnessAbsolute: \(brightness) -> level \(clampedLevel)")
        return BanlanXProtocol.brightnessLevels[clampedLevel]
    }

    /// BanlanX doesn't use step-based brightness
    func brightnessUp() -> Data? {
        print("[BANLANX] brightnessUp - use setBrightnessAbsolute instead")
        return nil
    }

    func brightnessDown() -> Data? {
        print("[BANLANX] brightnessDown - use setBrightnessAbsolute instead")
        return nil
    }

    // MARK: - Speed Commands (Not supported)

    func speedUp() -> Data? {
        print("[BANLANX] speedUp - not applicable for non-addressable LEDs")
        return nil
    }

    func speedDown() -> Data? {
        print("[BANLANX] speedDown - not applicable for non-addressable LEDs")
        return nil
    }

    // MARK: - Mode Commands (Not supported)

    func setMode(_ mode: Int) -> Data? {
        print("[BANLANX] setMode - not applicable for non-addressable LEDs")
        return nil
    }

    func setRGBMode() -> Data? {
        print("[BANLANX] setRGBMode not applicable for BanlanX")
        return nil
    }

    func setRGBWMode() -> Data? {
        print("[BANLANX] setRGBWMode not applicable for BanlanX")
        return nil
    }

    // MARK: - Static Color Presets (captured from BanlanX app)

    static let colorRed = Data([0x53, 0x52, 0xF6, 0x01, 0x00, 0x04, 0x44, 0xBB, 0xBB, 0x44])
    static let colorGreen = Data([0x53, 0x52, 0x37, 0x01, 0x00, 0x04, 0x7A, 0x85, 0x7A, 0x85])
    static let colorBlue = Data([0x53, 0x52, 0x83, 0x01, 0x00, 0x04, 0xCE, 0xCE, 0x31, 0x31])
    static let colorWhite = Data([0x53, 0x52, 0xB0, 0x01, 0x00, 0x04, 0x02, 0x02, 0x02, 0x02])
    static let colorYellow = Data([0x53, 0x52, 0xD1, 0x01, 0x00, 0x04, 0x63, 0x63, 0x9C, 0x63])
    static let colorCyan = Data([0x53, 0x52, 0xD0, 0x01, 0x00, 0x04, 0x9D, 0x62, 0x62, 0x62])
    static let colorMagenta = Data([0x53, 0x52, 0xFE, 0x01, 0x00, 0x04, 0x4C, 0xB3, 0x4C, 0x4C])
    static let colorOrange = Data([0x53, 0x52, 0xE7, 0x01, 0x00, 0x04, 0x55, 0x0C, 0xAE, 0x55])
    static let colorPurple = Data([0x53, 0x52, 0x96, 0x01, 0x00, 0x04, 0x24, 0x24, 0x24, 0x24])

    // MARK: - Quick Colors for UI

    static let quickColors: [(name: String, red: UInt8, green: UInt8, blue: UInt8)] = [
        ("Red", 255, 0, 0),
        ("Green", 0, 255, 0),
        ("Blue", 0, 0, 255),
        ("White", 255, 255, 255),
        ("Yellow", 255, 255, 0),
        ("Cyan", 0, 255, 255),
        ("Magenta", 255, 0, 255),
        ("Orange", 255, 128, 0),
        ("Purple", 128, 0, 255)
    ]
}
