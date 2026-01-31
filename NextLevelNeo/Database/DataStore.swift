import Foundation
import Combine

/// Persistent data store for devices and groups
/// Uses UserDefaults with Codable for simplicity
/// Can be migrated to CoreData or SQLite later if needed
class DataStore: ObservableObject {

    // MARK: - Singleton

    static let shared = DataStore()

    // MARK: - Published Properties

    @Published var devices: [DeviceItem] = []
    @Published var groups: [DeviceGroup] = []

    // MARK: - Private Properties

    private let devicesKey = "savedDevices"
    private let groupsKey = "savedGroups"
    private let defaults = UserDefaults.standard

    // MARK: - Initialization

    private init() {
        loadDevices()
        loadGroups()
    }

    // MARK: - Device Methods

    /// Load devices from storage
    private func loadDevices() {
        guard let data = defaults.data(forKey: devicesKey),
              let decoded = try? JSONDecoder().decode([DeviceItem].self, from: data) else {
            devices = []
            return
        }
        devices = decoded
    }

    /// Save devices to storage
    private func saveDevices() {
        if let encoded = try? JSONEncoder().encode(devices) {
            defaults.set(encoded, forKey: devicesKey)
        }
    }

    /// Add a new device (or update if exists)
    func addDevice(_ device: DeviceItem) {
        if let index = devices.firstIndex(where: { $0.address == device.address }) {
            // Update existing
            devices[index] = device
        } else {
            // Add new
            devices.append(device)
        }
        saveDevices()
    }

    /// Get a device by address
    func getDevice(address: String) -> DeviceItem? {
        devices.first { $0.address == address }
    }

    /// Update a device
    func updateDevice(_ device: DeviceItem) {
        if let index = devices.firstIndex(where: { $0.address == device.address }) {
            devices[index] = device
            saveDevices()
        }
    }

    /// Delete a device
    func deleteDevice(address: String) {
        devices.removeAll { $0.address == address }
        saveDevices()

        // Also remove from all groups
        for i in groups.indices {
            groups[i].deviceAddresses.removeAll { $0 == address }
        }
        saveGroups()
    }

    /// Rename a device
    func renameDevice(address: String, newName: String) {
        if let index = devices.firstIndex(where: { $0.address == address }) {
            devices[index].customName = newName
            saveDevices()
        }
    }

    // MARK: - Group Methods

    /// Load groups from storage
    private func loadGroups() {
        guard let data = defaults.data(forKey: groupsKey),
              let decoded = try? JSONDecoder().decode([DeviceGroup].self, from: data) else {
            groups = []
            return
        }
        groups = decoded
    }

    /// Save groups to storage
    private func saveGroups() {
        if let encoded = try? JSONEncoder().encode(groups) {
            defaults.set(encoded, forKey: groupsKey)
        }
    }

    /// Add a new group
    @discardableResult
    func addGroup(name: String) -> DeviceGroup {
        let group = DeviceGroup(name: name)
        groups.append(group)
        saveGroups()
        return group
    }

    /// Get a group by ID
    func getGroup(id: UUID) -> DeviceGroup? {
        groups.first { $0.id == id }
    }

    /// Delete a group
    func deleteGroup(id: UUID) {
        groups.removeAll { $0.id == id }
        saveGroups()
    }

    /// Rename a group
    func renameGroup(id: UUID, newName: String) {
        if let index = groups.firstIndex(where: { $0.id == id }) {
            groups[index].name = newName
            saveGroups()
        }
    }

    /// Set devices for a group
    func setGroupDevices(groupId: UUID, deviceAddresses: [String]) {
        if let index = groups.firstIndex(where: { $0.id == groupId }) {
            groups[index].deviceAddresses = deviceAddresses
            saveGroups()
        }
    }

    /// Get devices in a group
    func getDevicesInGroup(groupId: UUID) -> [DeviceItem] {
        guard let group = getGroup(id: groupId) else { return [] }
        return devices.filter { group.deviceAddresses.contains($0.address) }
    }

    // MARK: - Favorite Colors

    func saveFavoriteColor(deviceAddress: String, slot: Int, color: Int, name: String?) {
        guard slot >= 0 && slot < 6,
              let index = devices.firstIndex(where: { $0.address == deviceAddress }) else { return }

        devices[index].favoriteColors[slot] = color
        devices[index].favoriteColorNames[slot] = name
        saveDevices()
    }

    func clearFavoriteColor(deviceAddress: String, slot: Int) {
        guard slot >= 0 && slot < 6,
              let index = devices.firstIndex(where: { $0.address == deviceAddress }) else { return }

        devices[index].favoriteColors[slot] = -1
        devices[index].favoriteColorNames[slot] = nil
        saveDevices()
    }

    /// Update all favorite colors at once (for group control)
    func updateFavoriteColors(for deviceAddress: String, colors: [Int], names: [String?]) {
        guard let index = devices.firstIndex(where: { $0.address == deviceAddress }) else { return }
        devices[index].favoriteColors = colors
        devices[index].favoriteColorNames = names
        saveDevices()
    }

    // MARK: - Favorite Modes

    func saveFavoriteMode(deviceAddress: String, slot: Int, mode: Int, name: String?) {
        guard slot >= 0 && slot < 6,
              let index = devices.firstIndex(where: { $0.address == deviceAddress }) else { return }

        devices[index].favoriteModes[slot] = mode
        devices[index].favoriteModeNames[slot] = name
        saveDevices()
    }

    func clearFavoriteMode(deviceAddress: String, slot: Int) {
        guard slot >= 0 && slot < 6,
              let index = devices.firstIndex(where: { $0.address == deviceAddress }) else { return }

        devices[index].favoriteModes[slot] = -1
        devices[index].favoriteModeNames[slot] = nil
        saveDevices()
    }

    /// Update all favorite modes at once (for group control)
    func updateFavoriteModes(for deviceAddress: String, modes: [Int], names: [String?]) {
        guard let index = devices.firstIndex(where: { $0.address == deviceAddress }) else { return }
        devices[index].favoriteModes = modes
        devices[index].favoriteModeNames = names
        saveDevices()
    }

    // MARK: - Device State

    func saveDeviceState(address: String, brightness: Int, mode: Int, speed: Int, red: Int, green: Int, blue: Int) {
        guard let index = devices.firstIndex(where: { $0.address == address }) else { return }

        devices[index].lastBrightness = brightness
        devices[index].lastMode = mode
        devices[index].lastSpeed = speed
        devices[index].lastRed = red
        devices[index].lastGreen = green
        devices[index].lastBlue = blue
        saveDevices()
    }

    func saveColorOrder(address: String, colorOrder: Int) {
        guard let index = devices.firstIndex(where: { $0.address == address }) else { return }
        devices[index].colorOrder = colorOrder
        saveDevices()
    }
}
