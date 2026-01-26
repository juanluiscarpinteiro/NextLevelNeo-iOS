import Foundation
import CoreBluetooth

/// SP105E LED Controller Protocol
/// All commands follow format: [0x38, param1, param2, param3, footer]
struct SP105EProtocol {

    // MARK: - Service & Characteristic UUIDs

    static let serviceUUID = CBUUID(string: "FFE0")
    static let characteristicUUID = CBUUID(string: "FFE1")

    // MARK: - Color Commands

    /// Set static color (RGB)
    /// Format: 0x38 RR GG BB 0x1E
    static func setColor(red: UInt8, green: UInt8, blue: UInt8) -> Data {
        return Data([0x38, red, green, blue, 0x1E])
    }

    /// Set static color from tuple
    static func setColor(_ color: (red: Int, green: Int, blue: Int)) -> Data {
        return setColor(red: UInt8(color.red), green: UInt8(color.green), blue: UInt8(color.blue))
    }

    // MARK: - Mode Commands

    /// Set effect mode (1-180+)
    /// Format: 0x38 MODE 0x00 0x00 0x2C 0x83
    static func setMode(_ mode: Int) -> Data {
        return Data([0x38, UInt8(mode), 0x00, 0x00, 0x2C, 0x83])
    }

    // MARK: - Brightness Commands

    /// Increase brightness
    static let brightnessUp = Data([0x38, 0x00, 0x00, 0x00, 0x2A, 0x83])

    /// Decrease brightness
    static let brightnessDown = Data([0x38, 0x00, 0x00, 0x00, 0x28, 0x83])

    // MARK: - Speed Commands

    /// Increase effect speed
    static let speedUp = Data([0x38, 0x00, 0x00, 0x00, 0x03, 0x83])

    /// Decrease effect speed
    static let speedDown = Data([0x38, 0x00, 0x00, 0x00, 0x09, 0x83])

    // MARK: - Power Commands

    /// Toggle power on/off
    static let togglePower = Data([0x38, 0x00, 0x00, 0x00, 0xAA, 0x83])

    // MARK: - Strip Type Configuration

    /// Set strip type to RGB
    static let setRGBMode = Data([0x38, 0x02, 0xE2, 0x94, 0x1C])

    /// Set strip type to RGBW
    static let setRGBWMode = Data([0x38, 0x06, 0x1C, 0x7F, 0x1C])

    // MARK: - LED Modes List

    static let modeNames: [String] = [
        "Static Color",           // 0 - Special: solid color mode
        "Meteor",                 // 1
        "Breathing",              // 2
        "Wave",                   // 3
        "Catch Up",               // 4
        "Static",                 // 5
        "Stack",                  // 6
        "Flash",                  // 7
        "Colorful Flash",         // 8
        "Flow",                   // 9
        "Colorful Meteor",        // 10
        "Colorful Breathing",     // 11
        "Colorful Wave",          // 12
        "Colorful Catch Up",      // 13
        "RGB Static",             // 14
        "Colorful Stack",         // 15
        "Colorful Flash 2",       // 16
        "Colorful Flash 3",       // 17
        "Colorful Flow",          // 18
        // Add more modes as needed (SP105E supports 180+)
        "Mode 19", "Mode 20", "Mode 21", "Mode 22", "Mode 23", "Mode 24",
        "Mode 25", "Mode 26", "Mode 27", "Mode 28", "Mode 29", "Mode 30",
        "Mode 31", "Mode 32", "Mode 33", "Mode 34", "Mode 35", "Mode 36",
        "Mode 37", "Mode 38", "Mode 39", "Mode 40", "Mode 41", "Mode 42",
        "Mode 43", "Mode 44", "Mode 45", "Mode 46", "Mode 47", "Mode 48",
        "Mode 49", "Mode 50"
        // ... extend as needed
    ]

    // MARK: - Quick Colors

    static let quickColors: [(name: String, red: UInt8, green: UInt8, blue: UInt8)] = [
        ("Red", 255, 0, 0),
        ("Green", 0, 255, 0),
        ("Blue", 0, 0, 255),
        ("White", 255, 255, 255),
        ("Yellow", 255, 255, 0),
        ("Cyan", 0, 255, 255),
        ("Magenta", 255, 0, 255),
        ("Orange", 255, 128, 0),
        ("Purple", 128, 0, 255),
        ("Warm White", 255, 228, 181)
    ]
}
