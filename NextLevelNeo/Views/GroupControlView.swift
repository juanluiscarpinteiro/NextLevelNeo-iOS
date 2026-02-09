import SwiftUI
import Combine

struct GroupControlView: View {
    @EnvironmentObject var dataStore: DataStore
    @EnvironmentObject var bleManager: BLEManager
    @Environment(\.dismiss) var dismiss

    let group: DeviceGroup

    @StateObject private var groupManager = GroupConnectionManager()

    // Shared state
    @State private var isPowerOn = true
    @State private var showingHelp = false

    // Demon Eye (PWM) section state
    @State private var demonEyeColor = Color.white
    @State private var demonEyeRed: Double = 255
    @State private var demonEyeGreen: Double = 255
    @State private var demonEyeBlue: Double = 255
    @State private var showDemonEyeWheel = false
    @State private var demonEyeFavoriteColors: [Int] = Array(repeating: -1, count: 6)
    @State private var selectedDemonEyeDevices: Set<String> = []
    @State private var showingSaveDemonEyeColorDialog = false
    @State private var showingDemonEyeColorOptions = false
    @State private var selectedDemonEyeColorSlot: Int = 0

    // SP105E section state
    @State private var sp105eColor = Color.white
    @State private var sp105eRed: Double = 255
    @State private var sp105eGreen: Double = 255
    @State private var sp105eBlue: Double = 255
    @State private var brightness: Double = 128
    @State private var lastBrightness: Int = 128
    @State private var speed: Double = 128
    @State private var selectedMode: Int = 0
    @State private var selectedSP105EDevices: Set<String> = []
    @State private var sp105eFavoriteModes: [Int] = Array(repeating: -1, count: 6)
    @State private var showingSaveSP105EModeDialog = false
    @State private var showingSP105EModeOptions = false
    @State private var selectedSP105EModeSlot: Int = 0

    // Auto mode cycling
    @State private var isCycling = false
    @State private var cycleTimer: Timer?
    private let cycleInterval: TimeInterval = 15.0

    var body: some View {
        ZStack {
            Color(hex: "0f0f0f").ignoresSafeArea()

            VStack(spacing: 0) {
                headerView

                ScrollView {
                    VStack(spacing: 16) {
                        connectionStatusView
                        deviceStatusList
                        connectButton

                        // Only show controls when ALL devices are connected
                        if groupManager.connectedCount == groupManager.totalCount && groupManager.totalCount > 0 {
                            // Demon Eye Section (PWM devices)
                            if hasPWMDevices {
                                demonEyeSection
                            }

                            // SP105E Section (Addressable LED devices)
                            if hasSP105EDevices {
                                sp105eSection
                            }
                        }
                    }
                    .padding()
                }
            }
        }
        .navigationBarHidden(true)
        .onAppear(perform: initializeState)
        .onDisappear {
            stopModeCycling()
            groupManager.disconnectAll()
        }
        .sheet(isPresented: $showingHelp) {
            GroupControlHelpView()
        }
        .confirmationDialog("Save Color to Slot", isPresented: $showingSaveDemonEyeColorDialog) {
            ForEach(0..<6, id: \.self) { slot in
                Button("Slot \(slot + 1)") {
                    saveDemonEyeFavoriteColor(slot: slot)
                }
            }
            Button("Cancel", role: .cancel) { }
        }
        .confirmationDialog("Favorite Color Options", isPresented: $showingDemonEyeColorOptions) {
            Button("Delete", role: .destructive) {
                deleteDemonEyeFavoriteColor(slot: selectedDemonEyeColorSlot)
            }
            Button("Cancel", role: .cancel) { }
        }
        .confirmationDialog("Save Mode to Slot", isPresented: $showingSaveSP105EModeDialog) {
            ForEach(0..<6, id: \.self) { slot in
                Button("Slot \(slot + 1)") {
                    saveSP105EFavoriteMode(slot: slot)
                }
            }
            Button("Cancel", role: .cancel) { }
        }
        .confirmationDialog("Favorite Mode Options", isPresented: $showingSP105EModeOptions) {
            Button("Replace with current mode") {
                saveSP105EFavoriteMode(slot: selectedSP105EModeSlot)
            }
            Button("Delete", role: .destructive) {
                deleteSP105EFavoriteMode(slot: selectedSP105EModeSlot)
            }
            Button("Cancel", role: .cancel) { }
        }
    }

    // MARK: - Computed Properties

    private var devices: [DeviceItem] {
        dataStore.getDevicesInGroup(groupId: group.id)
    }

    private var pwmDevices: [DeviceItem] {
        devices.filter { $0.controllerType == .banlanX }
    }

    private var sp105eDevices: [DeviceItem] {
        devices.filter { $0.controllerType == .sp105e }
    }

    private var hasPWMDevices: Bool {
        !pwmDevices.isEmpty
    }

    private var hasSP105EDevices: Bool {
        !sp105eDevices.isEmpty
    }

    // MARK: - Header

    private var headerView: some View {
        HStack {
            Button(action: {
                stopModeCycling()
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
        VStack(spacing: 0) {
            ForEach(devices) { device in
                HStack {
                    Circle()
                        .fill(deviceStatusColor(for: device))
                        .frame(width: 12, height: 12)

                    Text(device.displayName)
                        .font(.subheadline)
                        .foregroundColor(.white)

                    Spacer()

                    Text(device.controllerType == .sp105e ? "Addressable" : "PWM")
                        .font(.caption2)
                        .foregroundColor(.gray)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color(hex: "3a3a3a"))
                        .cornerRadius(4)
                }
                .padding(.vertical, 6)
            }
        }
        .padding()
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

    // MARK: - Demon Eye Section (PWM Devices)

    private var demonEyeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Section Title
            Text("DEMON EYE")
                .font(.headline)
                .foregroundColor(.orange)
                .tracking(1)

            Divider().background(Color.gray.opacity(0.5))

            // Quick Colors
            demonEyeQuickColorsView

            Divider().background(Color.gray.opacity(0.5))

            // Custom Color with Show/Hide toggle
            demonEyeCustomColorView

            // Color Preview
            demonEyeColorPreviewView

            Divider().background(Color.gray.opacity(0.5))

            // Favorite Colors
            demonEyeFavoriteColorsView

            Divider().background(Color.gray.opacity(0.5))

            // Device Selection
            demonEyeDeviceSelectionView
        }
        .padding()
        .background(Color(hex: "252525"))
        .cornerRadius(12)
    }

    private var demonEyeQuickColorsView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("QUICK COLORS")
                .font(.caption.bold())
                .foregroundColor(.white)
                .tracking(1)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(SP105EProtocol.quickColors, id: \.name) { color in
                        Button(action: {
                            setDemonEyeColor(red: Int(color.red), green: Int(color.green), blue: Int(color.blue))
                        }) {
                            Circle()
                                .fill(Color(red: Double(color.red)/255,
                                           green: Double(color.green)/255,
                                           blue: Double(color.blue)/255))
                                .frame(width: 45, height: 45)
                                .overlay(Circle().stroke(Color.white.opacity(0.3), lineWidth: 2))
                        }
                    }
                }
            }
        }
    }

    private var demonEyeCustomColorView: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("CUSTOM COLOR")
                    .font(.caption.bold())
                    .foregroundColor(.white)
                    .tracking(1)

                Spacer()

                Button(action: { showDemonEyeWheel.toggle() }) {
                    Text(showDemonEyeWheel ? "Hide" : "Show")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.blue)
                        .cornerRadius(6)
                }
            }

            if showDemonEyeWheel {
                ColorWheelView(
                    selectedColor: $demonEyeColor,
                    onColorChanged: { color in
                        let components = color.components
                        setDemonEyeColor(red: Int(components.red * 255),
                                        green: Int(components.green * 255),
                                        blue: Int(components.blue * 255))
                    }
                )
                .frame(height: 220)
            }
        }
    }

    private var demonEyeColorPreviewView: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("SELECTED COLOR")
                    .font(.caption.bold())
                    .foregroundColor(.white)
                    .tracking(1)

                Spacer()

                Text("Long press to save")
                    .font(.caption2)
                    .foregroundColor(.gray)
            }

            Rectangle()
                .fill(Color(red: demonEyeRed/255, green: demonEyeGreen/255, blue: demonEyeBlue/255))
                .frame(height: 40)
                .cornerRadius(8)
                .onLongPressGesture {
                    showingSaveDemonEyeColorDialog = true
                }
        }
    }

    private var demonEyeFavoriteColorsView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("FAVORITE COLORS")
                .font(.caption.bold())
                .foregroundColor(.white)
                .tracking(1)

            HStack(spacing: 4) {
                ForEach(0..<6, id: \.self) { slot in
                    favoriteColorButton(slot: slot)
                }
            }
        }
    }

    private func favoriteColorButton(slot: Int) -> some View {
        Group {
            if demonEyeFavoriteColors[slot] != -1 {
                let (r, g, b) = DeviceItem.unpackColor(demonEyeFavoriteColors[slot])
                Rectangle()
                    .fill(Color(red: Double(r)/255, green: Double(g)/255, blue: Double(b)/255))
                    .frame(height: 40)
                    .cornerRadius(4)
            } else {
                Rectangle()
                    .fill(Color(hex: "3a3a3a"))
                    .frame(height: 40)
                    .cornerRadius(4)
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [4]))
                            .foregroundColor(.gray)
                    )
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            if demonEyeFavoriteColors[slot] != -1 {
                applyDemonEyeFavoriteColor(slot: slot)
            }
        }
        .onLongPressGesture(minimumDuration: 0.5) {
            if demonEyeFavoriteColors[slot] != -1 {
                // Existing color - show options to delete
                selectedDemonEyeColorSlot = slot
                showingDemonEyeColorOptions = true
            } else {
                // Empty slot - save current color
                saveDemonEyeFavoriteColor(slot: slot)
            }
        }
    }

    private var demonEyeDeviceSelectionView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("SELECT DEVICES")
                .font(.caption.bold())
                .foregroundColor(.white)
                .tracking(1)

            ForEach(pwmDevices) { device in
                HStack {
                    Button(action: {
                        if selectedDemonEyeDevices.contains(device.address) {
                            selectedDemonEyeDevices.remove(device.address)
                        } else {
                            selectedDemonEyeDevices.insert(device.address)
                        }
                    }) {
                        Image(systemName: selectedDemonEyeDevices.contains(device.address) ? "checkmark.square.fill" : "square")
                            .foregroundColor(selectedDemonEyeDevices.contains(device.address) ? .orange : .gray)
                    }

                    Text(device.displayName)
                        .font(.subheadline)
                        .foregroundColor(.white)

                    Spacer()
                }
                .padding(.vertical, 2)
            }
        }
    }

    // MARK: - SP105E Section (Addressable LED Devices)

    private var sp105eSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Section Title
            Text("LED STRIP CONTROLLERS")
                .font(.headline)
                .foregroundColor(.cyan)
                .tracking(1)

            Divider().background(Color.gray.opacity(0.5))

            // Quick Colors
            sp105eQuickColorsView

            Divider().background(Color.gray.opacity(0.5))

            // Color Wheel
            sp105eColorWheelView

            // Color Preview
            sp105eColorPreviewView

            Divider().background(Color.gray.opacity(0.5))

            // Effect Mode with Auto Cycle
            sp105eModeView

            Divider().background(Color.gray.opacity(0.5))

            // Brightness
            sp105eBrightnessView

            Divider().background(Color.gray.opacity(0.5))

            // Effect Speed
            sp105eSpeedView

            Divider().background(Color.gray.opacity(0.5))

            // Favorite Modes
            sp105eFavoriteModesView

            Divider().background(Color.gray.opacity(0.5))

            // Device Selection
            sp105eDeviceSelectionView
        }
        .padding()
        .background(Color(hex: "252525"))
        .cornerRadius(12)
    }

    private var sp105eQuickColorsView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("QUICK COLORS")
                .font(.caption.bold())
                .foregroundColor(.white)
                .tracking(1)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(SP105EProtocol.quickColors, id: \.name) { color in
                        Button(action: {
                            stopModeCycling()
                            setSP105EColor(red: Int(color.red), green: Int(color.green), blue: Int(color.blue))
                        }) {
                            Circle()
                                .fill(Color(red: Double(color.red)/255,
                                           green: Double(color.green)/255,
                                           blue: Double(color.blue)/255))
                                .frame(width: 45, height: 45)
                                .overlay(Circle().stroke(Color.white.opacity(0.3), lineWidth: 2))
                        }
                    }
                }
            }
        }
    }

    private var sp105eColorWheelView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("COLOR WHEEL")
                .font(.caption.bold())
                .foregroundColor(.white)
                .tracking(1)

            ColorWheelView(
                selectedColor: $sp105eColor,
                onColorChanged: { color in
                    stopModeCycling()
                    let components = color.components
                    setSP105EColor(red: Int(components.red * 255),
                                  green: Int(components.green * 255),
                                  blue: Int(components.blue * 255))
                }
            )
            .frame(height: 240)
        }
    }

    private var sp105eColorPreviewView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("SELECTED COLOR")
                .font(.caption.bold())
                .foregroundColor(.white)
                .tracking(1)

            Rectangle()
                .fill(Color(red: sp105eRed/255, green: sp105eGreen/255, blue: sp105eBlue/255))
                .frame(height: 50)
                .cornerRadius(8)
        }
    }

    private var sp105eModeView: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("EFFECT MODE")
                    .font(.caption.bold())
                    .foregroundColor(.white)
                    .tracking(1)

                Spacer()

                Button(action: toggleModeCycling) {
                    Text(isCycling ? "Stop Cycle" : "Auto Cycle")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(isCycling ? Color.red : Color.blue)
                        .cornerRadius(6)
                }
            }

            HStack {
                Button(action: previousMode) {
                    Image(systemName: "chevron.left")
                        .font(.title2.bold())
                        .frame(width: 45, height: 45)
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
                .frame(height: 45)
                .background(Color(hex: "3a3a3a"))
                .cornerRadius(8)
                .onChange(of: selectedMode) { newValue in
                    if newValue > 0 {
                        groupManager.setMode(newValue, selectedOnly: selectedSP105EDevices)
                    }
                }

                Button(action: nextMode) {
                    Image(systemName: "chevron.right")
                        .font(.title2.bold())
                        .frame(width: 45, height: 45)
                        .background(Color.orange)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
            }

            if isCycling {
                Text("Cycling modes every 15 seconds...")
                    .font(.caption)
                    .foregroundColor(.orange)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private var sp105eBrightnessView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("BRIGHTNESS")
                .font(.caption.bold())
                .foregroundColor(.white)
                .tracking(1)

            HStack {
                Button(action: decreaseBrightness) {
                    Text("-")
                        .font(.title.bold())
                        .frame(width: 45, height: 45)
                        .background(Color.orange)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }

                Slider(value: $brightness, in: 0...255, step: 1)
                    .tint(.orange)
                    .onChange(of: brightness) { newValue in
                        groupManager.setBrightnessAbsolute(Int(newValue), lastBrightness: lastBrightness, selectedOnly: selectedSP105EDevices)
                        lastBrightness = Int(newValue)
                    }

                Button(action: increaseBrightness) {
                    Text("+")
                        .font(.title.bold())
                        .frame(width: 45, height: 45)
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

    private var sp105eSpeedView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("EFFECT SPEED")
                .font(.caption.bold())
                .foregroundColor(.white)
                .tracking(1)

            HStack {
                Button(action: decreaseSpeed) {
                    Text("-")
                        .font(.title.bold())
                        .frame(width: 45, height: 45)
                        .background(Color.orange)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }

                Slider(value: $speed, in: 0...255, step: 1)
                    .tint(.orange)

                Button(action: increaseSpeed) {
                    Text("+")
                        .font(.title.bold())
                        .frame(width: 45, height: 45)
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

    private var sp105eFavoriteModesView: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("FAVORITE MODES")
                    .font(.caption.bold())
                    .foregroundColor(.white)
                    .tracking(1)

                Spacer()

                Text("Long press empty slot to save")
                    .font(.caption2)
                    .foregroundColor(.gray)
            }

            // Row 1: Slots 1-3
            HStack(spacing: 4) {
                ForEach(0..<3, id: \.self) { slot in
                    favoriteModeButton(slot: slot)
                }
            }

            // Row 2: Slots 4-6
            HStack(spacing: 4) {
                ForEach(3..<6, id: \.self) { slot in
                    favoriteModeButton(slot: slot)
                }
            }
        }
    }

    private func favoriteModeButton(slot: Int) -> some View {
        Group {
            if sp105eFavoriteModes[slot] != -1 {
                Text(SP105EProtocol.modeNames[safe: sp105eFavoriteModes[slot]] ?? "Mode \(sp105eFavoriteModes[slot])")
                    .font(.caption2)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 40)
                    .background(Color.orange)
                    .cornerRadius(4)
                    .lineLimit(1)
            } else {
                Rectangle()
                    .fill(Color(hex: "3a3a3a"))
                    .frame(height: 40)
                    .cornerRadius(4)
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [4]))
                            .foregroundColor(.gray)
                    )
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            if sp105eFavoriteModes[slot] != -1 {
                applySP105EFavoriteMode(slot: slot)
            }
        }
        .onLongPressGesture(minimumDuration: 0.5) {
            if sp105eFavoriteModes[slot] != -1 {
                // Existing mode - show options to replace or delete
                selectedSP105EModeSlot = slot
                showingSP105EModeOptions = true
            } else if selectedMode > 0 {
                // Empty slot and valid mode selected - save it
                saveSP105EFavoriteMode(slot: slot)
            }
        }
    }

    private var sp105eDeviceSelectionView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("SELECT DEVICES")
                .font(.caption.bold())
                .foregroundColor(.white)
                .tracking(1)

            ForEach(sp105eDevices) { device in
                HStack {
                    Button(action: {
                        if selectedSP105EDevices.contains(device.address) {
                            selectedSP105EDevices.remove(device.address)
                        } else {
                            selectedSP105EDevices.insert(device.address)
                        }
                    }) {
                        Image(systemName: selectedSP105EDevices.contains(device.address) ? "checkmark.square.fill" : "square")
                            .foregroundColor(selectedSP105EDevices.contains(device.address) ? .cyan : .gray)
                    }

                    Text(device.displayName)
                        .font(.subheadline)
                        .foregroundColor(.white)

                    Spacer()
                }
                .padding(.vertical, 2)
            }
        }
    }

    // MARK: - Actions

    private func initializeState() {
        // Initialize selected devices with all devices in each category
        selectedDemonEyeDevices = Set(pwmDevices.map { $0.address })
        selectedSP105EDevices = Set(sp105eDevices.map { $0.address })
    }

    private func toggleConnection() {
        if groupManager.isAnyConnected {
            stopModeCycling()
            groupManager.disconnectAll()
        } else {
            groupManager.connectAll(devices: devices, knownPeripherals: bleManager.discoveredPeripherals)
        }
    }

    private func togglePower() {
        isPowerOn.toggle()
        groupManager.togglePower(turnOn: isPowerOn)
    }

    // Demon Eye actions
    private func setDemonEyeColor(red: Int, green: Int, blue: Int) {
        demonEyeRed = Double(red)
        demonEyeGreen = Double(green)
        demonEyeBlue = Double(blue)
        groupManager.setColor(red: red, green: green, blue: blue, selectedOnly: selectedDemonEyeDevices)
    }

    private func saveDemonEyeFavoriteColor(slot: Int) {
        let packedColor = DeviceItem.packColor(red: Int(demonEyeRed), green: Int(demonEyeGreen), blue: Int(demonEyeBlue))
        demonEyeFavoriteColors[slot] = packedColor
    }

    private func applyDemonEyeFavoriteColor(slot: Int) {
        guard demonEyeFavoriteColors[slot] != -1 else { return }
        let (r, g, b) = DeviceItem.unpackColor(demonEyeFavoriteColors[slot])
        setDemonEyeColor(red: r, green: g, blue: b)
    }

    private func deleteDemonEyeFavoriteColor(slot: Int) {
        demonEyeFavoriteColors[slot] = -1
    }

    // SP105E actions
    private func setSP105EColor(red: Int, green: Int, blue: Int) {
        sp105eRed = Double(red)
        sp105eGreen = Double(green)
        sp105eBlue = Double(blue)
        selectedMode = 0
        groupManager.setColor(red: red, green: green, blue: blue, selectedOnly: selectedSP105EDevices)
    }

    private func previousMode() {
        stopModeCycling()
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
        let oldBrightness = Int(brightness)
        brightness = min(255, brightness + 25)
        groupManager.setBrightnessAbsolute(Int(brightness), lastBrightness: oldBrightness, selectedOnly: selectedSP105EDevices)
        lastBrightness = Int(brightness)
    }

    private func decreaseBrightness() {
        let oldBrightness = Int(brightness)
        brightness = max(0, brightness - 25)
        groupManager.setBrightnessAbsolute(Int(brightness), lastBrightness: oldBrightness, selectedOnly: selectedSP105EDevices)
        lastBrightness = Int(brightness)
    }

    private func increaseSpeed() {
        speed = min(255, speed + 25)
        groupManager.increaseSpeed(selectedOnly: selectedSP105EDevices)
    }

    private func decreaseSpeed() {
        speed = max(0, speed - 25)
        groupManager.decreaseSpeed(selectedOnly: selectedSP105EDevices)
    }

    private func saveSP105EFavoriteMode(slot: Int) {
        guard selectedMode > 0 else { return }
        sp105eFavoriteModes[slot] = selectedMode
    }

    private func applySP105EFavoriteMode(slot: Int) {
        guard sp105eFavoriteModes[slot] != -1 else { return }
        stopModeCycling()
        selectedMode = sp105eFavoriteModes[slot]
        groupManager.setMode(selectedMode, selectedOnly: selectedSP105EDevices)
    }

    private func deleteSP105EFavoriteMode(slot: Int) {
        sp105eFavoriteModes[slot] = -1
    }

    // Mode Cycling
    private func toggleModeCycling() {
        if isCycling {
            stopModeCycling()
        } else {
            startModeCycling()
        }
    }

    private func startModeCycling() {
        isCycling = true
        selectedMode = 1
        groupManager.setMode(1, selectedOnly: selectedSP105EDevices)

        cycleTimer = Timer.scheduledTimer(withTimeInterval: cycleInterval, repeats: true) { _ in
            DispatchQueue.main.async {
                if self.isCycling {
                    self.nextMode()
                    self.groupManager.setMode(self.selectedMode, selectedOnly: self.selectedSP105EDevices)
                }
            }
        }
    }

    private func stopModeCycling() {
        isCycling = false
        cycleTimer?.invalidate()
        cycleTimer = nil
    }
}

// MARK: - Array Safe Subscript

extension Array {
    subscript(safe index: Int) -> Element? {
        return indices.contains(index) ? self[index] : nil
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
                        This screen lets you control all devices in the group. Controls only appear when ALL devices are connected.
                        """)

                    helpSection(title: "DEMON EYE SECTION", content: """
                        • Controls PWM LED devices (non-addressable)
                        • Quick colors for instant color changes
                        • Custom color wheel (tap Show to reveal)
                        • Save up to 6 favorite colors
                        • Select which devices receive commands
                        """)

                    helpSection(title: "LED STRIP SECTION", content: """
                        • Controls addressable LED strip devices
                        • Full color wheel always visible
                        • 50+ effect modes with Auto Cycle
                        • Brightness and speed controls
                        • Save up to 6 favorite modes
                        • Select which devices receive commands
                        """)

                    helpSection(title: "DEVICE SELECTION", content: """
                        • Each section has its own device checkboxes
                        • Only checked devices receive commands
                        • Uncheck devices to exclude them
                        """)

                    helpSection(title: "IMPORTANT", content: """
                        ⚠️ Controls only appear when ALL devices are connected!

                        ⚠️ Maximum 4 devices per group recommended due to iOS BLE limits.
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
