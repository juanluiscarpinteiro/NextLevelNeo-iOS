# NLN Flow Controller - iOS

iOS version of the Next Level Neo LED Controller app for SP105E/SP110E LED strip controllers.

## Features

- **Device Scanning**: Scan for SP105E, SP110E, and compatible LED controllers
- **Single Device Control**: Full control of individual LED controllers
  - Color wheel for custom colors
  - Quick color presets
  - 50+ effect modes
  - Brightness and speed controls
  - Power toggle
- **Device Groups**: Control multiple LED controllers simultaneously
  - Create and manage groups
  - Send commands to all devices at once
  - Individual connection status per device
- **Persistent Storage**: Saves devices, groups, and settings

## Requirements

- iOS 16.0+
- Xcode 15.0+
- iPhone with Bluetooth LE (Simulator does not support BLE)
- SP105E/SP110E LED controller

## Setup Instructions

### 1. Create Xcode Project

1. Open Xcode
2. File → New → Project
3. Select **iOS → App**
4. Configure:
   - Product Name: `NextLevelNeo`
   - Organization Identifier: `com.nextlevelneo`
   - Interface: **SwiftUI**
   - Language: **Swift**
   - Uncheck "Include Tests"
5. Choose location and create

### 2. Add Source Files

1. Delete the auto-generated `ContentView.swift` and `NextLevelNeoApp.swift`
2. Drag all folders from this repo into your Xcode project:
   - `App/`
   - `Models/`
   - `Bluetooth/`
   - `Database/`
   - `Views/`
3. Make sure "Copy items if needed" is checked
4. Select "Create groups" for folders

### 3. Configure Info.plist

Add these keys to your Info.plist (or use the provided one):

```xml
<key>NSBluetoothAlwaysUsageDescription</key>
<string>This app uses Bluetooth to connect to and control your LED strip controllers.</string>

<key>NSBluetoothPeripheralUsageDescription</key>
<string>This app uses Bluetooth to connect to and control your LED strip controllers.</string>

<key>UIBackgroundModes</key>
<array>
    <string>bluetooth-central</string>
</array>

<key>UIRequiredDeviceCapabilities</key>
<array>
    <string>bluetooth-le</string>
</array>
```

### 4. Add App Icon (Optional)

1. Add your app icon to `Assets.xcassets`
2. Add a logo image named `next_level_neo_logo` for the header

### 5. Build and Run

1. Connect your iPhone
2. Select your device as the run target
3. Build and run (⌘R)

## Project Structure

```
NextLevelNeo/
├── App/
│   └── NextLevelNeoApp.swift      # App entry point
├── Models/
│   ├── DeviceItem.swift           # Device model
│   └── DeviceGroup.swift          # Group model
├── Bluetooth/
│   ├── BLEManager.swift           # Single device BLE manager
│   ├── GroupConnectionManager.swift # Multi-device BLE manager
│   └── SP105EProtocol.swift       # LED controller commands
├── Database/
│   └── DataStore.swift            # Persistent storage
├── Views/
│   ├── ContentView.swift          # Main navigation
│   ├── DeviceListView.swift       # Device list screen
│   ├── DeviceControlView.swift    # Single device control
│   ├── GroupListView.swift        # Group list screen
│   ├── GroupControlView.swift     # Group control screen
│   ├── HelpView.swift             # Help dialog
│   ├── SettingsView.swift         # Settings screen
│   └── Components/
│       └── ColorWheelView.swift   # Color picker component
└── Info.plist                     # App configuration
```

## SP105E Protocol

The app uses the following command format:

| Command | Bytes |
|---------|-------|
| Set Color | `0x38 RR GG BB 0x1E` |
| Set Mode | `0x38 MODE 0x00 0x00 0x2C 0x83` |
| Brightness Up | `0x38 0x00 0x00 0x00 0x2A 0x83` |
| Brightness Down | `0x38 0x00 0x00 0x00 0x28 0x83` |
| Speed Up | `0x38 0x00 0x00 0x00 0x03 0x83` |
| Speed Down | `0x38 0x00 0x00 0x00 0x09 0x83` |
| Power Toggle | `0x38 0x00 0x00 0x00 0xAA 0x83` |
| RGB Mode | `0x38 0x02 0xE2 0x94 0x1C` |
| RGBW Mode | `0x38 0x06 0x1C 0x7F 0x1C` |

BLE Service: `FFE0`
BLE Characteristic: `FFE1`

## Group Control Notes

- Maximum 4 devices per group recommended (iOS BLE limitation)
- Do NOT change strip type (RGB/RGBW) in group mode
- Groups work even if some devices fail to connect

## License

Copyright © Next Level Neo

## Links

- Website: [www.nextlevelneo.com](https://www.nextlevelneo.com)
- Android App: [NextLevelNeo Android](https://github.com/juanluiscarpinteiro/NextLevelNeo)
