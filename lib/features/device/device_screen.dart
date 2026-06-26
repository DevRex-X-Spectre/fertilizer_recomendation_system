// lib/features/device/device_screen.dart
// BLE device scan, connect, and run-test flow.
// Idle → Bluetooth prompt → radar scanning → connected → run test → results.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../ble/ble_service.dart';
import '../../core/theme.dart';
import '../../core/widgets/radar_animation.dart';
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
      appBar: AppBar(title: const Text('Device')),
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

class _IdleView extends ConsumerWidget {
  final WidgetRef ref;

  const _IdleView({required this.ref});

  Future<void> _onScanPressed(BuildContext context, WidgetRef ref) async {
    final notifier = ref.read(bleStateProvider.notifier);

    // ── Step 1: make sure Bluetooth is on ────────────────────────────
    if (!notifier.isBluetoothOn) {
      final shouldTurnOn = await _showTurnOnDialog(context);
      if (shouldTurnOn != true) return;

      final ok = await notifier.ensureBluetoothOn();
      if (!ok) return;
    }

    // ── Step 2: kick off the scan ────────────────────────────────────
    await notifier.startScan();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(bleStateProvider.notifier);
    final bluetoothOn = notifier.isBluetoothOn;
    final theme = Theme.of(context);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Spacer(flex: 2),

            // Hero radar in a soft container so it's the visual centre.
            Center(
              child: Container(
                width: 320,
                height: 320,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppTheme.primary.withValues(alpha: 0.04),
                ),
                child: Center(
                  child: RadarAnimation(
                    size: 260,
                    color: AppTheme.primary,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 32),

            // Headline + subtitle.
            Text(
              'Find your SoilSense device',
              textAlign: TextAlign.center,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Power on the hardware, keep it within range, '
              'and tap Scan to connect.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: const Color(0xFF6B7168),
                height: 1.45,
              ),
            ),

            const SizedBox(height: 28),

            // Bluetooth status indicator
            _BluetoothStatusChip(bluetoothOn: bluetoothOn),

            const Spacer(flex: 3),

            // Primary action
            ElevatedButton.icon(
              onPressed: () => _onScanPressed(context, ref),
              icon: const Icon(Icons.radar, size: 20),
              label: const Text('Scan for Device'),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(54),
              ),
            ),

            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Future<bool?> _showTurnOnDialog(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: Icon(Icons.bluetooth_disabled, size: 40, color: AppTheme.accent),
        title: const Text('Bluetooth is off'),
        content: const Text(
          'SoilSense needs Bluetooth to connect to your soil-testing '
          'hardware. Turn it on now?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Not now'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(ctx, true),
            icon: const Icon(Icons.bluetooth, size: 18),
            label: const Text('Turn on'),
          ),
        ],
      ),
    );
  }
}

class _BluetoothStatusChip extends StatelessWidget {
  final bool bluetoothOn;

  const _BluetoothStatusChip({required this.bluetoothOn});

  @override
  Widget build(BuildContext context) {
    final color = bluetoothOn ? AppTheme.statusAdequate : AppTheme.statusLow;
    final icon = bluetoothOn ? Icons.bluetooth : Icons.bluetooth_disabled;
    final label = bluetoothOn ? 'Bluetooth is on' : 'Bluetooth is off';

    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(99),
          border: Border.all(color: color.withValues(alpha: 0.30)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
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
    final theme = Theme.of(context);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Column(
          children: [
            const Spacer(),
            RadarAnimation(size: 320, color: AppTheme.primary),
            const SizedBox(height: 32),
            Text(
              'Looking for nearby Bluetooth devices',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Hold your SoilSense hardware close to the phone.\n'
              'It should pair automatically once found.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: const Color(0xFF6B7168),
                height: 1.5,
              ),
            ),
            const Spacer(flex: 2),
          ],
        ),
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
          RadarAnimation(size: 220, color: AppTheme.primary),
          const SizedBox(height: 24),
          Text(
            'Connecting...',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
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
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          RadarAnimation(size: 220, color: AppTheme.primary),
          const SizedBox(height: 24),
          Text(
            'Discovering sensor services...',
            style: Theme.of(context).textTheme.titleMedium,
          ),
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
    final theme = Theme.of(context);

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Connection chip
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: AppTheme.statusAdequate.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(99),
                  border: Border.all(
                    color: AppTheme.statusAdequate.withValues(alpha: 0.30),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: AppTheme.statusAdequate,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Connected to ${state.deviceName ?? "SoilSense"}',
                      style: const TextStyle(
                        color: AppTheme.statusAdequate,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            if (lastReading != null) ...[
              Text(
                'Latest reading',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              _SensorGrid(values: lastReading),
              const SizedBox(height: 24),
            ],

            // Action area
            if (!state.isReadingInProgress)
              ElevatedButton.icon(
                onPressed: () =>
                    ref.read(bleStateProvider.notifier).triggerReading(),
                icon: const Icon(Icons.science_outlined, size: 20),
                label: const Text('Run Soil Test'),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size.fromHeight(56),
                ),
              )
            else
              const _ReadingIndicator(),

            const SizedBox(height: 12),

            OutlinedButton.icon(
              onPressed: () =>
                  ref.read(bleStateProvider.notifier).disconnect(),
              icon: const Icon(Icons.link_off, size: 18),
              label: const Text('Disconnect'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
              ),
            ),
          ],
        ),
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
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      decoration: BoxDecoration(
        color: AppTheme.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppTheme.primary.withValues(alpha: 0.18),
        ),
      ),
      child: Row(
        children: [
          const SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2.5),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Taking reading…',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 2),
                const Text(
                  'Insert the probe into the soil',
                  style: TextStyle(
                    color: Color(0xFF6B7168),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Sensor grid ───────────────────────────────────────────────────────────

class _SensorGrid extends StatelessWidget {
  final SensorValues values;

  const _SensorGrid({required this.values});

  @override
  Widget build(BuildContext context) {
    final tiles = <_SensorTile>[
      _SensorTile(
        icon: Icons.science_outlined,
        label: 'Nitrogen',
        value: values.nitrogen.toStringAsFixed(1),
        unit: 'ppm',
        color: AppTheme.statusAdequate,
      ),
      _SensorTile(
        icon: Icons.grain,
        label: 'Phosphorus',
        value: values.phosphorus.toStringAsFixed(1),
        unit: 'ppm',
        color: AppTheme.accent,
      ),
      _SensorTile(
        icon: Icons.eco,
        label: 'Potassium',
        value: values.potassium.toStringAsFixed(1),
        unit: 'ppm',
        color: AppTheme.primary,
      ),
      _SensorTile(
        icon: Icons.balance,
        label: 'pH',
        value: values.ph.toStringAsFixed(1),
        unit: '',
        color: const Color(0xFF7C3AED),
      ),
      _SensorTile(
        icon: Icons.waves,
        label: 'Salinity',
        value: values.salinity.toStringAsFixed(2),
        unit: 'dS/m',
        color: const Color(0xFF0891B2),
      ),
      _SensorTile(
        icon: Icons.water_drop_outlined,
        label: 'Moisture',
        value: values.moisture.toStringAsFixed(0),
        unit: '%',
        color: const Color(0xFF2563EB),
      ),
    ];

    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 0.95,
      children: tiles,
    );
  }
}

class _SensorTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String unit;
  final Color color;

  const _SensorTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.unit,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppTheme.surfaceTint,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const Spacer(),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: Color(0xFF6B7168),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 2),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Flexible(
                child: Text(
                  value,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.5,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (unit.isNotEmpty) ...[
                const SizedBox(width: 2),
                Text(
                  unit,
                  style: const TextStyle(
                    fontSize: 10,
                    color: Color(0xFF6B7168),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
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
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              width: 96,
              height: 96,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.error.withValues(alpha: 0.10),
              ),
              child: const Icon(
                Icons.error_outline,
                size: 48,
                color: AppTheme.error,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Couldn\'t connect',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              state.errorMessage ?? 'An unknown error occurred.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF6B7168),
                height: 1.45,
              ),
            ),
            const SizedBox(height: 32),
            FilledButton(
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
            return _EmptyFieldsHint();
          }

          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Which field did you test?',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Pick the field this sample belongs to.',
                    style: TextStyle(color: Color(0xFF6B7168)),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: ListView.separated(
                      itemCount: fields.length,
                      separatorBuilder: (context, index) => const SizedBox(height: 8),
                      itemBuilder: (context, i) {
                        final f = fields[i];
                        return _FieldPickerTile(
                          field: f,
                          selected: _selectedField?.id == f.id,
                          onTap: () => setState(() => _selectedField = f),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _selectedField == null ? null : _proceed,
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(52),
                      ),
                      child: const Text('View Recommendations'),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Discard'),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _proceed() async {
    final db = ref.read(databaseProvider);
    final field = _selectedField!;

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

class _FieldPickerTile extends StatelessWidget {
  final Field field;
  final bool selected;
  final VoidCallback onTap;

  const _FieldPickerTile({
    required this.field,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected
          ? AppTheme.primaryContainer
          : AppTheme.surfaceTint,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected
                  ? AppTheme.primary
                  : AppTheme.outlineVariant,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              Icon(
                field.crop == Crop.maize
                    ? Icons.agriculture
                    : Icons.rice_bowl,
                color: selected ? AppTheme.primary : const Color(0xFF6B7168),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      field.name,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: selected
                            ? AppTheme.primary
                            : Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      field.crop == Crop.maize ? 'Maize' : 'Rice',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF6B7168),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                selected ? Icons.radio_button_checked : Icons.radio_button_off,
                color: selected ? AppTheme.primary : const Color(0xFF9CA39B),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyFieldsHint extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 96,
              height: 96,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.primary.withValues(alpha: 0.08),
              ),
              child: const Icon(
                Icons.add_circle_outline,
                size: 44,
                color: AppTheme.primary,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'No fields created yet',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Add a field in the My Fields tab first, then come back here '
              'to save your reading.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF6B7168), height: 1.45),
            ),
            const SizedBox(height: 24),
            OutlinedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Go Back'),
            ),
          ],
        ),
      ),
    );
  }
}
