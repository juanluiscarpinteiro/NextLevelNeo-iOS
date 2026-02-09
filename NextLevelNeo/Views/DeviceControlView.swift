import SwiftUI

struct DeviceControlView: View {
    @EnvironmentObject var dataStore: DataStore
    @EnvironmentObject var bleManager: BLEManager
    @Environment(\.dismiss) var dismiss

    let device: DeviceItem

    @State private var currentColor = Color.white
    @State private var currentRed: Double = 255
    @State private var currentGreen: Double = 255
    @State private var currentBlue: Double = 255
    @State private var brightness: Double = 128
    @State private var speed: Double = 128
    @State private var selectedMode: Int = 0
    @State private var isPowerOn = true
    @State private var showingHelp = false
    @State private var showingSettings = false
    @State private var showingDeleteConfirm = false
    @State private var showingRenameDialog = false
    @State private var newName = ""

    // Favorite colors
    @State private var favoriteColors: [Int] = Array(repeating: -1, count: 6)
    @State private var showingSaveFavoriteColorDialog = false
    @State private var showingFavoriteColorOptions = false
    @State private var selectedFavoriteColorSlot: Int = 0

    // Favorite modes
    @State private var favoriteModes: [Int] = Array(repeating: -1, count: 6)
    @State private var showingFavoriteModeOptions = false
    @State private var selectedFavoriteModeSlot: Int = 0

    var body: some View {
        ZStack {
            Color(hex: "0f0f0f").ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                headerView

                // Content
                if bleManager.isConnected {
                    ScrollView {
                        controlsView
                            .padding()
                    }
                } else {
                    disconnectedView
                }
            }
        }
        .navigationBarHidden(true)
        .onAppear(perform: loadDeviceState)
        .onDisappear(perform: saveAndDisconnect)
        .alert("Rename Device", isPresented: $showingRenameDialog) {
            TextField("Device name", text: $newName)
            Button("Cancel", role: .cancel) { }
            Button("Save") { renameDevice() }
        }
        .alert("Delete Device", isPresented: $showingDeleteConfirm) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) { deleteDevice() }
        } message: {
            Text("Are you sure you want to delete this device?")
        }
        .confirmationDialog("Save Color to Slot", isPresented: $showingSaveFavoriteColorDialog) {
            ForEach(0..<6, id: \.self) { slot in
                Button("Slot \(slot + 1)") {
                    saveFavoriteColor(slot: slot)
                }
            }
            Button("Cancel", role: .cancel) { }
        }
        .confirmationDialog("Favorite Color Options", isPresented: $showingFavoriteColorOptions) {
            Button("Delete") {
                deleteFavoriteColor(slot: selectedFavoriteColorSlot)
            }
            Button("Cancel", role: .cancel) { }
        }
        .confirmationDialog("Favorite Mode Options", isPresented: $showingFavoriteModeOptions) {
            Button("Replace with current mode") {
                saveFavoriteMode(slot: selectedFavoriteModeSlot)
            }
            Button("Delete") {
                deleteFavoriteMode(slot: selectedFavoriteModeSlot)
            }
            Button("Cancel", role: .cancel) { }
        }
        .sheet(isPresented: $showingHelp) {
            HelpView()
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView(device: device)
                .environmentObject(dataStore)
                .environmentObject(bleManager)
        }
    }

    // MARK: - Header

    private var headerView: some View {
        HStack {
            Button(action: { dismiss() }) {
                Image(systemName: "chevron.left")
                    .font(.title2)
                    .foregroundColor(.white)
            }

            Spacer()

            Text(device.displayName)
                .font(.headline)
                .foregroundColor(.white)

            Spacer()

            HStack(spacing: 8) {
                Button(action: { showingSettings = true }) {
                    Image(systemName: "gearshape")
                        .font(.title3)
                        .foregroundColor(.white)
                }

                Button(action: { showingHelp = true }) {
                    Image(systemName: "info.circle")
                        .font(.title3)
                        .foregroundColor(.white)
                }

                Button(action: togglePower) {
                    Image(systemName: "power")
                        .font(.title3)
                        .foregroundColor(isPowerOn ? .green : .gray)
                }
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

    // MARK: - Disconnected View

    private var disconnectedView: some View {
        VStack(spacing: 20) {
            // Status
            Text(connectionStatusText)
                .foregroundColor(connectionStatusColor)
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color(hex: "252525"))
                .cornerRadius(8)

            // Action buttons
            HStack(spacing: 12) {
                Button(action: connect) {
                    Text("Connect")
                        .fontWeight(.bold)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }

                Button(action: { showingRenameDialog = true; newName = device.displayName }) {
                    Text("Rename")
                        .fontWeight(.bold)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }

                Button(action: { showingDeleteConfirm = true }) {
                    Text("Delete")
                        .fontWeight(.bold)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Color.red)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
            }

            Spacer()
        }
        .padding()
    }

    // MARK: - Controls View

    private var controlsView: some View {
        VStack(spacing: 20) {
            // Quick Colors
            quickColorsSection

            Divider().background(Color.gray)

            // Favorite Colors
            favoriteColorsSection

            Divider().background(Color.gray)

            // Color Wheel
            colorWheelSection

            // Color Preview (long press to save)
            colorPreviewSection

            Divider().background(Color.gray)

            // Favorite Modes (only for SP105E)
            if device.supportsEffectModes {
                favoriteModesSection
                Divider().background(Color.gray)
            }

            // Mode Selection (grayed out for BanlanX)
            modeSection

            Divider().background(Color.gray)

            // Brightness
            brightnessSection

            // Speed (only for SP105E - has effect modes)
            if device.supportsSpeedControl {
                Divider().background(Color.gray)
                speedSection
            }
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

    // MARK: - Favorite Colors

    private var favoriteColorsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("FAVORITE COLORS")
                    .font(.caption.bold())
                    .foregroundColor(.white)
                    .tracking(1)

                Spacer()

                Text("Long press preview to save")
                    .font(.caption2)
                    .foregroundColor(.gray)
            }

            HStack(spacing: 8) {
                ForEach(0..<6, id: \.self) { slot in
                    Button(action: {
                        if favoriteColors[slot] != -1 {
                            applyFavoriteColor(slot: slot)
                        }
                    }) {
                        if favoriteColors[slot] != -1 {
                            let (r, g, b) = DeviceItem.unpackColor(favoriteColors[slot])
                            Circle()
                                .fill(Color(red: Double(r)/255, green: Double(g)/255, blue: Double(b)/255))
                                .frame(width: 44, height: 44)
                                .overlay(Circle().stroke(Color.white.opacity(0.3), lineWidth: 2))
                        } else {
                            Circle()
                                .fill(Color(hex: "3a3a3a"))
                                .frame(width: 44, height: 44)
                                .overlay(
                                    Circle()
                                        .strokeBorder(style: StrokeStyle(lineWidth: 2, dash: [4]))
                                        .foregroundColor(.gray)
                                )
                        }
                    }
                    .onLongPressGesture {
                        if favoriteColors[slot] != -1 {
                            selectedFavoriteColorSlot = slot
                            showingFavoriteColorOptions = true
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
                .fill(Color(red: currentRed/255, green: currentGreen/255, blue: currentBlue/255))
                .frame(height: 60)
                .cornerRadius(8)
                .onLongPressGesture {
                    showingSaveFavoriteColorDialog = true
                }
        }
    }

    // MARK: - Favorite Modes

    private var favoriteModesSection: some View {
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

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                ForEach(0..<6, id: \.self) { slot in
                    Button(action: {
                        if favoriteModes[slot] != -1 {
                            applyFavoriteMode(slot: slot)
                        }
                    }) {
                        if favoriteModes[slot] != -1 {
                            Text("Mode \(favoriteModes[slot])")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 36)
                                .background(Color.orange)
                                .cornerRadius(8)
                        } else {
                            Text("")
                                .frame(maxWidth: .infinity)
                                .frame(height: 36)
                                .background(Color(hex: "3a3a3a"))
                                .cornerRadius(8)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .strokeBorder(style: StrokeStyle(lineWidth: 2, dash: [4]))
                                        .foregroundColor(.gray)
                                )
                        }
                    }
                    .onLongPressGesture {
                        if favoriteModes[slot] != -1 {
                            selectedFavoriteModeSlot = slot
                            showingFavoriteModeOptions = true
                        } else {
                            // Empty slot - save current mode
                            if selectedMode > 0 {
                                saveFavoriteMode(slot: slot)
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Mode Section

    private var modeSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("EFFECT MODE")
                    .font(.caption.bold())
                    .foregroundColor(device.supportsEffectModes ? .white : .gray)
                    .tracking(1)

                if !device.supportsEffectModes {
                    Text("(Not available for this controller)")
                        .font(.caption2)
                        .foregroundColor(.gray)
                }
            }

            HStack {
                Button(action: previousMode) {
                    Image(systemName: "chevron.left")
                        .font(.title2.bold())
                        .frame(width: 50, height: 50)
                        .background(device.supportsEffectModes ? Color.orange : Color.gray.opacity(0.5))
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
                .disabled(!device.supportsEffectModes)

                Picker("Mode", selection: $selectedMode) {
                    ForEach(0..<SP105EProtocol.modeNames.count, id: \.self) { index in
                        Text(SP105EProtocol.modeNames[index]).tag(index)
                    }
                }
                .pickerStyle(.menu)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(device.supportsEffectModes ? Color(hex: "3a3a3a") : Color(hex: "2a2a2a"))
                .cornerRadius(8)
                .disabled(!device.supportsEffectModes)
                .opacity(device.supportsEffectModes ? 1.0 : 0.5)
                .onChange(of: selectedMode) { newValue in
                    if newValue > 0 && device.supportsEffectModes {
                        bleManager.setMode(newValue)
                    }
                }

                Button(action: nextMode) {
                    Image(systemName: "chevron.right")
                        .font(.title2.bold())
                        .frame(width: 50, height: 50)
                        .background(device.supportsEffectModes ? Color.orange : Color.gray.opacity(0.5))
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
                .disabled(!device.supportsEffectModes)
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
                    .onChange(of: brightness) { newValue in
                        // For BanlanX, send absolute brightness on slider change
                        if device.controllerType == .banlanX {
                            bleManager.setBrightnessAbsolute(Int(newValue))
                        }
                    }

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

    // MARK: - Computed Properties

    private var connectionStatusText: String {
        switch bleManager.connectionState {
        case .disconnected: return "Not Connected"
        case .connecting: return "Connecting..."
        case .connected: return "Connected"
        case .failed(let error): return "Failed: \(error)"
        }
    }

    private var connectionStatusColor: Color {
        switch bleManager.connectionState {
        case .disconnected: return .orange
        case .connecting: return .yellow
        case .connected: return .green
        case .failed: return .red
        }
    }

    // MARK: - Actions

    private func loadDeviceState() {
        // Load device from dataStore to get latest values
        if let savedDevice = dataStore.getDevice(address: device.address) {
            currentRed = Double(savedDevice.lastRed)
            currentGreen = Double(savedDevice.lastGreen)
            currentBlue = Double(savedDevice.lastBlue)
            brightness = Double(savedDevice.lastBrightness)
            speed = Double(savedDevice.lastSpeed)
            selectedMode = savedDevice.lastMode
            favoriteColors = savedDevice.favoriteColors
            favoriteModes = savedDevice.favoriteModes
        } else {
            currentRed = Double(device.lastRed)
            currentGreen = Double(device.lastGreen)
            currentBlue = Double(device.lastBlue)
            brightness = Double(device.lastBrightness)
            speed = Double(device.lastSpeed)
            selectedMode = device.lastMode
            favoriteColors = device.favoriteColors
            favoriteModes = device.favoriteModes
        }
    }

    private func saveAndDisconnect() {
        dataStore.saveDeviceState(
            address: device.address,
            brightness: Int(brightness),
            mode: selectedMode,
            speed: Int(speed),
            red: Int(currentRed),
            green: Int(currentGreen),
            blue: Int(currentBlue)
        )
        bleManager.disconnect()
    }

    private func connect() {
        bleManager.setProtocol(for: device)
        bleManager.connectToDevice(address: device.address)
    }

    private func togglePower() {
        isPowerOn.toggle()
        bleManager.togglePower()
    }

    private func setColor(red: Int, green: Int, blue: Int) {
        currentRed = Double(red)
        currentGreen = Double(green)
        currentBlue = Double(blue)
        selectedMode = 0  // Static color mode
        bleManager.setColor(red: red, green: green, blue: blue)
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
        if device.controllerType == .banlanX {
            bleManager.setBrightnessAbsolute(Int(brightness))
        } else {
            bleManager.increaseBrightness()
        }
    }

    private func decreaseBrightness() {
        brightness = max(0, brightness - 25)
        if device.controllerType == .banlanX {
            bleManager.setBrightnessAbsolute(Int(brightness))
        } else {
            bleManager.decreaseBrightness()
        }
    }

    private func increaseSpeed() {
        speed = min(255, speed + 25)
        bleManager.increaseSpeed()
    }

    private func decreaseSpeed() {
        speed = max(0, speed - 25)
        bleManager.decreaseSpeed()
    }

    private func renameDevice() {
        dataStore.renameDevice(address: device.address, newName: newName)
    }

    private func deleteDevice() {
        dataStore.deleteDevice(address: device.address)
        dismiss()
    }

    // MARK: - Favorite Colors Actions

    private func saveFavoriteColor(slot: Int) {
        let packedColor = DeviceItem.packColor(red: Int(currentRed), green: Int(currentGreen), blue: Int(currentBlue))
        favoriteColors[slot] = packedColor
        dataStore.saveFavoriteColor(deviceAddress: device.address, slot: slot, color: packedColor, name: nil)
    }

    private func applyFavoriteColor(slot: Int) {
        guard favoriteColors[slot] != -1 else { return }
        let (r, g, b) = DeviceItem.unpackColor(favoriteColors[slot])
        setColor(red: r, green: g, blue: b)
    }

    private func deleteFavoriteColor(slot: Int) {
        favoriteColors[slot] = -1
        dataStore.clearFavoriteColor(deviceAddress: device.address, slot: slot)
    }

    // MARK: - Favorite Modes Actions

    private func saveFavoriteMode(slot: Int) {
        guard selectedMode > 0 else { return }
        favoriteModes[slot] = selectedMode
        dataStore.saveFavoriteMode(deviceAddress: device.address, slot: slot, mode: selectedMode, name: nil)
    }

    private func applyFavoriteMode(slot: Int) {
        guard favoriteModes[slot] != -1 else { return }
        selectedMode = favoriteModes[slot]
        bleManager.setMode(selectedMode)
    }

    private func deleteFavoriteMode(slot: Int) {
        favoriteModes[slot] = -1
        dataStore.clearFavoriteMode(deviceAddress: device.address, slot: slot)
    }
}

// MARK: - Color Extension for Components

extension Color {
    var components: (red: Double, green: Double, blue: Double, alpha: Double) {
        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0

        UIColor(self).getRed(&r, green: &g, blue: &b, alpha: &a)
        return (Double(r), Double(g), Double(b), Double(a))
    }
}
