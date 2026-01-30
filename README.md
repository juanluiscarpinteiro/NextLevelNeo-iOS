# NLN Flow Controller - iOS

iOS version of the Next Level Neo LED Controller app for SP105E/SP110E and BanlanX (SP63x/SP64x) LED strip controllers.

## Features

- **Device Scanning**: Scan for SP105E, SP110E, BanlanX, and compatible LED controllers
- **Multi-Protocol Support**: Automatic protocol detection for different controller types
  - SP105E/SP110E: Addressable RGB/RGBW LED strips with 50+ effect modes
  - BanlanX (SP63x/SP64x): PWM RGB/RGBW controllers for non-addressable strips
- **Single Device Control**: Full control of individual LED controllers
  - Color wheel for custom colors
  - Quick color presets
  - 50+ effect modes (SP105E only)
  - Brightness and speed controls
  - Power toggle
- **Device Groups**: Control multiple LED controllers simultaneously
  - Create and manage groups
  - Send commands to all devices at once
  - Mixed protocol support (SP105E + BanlanX in same group)
  - Individual connection status per device
- **Persistent Storage**: Saves devices, groups, and settings

## Supported Controllers

| Controller | Protocol | Features |
|------------|----------|----------|
| SP105E | SP105E | Addressable LEDs, 50+ modes, brightness, speed |
| SP110E | SP105E | Addressable LEDs, 50+ modes, brightness, speed |
| SP100 | SP105E | Addressable LEDs, 50+ modes, brightness, speed |
| SP630E-SP639E | BanlanX | PWM RGB, 9 colors, brightness levels |
| SP640E-SP64AE | BanlanX | PWM RGBW, 9 colors, brightness levels |

## Requirements

- iOS 16.0+
- Xcode 15.0+
- iPhone with Bluetooth LE (Simulator does not support BLE)
- Compatible LED controller (SP105E, SP110E, SP63x, SP64x)

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
│   ├── DeviceItem.swift           # Device model with controller type
│   └── DeviceGroup.swift          # Group model
├── Bluetooth/
│   ├── BLEManager.swift           # Single device BLE manager
│   ├── GroupConnectionManager.swift # Multi-device BLE manager
│   ├── LEDProtocol.swift          # Protocol interface & factory
│   ├── SP105EProtocol.swift       # SP105E protocol implementation
│   └── BanlanXProtocol.swift      # BanlanX protocol implementation
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

## LED Controller Protocols

### Common BLE Settings
- **Service UUID**: `FFE0`
- **Characteristic UUID**: `FFE1`

### SP105E Protocol

Used by SP105E, SP110E, and SP100 series addressable LED controllers.

| Command | Bytes | Write Type |
|---------|-------|------------|
| Set Color | `0x38 RR GG BB 0x1E` | With Response |
| Set Mode | `0x38 MODE 0x00 0x00 0x2C 0x83` | With Response |
| Brightness Up | `0x38 0x00 0x00 0x00 0x2A 0x83` | With Response |
| Brightness Down | `0x38 0x00 0x00 0x00 0x28 0x83` | With Response |
| Speed Up | `0x38 0x00 0x00 0x00 0x03 0x83` | With Response |
| Speed Down | `0x38 0x00 0x00 0x00 0x09 0x83` | With Response |
| Power Toggle | `0x38 0x00 0x00 0x00 0xAA 0x83` | With Response |
| RGB Mode | `0x38 0x02 0xE2 0x94 0x1C` | With Response |
| RGBW Mode | `0x38 0x06 0x1C 0x7F 0x1C` | With Response |

### BanlanX Protocol

Used by SP63x and SP64x series PWM RGB/RGBW controllers. Commands captured from BanlanX app via HCI snoop log.

**Frame Format**: `53 [CMD] [CHECKSUM] 01 00 [LEN] [DATA...]`
- CMD `0x50` = Power
- CMD `0x51` = Brightness
- CMD `0x52` = Color

| Command | Bytes | Write Type |
|---------|-------|------------|
| Power On | `53 50 5E 01 00 01 12` | Without Response |
| Power Off | `53 50 F4 01 00 01 B9` | Without Response |
| Red | `53 52 F6 01 00 04 44 BB BB 44` | Without Response |
| Green | `53 52 37 01 00 04 7A 85 7A 85` | Without Response |
| Blue | `53 52 83 01 00 04 CE CE 31 31` | Without Response |
| White | `53 52 B0 01 00 04 02 02 02 02` | Without Response |
| Yellow | `53 52 D1 01 00 04 63 63 9C 63` | Without Response |
| Cyan | `53 52 D0 01 00 04 9D 62 62 62` | Without Response |
| Magenta | `53 52 FE 01 00 04 4C B3 4C 4C` | Without Response |
| Orange | `53 52 E7 01 00 04 55 0C AE 55` | Without Response |
| Purple | `53 52 96 01 00 04 24 24 24 24` | Without Response |

**Brightness**: 10 discrete levels (captured commands with checksums)

**Note**: BanlanX controllers do not support effect modes or speed control (non-addressable LEDs)

## Group Control Notes

- Maximum 4 devices per group recommended (iOS BLE limitation)
- Do NOT change strip type (RGB/RGBW) in group mode
- Groups work even if some devices fail to connect
- Mixed protocol groups supported (SP105E + BanlanX in same group)
- Each device receives protocol-appropriate commands automatically
- BanlanX devices in groups will ignore mode/speed commands (not supported)

## License

Copyright © Next Level Neo

## Links

- Website: [www.nextlevelneo.com](https://www.nextlevelneo.com)
- Android App: [NextLevelNeo Android](https://github.com/juanluiscarpinteiro/NextLevelNeo)
