// lib/features/device/device_screen.dart
// BLE device scan, connect, and run-test flow.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../ble/ble_service.dart';
import '../../data/database.dart';
import '../../data/models.dart';
import '../../data/providers.dart';
import '../results/results_screen.dart';

class DeviceScreen extends ConsumerWidget {
  const DeviceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bleState = ref.watch(bleStateProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('SoilSense Device')),
      body: _buildBody(context, ref, bleState),
    );
  }

  Widget _buildBody(BuildContext context, WidgetRef ref, BleState state) {
    switch (state.connectionState) {
      case BleConnectionState.idle:
        return _IdleView(ref: ref);
      case BleConnectionState.scanning:
        return const _ScanningView();
      case BleConnectionState.connecting:
        return const _ConnectingView();
      case BleConnectionState.discovering:
        return const _DiscoveringView();
      case BleConnectionState.connected:
      case BleConnectionState.reading:
        return _ConnectedView();
      case BleConnectionState.error:
        return _ErrorView(state: state, ref: ref);
    }
  }
}

// ── Idle ────────────────────────────────────────────────────────────────────

class _IdleView extends StatelessWidget {
  final WidgetRef ref;

  const _IdleView({required this.ref});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.bluetooth_searching,
              size: 80,
              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.4),
            ),
            const SizedBox(height: 24),
            Text(
              'Connect your SoilSense device',
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Power on your hardware device and tap Scan to find it.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey[600],
                  ),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () => ref.read(bleStateProvider.notifier).startScan(),
              icon: const Icon(Icons.radar),
              label: const Text('Scan for Device'),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Scanning ────────────────────────────────────────────────────────────────

class _ScanningView extends StatelessWidget {
  const _ScanningView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 60,
            height: 60,
            child: CircularProgressIndicator(strokeWidth: 3),
          ),
          const SizedBox(height: 24),
          Text(
            'Scanning for devices...',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'Make sure your SoilSense hardware is powered on',
            style: TextStyle(color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }
}

// ── Connecting ──────────────────────────────────────────────────────────────

class _ConnectingView extends StatelessWidget {
  const _ConnectingView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(strokeWidth: 3),
          const SizedBox(height: 24),
          Text(
            'Connecting...',
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ],
      ),
    );
  }
}

// ── Discovering ────────────────────────────────────────────────────────────

class _DiscoveringView extends StatelessWidget {
  const _DiscoveringView();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(strokeWidth: 3),
          SizedBox(height: 24),
          Text('Discovering sensor services...'),
        ],
      ),
    );
  }
}

// ── Connected ─────────────────────────────────────────────────────────────

class _ConnectedView extends ConsumerStatefulWidget {
  const _ConnectedView();

  @override
  ConsumerState<_ConnectedView> createState() => _ConnectedViewState();
}

class _ConnectedViewState extends ConsumerState<_ConnectedView> {
  bool _navigating = false;
  SensorValues? _pendingValues;

  @override
  void initState() {
    super.initState();
    final initial = ref.read(bleStateProvider).lastReading;
    if (initial != null) {
      _pendingValues = initial;
    }
  }

  Future<void> _onRunTest(SensorValues values) async {
    if (_navigating) return;
    _navigating = true;

    final db = ref.read(databaseProvider);

    // Insert a placeholder reading (fieldId=0) to get an ID for measurements.
    final tempReading = await db.insertReading(
      TestReadingsCompanion.insert(fieldId: 0),
    );

    if (mounted) {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => _ResultsGate(
            tempReadingId: tempReading,
            bleValues: values,
          ),
        ),
      );
      _navigating = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(bleStateProvider);
    final lastReading = state.lastReading;

    // Navigate when a new reading arrives
    if (lastReading != null && lastReading != _pendingValues && !_navigating) {
      _pendingValues = lastReading;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _onRunTest(lastReading);
      });
    }

    return _buildContent(context, state);
  }

  Widget _buildContent(BuildContext context, BleState state) {
    final lastReading = state.lastReading;

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // Status chip
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.green.shade200),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.bluetooth_connected, color: Colors.green, size: 18),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    'Connected to ${state.deviceName ?? "SoilSense"}',
                    style: const TextStyle(
                      color: Colors.green,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Last reading preview
          if (lastReading != null) ...[
            Text(
              'Last Reading',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            _ReadingPreview(values: lastReading),
            const SizedBox(height: 20),
          ],

          const Spacer(),

          // Run new test button OR reading indicator
          if (!state.isReadingInProgress)
            ElevatedButton.icon(
              onPressed: () =>
                  ref.read(bleStateProvider.notifier).triggerReading(),
              icon: const Icon(Icons.science),
              label: const Text('Run Soil Test'),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 56),
              ),
            )
          else
            const _ReadingIndicator(),

          const SizedBox(height: 16),

          OutlinedButton.icon(
            onPressed: () => ref.read(bleStateProvider.notifier).disconnect(),
            icon: const Icon(Icons.bluetooth_disabled),
            label: const Text('Disconnect'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(double.infinity, 48),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Reading indicator ─────────────────────────────────────────────────────

class _ReadingIndicator extends StatelessWidget {
  const _ReadingIndicator();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text(
            'Taking reading...',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 4),
          Text(
            'Insert the probe into the soil and wait',
            style: TextStyle(color: Colors.grey[600], fontSize: 13),
          ),
        ],
      ),
    );
  }
}

// ── Reading preview ───────────────────────────────────────────────────────

class _ReadingPreview extends StatelessWidget {
  final SensorValues values;

  const _ReadingPreview({required this.values});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _Row('🌱 Nitrogen', '${values.nitrogen.toStringAsFixed(1)} ppm'),
            const Divider(height: 12),
            _Row('💧 Phosphorus', '${values.phosphorus.toStringAsFixed(1)} ppm'),
            const Divider(height: 12),
            _Row('🍌 Potassium', '${values.potassium.toStringAsFixed(1)} ppm'),
            const Divider(height: 12),
            _Row('⚗️ pH', values.ph.toStringAsFixed(1)),
            const Divider(height: 12),
            _Row('🧂 Salinity', '${values.salinity.toStringAsFixed(1)} dS/m'),
            const Divider(height: 12),
            _Row('💦 Moisture', '${values.moisture.toStringAsFixed(0)}%'),
          ],
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final String label;
  final String value;

  const _Row(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
      ],
    );
  }
}

// ── Error ─────────────────────────────────────────────────────────────────

class _ErrorView extends ConsumerWidget {
  final BleState state;
  final WidgetRef ref;

  const _ErrorView({required this.state, required this.ref});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              'Connection Error',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              state.errorMessage ?? 'An unknown error occurred.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[700]),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                ref.read(bleStateProvider.notifier).clearError();
                ref.read(bleStateProvider.notifier).startScan();
              },
              child: const Text('Try Again'),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () =>
                  ref.read(bleStateProvider.notifier).disconnect(),
              child: const Text('Back'),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Results Gate — field picker before showing recommendations ────────────────

class _ResultsGate extends ConsumerStatefulWidget {
  final int tempReadingId;
  final SensorValues bleValues;

  const _ResultsGate({
    required this.tempReadingId,
    required this.bleValues,
  });

  @override
  ConsumerState<_ResultsGate> createState() => _ResultsGateState();
}

class _ResultsGateState extends ConsumerState<_ResultsGate> {
  Field? _selectedField;

  @override
  Widget build(BuildContext context) {
    final db = ref.watch(databaseProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Save Reading')),
      body: StreamBuilder<List<Field>>(
        stream: db.watchAllFields(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final fields = snap.data ?? [];

          if (fields.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.info_outline, size: 48, color: Colors.grey),
                    const SizedBox(height: 16),
                    Text(
                      'No fields created yet',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Go to My Fields tab and add a field first.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 20),
                    OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Go Back'),
                    ),
                  ],
                ),
              ),
            );
          }

          return Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Which field did you test?',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 16),
                RadioGroup<Field>(
                  groupValue: _selectedField,
                  onChanged: (v) => setState(() => _selectedField = v),
                  child: Column(
                    children: fields.map((f) {
                      return RadioListTile<Field>(
                        value: f,
                        title: Text(f.name),
                        subtitle: Text(
                          f.crop == Crop.maize ? 'Maize 🌽' : 'Rice 🌾',
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const Spacer(),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _selectedField == null ? null : _proceed,
                    child: const Text('View Recommendations'),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Discard'),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _proceed() async {
    final db = ref.read(databaseProvider);
    final field = _selectedField!;

    // Update the placeholder reading with the real fieldId.
    await db.updateReadingField(widget.tempReadingId, field.id);

    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => ResultsScreen(
            readingId: widget.tempReadingId,
            fieldId: field.id,
            crop: field.crop,
            values: widget.bleValues,
          ),
        ),
      );
    }
  }
}
