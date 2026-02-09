import Foundation
import CoreBluetooth
import Combine

/// Connection state for a device
enum ConnectionState {
    case disconnected
    case connecting
    case connected
    case failed(String)
}

/// BLE Manager for single device connections
class BLEManager: NSObject, ObservableObject {

    // MARK: - Published Properties

    @Published var isBluetoothOn = false
    @Published var isScanning = false
    @Published var connectionState: ConnectionState = .disconnected
    @Published var discoveredPeripherals: [CBPeripheral] = []

    // MARK: - Protocol Properties

    /// Current device's protocol (auto-detected on connection)
    private(set) var currentProtocol: LEDProtocol = SP105EProtocolImpl()

    /// Current device's controller type
    private(set) var controllerType: ControllerType = .sp105e

    // MARK: - Private Properties

    private var centralManager: CBCentralManager!
    private var connectedPeripheral: CBPeripheral?
    private var writeCharacteristic: CBCharacteristic?
    private var lastCommandTime: Date = .distantPast
    private let commandThrottleMs: Double = 50  // Minimum ms between commands

    // Device name filters - includes BanlanX (SP63x/SP64x)
    private let deviceNameFilters = ["SP105E", "SP110E", "SP100", "SP63", "SP64", "LED", "Magic"]

    // MARK: - Initialization

    override init() {
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: nil)
    }

    // MARK: - Public Methods

    /// Start scanning for LED controllers
    func startScanning() {
        guard isBluetoothOn else {
            print("Bluetooth is not available")
            return
        }

        discoveredPeripherals.removeAll()
        isScanning = true
        centralManager.scanForPeripherals(withServices: nil, options: [
            CBCentralManagerScanOptionAllowDuplicatesKey: false
        ])

        // Auto-stop after 10 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 10) { [weak self] in
            self?.stopScanning()
        }
    }

    /// Connect to a known device by its UUID string
    func connectToDevice(address: String) {
        guard isBluetoothOn else {
            print("Bluetooth is not available")
            connectionState = .failed("Bluetooth is off")
            return
        }

        guard let uuid = UUID(uuidString: address) else {
            print("Invalid device address: \(address)")
            connectionState = .failed("Invalid device address")
            return
        }

        connectionState = .connecting

        // Try to retrieve the peripheral directly by its identifier
        let peripherals = centralManager.retrievePeripherals(withIdentifiers: [uuid])

        if let peripheral = peripherals.first {
            print("Found known peripheral: \(peripheral.name ?? "Unknown")")
            connect(to: peripheral)
        } else {
            // Peripheral not found in cache, need to scan for it
            print("Peripheral not in cache, scanning...")
            startScanningForDevice(address: address)
        }
    }

    /// Start scanning specifically to find and connect to a device
    private var targetDeviceAddress: String?

    private func startScanningForDevice(address: String) {
        guard isBluetoothOn else { return }

        targetDeviceAddress = address
        discoveredPeripherals.removeAll()
        isScanning = true
        centralManager.scanForPeripherals(withServices: nil, options: [
            CBCentralManagerScanOptionAllowDuplicatesKey: false
        ])

        // Timeout after 15 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 15) { [weak self] in
            guard let self = self else { return }
            if self.isScanning && self.connectionState == .connecting {
                self.stopScanning()
                self.connectionState = .failed("Device not found")
                self.targetDeviceAddress = nil
            }
        }
    }

    /// Stop scanning
    func stopScanning() {
        centralManager.stopScan()
        isScanning = false
    }

    /// Connect to a peripheral
    func connect(to peripheral: CBPeripheral) {
        stopScanning()
        connectionState = .connecting
        connectedPeripheral = peripheral
        peripheral.delegate = self
        centralManager.connect(peripheral, options: nil)
    }

    /// Disconnect from current peripheral
    func disconnect() {
        if let peripheral = connectedPeripheral {
            centralManager.cancelPeripheralConnection(peripheral)
        }
        cleanup()
    }

    /// Check if connected
    var isConnected: Bool {
        connectionState == .connected && writeCharacteristic != nil
    }

    /// Send a command to the connected device
    func sendCommand(_ data: Data) {
        guard let peripheral = connectedPeripheral,
              let characteristic = writeCharacteristic else {
            print("Not connected - cannot send command")
            return
        }

        // Throttle commands (50ms minimum between sends)
        let now = Date()
        let timeSinceLastCommand = now.timeIntervalSince(lastCommandTime) * 1000
        if timeSinceLastCommand < commandThrottleMs {
            let delay = (commandThrottleMs - timeSinceLastCommand) / 1000
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                self?.doSendCommand(peripheral: peripheral, characteristic: characteristic, data: data)
            }
        } else {
            doSendCommand(peripheral: peripheral, characteristic: characteristic, data: data)
        }
    }

    private func doSendCommand(peripheral: CBPeripheral, characteristic: CBCharacteristic, data: Data) {
        // Use correct write type based on protocol
        // SP105E uses .withResponse, BanlanX uses .withoutResponse
        let writeType: CBCharacteristicWriteType = currentProtocol.usesWriteWithoutResponse ? .withoutResponse : .withResponse

        // Log command for debugging
        let hexString = data.map { String(format: "%02X", $0) }.joined(separator: " ")
        print("[LED_CMD] Sending (\(currentProtocol.name), type=\(controllerType.rawValue)): \(hexString)")

        peripheral.writeValue(data, for: characteristic, type: writeType)
        lastCommandTime = Date()
    }

    /// Set the protocol for the current device
    func setProtocol(for device: DeviceItem) {
        self.controllerType = device.controllerType
        self.currentProtocol = device.ledProtocol
        print("[BLEManager] Protocol set to \(currentProtocol.name) for \(device.displayName)")
    }

    // MARK: - Convenience Command Methods

    func setColor(red: Int, green: Int, blue: Int) {
        sendCommand(currentProtocol.setColor(red: UInt8(red), green: UInt8(green), blue: UInt8(blue)))
    }

    func setMode(_ mode: Int) {
        if let data = currentProtocol.setMode(mode) {
            sendCommand(data)
        } else {
            print("[BLEManager] Mode not supported by \(currentProtocol.name)")
        }
    }

    func increaseBrightness() {
        if let data = currentProtocol.brightnessUp() {
            sendCommand(data)
        } else {
            print("[BLEManager] Brightness up not supported by \(currentProtocol.name)")
        }
    }

    func decreaseBrightness() {
        if let data = currentProtocol.brightnessDown() {
            sendCommand(data)
        } else {
            print("[BLEManager] Brightness down not supported by \(currentProtocol.name)")
        }
    }

    /// Set brightness using absolute value (0-255) - for BanlanX
    func setBrightnessAbsolute(_ brightness: Int) {
        if let banlanx = currentProtocol as? BanlanXProtocol {
            sendCommand(banlanx.setBrightnessAbsolute(brightness))
        } else {
            // For SP105E, use step-based brightness
            print("[BLEManager] Absolute brightness not supported by \(currentProtocol.name)")
        }
    }

    func increaseSpeed() {
        if let data = currentProtocol.speedUp() {
            sendCommand(data)
        } else {
            print("[BLEManager] Speed up not supported by \(currentProtocol.name)")
        }
    }

    func decreaseSpeed() {
        if let data = currentProtocol.speedDown() {
            sendCommand(data)
        } else {
            print("[BLEManager] Speed down not supported by \(currentProtocol.name)")
        }
    }

    func togglePower() {
        sendCommand(currentProtocol.powerToggle())
    }

    func powerOn() {
        sendCommand(currentProtocol.powerOn())
    }

    func powerOff() {
        sendCommand(currentProtocol.powerOff())
    }

    // MARK: - Private Helpers

    private func cleanup() {
        connectedPeripheral = nil
        writeCharacteristic = nil
        connectionState = .disconnected
        // Reset to default protocol
        controllerType = .sp105e
        currentProtocol = SP105EProtocolImpl()
    }

    private func isLEDController(name: String?) -> Bool {
        return LEDProtocolFactory.isSupported(deviceName: name)
    }
}

// MARK: - CBCentralManagerDelegate

extension BLEManager: CBCentralManagerDelegate {

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        isBluetoothOn = central.state == .poweredOn

        if central.state != .poweredOn {
            cleanup()
        }

        switch central.state {
        case .poweredOn:
            print("Bluetooth is powered on")
        case .poweredOff:
            print("Bluetooth is powered off")
        case .unauthorized:
            print("Bluetooth is unauthorized")
        case .unsupported:
            print("Bluetooth is unsupported")
        default:
            print("Bluetooth state: \(central.state.rawValue)")
        }
    }

    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral,
                        advertisementData: [String: Any], rssi RSSI: NSNumber) {
        // Filter for LED controllers
        guard isLEDController(name: peripheral.name) else { return }

        // Avoid duplicates
        if !discoveredPeripherals.contains(where: { $0.identifier == peripheral.identifier }) {
            print("Discovered: \(peripheral.name ?? "Unknown") - \(peripheral.identifier)")
            discoveredPeripherals.append(peripheral)

            // If we're looking for a specific device, connect to it
            if let targetAddress = targetDeviceAddress,
               peripheral.identifier.uuidString == targetAddress {
                print("Found target device, connecting...")
                targetDeviceAddress = nil
                connect(to: peripheral)
            }
        }
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        print("Connected to \(peripheral.name ?? "Unknown")")
        // Auto-detect controller type from device name
        controllerType = LEDProtocolFactory.detectControllerType(deviceName: peripheral.name)
        currentProtocol = LEDProtocolFactory.protocolFor(type: controllerType)
        print("[BLEManager] Using protocol: \(currentProtocol.name)")
        peripheral.discoverServices([LEDProtocolFactory.serviceUUID])
    }

    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        print("Failed to connect: \(error?.localizedDescription ?? "Unknown error")")
        connectionState = .failed(error?.localizedDescription ?? "Connection failed")
    }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        print("Disconnected from \(peripheral.name ?? "Unknown")")
        cleanup()
    }
}

// MARK: - CBPeripheralDelegate

extension BLEManager: CBPeripheralDelegate {

    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        if let error = error {
            print("Error discovering services: \(error)")
            connectionState = .failed("Service discovery failed")
            return
        }

        guard let service = peripheral.services?.first(where: { $0.uuid == LEDProtocolFactory.serviceUUID }) else {
            print("LED service not found")
            connectionState = .failed("LED service not found")
            return
        }

        peripheral.discoverCharacteristics([LEDProtocolFactory.characteristicUUID], for: service)
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        if let error = error {
            print("Error discovering characteristics: \(error)")
            connectionState = .failed("Characteristic discovery failed")
            return
        }

        guard let characteristic = service.characteristics?.first(where: { $0.uuid == LEDProtocolFactory.characteristicUUID }) else {
            print("LED characteristic not found")
            connectionState = .failed("LED characteristic not found")
            return
        }

        writeCharacteristic = characteristic
        connectionState = .connected
        print("Ready to send commands with \(currentProtocol.name) protocol!")
    }

    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        if let error = error {
            print("Write error: \(error.localizedDescription)")
        }
    }
}
