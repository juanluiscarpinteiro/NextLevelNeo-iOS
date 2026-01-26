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
    private var characteristics: [String: CBCharacteristic] = [] // identifier -> write characteristic
    private var pendingConnections: [CBPeripheral] = []
    private var connectionDelayMs: Double = 200  // Delay between connection attempts
    private var commandDelayMs: Double = 50      // Delay between sending to each device

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

        // Initialize connection states
        for device in devices {
            connectionStates[device.address] = .disconnected
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
        connectedCount = 0
        totalCount = 0
    }

    /// Check if any device is connected
    var isAnyConnected: Bool {
        connectedCount > 0
    }

    /// Send command to all connected devices
    func sendCommandToAll(_ data: Data) {
        var delay: Double = 0

        for (identifier, characteristic) in characteristics {
            guard let peripheral = peripherals[identifier],
                  connectionStates[identifier] == .connected else { continue }

            DispatchQueue.main.asyncAfter(deadline: .now() + delay / 1000) {
                peripheral.writeValue(data, for: characteristic, type: .withResponse)
            }
            delay += commandDelayMs
        }
    }

    // MARK: - Convenience Command Methods

    func setColor(red: Int, green: Int, blue: Int) {
        sendCommandToAll(SP105EProtocol.setColor(red: UInt8(red), green: UInt8(green), blue: UInt8(blue)))
    }

    func setMode(_ mode: Int) {
        sendCommandToAll(SP105EProtocol.setMode(mode))
    }

    func increaseBrightness() {
        sendCommandToAll(SP105EProtocol.brightnessUp)
    }

    func decreaseBrightness() {
        sendCommandToAll(SP105EProtocol.brightnessDown)
    }

    func increaseSpeed() {
        sendCommandToAll(SP105EProtocol.speedUp)
    }

    func decreaseSpeed() {
        sendCommandToAll(SP105EProtocol.speedDown)
    }

    func togglePower() {
        sendCommandToAll(SP105EProtocol.togglePower)
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
        peripheral.discoverServices([SP105EProtocol.serviceUUID])
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
            return
        }

        guard let service = peripheral.services?.first(where: { $0.uuid == SP105EProtocol.serviceUUID }) else {
            connectionStates[identifier] = .failed("LED service not found")
            return
        }

        peripheral.discoverCharacteristics([SP105EProtocol.characteristicUUID], for: service)
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        let identifier = peripheral.identifier.uuidString

        if let error = error {
            print("Group: Characteristic discovery failed: \(error)")
            connectionStates[identifier] = .failed("Characteristic not found")
            return
        }

        guard let characteristic = service.characteristics?.first(where: { $0.uuid == SP105EProtocol.characteristicUUID }) else {
            connectionStates[identifier] = .failed("LED characteristic not found")
            return
        }

        characteristics[identifier] = characteristic
        connectionStates[identifier] = .connected
        updateConnectedCount()
        print("Group: \(peripheral.name ?? "Unknown") ready!")
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
