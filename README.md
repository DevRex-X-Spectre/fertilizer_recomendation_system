# SoilSense

> On-device soil testing and fertilizer recommendation app for Nigerian farmers growing maize and rice.

## Overview

SoilSense connects to a custom Bluetooth soil-testing hardware device to read NPK, pH, salinity, and moisture values directly from the field. Based on those readings and the farmer's selected crop, the app generates specific fertilizer recommendations (type + kg/ha) and agronomic suggestions — all without an internet connection, no account required.

## Features

- **BLE device connection** — scan, pair, and communicate with your custom SoilSense hardware
- **Soil test** — trigger a reading, view live sensor values
- **Fertilizer recommendations** — hardcoded agronomic engine for Nigerian maize and rice, based on FMARD/IAR standards (Urea, NPK 15-15-15, NPK 20-10-10, SSP, MOP, lime)
- **Agronomic suggestions** — pH amendment, salinity management, irrigation advice
- **Field management** — create named fields with crop assignment
- **Field history + trend charts** — NPK trend lines per field over time
- **Local-first** — all data stored on-device in SQLite via Drift, no server

## Crops Supported

- 🌽 Maize
- 🌾 Rice

## Sensors

- Nitrogen (N) — ppm
- Phosphorus (P) — ppm
- Potassium (K) — ppm
- pH
- Salinity (EC) — dS/m
- Moisture — %

## Architecture

| Layer | Technology |
|---|---|
| UI | Flutter + Material 3 |
| State | Riverpod |
| Database | Drift (SQLite) |
| BLE | flutter_blue_plus |
| Charts | fl_chart |
| Engine | Hardcoded Dart (no server/config) |

## Project Structure

```
lib/
├── main.dart                      # App shell + bottom nav
├── core/
│   └── theme.dart                 # Material 3 agricultural theme
├── data/
│   ├── models.dart                # Domain models (SensorValues, Crop, etc.)
│   ├── database.dart              # Drift schema
│   └── providers.dart             # Riverpod DB provider
├── engine/
│   └── recommendation_engine.dart # Agronomic rules for maize + rice
├── ble/
│   └── ble_service.dart           # BLE scan/connect/parse wrapper
└── features/
    ├── fields/                    # Field list + add field
    ├── device/                    # BLE connect + run test + results gate
    ├── results/                   # Sensor values + recommendations
    └── history/                   # Per-field history + NPK trend chart
```

## Getting Started

### Prerequisites

- Flutter 3.12+
- Android SDK 36+
- Android device with BLE support (or emulator)

### Setup

```bash
# Clone the repo
git clone https://github.com/DevRex-X-Spectre/fertilizer_recomendation_system.git
cd fertilizer_recomendation_system

# Get dependencies
flutter pub get

# Generate Drift database code
dart run build_runner build

# Run on connected device
flutter run

# Build release APK
flutter build apk --release
```

### Hardware Integration

The BLE GATT profile is defined as placeholders in `lib/ble/ble_service.dart`. Update these with the values from your hardware designer:

```dart
final _serviceUuid       = Guid('0000ffe0-0000-1000-8000-00805f9b34fb');
final _characteristicUuid = Guid('0000ffe1-0000-1000-8000-00805f9b34fb');
```

Expected byte frame format (12 bytes):
```
[0]  Header (0xAA)
[1-2] Nitrogen (ppm × 10, little-endian)
[3-4] Phosphorus (ppm × 10, little-endian)
[5-6] Potassium (ppm × 10, little-endian)
[7]   pH (pH × 10)
[8-9] Salinity (EC × 100, little-endian)
[10]  Moisture (%)
[11]  Checksum (XOR bytes 0–10)
```

## Recommendation Engine

Rules are implemented in Dart in `lib/engine/recommendation_engine.dart`. Thresholds are based on FMARD/IAR Zaria recommended rates for Nigerian conditions. Threshold constants and fertilizer application rates are documented inline and can be tuned against calibrated soil samples.

## License

Private / All rights reserved.
