import SwiftUI
import CoreBluetooth

struct DeviceListView: View {
    @EnvironmentObject var dataStore: DataStore
    @EnvironmentObject var bleManager: BLEManager

    @State private var showingScannedDevices = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                headerView

                // Main content
                ScrollView {
                    VStack(spacing: 16) {
                        // Status
                        statusView

                        // Buttons row
                        buttonsRow

                        // My Devices section
                        devicesSection
                    }
                    .padding()
                }
            }
        }
        .navigationBarHidden(true)
        .sheet(isPresented: $showingScannedDevices) {
            ScanResultsView(onDeviceSelected: { peripheral in
                addDevice(peripheral)
                showingScannedDevices = false
            })
            .environmentObject(bleManager)
        }
    }

    // MARK: - Header

    private var headerView: some View {
        VStack(spacing: 8) {
            Image("next_level_neo_logo")
                .resizable()
                .scaledToFit()
                .frame(height: 60)

            Link("www.NEXTLEVELNEO.com", destination: URL(string: "https://www.nextlevelneo.com")!)
                .font(.footnote.bold())
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(
                            LinearGradient(
                                colors: [.red, .orange, .yellow, .green, .blue, .purple],
                                startPoint: .leading,
                                endPoint: .trailing
                            ),
                            lineWidth: 2
                        )
                )
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(
            LinearGradient(
                colors: [Color(hex: "1a1a1a"), Color(hex: "0f0f0f")],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }

    // MARK: - Status

    private var statusView: some View {
        Text(dataStore.devices.isEmpty
             ? "No saved devices. Tap scan to find controllers."
             : "\(dataStore.devices.count) saved device(s)")
            .font(.subheadline)
            .foregroundColor(.gray)
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color(hex: "1a1a1a"))
            .cornerRadius(8)
    }

    // MARK: - Buttons

    private var buttonsRow: some View {
        HStack(spacing: 12) {
            // Scan button
            Button(action: startScan) {
                HStack {
                    if bleManager.isScanning {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(0.8)
                    }
                    Text(bleManager.isScanning ? "Scanning..." : "Scan for Devices")
                        .fontWeight(.bold)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(bleManager.isScanning ? Color.red : Color.green)
                .foregroundColor(.white)
                .cornerRadius(8)
            }
            .disabled(!bleManager.isBluetoothOn)

            // Groups button
            NavigationLink(destination: GroupListView()) {
                Text("Groups")
                    .fontWeight(.bold)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(Color.orange)
                    .foregroundColor(.white)
                    .cornerRadius(8)
            }
        }
    }

    // MARK: - Devices Section

    private var devicesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("MY DEVICES")
                .font(.caption.bold())
                .foregroundColor(Color(hex: "FF6B35"))
                .tracking(1)

            if dataStore.devices.isEmpty {
                Text("No devices yet")
                    .foregroundColor(.gray)
                    .frame(maxWidth: .infinity, minHeight: 100)
                    .background(Color(hex: "1a1a1a"))
                    .cornerRadius(8)
            } else {
                LazyVStack(spacing: 1) {
                    ForEach(dataStore.devices) { device in
                        NavigationLink(destination: DeviceControlView(device: device)) {
                            DeviceRowView(device: device)
                        }
                    }
                }
                .background(Color(hex: "1a1a1a"))
                .cornerRadius(8)
            }
        }
    }

    // MARK: - Actions

    private func startScan() {
        if bleManager.isScanning {
            bleManager.stopScanning()
        } else {
            bleManager.startScanning()
            showingScannedDevices = true
        }
    }

    private func addDevice(_ peripheral: CBPeripheral) {
        let device = DeviceItem(
            address: peripheral.identifier.uuidString,
            deviceName: peripheral.name ?? "LED Controller",
            customName: peripheral.name
        )
        dataStore.addDevice(device)
    }
}

// MARK: - Device Row

struct DeviceRowView: View {
    let device: DeviceItem

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: "lightstrip.2")
                .font(.title)
                .foregroundColor(.orange)
                .frame(width: 48, height: 48)

            VStack(alignment: .leading, spacing: 4) {
                Text(device.displayName)
                    .font(.headline)
                    .foregroundColor(.white)

                Text(device.address.prefix(17))
                    .font(.caption)
                    .foregroundColor(.gray)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .foregroundColor(.gray)
        }
        .padding()
        .background(Color(hex: "252525"))
    }
}

// MARK: - Scan Results Sheet

struct ScanResultsView: View {
    @EnvironmentObject var bleManager: BLEManager
    @Environment(\.dismiss) var dismiss

    let onDeviceSelected: (CBPeripheral) -> Void

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                VStack {
                    if bleManager.isScanning {
                        ProgressView("Scanning for LED controllers...")
                            .foregroundColor(.white)
                            .padding()
                    }

                    if bleManager.discoveredPeripherals.isEmpty && !bleManager.isScanning {
                        Text("No devices found")
                            .foregroundColor(.gray)
                            .padding()
                    } else {
                        List(bleManager.discoveredPeripherals, id: \.identifier) { peripheral in
                            Button(action: {
                                onDeviceSelected(peripheral)
                            }) {
                                HStack {
                                    Image(systemName: "lightstrip.2")
                                        .foregroundColor(.orange)

                                    VStack(alignment: .leading) {
                                        Text(peripheral.name ?? "Unknown")
                                            .foregroundColor(.white)
                                        Text(peripheral.identifier.uuidString.prefix(17))
                                            .font(.caption)
                                            .foregroundColor(.gray)
                                    }

                                    Spacer()

                                    Image(systemName: "plus.circle.fill")
                                        .foregroundColor(.green)
                                }
                            }
                            .listRowBackground(Color(hex: "252525"))
                        }
                        .listStyle(.plain)
                        .scrollContentBackground(.hidden)
                    }
                }
            }
            .navigationTitle("Found Devices")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        bleManager.stopScanning()
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(bleManager.isScanning ? "Stop" : "Scan") {
                        if bleManager.isScanning {
                            bleManager.stopScanning()
                        } else {
                            bleManager.startScanning()
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Color Extension

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

#Preview {
    DeviceListView()
        .environmentObject(DataStore.shared)
        .environmentObject(BLEManager())
}
