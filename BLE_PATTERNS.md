# BLE Communication Patterns - iOS

## Critical: CoreBluetooth Best Practices

### iOS BLE Behavior

iOS CoreBluetooth handles BLE writes somewhat differently than Android:

1. **Write with Response (.withResponse)**: iOS queues these writes and handles them sequentially. Used by SP105E.

2. **Write without Response (.withoutResponse)**: These can potentially overflow if sent too quickly. Used by BanlanX.

### Command Delay Pattern

To ensure reliable command delivery, we use delays between commands when sending to multiple devices:

```swift
private var commandDelayMs: Double = 150  // Delay between sending to each device

func sendProtocolCommandToAll(_ commandGenerator: (LEDProtocol) -> Data?) {
    var delay: Double = 0

    for (identifier, characteristic) in characteristics {
        // ... validation code ...

        DispatchQueue.main.asyncAfter(deadline: .now() + delay / 1000) {
            peripheral.writeValue(command, for: characteristic, type: writeType)
        }
        delay += commandDelayMs
    }
}
```

### Protocol Write Types

| Controller | Write Type | Service UUID | Char UUID |
|------------|-----------|--------------|-----------|
| SP105E | .withResponse | FFE0 | FFE1 |
| BanlanX/SP634E | .withoutResponse | FFE0 | FFE1 |

### Files Using This Pattern

1. **GroupConnectionManager.swift** - Multi-device group control
   - Uses `commandDelayMs` (150ms) between device writes
   - `sendProtocolCommandToAll()` - sends to all connected devices
   - `sendCommandToSelected()` - sends to selected devices only

2. **BLEManager.swift** - Single device control
   - Uses throttling (50ms minimum between sends)
   - Uses correct write type per protocol

### Group Control Architecture

The group control separates devices by controller type:

```
GroupControlView
├── DEMON EYE Section (BanlanX devices)
│   ├── Quick Colors
│   ├── Collapsible Color Wheel
│   ├── Favorite Colors (6 slots)
│   └── Device Selection Checkboxes
└── LED STRIP CONTROLLERS Section (SP105E devices)
    ├── Quick Colors
    ├── Color Wheel
    ├── Effect Modes
    ├── Brightness Slider
    ├── Speed Slider
    ├── Favorite Modes (6 slots)
    └── Device Selection Checkboxes
```

### Connection Management

```swift
// Connect devices sequentially to avoid BLE congestion
private var connectionDelayMs: Double = 300

private func connectNextDevice() {
    // ... connect first device ...

    DispatchQueue.main.asyncAfter(deadline: .now() + connectionDelayMs / 1000) {
        self?.connectNextDevice()
    }
}
```

### iOS-Specific Limitations

1. **Maximum 7 simultaneous BLE connections** (may vary by iOS version/device)
2. **Recommend max 4 devices per group** for reliability
3. **BLE state restoration** available but not currently implemented

### Debugging

Use Xcode console or device logs to see:
- `[GroupManager] Sending to ...` - Command being sent
- `[GroupManager] Device X using Y protocol` - Protocol detection

---

**Last Updated:** January 2026
**Synced with:** Android BLE_PATTERNS.md
