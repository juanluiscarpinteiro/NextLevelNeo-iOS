import SwiftUI

struct GroupListView: View {
    @EnvironmentObject var dataStore: DataStore
    @Environment(\.dismiss) var dismiss

    @State private var showingCreateGroup = false
    @State private var showingHelp = false
    @State private var newGroupName = ""
    @State private var selectedGroup: DeviceGroup?
    @State private var showingGroupOptions = false
    @State private var showingEditDevices = false
    @State private var showingRenameGroup = false
    @State private var showingDeleteConfirm = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                headerView

                // Content
                ScrollView {
                    VStack(spacing: 16) {
                        // Status
                        statusView

                        // Create button
                        createButton

                        // Groups list
                        groupsSection
                    }
                    .padding()
                }
            }
        }
        .navigationBarHidden(true)
        .alert("Create Group", isPresented: $showingCreateGroup) {
            TextField("Group name", text: $newGroupName)
            Button("Cancel", role: .cancel) { newGroupName = "" }
            Button("Next") { createGroup() }
        }
        .alert("Rename Group", isPresented: $showingRenameGroup) {
            TextField("Group name", text: $newGroupName)
            Button("Cancel", role: .cancel) { }
            Button("Save") { renameGroup() }
        }
        .alert("Delete Group", isPresented: $showingDeleteConfirm) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) { deleteGroup() }
        } message: {
            Text("Delete \"\(selectedGroup?.name ?? "")\"? This will not delete the devices themselves.")
        }
        .confirmationDialog("Group Options", isPresented: $showingGroupOptions, presenting: selectedGroup) { group in
            Button("Edit Devices") { showingEditDevices = true }
            Button("Rename") {
                newGroupName = group.name
                showingRenameGroup = true
            }
            Button("Delete", role: .destructive) { showingDeleteConfirm = true }
            Button("Cancel", role: .cancel) { }
        }
        .sheet(isPresented: $showingEditDevices) {
            if let group = selectedGroup {
                EditGroupDevicesView(group: group)
                    .environmentObject(dataStore)
            }
        }
        .sheet(isPresented: $showingHelp) {
            GroupHelpView()
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

            Text("Device Groups")
                .font(.headline)
                .foregroundColor(.white)

            Spacer()

            Button(action: { showingHelp = true }) {
                Image(systemName: "info.circle")
                    .font(.title3)
                    .foregroundColor(.white)
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

    // MARK: - Status

    private var statusView: some View {
        Text(dataStore.groups.isEmpty
             ? "No groups yet. Create one to control multiple devices together."
             : "\(dataStore.groups.count) group(s)")
            .font(.subheadline)
            .foregroundColor(.gray)
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color(hex: "1a1a1a"))
            .cornerRadius(8)
    }

    // MARK: - Create Button

    private var createButton: some View {
        Button(action: { showingCreateGroup = true }) {
            Text("Create New Group")
                .fontWeight(.bold)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(Color.orange)
                .foregroundColor(.white)
                .cornerRadius(8)
        }
    }

    // MARK: - Groups Section

    private var groupsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("MY GROUPS")
                .font(.caption.bold())
                .foregroundColor(Color(hex: "FF6B35"))
                .tracking(1)

            if dataStore.groups.isEmpty {
                Text("No groups yet")
                    .foregroundColor(.gray)
                    .frame(maxWidth: .infinity, minHeight: 100)
                    .background(Color(hex: "1a1a1a"))
                    .cornerRadius(8)
            } else {
                LazyVStack(spacing: 1) {
                    ForEach(dataStore.groups) { group in
                        NavigationLink(destination: GroupControlView(group: group)) {
                            GroupRowView(
                                group: group,
                                onMenuTapped: {
                                    selectedGroup = group
                                    showingGroupOptions = true
                                }
                            )
                        }
                        .disabled(group.deviceCount == 0)
                    }
                }
                .background(Color(hex: "1a1a1a"))
                .cornerRadius(8)
            }
        }
    }

    // MARK: - Actions

    private func createGroup() {
        guard !newGroupName.isEmpty else { return }
        let group = dataStore.addGroup(name: newGroupName)
        newGroupName = ""
        selectedGroup = group
        showingEditDevices = true
    }

    private func renameGroup() {
        guard let group = selectedGroup, !newGroupName.isEmpty else { return }
        dataStore.renameGroup(id: group.id, newName: newGroupName)
        newGroupName = ""
    }

    private func deleteGroup() {
        guard let group = selectedGroup else { return }
        dataStore.deleteGroup(id: group.id)
        selectedGroup = nil
    }
}

// MARK: - Group Row

struct GroupRowView: View {
    let group: DeviceGroup
    let onMenuTapped: () -> Void

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: "rectangle.3.group")
                .font(.title)
                .foregroundColor(.orange)
                .frame(width: 48, height: 48)

            VStack(alignment: .leading, spacing: 4) {
                Text(group.name)
                    .font(.headline)
                    .foregroundColor(.white)

                Text(group.deviceCountText)
                    .font(.caption)
                    .foregroundColor(.gray)
            }

            Spacer()

            Button(action: onMenuTapped) {
                Image(systemName: "ellipsis")
                    .font(.title3)
                    .foregroundColor(.white)
                    .frame(width: 40, height: 40)
            }

            Image(systemName: "chevron.right")
                .foregroundColor(.gray)
        }
        .padding()
        .background(Color(hex: "252525"))
    }
}

// MARK: - Edit Group Devices

struct EditGroupDevicesView: View {
    @EnvironmentObject var dataStore: DataStore
    @Environment(\.dismiss) var dismiss

    let group: DeviceGroup
    @State private var selectedAddresses: Set<String>

    init(group: DeviceGroup) {
        self.group = group
        _selectedAddresses = State(initialValue: Set(group.deviceAddresses))
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                if dataStore.devices.isEmpty {
                    VStack {
                        Text("No devices available")
                            .foregroundColor(.gray)
                        Text("Scan for devices first")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                } else {
                    List(dataStore.devices) { device in
                        Button(action: { toggleDevice(device) }) {
                            HStack {
                                Image(systemName: selectedAddresses.contains(device.address)
                                      ? "checkmark.circle.fill" : "circle")
                                    .foregroundColor(selectedAddresses.contains(device.address)
                                                    ? .green : .gray)

                                VStack(alignment: .leading) {
                                    Text(device.displayName)
                                        .foregroundColor(.white)
                                    Text(device.address.prefix(17))
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                }

                                Spacer()
                            }
                        }
                        .listRowBackground(Color(hex: "252525"))
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
            }
            .navigationTitle("Select Devices")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") { saveChanges() }
                        .fontWeight(.bold)
                }
            }
        }
    }

    private func toggleDevice(_ device: DeviceItem) {
        if selectedAddresses.contains(device.address) {
            selectedAddresses.remove(device.address)
        } else {
            selectedAddresses.insert(device.address)
        }
    }

    private func saveChanges() {
        if selectedAddresses.count > 4 {
            // Show warning but still allow
            print("Warning: Groups with more than 4 devices may have connection issues")
        }
        dataStore.setGroupDevices(groupId: group.id, deviceAddresses: Array(selectedAddresses))
        dismiss()
    }
}

// MARK: - Group Help View

struct GroupHelpView: View {
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    helpSection(title: "DEVICE GROUPS", content: """
                        Groups let you control multiple LED controllers at once. All commands (color, mode, brightness, speed) are sent to every device in the group simultaneously.
                        """)

                    helpSection(title: "CREATING A GROUP", content: """
                        1. Tap "Create New Group"
                        2. Enter a name for your group
                        3. Select which devices to include
                        """)

                    helpSection(title: "USING A GROUP", content: """
                        Tap a group to open the control screen. The app will connect to all devices and you can control them together.
                        """)

                    helpSection(title: "MANAGING GROUPS", content: """
                        Tap the menu icon (•••) on a group to:
                        • Edit which devices are in the group
                        • Rename the group
                        • Delete the group
                        """)

                    helpSection(title: "IMPORTANT NOTES", content: """
                        • Maximum 4 devices per group is recommended for reliable connections
                        • iOS has BLE connection limits
                        • Groups with more devices may experience connection issues
                        • Deleting a group does NOT delete the devices themselves
                        """)
                }
                .padding()
            }
            .background(Color.black)
            .navigationTitle("Groups Help")
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
