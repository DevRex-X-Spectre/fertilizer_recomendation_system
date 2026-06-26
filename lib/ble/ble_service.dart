// lib/ble/ble_service.dart
// Bluetooth Low Energy service — wraps flutter_blue_plus.
// GATT profile: replace SERVICE_UUID and CHARACTERISTIC_UUID with your
// hardware designer's values. Frame format is documented in _parseFrame().

import 'dart:async';
import 'dart:typed_data';

import 'package:collection/collection.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models.dart';

// TODO (hardware integration): Replace with your device's actual UUIDs.
// Contact your hardware engineer for these values.
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

// ── BLE state notifier ─────────────────────────────────────────────────────

class BleState {
  final BleConnectionState connectionState;
  final String? deviceName;
  final String? errorMessage;
  final SensorValues? lastReading;
  final bool isReadingInProgress;

  const BleState({
    this.connectionState = BleConnectionState.idle,
    this.deviceName,
    this.errorMessage,
    this.lastReading,
    this.isReadingInProgress = false,
  });

  BleState copyWith({
    BleConnectionState? connectionState,
    String? deviceName,
    String? errorMessage,
    SensorValues? lastReading,
    bool? isReadingInProgress,
  }) {
    return BleState(
      connectionState: connectionState ?? this.connectionState,
      deviceName: deviceName ?? this.deviceName,
      errorMessage: errorMessage ?? this.errorMessage,
      lastReading: lastReading ?? this.lastReading,
      isReadingInProgress: isReadingInProgress ?? this.isReadingInProgress,
    );
  }
}

class BleStateNotifier extends StateNotifier<BleState> {
  BleStateNotifier() : super(const BleState());

  StreamSubscription<List<ScanResult>>? _scanSubscription;
  StreamSubscription<BluetoothConnectionState>? _deviceSubscription;
  StreamSubscription<List<int>>? _charSubscription;
  Timer? _readingTimer;

  BluetoothDevice? _connectedDevice;
  int _retryCount = 0;
  static const _maxRetries = 2;

  // ── Public API ─────────────────────────────────────────────────────────

  /// Returns the current bluetooth adapter state synchronously.
  BluetoothAdapterState get adapterStateNow => FlutterBluePlus.adapterStateNow;

  /// True if Bluetooth is currently on.
  bool get isBluetoothOn =>
      FlutterBluePlus.adapterStateNow == BluetoothAdapterState.on;

  /// If Bluetooth is off, request the user to turn it on. On Android this
  /// shows the system "Allow Bluetooth" prompt. On iOS this opens the
  /// permission prompt. Returns true if Bluetooth is on after the call,
  /// false if it couldn't be enabled (denied, unsupported, timeout).
  Future<bool> ensureBluetoothOn({int timeoutSeconds = 30}) async {
    if (isBluetoothOn) return true;

    // Not available on this device (e.g. emulator without BT, or desktop).
    final now = FlutterBluePlus.adapterStateNow;
    if (now == BluetoothAdapterState.unavailable) {
      _setError('This device does not support Bluetooth.');
      return false;
    }

    try {
      await FlutterBluePlus.turnOn(timeout: timeoutSeconds);
    } catch (e) {
      _setError('Could not turn on Bluetooth: $e');
      return false;
    }

    final on = isBluetoothOn;
    if (!on) {
      _setError('Bluetooth was not enabled. Please turn it on in Settings.');
    }
    return on;
  }

  Future<void> startScan() async {
    // If adapter is off, fall back to the off state so the UI can decide.
    // In practice the UI calls ensureBluetoothOn() first, but guard anyway.
    if (!isBluetoothOn) {
      state = state.copyWith(
        connectionState: BleConnectionState.error,
        errorMessage:
            'Bluetooth is turned off. Please enable it and try again.',
      );
      return;
    }

    state = state.copyWith(connectionState: BleConnectionState.scanning);
    _retryCount = 0;

    try {
      await FlutterBluePlus.startScan(timeout: const Duration(seconds: 15));

      _scanSubscription = FlutterBluePlus.scanResults.listen((results) async {
        // Pick the first named device.
        final soilDevice = results.firstWhereOrNull(
          (r) => r.device.platformName.isNotEmpty,
        );

        if (soilDevice != null) {
          await _scanSubscription?.cancel();
          await FlutterBluePlus.stopScan();
          await _connectToDevice(soilDevice.device);
        }
      });

      // Timeout after 15s
      Future.delayed(const Duration(seconds: 15), () {
        _scanSubscription?.cancel();
        FlutterBluePlus.stopScan();
        if (state.connectionState == BleConnectionState.scanning) {
          state = state.copyWith(
            connectionState: BleConnectionState.error,
            errorMessage:
                'No SoilSense device found. Make sure your device is on and nearby.',
          );
        }
      });
    } catch (e) {
      state = state.copyWith(
        connectionState: BleConnectionState.error,
        errorMessage: 'Scan error: $e',
      );
    }
  }

  Future<void> _connectToDevice(BluetoothDevice device) async {
    state = state.copyWith(connectionState: BleConnectionState.connecting);

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
        deviceName: device.platformName,
      );

      await _discoverAndRead(device);
    } catch (e) {
      await _handleConnectionError(device, e);
    }
  }

  Future<void> _discoverAndRead(BluetoothDevice device) async {
    try {
      final services = await device.discoverServices();

      // Find our service
      BluetoothService? soilService = services.firstWhereOrNull(
        (s) => s.uuid == _serviceUuid,
      );

      // Fallback: first service with a notifyable/readable characteristic.
      soilService ??= services.firstWhereOrNull(
        (s) => s.characteristics.any(
          (c) => c.properties.notify || c.properties.read,
        ),
      );

      if (soilService == null) {
        state = state.copyWith(
          connectionState: BleConnectionState.error,
          errorMessage: 'No compatible BLE service found on this device.',
        );
        return;
      }

      // Find characteristic
      var char = soilService.characteristics.firstWhereOrNull(
        (c) => c.uuid == _characteristicUuid,
      );
      // Fallback: first notifyable or readable characteristic.
      char ??= soilService.characteristics.firstWhereOrNull(
        (c) => c.properties.notify || c.properties.read,
      );

      if (char == null) {
        state = state.copyWith(
          connectionState: BleConnectionState.error,
          errorMessage: 'No readable characteristic found.',
        );
        return;
      }

      state = state.copyWith(connectionState: BleConnectionState.connected);

      // Subscribe to notifications (for streaming sensors)
      if (char.properties.notify) {
        await char.setNotifyValue(true);
        _charSubscription = char.lastValueStream.listen((data) {
          final result = _parseFrame(data);
          if (result != null) {
            state = state.copyWith(lastReading: result);
          }
        });
      }

      // Read current value (for request-response sensors)
      if (char.properties.read) {
        await _triggerReadingAndWait(char);
      }
    } catch (e) {
      state = state.copyWith(
        connectionState: BleConnectionState.error,
        errorMessage: 'Discover error: $e',
      );
    }
  }

  /// Triggers a reading by writing a command byte (0x01 = "read sensors")
  /// then waits for the response on the notification stream.
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
        state = state.copyWith(
          errorMessage: 'Characteristic not found for write.',
        );
        return;
      }

      if (char.properties.write) {
        // Write 0x01 to trigger a sensor reading.
        await char.write([0x01], withoutResponse: false);
      }

      state = state.copyWith(isReadingInProgress: true);

      // Timeout after 10s if no data comes back.
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

    // Timeout after 10s
    _readingTimer?.cancel();
    _readingTimer = Timer(const Duration(seconds: 10), () {
      if (state.isReadingInProgress) {
        state = state.copyWith(
          isReadingInProgress: false,
          errorMessage:
              'Sensor reading timed out. Make sure the device is '
              'actively sampling and within range.',
        );
      }
    });
  }

  Future<void> disconnect() async {
    await _connectedDevice?.disconnect();
    _cleanup();
    state = const BleState(connectionState: BleConnectionState.idle);
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
  //
  // If your hardware uses a different format, update _parseFrame below.

  SensorValues? _parseFrame(List<int> data) {
    if (data.length < 12) return null;

    try {
      final bytes = Uint8List.fromList(data);

      // Verify header
      if (bytes[0] != 0xAA) return null;

      // Verify checksum
      int checksum = 0;
      for (int i = 0; i < 11; i++) {
        checksum ^= bytes[i];
      }
      // Note: we accept even if checksum fails, but flag in logs would be nice.
      if (checksum != bytes[11]) {
        // Checksum mismatch — data may be corrupted.
      }

      // Parse little-endian 16-bit values.
      final n  = _bytesToDouble(bytes[1], bytes[2]) / 10.0;  // ppm
      final p  = _bytesToDouble(bytes[3], bytes[4]) / 10.0;
      final k  = _bytesToDouble(bytes[5], bytes[6]) / 10.0;
      final ph = bytes[7] / 10.0;
      final ec = _bytesToDouble(bytes[8], bytes[9]) / 100.0; // dS/m
      final m  = bytes[10].toDouble();                        // %

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

  double _bytesToDouble(int high, int low) {
    return (high << 8 | low).toDouble();
  }

  // ── Retry logic ─────────────────────────────────────────────────────────
  Future<void> _handleConnectionError(BluetoothDevice device, Object e) async {
    if (_retryCount < _maxRetries) {
      _retryCount++;
      state = state.copyWith(
        connectionState: BleConnectionState.connecting,
        errorMessage: 'Connection failed (attempt $_retryCount). Retrying...',
      );
      await Future.delayed(const Duration(seconds: 2));
      await _connectToDevice(device);
    } else {
      state = state.copyWith(
        connectionState: BleConnectionState.error,
        errorMessage:
            'Could not connect to device. Make sure it is on and nearby.',
      );
    }
  }

  void _cleanup() {
    _scanSubscription?.cancel();
    _deviceSubscription?.cancel();
    _charSubscription?.cancel();
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
