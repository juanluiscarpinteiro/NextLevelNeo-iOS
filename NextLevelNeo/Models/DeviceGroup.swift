import Foundation

struct DeviceGroup: Identifiable, Codable, Hashable {
    var id: UUID
    var name: String
    var deviceAddresses: [String]  // Bluetooth identifiers
    var createdAt: Date

    init(id: UUID = UUID(), name: String, deviceAddresses: [String] = []) {
        self.id = id
        self.name = name
        self.deviceAddresses = deviceAddresses
        self.createdAt = Date()
    }

    var deviceCount: Int {
        deviceAddresses.count
    }

    var deviceCountText: String {
        let count = deviceCount
        return "\(count) device\(count != 1 ? "s" : "")"
    }
}
