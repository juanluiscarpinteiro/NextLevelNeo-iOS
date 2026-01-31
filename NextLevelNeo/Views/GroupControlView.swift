import SwiftUI

struct GroupControlView: View {
    @EnvironmentObject var dataStore: DataStore
    @EnvironmentObject var bleManager: BLEManager
    @Environment(\.dismiss) var dismiss

    let group: DeviceGroup

    @StateObject private var groupManager = GroupConnectionManager()

    // Separate devices by type
    @State private var banlanXDevices: [DeviceItem] = []
    @State private var sp105eDevices: [DeviceItem] = []

    // Selection tracking (default: all selected)
    @State private var selectedBanlanXAddresses: Set<String> = []
    @State private var selectedSP105EAddresses: Set<String> = []

    // DEMON EYE state
    @State private var demonEyeColor = Color.white
    @State private var demonEyeRed: Double = 255
    @State private var demonEyeGreen: Double = 255
    @State private var demonEyeBlue: Double = 255
    @State private var isDemonEyeWheelExpanded = false
    @State private var demonEyeFavoriteColors: [Int] = Array(repeating: -1, count: 6)

    // SP105E state
    @State private var sp105eColor = Color.white
    @State private var sp105eRed: Double = 255
    @State private var sp105eGreen: Double = 255
    @State private var sp105eBlue: Double = 255
    @State private var sp105eBrightness: Double = 128
    @State private var sp105eLastBrightness: Int = 128
    @State private var sp105eSpeed: Double = 128
    @State private var sp105eSelectedMode: Int = 0
    @State private var sp105eFavoriteModes: [Int] = Array(repeating: -1, count: 6)

    // Common state
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

                        // DEMON EYE Section (BanlanX devices)
                        if !banlanXDevices.isEmpty {
                            demonEyeSection
                        }

                        // SP105E Section
                        if !sp105eDevices.isEmpty {
                            sp105eSection
                        }
                    }
                    .padding()
                }
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            separateDevicesByType()
            loadFavorites()
        }
        .onDisappear {
            groupManager.disconnectAll()
        }
        .sheet(isPresented: $showingHelp) {
            GroupControlHelpView()
        }
    }

    // MARK: - Device Separation

    private func separateDevicesByType() {
        let allDevices = dataStore.getDevicesInGroup(groupId: group.id)
        banlanXDevices = allDevices.filter { $0.controllerType == .banlanX }
        sp105eDevices = allDevices.filter { $0.controllerType == .sp105e }

        // Default: all selected
        selectedBanlanXAddresses = Set(banlanXDevices.map { $0.address })
        selectedSP105EAddresses = Set(sp105eDevices.map { $0.address })
    }

    private func loadFavorites() {
        // Load DEMON EYE favorites from first BanlanX device
        if let firstBanlanX = banlanXDevices.first {
            demonEyeFavoriteColors = firstBanlanX.favoriteColors
        }
        // Load SP105E favorites from first SP105E device
        if let firstSP105E = sp105eDevices.first {
            sp105eFavoriteModes = firstSP105E.favoriteModes
        }
    }

    private func saveDemonEyeFavorites() {
        guard let firstBanlanX = banlanXDevices.first else { return }
        dataStore.updateFavoriteColors(for: firstBanlanX.address, colors: demonEyeFavoriteColors, names: Array(repeating: nil, count: 6))
    }

    private func saveSP105EFavoriteModes() {
        guard let firstSP105E = sp105eDevices.first else { return }
        dataStore.updateFavoriteModes(for: firstSP105E.address, modes: sp105eFavoriteModes, names: Array(repeating: nil, count: 6))
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

                    Text(device.controllerType == .banlanX ? "DEMON EYE" : "LED STRIP")
                        .font(.caption2)
                        .foregroundColor(.gray)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color(hex: "3a3a3a"))
                        .cornerRadius(4)
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

    // MARK: - DEMON EYE Section

    private var demonEyeSection: some View {
        VStack(spacing: 0) {
            // Section header
            HStack {
                Text("DEMON EYE")
                    .font(.headline.bold())
                    .foregroundColor(.orange)
                Spacer()
            }
            .padding()
            .background(Color(hex: "2a2a2a"))

            VStack(spacing: 16) {
                // Quick Colors
                demonEyeQuickColors

                Divider().background(Color.gray)

                // Collapsible Color Wheel
                demonEyeColorWheelSection

                // Color Preview
                demonEyeColorPreview

                Divider().background(Color.gray)

                // Favorite Colors
                demonEyeFavoritesSection

                Divider().background(Color.gray)

                // Device Selection
                demonEyeDeviceSelection
            }
            .padding()
        }
        .background(Color(hex: "252525"))
        .cornerRadius(12)
        .opacity(groupManager.isAnyConnected ? 1 : 0.5)
        .disabled(!groupManager.isAnyConnected)
    }

    private var demonEyeQuickColors: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("QUICK COLORS")
                .font(.caption.bold())
                .foregroundColor(.white)
                .tracking(1)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(SP105EProtocol.quickColors, id: \.name) { color in
                        Button(action: {
                            setDemonEyeColor(red: Int(color.red), green: Int(color.green), blue: Int(color.blue))
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

    private var demonEyeColorWheelSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button(action: {
                withAnimation(.easeInOut(duration: 0.3)) {
                    isDemonEyeWheelExpanded.toggle()
                }
            }) {
                HStack {
                    Text("CUSTOM COLOR")
                        .font(.caption.bold())
                        .foregroundColor(.white)
                        .tracking(1)
                    Spacer()
                    Image(systemName: isDemonEyeWheelExpanded ? "chevron.up" : "chevron.down")
                        .foregroundColor(.orange)
                }
            }

            if isDemonEyeWheelExpanded {
                ColorWheelView(
                    selectedColor: $demonEyeColor,
                    onColorChanged: { color in
                        let components = color.components
                        setDemonEyeColor(red: Int(components.red * 255),
                                        green: Int(components.green * 255),
                                        blue: Int(components.blue * 255))
                    }
                )
                .frame(height: 250)
            }
        }
    }

    private var demonEyeColorPreview: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("SELECTED COLOR")
                .font(.caption.bold())
                .foregroundColor(.white)
                .tracking(1)

            Rectangle()
                .fill(Color(red: demonEyeRed/255, green: demonEyeGreen/255, blue: demonEyeBlue/255))
                .frame(height: 40)
                .cornerRadius(8)
        }
    }

    private var demonEyeFavoritesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("FAVORITE COLORS")
                .font(.caption.bold())
                .foregroundColor(.white)
                .tracking(1)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 6), spacing: 8) {
                ForEach(0..<6, id: \.self) { index in
                    demonEyeFavoriteSlot(index: index)
                }
            }
        }
    }

    private func demonEyeFavoriteSlot(index: Int) -> some View {
        let packed = demonEyeFavoriteColors[index]
        let hasColor = packed != -1

        return Button(action: {
            if hasColor {
                let (r, g, b) = DeviceItem.unpackColor(packed)
                setDemonEyeColor(red: r, green: g, blue: b)
            }
        }) {
            RoundedRectangle(cornerRadius: 8)
                .fill(hasColor ? Color(red: Double((packed >> 16) & 0xFF) / 255,
                                       green: Double((packed >> 8) & 0xFF) / 255,
                                       blue: Double(packed & 0xFF) / 255) : Color(hex: "3a3a3a"))
                .frame(height: 40)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                )
                .overlay(
                    !hasColor ? Image(systemName: "plus")
                        .foregroundColor(.gray) : nil
                )
        }
        .simultaneousGesture(
            LongPressGesture(minimumDuration: 0.5)
                .onEnded { _ in
                    // Save current color to favorite
                    let packed = DeviceItem.packColor(red: Int(demonEyeRed), green: Int(demonEyeGreen), blue: Int(demonEyeBlue))
                    demonEyeFavoriteColors[index] = packed
                    saveDemonEyeFavorites()
                }
        )
    }

    private var demonEyeDeviceSelection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("SELECT DEVICES")
                .font(.caption.bold())
                .foregroundColor(.white)
                .tracking(1)

            ForEach(banlanXDevices) { device in
                HStack {
                    Toggle(isOn: Binding(
                        get: { selectedBanlanXAddresses.contains(device.address) },
                        set: { isSelected in
                            if isSelected {
                                selectedBanlanXAddresses.insert(device.address)
                            } else {
                                selectedBanlanXAddresses.remove(device.address)
                            }
                        }
                    )) {
                        HStack {
                            Circle()
                                .fill(deviceStatusColor(for: device))
                                .frame(width: 8, height: 8)
                            Text(device.displayName)
                                .font(.subheadline)
                                .foregroundColor(.white)
                        }
                    }
                    .toggleStyle(CheckboxToggleStyle())
                }
            }
        }
    }

    // MARK: - SP105E Section

    private var sp105eSection: some View {
        VStack(spacing: 0) {
            // Section header
            HStack {
                Text("LED STRIP CONTROLLERS")
                    .font(.headline.bold())
                    .foregroundColor(.orange)
                Spacer()
            }
            .padding()
            .background(Color(hex: "2a2a2a"))

            VStack(spacing: 16) {
                // Quick Colors
                sp105eQuickColors

                Divider().background(Color.gray)

                // Color Wheel
                sp105eColorWheelSection

                // Color Preview
                sp105eColorPreview

                Divider().background(Color.gray)

                // Effect Mode
                sp105eModeSection

                Divider().background(Color.gray)

                // Brightness
                sp105eBrightnessSection

                Divider().background(Color.gray)

                // Speed
                sp105eSpeedSection

                Divider().background(Color.gray)

                // Favorite Modes
                sp105eFavoriteModesSection

                Divider().background(Color.gray)

                // Device Selection
                sp105eDeviceSelection
            }
            .padding()
        }
        .background(Color(hex: "252525"))
        .cornerRadius(12)
        .opacity(groupManager.isAnyConnected ? 1 : 0.5)
        .disabled(!groupManager.isAnyConnected)
    }

    private var sp105eQuickColors: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("QUICK COLORS")
                .font(.caption.bold())
                .foregroundColor(.white)
                .tracking(1)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(SP105EProtocol.quickColors, id: \.name) { color in
                        Button(action: {
                            setSP105EColor(red: Int(color.red), green: Int(color.green), blue: Int(color.blue))
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

    private var sp105eColorWheelSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("COLOR WHEEL")
                .font(.caption.bold())
                .foregroundColor(.white)
                .tracking(1)

            ColorWheelView(
                selectedColor: $sp105eColor,
                onColorChanged: { color in
                    let components = color.components
                    setSP105EColor(red: Int(components.red * 255),
                                  green: Int(components.green * 255),
                                  blue: Int(components.blue * 255))
                }
            )
            .frame(height: 250)
        }
    }

    private var sp105eColorPreview: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("SELECTED COLOR")
                .font(.caption.bold())
                .foregroundColor(.white)
                .tracking(1)

            Rectangle()
                .fill(Color(red: sp105eRed/255, green: sp105eGreen/255, blue: sp105eBlue/255))
                .frame(height: 40)
                .cornerRadius(8)
        }
    }

    private var sp105eModeSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("EFFECT MODE")
                .font(.caption.bold())
                .foregroundColor(.white)
                .tracking(1)

            HStack {
                Button(action: previousSP105EMode) {
                    Image(systemName: "chevron.left")
                        .font(.title2.bold())
                        .frame(width: 50, height: 50)
                        .background(Color.orange)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }

                Picker("Mode", selection: $sp105eSelectedMode) {
                    ForEach(0..<SP105EProtocol.modeNames.count, id: \.self) { index in
                        Text(SP105EProtocol.modeNames[index]).tag(index)
                    }
                }
                .pickerStyle(.menu)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(Color(hex: "3a3a3a"))
                .cornerRadius(8)
                .onChange(of: sp105eSelectedMode) { _, newValue in
                    if newValue > 0 {
                        groupManager.setModeToSelected(selectedSP105EAddresses, mode: newValue)
                    }
                }

                Button(action: nextSP105EMode) {
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

    private var sp105eBrightnessSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("BRIGHTNESS")
                .font(.caption.bold())
                .foregroundColor(.white)
                .tracking(1)

            HStack {
                Button(action: decreaseSP105EBrightness) {
                    Text("-")
                        .font(.title.bold())
                        .frame(width: 50, height: 50)
                        .background(Color.orange)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }

                Slider(value: $sp105eBrightness, in: 0...255, step: 1)
                    .tint(.orange)
                    .onChange(of: sp105eBrightness) { oldValue, newValue in
                        groupManager.setBrightnessToSelected(selectedSP105EAddresses, brightness: Int(newValue), lastBrightness: sp105eLastBrightness)
                        sp105eLastBrightness = Int(newValue)
                    }

                Button(action: increaseSP105EBrightness) {
                    Text("+")
                        .font(.title.bold())
                        .frame(width: 50, height: 50)
                        .background(Color.orange)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
            }

            Text("\(Int(sp105eBrightness * 100 / 255))%")
                .foregroundColor(.orange)
                .frame(maxWidth: .infinity)
        }
    }

    private var sp105eSpeedSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("EFFECT SPEED")
                .font(.caption.bold())
                .foregroundColor(.white)
                .tracking(1)

            HStack {
                Button(action: decreaseSP105ESpeed) {
                    Text("-")
                        .font(.title.bold())
                        .frame(width: 50, height: 50)
                        .background(Color.orange)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }

                Slider(value: $sp105eSpeed, in: 0...255, step: 1)
                    .tint(.orange)

                Button(action: increaseSP105ESpeed) {
                    Text("+")
                        .font(.title.bold())
                        .frame(width: 50, height: 50)
                        .background(Color.orange)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
            }

            Text("\(Int(sp105eSpeed * 100 / 255))%")
                .foregroundColor(.orange)
                .frame(maxWidth: .infinity)
        }
    }

    private var sp105eFavoriteModesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("FAVORITE MODES")
                .font(.caption.bold())
                .foregroundColor(.white)
                .tracking(1)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
                ForEach(0..<6, id: \.self) { index in
                    sp105eFavoriteModeSlot(index: index)
                }
            }
        }
    }

    private func sp105eFavoriteModeSlot(index: Int) -> some View {
        let mode = sp105eFavoriteModes[index]
        let hasMode = mode != -1

        return Button(action: {
            if hasMode {
                sp105eSelectedMode = mode
                groupManager.setModeToSelected(selectedSP105EAddresses, mode: mode)
            }
        }) {
            RoundedRectangle(cornerRadius: 8)
                .fill(hasMode ? Color.orange.opacity(0.3) : Color(hex: "3a3a3a"))
                .frame(height: 50)
                .overlay(
                    Text(hasMode ? SP105EProtocol.modeNames[safe: mode] ?? "Mode \(mode)" : "+")
                        .font(.caption)
                        .foregroundColor(hasMode ? .white : .gray)
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                        .padding(4)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.orange.opacity(hasMode ? 0.5 : 0.2), lineWidth: 1)
                )
        }
        .simultaneousGesture(
            LongPressGesture(minimumDuration: 0.5)
                .onEnded { _ in
                    // Save current mode to favorite
                    if sp105eSelectedMode > 0 {
                        sp105eFavoriteModes[index] = sp105eSelectedMode
                        saveSP105EFavoriteModes()
                    }
                }
        )
    }

    private var sp105eDeviceSelection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("SELECT DEVICES")
                .font(.caption.bold())
                .foregroundColor(.white)
                .tracking(1)

            ForEach(sp105eDevices) { device in
                HStack {
                    Toggle(isOn: Binding(
                        get: { selectedSP105EAddresses.contains(device.address) },
                        set: { isSelected in
                            if isSelected {
                                selectedSP105EAddresses.insert(device.address)
                            } else {
                                selectedSP105EAddresses.remove(device.address)
                            }
                        }
                    )) {
                        HStack {
                            Circle()
                                .fill(deviceStatusColor(for: device))
                                .frame(width: 8, height: 8)
                            Text(device.displayName)
                                .font(.subheadline)
                                .foregroundColor(.white)
                        }
                    }
                    .toggleStyle(CheckboxToggleStyle())
                }
            }
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

    // DEMON EYE Actions
    private func setDemonEyeColor(red: Int, green: Int, blue: Int) {
        demonEyeRed = Double(red)
        demonEyeGreen = Double(green)
        demonEyeBlue = Double(blue)
        groupManager.setColorToSelected(selectedBanlanXAddresses, red: red, green: green, blue: blue)
    }

    // SP105E Actions
    private func setSP105EColor(red: Int, green: Int, blue: Int) {
        sp105eRed = Double(red)
        sp105eGreen = Double(green)
        sp105eBlue = Double(blue)
        sp105eSelectedMode = 0
        groupManager.setColorToSelected(selectedSP105EAddresses, red: red, green: green, blue: blue)
    }

    private func previousSP105EMode() {
        if sp105eSelectedMode > 1 {
            sp105eSelectedMode -= 1
        } else {
            sp105eSelectedMode = SP105EProtocol.modeNames.count - 1
        }
    }

    private func nextSP105EMode() {
        if sp105eSelectedMode < SP105EProtocol.modeNames.count - 1 {
            sp105eSelectedMode += 1
        } else {
            sp105eSelectedMode = 1
        }
    }

    private func increaseSP105EBrightness() {
        let oldBrightness = Int(sp105eBrightness)
        sp105eBrightness = min(255, sp105eBrightness + 25)
        groupManager.setBrightnessToSelected(selectedSP105EAddresses, brightness: Int(sp105eBrightness), lastBrightness: oldBrightness)
        sp105eLastBrightness = Int(sp105eBrightness)
    }

    private func decreaseSP105EBrightness() {
        let oldBrightness = Int(sp105eBrightness)
        sp105eBrightness = max(0, sp105eBrightness - 25)
        groupManager.setBrightnessToSelected(selectedSP105EAddresses, brightness: Int(sp105eBrightness), lastBrightness: oldBrightness)
        sp105eLastBrightness = Int(sp105eBrightness)
    }

    private func increaseSP105ESpeed() {
        sp105eSpeed = min(255, sp105eSpeed + 25)
        groupManager.increaseSpeedToSelected(selectedSP105EAddresses)
    }

    private func decreaseSP105ESpeed() {
        sp105eSpeed = max(0, sp105eSpeed - 25)
        groupManager.decreaseSpeedToSelected(selectedSP105EAddresses)
    }
}

// MARK: - Checkbox Toggle Style

struct CheckboxToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        Button(action: {
            configuration.isOn.toggle()
        }) {
            HStack {
                Image(systemName: configuration.isOn ? "checkmark.square.fill" : "square")
                    .foregroundColor(configuration.isOn ? .orange : .gray)
                    .font(.title3)
                configuration.label
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Safe Array Access

extension Array {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
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
                        This screen lets you control devices in your group. Devices are separated by controller type:

                        • DEMON EYE: BanlanX/SP63x controllers (color only)
                        • LED STRIP CONTROLLERS: SP105E controllers (full control)
                        """)

                    helpSection(title: "DEVICE SELECTION", content: """
                        Each section has checkboxes at the bottom to select which devices receive commands.

                        • By default, all devices are selected
                        • Uncheck devices to exclude them from commands
                        • Commands only go to checked devices
                        """)

                    helpSection(title: "FAVORITE COLORS (DEMON EYE)", content: """
                        • Tap a favorite slot to apply that color
                        • Long-press a slot to save the current color
                        • Favorites are shared across all DEMON EYE devices in the group
                        """)

                    helpSection(title: "FAVORITE MODES (LED STRIP)", content: """
                        • Tap a favorite slot to apply that mode
                        • Long-press a slot to save the current mode
                        • Favorites are shared across all LED STRIP devices in the group
                        """)

                    helpSection(title: "IMPORTANT WARNINGS", content: """
                        ⚠️ Maximum 4 devices per group recommended
                        iOS has BLE connection limits. Groups with more than 4 devices may experience connection drops.

                        ⚠️ Power button controls ALL devices
                        The power button at the top affects all devices regardless of checkbox selections.
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
