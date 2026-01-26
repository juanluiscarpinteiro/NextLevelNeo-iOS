import SwiftUI

struct GroupControlView: View {
    @EnvironmentObject var dataStore: DataStore
    @EnvironmentObject var bleManager: BLEManager
    @Environment(\.dismiss) var dismiss

    let group: DeviceGroup

    @StateObject private var groupManager = GroupConnectionManager()

    @State private var currentColor = Color.white
    @State private var currentRed: Double = 255
    @State private var currentGreen: Double = 255
    @State private var currentBlue: Double = 255
    @State private var brightness: Double = 128
    @State private var speed: Double = 128
    @State private var selectedMode: Int = 0
    @State private var isPowerOn = true
    @State private var showingHelp = false

    var body: some View {
        ZStack {
            Color(hex: "0f0f0f").ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                headerView

                // Content
                ScrollView {
                    VStack(spacing: 16) {
                        // Connection status
                        connectionStatusView

                        // Device status list
                        deviceStatusList

                        // Connect button
                        connectButton

                        // Controls (shown when connected)
                        if groupManager.isAnyConnected {
                            controlsView
                        }
                    }
                    .padding()
                }
            }
        }
        .navigationBarHidden(true)
        .onDisappear {
            groupManager.disconnectAll()
        }
        .sheet(isPresented: $showingHelp) {
            GroupControlHelpView()
        }
    }

    // MARK: - Header

    private var headerView: some View {
        HStack {
            Button(action: {
                groupManager.disconnectAll()
                dismiss()
            }) {
                Image(systemName: "chevron.left")
                    .font(.title2)
                    .foregroundColor(.white)
            }

            Spacer()

            Text(group.name)
                .font(.headline)
                .foregroundColor(.white)

            Spacer()

            HStack(spacing: 8) {
                Button(action: { showingHelp = true }) {
                    Image(systemName: "info.circle")
                        .font(.title3)
                        .foregroundColor(.white)
                }

                Button(action: togglePower) {
                    Image(systemName: "power")
                        .font(.title3)
                        .foregroundColor(isPowerOn && groupManager.isAnyConnected ? .green : .gray)
                }
                .disabled(!groupManager.isAnyConnected)
            }
        }
        .padding()
        .background(
            LinearGradient(
                colors: [Color(hex: "1a1a1a"), Color(hex: "0f0f0f")],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }

    // MARK: - Connection Status

    private var connectionStatusView: some View {
        VStack(spacing: 4) {
            Text(statusText)
                .font(.headline)
                .foregroundColor(statusColor)

            Text("\(groupManager.connectedCount)/\(groupManager.totalCount) devices")
                .font(.subheadline)
                .foregroundColor(.gray)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color(hex: "252525"))
        .cornerRadius(8)
    }

    private var statusText: String {
        if groupManager.connectedCount == 0 {
            return "Disconnected"
        } else if groupManager.connectedCount == groupManager.totalCount {
            return "All Connected"
        } else {
            return "Partially Connected"
        }
    }

    private var statusColor: Color {
        if groupManager.connectedCount == 0 {
            return .orange
        } else if groupManager.connectedCount == groupManager.totalCount {
            return .green
        } else {
            return .yellow
        }
    }

    // MARK: - Device Status List

    private var deviceStatusList: some View {
        VStack(spacing: 8) {
            let devices = dataStore.getDevicesInGroup(groupId: group.id)
            ForEach(devices) { device in
                HStack {
                    Circle()
                        .fill(deviceStatusColor(for: device))
                        .frame(width: 12, height: 12)

                    Text(device.displayName)
                        .font(.subheadline)
                        .foregroundColor(.white)

                    Spacer()
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
            }
        }
        .background(Color(hex: "1a1a1a"))
        .cornerRadius(8)
    }

    private func deviceStatusColor(for device: DeviceItem) -> Color {
        let state = groupManager.connectionStates[device.address] ?? .disconnected
        switch state {
        case .connected: return .green
        case .connecting: return .yellow
        default: return .orange
        }
    }

    // MARK: - Connect Button

    private var connectButton: some View {
        Button(action: toggleConnection) {
            Text(groupManager.isAnyConnected ? "Disconnect All" : "Connect All")
                .fontWeight(.bold)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(groupManager.isAnyConnected ? Color.red : Color.green)
                .foregroundColor(.white)
                .cornerRadius(8)
        }
    }

    // MARK: - Controls

    private var controlsView: some View {
        VStack(spacing: 20) {
            // Quick Colors
            quickColorsSection

            Divider().background(Color.gray)

            // Color Wheel
            colorWheelSection

            // Color Preview
            colorPreviewSection

            Divider().background(Color.gray)

            // Mode Selection
            modeSection

            Divider().background(Color.gray)

            // Brightness
            brightnessSection

            Divider().background(Color.gray)

            // Speed
            speedSection
        }
        .padding()
        .background(Color(hex: "252525"))
        .cornerRadius(12)
    }

    // MARK: - Quick Colors

    private var quickColorsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("QUICK COLORS")
                .font(.caption.bold())
                .foregroundColor(.white)
                .tracking(1)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(SP105EProtocol.quickColors, id: \.name) { color in
                        Button(action: {
                            setColor(red: Int(color.red), green: Int(color.green), blue: Int(color.blue))
                        }) {
                            Circle()
                                .fill(Color(red: Double(color.red)/255,
                                           green: Double(color.green)/255,
                                           blue: Double(color.blue)/255))
                                .frame(width: 50, height: 50)
                                .overlay(Circle().stroke(Color.white.opacity(0.3), lineWidth: 2))
                        }
                    }
                }
            }
        }
    }

    // MARK: - Color Wheel

    private var colorWheelSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("COLOR WHEEL")
                .font(.caption.bold())
                .foregroundColor(.white)
                .tracking(1)

            ColorWheelView(
                selectedColor: $currentColor,
                onColorChanged: { color in
                    let components = color.components
                    setColor(red: Int(components.red * 255),
                            green: Int(components.green * 255),
                            blue: Int(components.blue * 255))
                }
            )
            .frame(height: 250)
        }
    }

    // MARK: - Color Preview

    private var colorPreviewSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("SELECTED COLOR")
                .font(.caption.bold())
                .foregroundColor(.white)
                .tracking(1)

            Rectangle()
                .fill(Color(red: currentRed/255, green: currentGreen/255, blue: currentBlue/255))
                .frame(height: 60)
                .cornerRadius(8)
        }
    }

    // MARK: - Mode Section

    private var modeSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("EFFECT MODE")
                .font(.caption.bold())
                .foregroundColor(.white)
                .tracking(1)

            HStack {
                Button(action: previousMode) {
                    Image(systemName: "chevron.left")
                        .font(.title2.bold())
                        .frame(width: 50, height: 50)
                        .background(Color.orange)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }

                Picker("Mode", selection: $selectedMode) {
                    ForEach(0..<SP105EProtocol.modeNames.count, id: \.self) { index in
                        Text(SP105EProtocol.modeNames[index]).tag(index)
                    }
                }
                .pickerStyle(.menu)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(Color(hex: "3a3a3a"))
                .cornerRadius(8)
                .onChange(of: selectedMode) { _, newValue in
                    if newValue > 0 {
                        groupManager.setMode(newValue)
                    }
                }

                Button(action: nextMode) {
                    Image(systemName: "chevron.right")
                        .font(.title2.bold())
                        .frame(width: 50, height: 50)
                        .background(Color.orange)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
            }
        }
    }

    // MARK: - Brightness Section

    private var brightnessSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("BRIGHTNESS")
                .font(.caption.bold())
                .foregroundColor(.white)
                .tracking(1)

            HStack {
                Button(action: decreaseBrightness) {
                    Text("-")
                        .font(.title.bold())
                        .frame(width: 50, height: 50)
                        .background(Color.orange)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }

                Slider(value: $brightness, in: 0...255, step: 1)
                    .tint(.orange)

                Button(action: increaseBrightness) {
                    Text("+")
                        .font(.title.bold())
                        .frame(width: 50, height: 50)
                        .background(Color.orange)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
            }

            Text("\(Int(brightness * 100 / 255))%")
                .foregroundColor(.orange)
                .frame(maxWidth: .infinity)
        }
    }

    // MARK: - Speed Section

    private var speedSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("EFFECT SPEED")
                .font(.caption.bold())
                .foregroundColor(.white)
                .tracking(1)

            HStack {
                Button(action: decreaseSpeed) {
                    Text("-")
                        .font(.title.bold())
                        .frame(width: 50, height: 50)
                        .background(Color.orange)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }

                Slider(value: $speed, in: 0...255, step: 1)
                    .tint(.orange)

                Button(action: increaseSpeed) {
                    Text("+")
                        .font(.title.bold())
                        .frame(width: 50, height: 50)
                        .background(Color.orange)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
            }

            Text("\(Int(speed * 100 / 255))%")
                .foregroundColor(.orange)
                .frame(maxWidth: .infinity)
        }
    }

    // MARK: - Actions

    private func toggleConnection() {
        if groupManager.isAnyConnected {
            groupManager.disconnectAll()
        } else {
            let devices = dataStore.getDevicesInGroup(groupId: group.id)
            groupManager.connectAll(devices: devices, knownPeripherals: bleManager.discoveredPeripherals)
        }
    }

    private func togglePower() {
        isPowerOn.toggle()
        groupManager.togglePower()
    }

    private func setColor(red: Int, green: Int, blue: Int) {
        currentRed = Double(red)
        currentGreen = Double(green)
        currentBlue = Double(blue)
        selectedMode = 0
        groupManager.setColor(red: red, green: green, blue: blue)
    }

    private func previousMode() {
        if selectedMode > 1 {
            selectedMode -= 1
        } else {
            selectedMode = SP105EProtocol.modeNames.count - 1
        }
    }

    private func nextMode() {
        if selectedMode < SP105EProtocol.modeNames.count - 1 {
            selectedMode += 1
        } else {
            selectedMode = 1
        }
    }

    private func increaseBrightness() {
        brightness = min(255, brightness + 25)
        groupManager.increaseBrightness()
    }

    private func decreaseBrightness() {
        brightness = max(0, brightness - 25)
        groupManager.decreaseBrightness()
    }

    private func increaseSpeed() {
        speed = min(255, speed + 25)
        groupManager.increaseSpeed()
    }

    private func decreaseSpeed() {
        speed = max(0, speed - 25)
        groupManager.decreaseSpeed()
    }
}

// MARK: - Group Control Help

struct GroupControlHelpView: View {
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    helpSection(title: "GROUP CONTROL", content: """
                        This screen lets you control all devices in the group simultaneously. Every command you send (color, mode, brightness, speed) is sent to ALL connected devices at once.
                        """)

                    helpSection(title: "CONNECTION STATUS", content: """
                        • Green dot = Device connected
                        • Yellow dot = Connecting
                        • Orange dot = Device disconnected

                        The group still works even if some devices fail to connect.
                        """)

                    helpSection(title: "CONTROLS", content: """
                        • Quick Colors: Tap to instantly set color on all devices
                        • Color Wheel: Pick any color by touching the wheel
                        • Effect Mode: Select from 50+ lighting effects
                        • Brightness/Speed: Use sliders or +/- buttons
                        • Power: Toggle all devices on/off
                        """)

                    helpSection(title: "IMPORTANT WARNINGS", content: """
                        ⚠️ DO NOT change strip type (RGB/RGBW) in group mode!
                        Strip type should be configured per-device individually. Sending strip type commands to multiple devices simultaneously may cause unexpected behavior.

                        ⚠️ Maximum 4 devices per group recommended
                        iOS has BLE connection limits. Groups with more than 4 devices may experience connection drops or delays.
                        """)

                    helpSection(title: "TIPS", content: """
                        • If a device disconnects, try reconnecting the group
                        • Settings are not saved per-group
                        • Each device keeps its own settings for single-device use
                        """)
                }
                .padding()
            }
            .background(Color.black)
            .navigationTitle("Group Control Help")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func helpSection(title: String, content: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
                .foregroundColor(.orange)

            Text(content)
                .foregroundColor(.white)
        }
    }
}
