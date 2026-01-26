import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var dataStore: DataStore
    @EnvironmentObject var bleManager: BLEManager
    @Environment(\.dismiss) var dismiss

    let device: DeviceItem

    @State private var selectedColorOrder: Int

    init(device: DeviceItem) {
        self.device = device
        _selectedColorOrder = State(initialValue: device.colorOrder)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                List {
                    // Strip Type Section
                    Section {
                        Picker("Strip Type", selection: $selectedColorOrder) {
                            Text("RGB").tag(0)
                            Text("RGBW").tag(1)
                        }
                        .pickerStyle(.segmented)
                        .listRowBackground(Color(hex: "252525"))
                        .onChange(of: selectedColorOrder) { _, newValue in
                            applyStripType(newValue)
                        }
                    } header: {
                        Text("LED Strip Configuration")
                            .foregroundColor(.orange)
                    } footer: {
                        Text("Select the type that matches your LED strip. Incorrect settings may cause wrong colors.")
                            .foregroundColor(.gray)
                    }

                    // Device Info Section
                    Section {
                        HStack {
                            Text("Name")
                            Spacer()
                            Text(device.displayName)
                                .foregroundColor(.gray)
                        }
                        .listRowBackground(Color(hex: "252525"))

                        HStack {
                            Text("Address")
                            Spacer()
                            Text(device.address.prefix(23))
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                        .listRowBackground(Color(hex: "252525"))
                    } header: {
                        Text("Device Information")
                            .foregroundColor(.orange)
                    }

                    // About Section
                    Section {
                        Link(destination: URL(string: "https://www.nextlevelneo.com")!) {
                            HStack {
                                Text("Visit Website")
                                Spacer()
                                Image(systemName: "arrow.up.right.square")
                            }
                        }
                        .listRowBackground(Color(hex: "252525"))

                        HStack {
                            Text("Version")
                            Spacer()
                            Text("1.0.0")
                                .foregroundColor(.gray)
                        }
                        .listRowBackground(Color(hex: "252525"))
                    } header: {
                        Text("About")
                            .foregroundColor(.orange)
                    }
                }
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func applyStripType(_ colorOrder: Int) {
        dataStore.saveColorOrder(address: device.address, colorOrder: colorOrder)

        if bleManager.isConnected {
            if colorOrder == 0 {
                bleManager.sendCommand(SP105EProtocol.setRGBMode)
            } else {
                bleManager.sendCommand(SP105EProtocol.setRGBWMode)
            }
        }
    }
}
