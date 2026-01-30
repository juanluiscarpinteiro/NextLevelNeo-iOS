import Foundation
import CoreBluetooth

/// Controller type constants
enum ControllerType: Int, Codable {
    case sp105e = 0    // SP105E, SP110E, SP100 series
    case banlanX = 1   // SP63x series (SP630E-SP639E, SP640E-SP64AE)
}

/// Protocol interface for LED controllers
/// Different controllers (SP105E, BanlanX/SP63x) use different command formats
protocol LEDProtocol {
    /// Protocol name for logging
    var name: String { get }

    /// Whether this protocol uses write without response
    var usesWriteWithoutResponse: Bool { get }

    /// Power on command
    func powerOn() -> Data

    /// Power off command
    func powerOff() -> Data

    /// Toggle power command
    func powerToggle() -> Data

    /// Set color command
    func setColor(red: UInt8, green: UInt8, blue: UInt8) -> Data

    /// Brightness up command (returns nil if not supported)
    func brightnessUp() -> Data?

    /// Brightness down command (returns nil if not supported)
    func brightnessDown() -> Data?

    /// Speed up command (returns nil if not supported)
    func speedUp() -> Data?

    /// Speed down command (returns nil if not supported)
    func speedDown() -> Data?

    /// Set mode command (returns nil if not supported)
    func setMode(_ mode: Int) -> Data?

    /// Set RGB strip mode (returns nil if not supported)
    func setRGBMode() -> Data?

    /// Set RGBW strip mode (returns nil if not supported)
    func setRGBWMode() -> Data?
}

/// Protocol detection and factory
struct LEDProtocolFactory {

    /// BLE Service UUID (same for all supported controllers)
    static let serviceUUID = CBUUID(string: "FFE0")

    /// BLE Characteristic UUID (same for all supported controllers)
    static let characteristicUUID = CBUUID(string: "FFE1")

    /// Detect controller type based on device name
    static func detectControllerType(deviceName: String?) -> ControllerType {
        guard let name = deviceName?.uppercased() else {
            return .sp105e
        }

        // BanlanX/SP63x series detection
        if name.contains("SP63") || name.contains("SP64") {
            print("[LEDProtocol] Detected BanlanX device: \(deviceName ?? "")")
            return .banlanX
        }

        print("[LEDProtocol] Detected SP105E device: \(deviceName ?? "")")
        return .sp105e
    }

    /// Get protocol instance for controller type
    static func protocolFor(type: ControllerType) -> LEDProtocol {
        switch type {
        case .banlanX:
            return BanlanXProtocol()
        case .sp105e:
            return SP105EProtocolImpl()
        }
    }

    /// Check if device name matches supported controllers
    static func isSupported(deviceName: String?) -> Bool {
        guard let name = deviceName?.uppercased() else { return false }

        let supportedPrefixes = ["SP105", "SP110", "SP100", "SP63", "SP64", "LED", "MAGIC"]
        return supportedPrefixes.contains { name.contains($0) }
    }
}
