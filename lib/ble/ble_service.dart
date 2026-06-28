// lib/ble/ble_service.dart
// Bluetooth Low BLE service — wraps flutter_blue_plus.
//
// Identity model
// ──────────────
// The firmware on the SoilSense hardware MUST advertise one of these two
// signals so the app can recognise it:
//   • Service UUID: 0001abc0-0000-1000-8000-00805f9b34fb
//     (firmware: advertise this UUID in the advertisement packet)
//   • Device name prefix: "SoilSense-"
//     (firmware: set BLE device name to e.g. "SoilSense-A1")
//
// The app treats a device as "connectable" if either signal matches.
// Replace _soilsenseServiceUuid with the UUID your firmware team has chosen.
//
// GATT profile: replace _serviceUuid and _characteristicUuid with the
// values from your hardware designer.

import 'dart:async';
import 'dart:typed_data';

import 'package:collection/collection.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

import '../data/models.dart';

// ── SoilSense identity ────────────────────────────────────────────────────

/// Service UUID advertised by the SoilSense firmware in its BLE packet.
/// PRIMARY identity check. Replace this with the UUID your firmware team chose.
final _soilsenseServiceUuid =
    Guid('0001abc0-0000-1000-8000-00805f9b34fb');

/// Secondary identity check. Firmware should set its BLE device name to
/// something starting with this prefix (e.g. "SoilSense-A1").
const _soilsenseNamePrefix = 'SoilSense-';

// ── GATT profile (data characteristic) ────────────────────────────────────

final _serviceUuid = Guid('0000ffe0-0000-1000-8000-00805f9b34fb');
final _characteristicUuid = Guid('0000ffe1-0000-1000-8000-00805f9b34fb');

// ── Connection state ────────────────────────────────────────────────────────

enum BleConnectionState {
  idle,
  scanning,
  connecting,
  connected,
  discovering,
  reading,
  error,
}

// ── Discovered device (visible on radar) ────────────────────────────────────

/// One device found during scanning. Built from a flutter_blue_plus ScanResult.
class DiscoveredDevice {
  final BluetoothDevice device;
  final String id;             // MAC address
  final String name;
  final int rssi;              // signal strength, typically -100..0 dBm
  final List<Guid> advertisedServiceUuids;
  final bool isSoilSense;      // computed at scan time
  final String? manufacturerDataHex;

  const DiscoveredDevice({
    required this.device,
    required this.id,
    required this.name,
    required this.rssi,
    required this.advertisedServiceUuids,
    required this.isSoilSense,
    this.manufacturerDataHex,
  });

  /// Deterministic angle (radians, 0..2π) from the device id — same device
  /// always lands at the same spot on the radar between rescans.
  double radarAngle() {
    var hash = 0;
    for (final code in id.codeUnits) {
      hash = (hash * 31 + code) & 0x7fffffff;
    }
    return (hash % 3600) / 3600.0 * 2 * 3.141592653589793;
  }

  /// Radius (0..1) from RSSI. Stronger signal (closer to 0) = smaller radius.
  /// -40 dBm ≈ 0.30, -90 dBm ≈ 0.95.
  double radarRadius() {
    final clamped = rssi.clamp(-100, -30);
    final normalized = (clamped + 100) / 70.0; // 0..1 (1 = strongest)
    return 0.30 + (1 - normalized) * 0.65;
  }
}

// ── BLE state ───────────────────────────────────────────────────────────────

class BleState {
  final BleConnectionState connectionState;
  final String? deviceName;
  final String? errorMessage;
  final SensorValues? lastReading;
  final bool isReadingInProgress;
  final List<DiscoveredDevice> discoveredDevices;

  /// Current Bluetooth adapter state. Reflects the real adapter at all times
  /// because the notifier subscribes to FlutterBluePlus.adapterState and
  /// keeps this in sync. UI should read this instead of asking the adapter
  /// directly so it rebuilds on changes.
  final BluetoothAdapterState adapterState;

  const BleState({
    this.connectionState = BleConnectionState.idle,
    this.deviceName,
    this.errorMessage,
    this.lastReading,
    this.isReadingInProgress = false,
    this.discoveredDevices = const [],
    this.adapterState = BluetoothAdapterState.unknown,
  });

  bool get bluetoothOn => adapterState == BluetoothAdapterState.on;

  /// True when the adapter is permanently unable to scan/connect
  /// (e.g. BLE is unsupported on this device).
  bool get bluetoothUnavailable =>
      adapterState == BluetoothAdapterState.unavailable;

  /// True when the user must be prompted to turn Bluetooth on
  /// (off or currently turning on).
  bool get bluetoothOffOrTransitioning =>
      adapterState == BluetoothAdapterState.off ||
      adapterState == BluetoothAdapterState.turningOn ||
      adapterState == BluetoothAdapterState.turningOff ||
      adapterState == BluetoothAdapterState.unknown;

  BleState copyWith({
    BleConnectionState? connectionState,
    String? deviceName,
    String? errorMessage,
    SensorValues? lastReading,
    bool? isReadingInProgress,
    List<DiscoveredDevice>? discoveredDevices,
    BluetoothAdapterState? adapterState,
  }) {
    return BleState(
      connectionState: connectionState ?? this.connectionState,
      deviceName: deviceName ?? this.deviceName,
      errorMessage: errorMessage ?? this.errorMessage,
      lastReading: lastReading ?? this.lastReading,
      isReadingInProgress: isReadingInProgress ?? this.isReadingInProgress,
      discoveredDevices: discoveredDevices ?? this.discoveredDevices,
      adapterState: adapterState ?? this.adapterState,
    );
  }
}

// ── Identity helpers ────────────────────────────────────────────────────────

bool isSoilSenseScanResult(ScanResult r) {
  return isSoilSenseIdentity(
    name: r.device.platformName,
    advertisedServiceUuids: r.advertisementData.serviceUuids,
  );
}

bool isSoilSenseIdentity({
  required String name,
  required List<Guid> advertisedServiceUuids,
}) {
  if (advertisedServiceUuids.contains(_soilsenseServiceUuid)) return true;
  if (name.startsWith(_soilsenseNamePrefix)) return true;
  return false;
}

DiscoveredDevice discoveredDeviceFromScanResult(ScanResult r) {
  return DiscoveredDevice(
    device: r.device,
    id: r.device.remoteId.str,
    name: r.device.platformName.isNotEmpty
        ? r.device.platformName
        : '(unnamed)',
    rssi: r.rssi,
    advertisedServiceUuids: r.advertisementData.serviceUuids,
    isSoilSense: isSoilSenseScanResult(r),
    manufacturerDataHex: r.advertisementData.manufacturerData.isNotEmpty
        ? r.advertisementData.manufacturerData.entries
            .map((e) =>
                '${e.key.toRadixString(16).padLeft(4, '0')}: '
                '${e.value.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ')}')
            .join(' | ')
        : null,
  );
}

// ── BLE notifier ────────────────────────────────────────────────────────────

class BleStateNotifier extends StateNotifier<BleState> {
  BleStateNotifier() : super(BleState(adapterState: FlutterBluePlus.adapterStateNow)) {
    // Keep state.adapterState in sync with the OS. UI rebuilds when this
    // fires because Riverpod watches BleState.
    _adapterSubscription = FlutterBluePlus.adapterState.listen((s) {
      state = state.copyWith(adapterState: s);
    });
  }

  StreamSubscription<List<ScanResult>>? _scanSubscription;
  StreamSubscription<BluetoothConnectionState>? _deviceSubscription;
  StreamSubscription<List<int>>? _charSubscription;
  StreamSubscription<BluetoothAdapterState>? _adapterSubscription;
  Timer? _scanTimeoutTimer;
  Timer? _readingTimer;

  BluetoothDevice? _connectedDevice;
  int _retryCount = 0;
  static const _maxRetries = 2;

  // ── Public API ─────────────────────────────────────────────────────────

  /// Read Bluetooth on/off from the synced state so it stays consistent
  /// across rebuilds. Prefer checking state.bluetoothOn through the UI.
  bool get isBluetoothOn => state.bluetoothOn;

  /// Request the runtime permissions Android requires to scan + connect
  /// over BLE. On Android 12+ these are BLUETOOTH_SCAN and
  /// BLUETOOTH_CONNECT (both "runtime" — not auto-granted on install).
  /// On older Android we also ask for fine location because BLE scanning
  /// requires it.
  ///
  /// Returns true when all required permissions are granted.
  Future<bool> requestPermissions() async {
    // On Android 12+ BLUETOOTH_SCAN implies location capability,
    // so no separate location permission is needed for scanning.
    // On Android 11 and below, location is required for BLE scanning.
    final permissions = <Permission>[
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.locationWhenInUse,
    ];

    final results = await permissions.request();

    final scanGranted = results[Permission.bluetoothScan]?.isGranted ?? true;
    final connectGranted = results[Permission.bluetoothConnect]?.isGranted ?? true;

    if (!scanGranted || !connectGranted) {
      final missing = <String>[];
      if (!scanGranted) missing.add('Nearby devices (Bluetooth scan)');
      if (!connectGranted) missing.add('Bluetooth connection');
      _setError(
        'SoilSense needs these permissions to find your device:\n'
        '• ${missing.join('\n• ')}\n\n'
        'Open Settings → Apps → SoilSense → Permissions and grant them.',
      );
      return false;
    }
    return true;
  }

  /// Open the system Bluetooth settings so the user can toggle it on
  /// manually. On Android this is the BLUETOOTH_SETTINGS screen; the user
  /// toggles the switch there, then comes back to the app. The
  /// adapterState stream will fire when BT actually turns on, which
  /// rebuilds the UI reactively.
  ///
  /// Note: we deliberately do NOT use FlutterBluePlus.turnOn() here —
  /// on Android 10+ it shows an ACTION_REQUEST_ENABLE system dialog,
  /// but many devices have it disabled. Opening the settings page is
  /// the most reliable path.
  Future<void> openBluetoothSettings() async {
    await FlutterBluePlus.turnOn();
  }

  /// Begin scanning. Devices are collected into state.discoveredDevices
  /// as advertisements arrive. The scan does NOT auto-connect — the user
  /// picks a device from the radar / list, opens its details, then taps
  /// Connect (only enabled for SoilSense devices).
  Future<void> startScan({Duration timeout = const Duration(seconds: 15)}) async {
    // Android 12+ requires BLUETOOTH_SCAN at runtime. Without it,
    // FlutterBluePlus.startScan throws and the user sees a generic
    // "Couldn't connect" error. Request first.
    final permsOk = await requestPermissions();
    if (!permsOk) return;

    if (!isBluetoothOn) {
      _setError('Bluetooth is turned off. Please enable it and try again.');
      return;
    }

    // Always cancel any prior scan first so we don't leak subscriptions
    // or have two streams racing into state.
    await _stopScanSilently();

    // Reset state for a fresh scan.
    state = state.copyWith(
      connectionState: BleConnectionState.scanning,
      discoveredDevices: const [],
      errorMessage: null,
    );
    _retryCount = 0;

    // IMPORTANT: subscribe to scanResults BEFORE calling startScan.
    // FlutterBluePlus buffers results into a single stream that's emitted
    // incrementally, but if we await startScan before subscribing we miss
    // the burst of advertisements that arrive during the start handshake.
    _scanSubscription = FlutterBluePlus.scanResults.listen(
      _onScanResults,
      onError: (Object e) {
        _setError('Scan error: $e');
      },
    );

    try {
      await FlutterBluePlus.startScan(timeout: timeout);
    } catch (e) {
      _setError('Scan failed: $e');
      _scanSubscription?.cancel();
      _scanSubscription = null;
      return;
    }

    _scanTimeoutTimer?.cancel();
    _scanTimeoutTimer = Timer(timeout, () {
      // Auto-stop after the timeout: keep whatever devices we already
      // collected, but move out of "scanning" so the UI shows a Stop
      // button affordance and the user knows new results won't arrive.
      if (state.connectionState != BleConnectionState.scanning) return;
      _scanSubscription?.cancel();
      _scanSubscription = null;
      FlutterBluePlus.stopScan();
      state = state.copyWith(
        connectionState: BleConnectionState.idle,
        errorMessage:
            state.discoveredDevices.isEmpty
                ? 'No devices found. Make sure your SoilSense probe is on '
                    'and nearby, then try again.'
                : null,
      );
    });
  }

  /// Internal helper — cancels subscriptions/timer without changing state.
  Future<void> _stopScanSilently() async {
    _scanSubscription?.cancel();
    _scanSubscription = null;
    _scanTimeoutTimer?.cancel();
    _scanTimeoutTimer = null;
    try {
      if (FlutterBluePlus.isScanningNow) {
        await FlutterBluePlus.stopScan();
      }
    } catch (_) {
      // Best-effort. Even if stopScan throws, we've already cancelled
      // our subscription so no more results will reach state.
    }
  }

  void _onScanResults(List<ScanResult> results) {
    // Dedupe by MAC address, keeping the highest RSSI observed.
    final byId = <String, DiscoveredDevice>{};
    for (final r in results) {
      final dev = discoveredDeviceFromScanResult(r);
      final existing = byId[dev.id];
      if (existing == null || dev.rssi > existing.rssi) {
        byId[dev.id] = dev;
      }
    }
    final list = byId.values.toList()
      // SoilSense first, then by signal strength.
      ..sort((a, b) {
        if (a.isSoilSense != b.isSoilSense) return a.isSoilSense ? -1 : 1;
        return b.rssi.compareTo(a.rssi);
      });

    state = state.copyWith(discoveredDevices: list);
  }

  /// User-initiated connection. Called from the device details screen
  /// after the user taps Connect. Validates that the device is recognised
  /// as a SoilSense device before attempting connection. NEVER called
  /// automatically — the scan flow only populates the radar/list; the user
  /// must explicitly tap a ping, open details, then tap Connect.
  Future<void> connectToDevice(BluetoothDevice device) async {
    // Cancel any ongoing scan so we don't keep collecting pings during
    // the connection handshake.
    _scanSubscription?.cancel();
    _scanTimeoutTimer?.cancel();
    await FlutterBluePlus.stopScan();

    // Find the discovered record for this device to know if it's SoilSense.
    final dev = state.discoveredDevices.firstWhereOrNull(
      (d) => d.id == device.remoteId.str,
    );
    final isSoilSense = dev?.isSoilSense ?? false;

    if (!isSoilSense) {
      _setError(
        'This device is not a SoilSense hardware. '
        'Only SoilSense devices can be connected.',
      );
      return;
    }

    // Confirm runtime permissions are still granted (user may have revoked
    // them in Settings between scan and connect).
    final permsOk = await requestPermissions();
    if (!permsOk) return;

    if (!isBluetoothOn) {
      _setError('Bluetooth was turned off. Please turn it on and try again.');
      return;
    }

    state = state.copyWith(
      connectionState: BleConnectionState.connecting,
      deviceName: device.platformName.isNotEmpty
          ? device.platformName
          : '(unnamed)',
      errorMessage: null,
    );

    _retryCount = 0;
    await _connectWithRetry(device);
  }

  Future<void> _connectWithRetry(BluetoothDevice device) async {
    try {
      await device.connect(timeout: const Duration(seconds: 10));
      _connectedDevice = device;

      _deviceSubscription = device.connectionState.listen((connState) {
        if (connState == BluetoothConnectionState.disconnected) {
          state = state.copyWith(
            connectionState: BleConnectionState.idle,
            deviceName: null,
          );
          _cleanup();
        }
      });

      state = state.copyWith(
        connectionState: BleConnectionState.discovering,
        deviceName: device.platformName.isNotEmpty
            ? device.platformName
            : '(unnamed)',
      );

      await _discoverAndRead(device);
    } catch (e) {
      if (_retryCount < _maxRetries) {
        _retryCount++;
        state = state.copyWith(
          connectionState: BleConnectionState.connecting,
          errorMessage:
              'Connection failed (attempt $_retryCount of $_maxRetries). Retrying…',
        );
        await Future.delayed(const Duration(seconds: 2));
        await _connectWithRetry(device);
      } else {
        _setError(
          'Could not connect to ${device.platformName.isNotEmpty ? device.platformName : "device"}. '
          'Make sure it is on and nearby.',
        );
      }
    }
  }

  Future<void> _discoverAndRead(BluetoothDevice device) async {
    try {
      final services = await device.discoverServices();

      // Find our service.
      BluetoothService? soilService = services.firstWhereOrNull(
        (s) => s.uuid == _serviceUuid,
      );
      soilService ??= services.firstWhereOrNull(
        (s) => s.characteristics.any(
          (c) => c.properties.notify || c.properties.read,
        ),
      );

      if (soilService == null) {
        _setError('No compatible BLE service found on this device.');
        return;
      }

      var char = soilService.characteristics.firstWhereOrNull(
        (c) => c.uuid == _characteristicUuid,
      );
      char ??= soilService.characteristics.firstWhereOrNull(
        (c) => c.properties.notify || c.properties.read,
      );

      if (char == null) {
        _setError('No readable characteristic found.');
        return;
      }

      state = state.copyWith(connectionState: BleConnectionState.connected);

      if (char.properties.notify) {
        await char.setNotifyValue(true);
        _charSubscription = char.lastValueStream.listen((data) {
          final result = _parseFrame(data);
          if (result != null) {
            state = state.copyWith(lastReading: result);
          }
        });
      }

      if (char.properties.read) {
        await _triggerReadingAndWait(char);
      }
    } catch (e) {
      _setError('Discover error: $e');
    }
  }

  Future<void> triggerReading() async {
    if (_connectedDevice == null) {
      state = state.copyWith(errorMessage: 'No device connected.');
      return;
    }

    try {
      final services = await _connectedDevice!.discoverServices();
      BluetoothCharacteristic? char;

      for (final svc in services) {
        char = svc.characteristics.firstWhereOrNull(
          (c) => c.uuid == _characteristicUuid,
        );
        char ??= svc.characteristics.firstWhereOrNull(
          (c) => c.properties.notify || c.properties.write,
        );
        if (char != null) break;
      }

      if (char == null) {
        state = state.copyWith(errorMessage: 'Characteristic not found for write.');
        return;
      }

      if (char.properties.write) {
        await char.write([0x01], withoutResponse: false);
      }

      state = state.copyWith(isReadingInProgress: true);

      _readingTimer?.cancel();
      _readingTimer = Timer(const Duration(seconds: 10), () {
        if (state.isReadingInProgress) {
          state = state.copyWith(
            isReadingInProgress: false,
            errorMessage: 'Reading timed out. Try again.',
          );
        }
      });
    } catch (e) {
      state = state.copyWith(
        isReadingInProgress: false,
        errorMessage: 'Trigger error: $e',
      );
    }
  }

  Future<void> _triggerReadingAndWait(BluetoothCharacteristic char) async {
    state = state.copyWith(isReadingInProgress: true);

    if (char.properties.write) {
      await char.write([0x01], withoutResponse: false);
    }

    _readingTimer?.cancel();
    _readingTimer = Timer(const Duration(seconds: 10), () {
      if (state.isReadingInProgress) {
        state = state.copyWith(
          isReadingInProgress: false,
          errorMessage:
              'Sensor reading timed out. Make sure the device is actively '
              'sampling and within range.',
        );
      }
    });
  }

  Future<void> disconnect() async {
    await _connectedDevice?.disconnect();
    _cleanup();
    state = const BleState(connectionState: BleConnectionState.idle);
  }

  /// Stop scanning but keep whatever devices have been discovered so far.
  /// Safe to call even if no scan is in progress.
  Future<void> stopScan() async {
    await _stopScanSilently();
    // Move out of scanning state but keep the discovered list so the
    // user can still tap a previously-seen device.
    if (state.connectionState == BleConnectionState.scanning) {
      state = state.copyWith(
        connectionState: BleConnectionState.idle,
        errorMessage: null,
      );
    }
  }

  void clearError() {
    state = state.copyWith(errorMessage: null);
  }

  void _setError(String message) {
    state = state.copyWith(
      connectionState: BleConnectionState.error,
      errorMessage: message,
    );
  }

  // ── Frame parser ────────────────────────────────────────────────────────
  // TODO (hardware integration): Confirm the byte layout with your hardware team.
  //
  // Expected frame (12 bytes, little-endian):
  //   [0]  = Header (0xAA)
  //   [1]  = Nitrogen high byte   (ppm * 10, e.g. 145 = 14.5 ppm)
  //   [2]  = Nitrogen low byte
  //   [3]  = Phosphorus high byte
  //   [4]  = Phosphorus low byte
  //   [5]  = Potassium high byte
  //   [6]  = Potassium low byte
  //   [7]  = pH value (pH * 10, e.g. 62 = 6.2)
  //   [8]  = Salinity high byte   (dS/m * 100)
  //   [9]  = Salinity low byte
  //   [10] = Moisture byte        (0–100 %)
  //   [11] = Checksum (XOR of bytes 0–10)

  SensorValues? _parseFrame(List<int> data) {
    if (data.length < 12) return null;
    try {
      final bytes = Uint8List.fromList(data);
      if (bytes[0] != 0xAA) return null;

      final n  = _bytesToDouble(bytes[1], bytes[2]) / 10.0;
      final p  = _bytesToDouble(bytes[3], bytes[4]) / 10.0;
      final k  = _bytesToDouble(bytes[5], bytes[6]) / 10.0;
      final ph = bytes[7] / 10.0;
      final ec = _bytesToDouble(bytes[8], bytes[9]) / 100.0;
      final m  = bytes[10].toDouble();

      final values = SensorValues(
        nitrogen: n,
        phosphorus: p,
        potassium: k,
        ph: ph,
        salinity: ec,
        moisture: m,
      );
      state = state.copyWith(
        lastReading: values,
        isReadingInProgress: false,
      );
      return values;
    } catch (_) {
      return null;
    }
  }

  double _bytesToDouble(int high, int low) => (high << 8 | low).toDouble();

  void _cleanup() {
    _scanSubscription?.cancel();
    _deviceSubscription?.cancel();
    _charSubscription?.cancel();
    _adapterSubscription?.cancel();
    _scanTimeoutTimer?.cancel();
    _readingTimer?.cancel();
    _connectedDevice = null;
    _retryCount = 0;
  }

  @override
  void dispose() {
    _cleanup();
    super.dispose();
  }
}

// ── Provider ────────────────────────────────────────────────────────────────

final bleStateProvider = StateNotifierProvider<BleStateNotifier, BleState>(
  (ref) => BleStateNotifier(),
);
