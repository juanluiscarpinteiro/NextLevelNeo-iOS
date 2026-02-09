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
    private var pendingDevices: [DeviceItem] = []                // Devices waiting to be found via scan
    private var connectionDelayMs: Double = 300  // Delay between connection attempts (increased for reliability)
    private var commandDelayMs: Double = 50      // Delay between sending to each device
    private var isScanning = false

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
        pendingDevices = devices

        // Initialize connection states and protocols
        for device in devices {
            connectionStates[device.address] = .connecting
            // Re-detect controller type (in case device was saved with wrong type)
            let detectedType = LEDProtocolFactory.detectControllerType(deviceName: device.deviceName)
            deviceTypes[device.address] = detectedType
            deviceProtocols[device.address] = LEDProtocolFactory.protocolFor(type: detectedType)
            print("[GroupManager] Device \(device.displayName) using \(deviceProtocols[device.address]?.name ?? "unknown") protocol")
        }

        // First, try to retrieve peripherals directly from system cache
        for device in devices {
            if let uuid = UUID(uuidString: device.address) {
                let cachedPeripherals = centralManager.retrievePeripherals(withIdentifiers: [uuid])
                if let peripheral = cachedPeripherals.first {
                    print("[GroupManager] Found \(device.displayName) in system cache")
                    pendingConnections.append(peripheral)
                    peripherals[device.address] = peripheral
                }
            }
        }

        // Also check known peripherals passed in
        for device in devices {
            if peripherals[device.address] == nil,
               let peripheral = knownPeripherals.first(where: { $0.identifier.uuidString == device.address }) {
                print("[GroupManager] Found \(device.displayName) in known peripherals")
                pendingConnections.append(peripheral)
                peripherals[device.address] = peripheral
            }
        }

        // Check if we still have devices that weren't found
        let foundAddresses = Set(peripherals.keys)
        let missingDevices = devices.filter { !foundAddresses.contains($0.address) }

        if !missingDevices.isEmpty {
            print("[GroupManager] \(missingDevices.count) device(s) not in cache, starting scan...")
            pendingDevices = missingDevices
            startScanningForDevices()
        } else {
            pendingDevices = []
        }

        // Start connecting devices we already found
        if !pendingConnections.isEmpty {
            connectNextDevice()
        }
    }

    /// Start scanning for devices not found in cache
    private func startScanningForDevices() {
        guard isBluetoothOn, !pendingDevices.isEmpty else { return }

        isScanning = true
        centralManager.scanForPeripherals(withServices: nil, options: [
            CBCentralManagerScanOptionAllowDuplicatesKey: false
        ])

        // Timeout after 15 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 15) { [weak self] in
            self?.stopScanning()
        }
    }

    /// Stop scanning
    private func stopScanning() {
        guard isScanning else { return }
        isScanning = false
        centralManager.stopScan()

        // Mark any still-missing devices as failed
        for device in pendingDevices {
            if peripherals[device.address] == nil {
                connectionStates[device.address] = .failed("Device not found")
            }
        }
        pendingDevices = []
    }

    /// Disconnect from all devices
    func disconnectAll() {
        // Stop scanning if active
        if isScanning {
            centralManager.stopScan()
            isScanning = false
        }

        pendingConnections.removeAll()
        pendingDevices.removeAll()

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
    /// - Parameters:
    ///   - commandGenerator: Closure that generates the command data for a given protocol
    ///   - selectedOnly: Optional set of device addresses to send to (nil = all connected devices)
    func sendProtocolCommandToAll(_ commandGenerator: (LEDProtocol) -> Data?, selectedOnly: Set<String>? = nil) {
        var delay: Double = 0
        var sentCount = 0

        print("[GroupManager] sendProtocolCommandToAll - characteristics count: \(characteristics.count), selectedOnly: \(selectedOnly?.count ?? -1)")

        for (identifier, characteristic) in characteristics {
            print("[GroupManager] Checking device \(identifier.prefix(8))... peripheral: \(peripherals[identifier] != nil), protocol: \(deviceProtocols[identifier] != nil), state: \(connectionStates[identifier] ?? .disconnected)")

            guard let peripheral = peripherals[identifier],
                  let deviceProtocol = deviceProtocols[identifier],
                  connectionStates[identifier] == .connected else {
                print("[GroupManager] Skipping \(identifier.prefix(8)) - not ready")
                continue
            }

            // Skip if we have a filter and this device isn't selected
            if let selected = selectedOnly, !selected.contains(identifier) {
                print("[GroupManager] Skipping \(identifier.prefix(8)) - not in selectedOnly")
                continue
            }

            let writeType: CBCharacteristicWriteType = deviceProtocol.usesWriteWithoutResponse ? .withoutResponse : .withResponse

            // Generate command for this device's protocol
            guard let command = commandGenerator(deviceProtocol) else {
                print("[GroupManager] Command not supported by \(deviceProtocol.name)")
                continue
            }

            sentCount += 1
            DispatchQueue.main.asyncAfter(deadline: .now() + delay / 1000) {
                let hexString = command.map { String(format: "%02X", $0) }.joined(separator: " ")
                print("[GroupManager] Sending to \(peripheral.name ?? "Unknown") (\(deviceProtocol.name)): \(hexString)")
                peripheral.writeValue(command, for: characteristic, type: writeType)
            }
            delay += commandDelayMs
        }

        print("[GroupManager] Sent commands to \(sentCount) devices")
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

    func setColor(red: Int, green: Int, blue: Int, selectedOnly: Set<String>? = nil) {
        sendProtocolCommandToAll({ ledProtocol in
            ledProtocol.setColor(red: UInt8(red), green: UInt8(green), blue: UInt8(blue))
        }, selectedOnly: selectedOnly)
    }

    func setMode(_ mode: Int, selectedOnly: Set<String>? = nil) {
        sendProtocolCommandToAll({ ledProtocol in
            ledProtocol.setMode(mode)
        }, selectedOnly: selectedOnly)
    }

    func increaseBrightness(selectedOnly: Set<String>? = nil) {
        sendProtocolCommandToAll({ ledProtocol in
            ledProtocol.brightnessUp()
        }, selectedOnly: selectedOnly)
    }

    func decreaseBrightness(selectedOnly: Set<String>? = nil) {
        sendProtocolCommandToAll({ ledProtocol in
            ledProtocol.brightnessDown()
        }, selectedOnly: selectedOnly)
    }

    /// Set absolute brightness for devices (PWM uses absolute, SP105E uses step-based)
    func setBrightnessAbsolute(_ brightness: Int, lastBrightness: Int, selectedOnly: Set<String>? = nil) {
        sendProtocolCommandToAll({ ledProtocol in
            if let banlanx = ledProtocol as? BanlanXProtocol {
                return banlanx.setBrightnessAbsolute(brightness)
            } else {
                // SP105E uses step-based
                if brightness > lastBrightness {
                    return ledProtocol.brightnessUp()
                } else if brightness < lastBrightness {
                    return ledProtocol.brightnessDown()
                }
                return nil
            }
        }, selectedOnly: selectedOnly)
    }

    func increaseSpeed(selectedOnly: Set<String>? = nil) {
        sendProtocolCommandToAll({ ledProtocol in
            ledProtocol.speedUp()
        }, selectedOnly: selectedOnly)
    }

    func decreaseSpeed(selectedOnly: Set<String>? = nil) {
        sendProtocolCommandToAll({ ledProtocol in
            ledProtocol.speedDown()
        }, selectedOnly: selectedOnly)
    }

    func togglePower(turnOn: Bool, selectedOnly: Set<String>? = nil) {
        print("[GroupManager] togglePower called - turnOn: \(turnOn), connected: \(connectedCount), characteristics: \(characteristics.count)")
        sendProtocolCommandToAll({ ledProtocol in
            if turnOn {
                print("[GroupManager] Generating powerOn command for \(ledProtocol.name)")
                return ledProtocol.powerOn()
            } else {
                print("[GroupManager] Generating powerOff command for \(ledProtocol.name)")
                return ledProtocol.powerOff()
            }
        }, selectedOnly: selectedOnly)
    }

    func powerOn(selectedOnly: Set<String>? = nil) {
        sendProtocolCommandToAll({ ledProtocol in
            ledProtocol.powerOn()
        }, selectedOnly: selectedOnly)
    }

    func powerOff(selectedOnly: Set<String>? = nil) {
        sendProtocolCommandToAll({ ledProtocol in
            ledProtocol.powerOff()
        }, selectedOnly: selectedOnly)
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

    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral,
                        advertisementData: [String: Any], rssi RSSI: NSNumber) {
        // Check if this is one of our pending devices
        let identifier = peripheral.identifier.uuidString

        if let deviceIndex = pendingDevices.firstIndex(where: { $0.address == identifier }) {
            let device = pendingDevices[deviceIndex]
            print("[GroupManager] Found \(device.displayName) via scan")

            // Store peripheral and queue for connection
            peripherals[identifier] = peripheral
            pendingConnections.append(peripheral)
            pendingDevices.remove(at: deviceIndex)

            // Start connecting if this is the first one found
            if pendingConnections.count == 1 {
                connectNextDevice()
            }

            // Stop scanning if we found all devices
            if pendingDevices.isEmpty {
                stopScanning()
            }
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
