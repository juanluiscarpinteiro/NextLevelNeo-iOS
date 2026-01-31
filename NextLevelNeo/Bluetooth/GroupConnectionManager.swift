import Foundation
import CoreBluetooth
import Combine

/// Manages multiple simultaneous BLE connections for group control
class GroupConnectionManager: NSObject, ObservableObject {

    // MARK: - Published Properties

    @Published var isBluetoothOn = false
    @Published var connectionStates: [String: ConnectionState] = [:]  // peripheral.identifier.uuidString -> state
    @Published var connectedCount = 0
    @Published var totalCount = 0

    // MARK: - Private Properties

    private var centralManager: CBCentralManager!
    private var peripherals: [String: CBPeripheral] = [:]        // identifier -> peripheral
    private var characteristics: [String: CBCharacteristic] = [:] // identifier -> write characteristic
    private var deviceProtocols: [String: LEDProtocol] = [:]     // identifier -> protocol
    private var deviceTypes: [String: ControllerType] = [:]      // identifier -> controller type
    private var pendingConnections: [CBPeripheral] = []
    private var connectionDelayMs: Double = 300  // Delay between connection attempts (increased for reliability)
    private var commandDelayMs: Double = 150     // Delay between sending to each device (increased for reliability)

    // MARK: - Initialization

    override init() {
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: nil)
    }

    // MARK: - Public Methods

    /// Connect to all devices in a group
    func connectAll(devices: [DeviceItem], knownPeripherals: [CBPeripheral]) {
        disconnectAll()

        totalCount = devices.count
        connectedCount = 0

        // Initialize connection states and protocols
        for device in devices {
            connectionStates[device.address] = .disconnected
            // Re-detect controller type (in case device was saved with wrong type)
            let detectedType = LEDProtocolFactory.detectControllerType(deviceName: device.deviceName)
            deviceTypes[device.address] = detectedType
            deviceProtocols[device.address] = LEDProtocolFactory.protocolFor(type: detectedType)
            print("[GroupManager] Device \(device.displayName) using \(deviceProtocols[device.address]?.name ?? "unknown") protocol")
        }

        // Find matching peripherals and queue for connection
        for device in devices {
            if let peripheral = knownPeripherals.first(where: { $0.identifier.uuidString == device.address }) {
                pendingConnections.append(peripheral)
                peripherals[device.address] = peripheral
            }
        }

        // Start connecting sequentially
        connectNextDevice()
    }

    /// Disconnect from all devices
    func disconnectAll() {
        pendingConnections.removeAll()

        for (_, peripheral) in peripherals {
            centralManager.cancelPeripheralConnection(peripheral)
        }

        peripherals.removeAll()
        characteristics.removeAll()
        connectionStates.removeAll()
        deviceProtocols.removeAll()
        deviceTypes.removeAll()
        connectedCount = 0
        totalCount = 0
    }

    /// Check if any device is connected
    var isAnyConnected: Bool {
        connectedCount > 0
    }

    /// Send command to all connected devices (protocol-specific)
    /// Uses commandGenerator to create appropriate command for each device's protocol
    func sendProtocolCommandToAll(_ commandGenerator: (LEDProtocol) -> Data?) {
        var delay: Double = 0

        for (identifier, characteristic) in characteristics {
            guard let peripheral = peripherals[identifier],
                  let deviceProtocol = deviceProtocols[identifier],
                  connectionStates[identifier] == .connected else { continue }

            let deviceType = deviceTypes[identifier] ?? .sp105e
            let writeType: CBCharacteristicWriteType = deviceProtocol.usesWriteWithoutResponse ? .withoutResponse : .withResponse

            // Generate command for this device's protocol
            guard let command = commandGenerator(deviceProtocol) else {
                print("[GroupManager] Command not supported by \(deviceProtocol.name)")
                continue
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + delay / 1000) {
                let hexString = command.map { String(format: "%02X", $0) }.joined(separator: " ")
                print("[GroupManager] Sending to \(peripheral.name ?? "Unknown") (\(deviceProtocol.name)): \(hexString)")
                peripheral.writeValue(command, for: characteristic, type: writeType)
            }
            delay += commandDelayMs
        }
    }

    /// Send same raw command to all devices (legacy, for backward compatibility)
    func sendCommandToAll(_ data: Data) {
        var delay: Double = 0

        for (identifier, characteristic) in characteristics {
            guard let peripheral = peripherals[identifier],
                  connectionStates[identifier] == .connected else { continue }

            let deviceProtocol = deviceProtocols[identifier]
            let writeType: CBCharacteristicWriteType = (deviceProtocol?.usesWriteWithoutResponse ?? false) ? .withoutResponse : .withResponse

            DispatchQueue.main.asyncAfter(deadline: .now() + delay / 1000) {
                peripheral.writeValue(data, for: characteristic, type: writeType)
            }
            delay += commandDelayMs
        }
    }

    // MARK: - Convenience Command Methods (Protocol-aware)

    func setColor(red: Int, green: Int, blue: Int) {
        sendProtocolCommandToAll { protocol in
            protocol.setColor(red: UInt8(red), green: UInt8(green), blue: UInt8(blue))
        }
    }

    func setMode(_ mode: Int) {
        sendProtocolCommandToAll { protocol in
            protocol.setMode(mode)
        }
    }

    func increaseBrightness() {
        sendProtocolCommandToAll { protocol in
            protocol.brightnessUp()
        }
    }

    func decreaseBrightness() {
        sendProtocolCommandToAll { protocol in
            protocol.brightnessDown()
        }
    }

    /// Set absolute brightness for all devices (BanlanX uses absolute, SP105E uses step-based)
    func setBrightnessAbsolute(_ brightness: Int, lastBrightness: Int) {
        sendProtocolCommandToAll { protocol in
            if let banlanx = protocol as? BanlanXProtocol {
                return banlanx.setBrightnessAbsolute(brightness)
            } else {
                // SP105E uses step-based
                if brightness > lastBrightness {
                    return protocol.brightnessUp()
                } else if brightness < lastBrightness {
                    return protocol.brightnessDown()
                }
                return nil
            }
        }
    }

    func increaseSpeed() {
        sendProtocolCommandToAll { protocol in
            protocol.speedUp()
        }
    }

    func decreaseSpeed() {
        sendProtocolCommandToAll { protocol in
            protocol.speedDown()
        }
    }

    func togglePower() {
        sendProtocolCommandToAll { protocol in
            protocol.powerToggle()
        }
    }

    func powerOn() {
        sendProtocolCommandToAll { protocol in
            protocol.powerOn()
        }
    }

    func powerOff() {
        sendProtocolCommandToAll { protocol in
            protocol.powerOff()
        }
    }

    // MARK: - Selected Device Commands

    /// Send command to only selected devices (for separate controller sections)
    func sendCommandToSelected(_ selectedAddresses: Set<String>, commandGenerator: (LEDProtocol) -> Data?) {
        var delay: Double = 0

        for (identifier, characteristic) in characteristics {
            // Skip if not selected
            guard selectedAddresses.contains(identifier) else { continue }

            guard let peripheral = peripherals[identifier],
                  let deviceProtocol = deviceProtocols[identifier],
                  connectionStates[identifier] == .connected else { continue }

            let writeType: CBCharacteristicWriteType = deviceProtocol.usesWriteWithoutResponse ? .withoutResponse : .withResponse

            // Generate command for this device's protocol
            guard let command = commandGenerator(deviceProtocol) else {
                continue
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + delay / 1000) {
                let hexString = command.map { String(format: "%02X", $0) }.joined(separator: " ")
                print("[GroupManager] Sending to selected \(peripheral.name ?? "Unknown"): \(hexString)")
                peripheral.writeValue(command, for: characteristic, type: writeType)
            }
            delay += commandDelayMs
        }
    }

    /// Set color to selected devices only
    func setColorToSelected(_ selectedAddresses: Set<String>, red: Int, green: Int, blue: Int) {
        sendCommandToSelected(selectedAddresses) { protocol in
            protocol.setColor(red: UInt8(red), green: UInt8(green), blue: UInt8(blue))
        }
    }

    /// Set mode to selected devices only
    func setModeToSelected(_ selectedAddresses: Set<String>, mode: Int) {
        sendCommandToSelected(selectedAddresses) { protocol in
            protocol.setMode(mode)
        }
    }

    /// Set brightness to selected devices only (handles both BanlanX absolute and SP105E step-based)
    func setBrightnessToSelected(_ selectedAddresses: Set<String>, brightness: Int, lastBrightness: Int) {
        sendCommandToSelected(selectedAddresses) { protocol in
            if let banlanx = protocol as? BanlanXProtocol {
                return banlanx.setBrightnessAbsolute(brightness)
            } else {
                // SP105E uses step-based
                if brightness > lastBrightness {
                    return protocol.brightnessUp()
                } else if brightness < lastBrightness {
                    return protocol.brightnessDown()
                }
                return nil
            }
        }
    }

    /// Increase brightness for selected devices only
    func increaseBrightnessToSelected(_ selectedAddresses: Set<String>) {
        sendCommandToSelected(selectedAddresses) { protocol in
            protocol.brightnessUp()
        }
    }

    /// Decrease brightness for selected devices only
    func decreaseBrightnessToSelected(_ selectedAddresses: Set<String>) {
        sendCommandToSelected(selectedAddresses) { protocol in
            protocol.brightnessDown()
        }
    }

    /// Increase speed for selected devices only
    func increaseSpeedToSelected(_ selectedAddresses: Set<String>) {
        sendCommandToSelected(selectedAddresses) { protocol in
            protocol.speedUp()
        }
    }

    /// Decrease speed for selected devices only
    func decreaseSpeedToSelected(_ selectedAddresses: Set<String>) {
        sendCommandToSelected(selectedAddresses) { protocol in
            protocol.speedDown()
        }
    }

    /// Toggle power for selected devices only
    func togglePowerToSelected(_ selectedAddresses: Set<String>) {
        sendCommandToSelected(selectedAddresses) { protocol in
            protocol.powerToggle()
        }
    }

    // MARK: - Device Type Helpers

    /// Get all connected BanlanX device addresses
    func getConnectedBanlanXAddresses() -> Set<String> {
        var addresses = Set<String>()
        for (identifier, _) in characteristics {
            if connectionStates[identifier] == .connected,
               deviceTypes[identifier] == .banlanX {
                addresses.insert(identifier)
            }
        }
        return addresses
    }

    /// Get all connected SP105E device addresses
    func getConnectedSP105EAddresses() -> Set<String> {
        var addresses = Set<String>()
        for (identifier, _) in characteristics {
            if connectionStates[identifier] == .connected,
               deviceTypes[identifier] == .sp105e {
                addresses.insert(identifier)
            }
        }
        return addresses
    }

    /// Get controller type for a device address
    func getControllerType(for address: String) -> ControllerType {
        return deviceTypes[address] ?? .sp105e
    }

    // MARK: - Private Methods

    private func connectNextDevice() {
        guard !pendingConnections.isEmpty else {
            print("All connection attempts completed: \(connectedCount)/\(totalCount)")
            return
        }

        let peripheral = pendingConnections.removeFirst()
        let identifier = peripheral.identifier.uuidString

        connectionStates[identifier] = .connecting
        peripheral.delegate = self
        centralManager.connect(peripheral, options: nil)

        // Schedule next connection
        if !pendingConnections.isEmpty {
            DispatchQueue.main.asyncAfter(deadline: .now() + connectionDelayMs / 1000) { [weak self] in
                self?.connectNextDevice()
            }
        }
    }

    private func updateConnectedCount() {
        connectedCount = connectionStates.values.filter { $0 == .connected }.count
    }
}

// MARK: - CBCentralManagerDelegate

extension GroupConnectionManager: CBCentralManagerDelegate {

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        isBluetoothOn = central.state == .poweredOn

        if central.state != .poweredOn {
            disconnectAll()
        }
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        print("Group: Connected to \(peripheral.name ?? "Unknown")")
        peripheral.discoverServices([LEDProtocolFactory.serviceUUID])
    }

    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        let identifier = peripheral.identifier.uuidString
        print("Group: Failed to connect \(peripheral.name ?? "Unknown"): \(error?.localizedDescription ?? "Unknown")")
        connectionStates[identifier] = .failed(error?.localizedDescription ?? "Connection failed")
    }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        let identifier = peripheral.identifier.uuidString
        print("Group: Disconnected from \(peripheral.name ?? "Unknown")")
        connectionStates[identifier] = .disconnected
        characteristics.removeValue(forKey: identifier)
        updateConnectedCount()
    }
}

// MARK: - CBPeripheralDelegate

extension GroupConnectionManager: CBPeripheralDelegate {

    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        let identifier = peripheral.identifier.uuidString

        if let error = error {
            print("Group: Service discovery failed for \(peripheral.name ?? "Unknown"): \(error)")
            connectionStates[identifier] = .failed("Service discovery failed")
            updateConnectedCount()
            return
        }

        guard let service = peripheral.services?.first(where: { $0.uuid == LEDProtocolFactory.serviceUUID }) else {
            connectionStates[identifier] = .failed("LED service not found")
            updateConnectedCount()
            return
        }

        peripheral.discoverCharacteristics([LEDProtocolFactory.characteristicUUID], for: service)
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        let identifier = peripheral.identifier.uuidString

        if let error = error {
            print("Group: Characteristic discovery failed: \(error)")
            connectionStates[identifier] = .failed("Characteristic not found")
            updateConnectedCount()
            return
        }

        guard let characteristic = service.characteristics?.first(where: { $0.uuid == LEDProtocolFactory.characteristicUUID }) else {
            connectionStates[identifier] = .failed("LED characteristic not found")
            updateConnectedCount()
            return
        }

        characteristics[identifier] = characteristic
        connectionStates[identifier] = .connected
        updateConnectedCount()
        let protocolName = deviceProtocols[identifier]?.name ?? "Unknown"
        print("Group: \(peripheral.name ?? "Unknown") ready with \(protocolName) protocol!")
    }

    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        if let error = error {
            print("Group: Write error for \(peripheral.name ?? "Unknown"): \(error)")
        }
    }
}

// MARK: - ConnectionState Equatable

extension ConnectionState: Equatable {
    static func == (lhs: ConnectionState, rhs: ConnectionState) -> Bool {
        switch (lhs, rhs) {
        case (.disconnected, .disconnected),
             (.connecting, .connecting),
             (.connected, .connected):
            return true
        case (.failed(let a), .failed(let b)):
            return a == b
        default:
            return false
        }
    }
}
