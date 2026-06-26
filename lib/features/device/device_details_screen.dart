// lib/features/device/device_details_screen.dart
// Pre-connection device details.
//
// Shows every BLE device discovered during a scan — SoilSense hardware is
// flagged as connectable, every other nearby device is flagged as not.
//
// The primary action is Connect. Non-SoilSense devices render the button
// disabled with an explanatory chip. The "View Details" expansion reveals
// the raw advertisement payload (service UUIDs, manufacturer data) for
// debugging and so the user can see WHY the device was or wasn't
// recognised.

import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../ble/ble_service.dart';
import '../../core/theme.dart';

class DeviceDetailsScreen extends ConsumerStatefulWidget {
  final DiscoveredDevice device;

  const DeviceDetailsScreen({super.key, required this.device});

  @override
  ConsumerState<DeviceDetailsScreen> createState() =>
      _DeviceDetailsScreenState();
}

class _DeviceDetailsScreenState extends ConsumerState<DeviceDetailsScreen> {
  bool _showRawDetails = false;

  @override
  Widget build(BuildContext context) {
    final bleState = ref.watch(bleStateProvider);
    final device = widget.device;

    // The "currently connecting to" device, if any.
    final isConnecting =
        bleState.connectionState == BleConnectionState.connecting &&
            bleState.deviceName == device.name;
    final isConnected =
        bleState.connectionState == BleConnectionState.connected &&
            bleState.deviceName == device.name;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Device Details'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _DeviceHeader(device: device),
                    const SizedBox(height: 20),
                    _SignalCard(rssi: device.rssi),
                    const SizedBox(height: 16),
                    _ConnectableBadge(device: device),
                    const SizedBox(height: 24),
                    _ViewDetailsExpansion(
                      device: device,
                      expanded: _showRawDetails,
                      onToggle: () =>
                          setState(() => _showRawDetails = !_showRawDetails),
                    ),
                    if (isConnecting || isConnected) ...[
                      const SizedBox(height: 24),
                      _StatusCard(
                        connecting: isConnecting,
                        connected: isConnected,
                      ),
                    ],
                  ],
                ),
              ),
            ),
            // Sticky bottom action area.
            Container(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              decoration: const BoxDecoration(
                border: Border(
                  top: BorderSide(color: AppTheme.outlineVariant),
                ),
              ),
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _canConnect(bleState)
                            ? () => _onConnect(device)
                            : null,
                        icon: Icon(
                          device.isSoilSense
                              ? Icons.link
                              : Icons.link_off,
                          size: 20,
                        ),
                        label: Text(
                          device.isSoilSense
                              ? 'Connect to Device'
                              : 'Not Connectable',
                        ),
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(56),
                          backgroundColor: device.isSoilSense
                              ? AppTheme.primary
                              : AppTheme.outline,
                          foregroundColor: device.isSoilSense
                              ? Colors.white
                              : const Color(0xFF6B7168),
                          disabledBackgroundColor: AppTheme.outline,
                          disabledForegroundColor: const Color(0xFF6B7168),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool _canConnect(BleState state) {
    if (!widget.device.isSoilSense) return false;
    // Don't allow double-tap while we're already mid-flow.
    final blocking = {
      BleConnectionState.connecting,
      BleConnectionState.discovering,
      BleConnectionState.connected,
      BleConnectionState.reading,
    };
    return !blocking.contains(state.connectionState);
  }

  Future<void> _onConnect(DiscoveredDevice device) async {
    final notifier = ref.read(bleStateProvider.notifier);
    await notifier.connectToDevice(device.device);

    // Pop back to the device tab — the BLE state change will swap the view
    // there to the connected / connecting / error screen automatically.
    if (mounted) {
      Navigator.of(context).pop();
    }
  }
}

// ── Header ──────────────────────────────────────────────────────────────────

class _DeviceHeader extends StatelessWidget {
  final DiscoveredDevice device;
  const _DeviceHeader({required this.device});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.surfaceTint,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.outlineVariant),
      ),
      child: Row(
        children: [
          Container(
            width: 64,
            height: 64,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: device.isSoilSense
                  ? AppTheme.primary.withValues(alpha: 0.10)
                  : const Color(0xFF6B7168).withValues(alpha: 0.10),
            ),
            child: Icon(
              device.isSoilSense ? Icons.sensors : Icons.bluetooth,
              color: device.isSoilSense
                  ? AppTheme.primary
                  : const Color(0xFF6B7168),
              size: 30,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  device.name,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  device.isSoilSense
                      ? 'SoilSense hardware'
                      : 'Unknown device',
                  style: TextStyle(
                    color: device.isSoilSense
                        ? AppTheme.primary
                        : const Color(0xFF6B7168),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  device.id,
                  style: const TextStyle(
                    color: Color(0xFF9CA39B),
                    fontSize: 11,
                    fontFamily: 'monospace',
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

// ── Signal strength ─────────────────────────────────────────────────────────

class _SignalCard extends StatelessWidget {
  final int rssi;
  const _SignalCard({required this.rssi});

  @override
  Widget build(BuildContext context) {
    final quality = _signalQuality(rssi);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceTint,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.outlineVariant),
      ),
      child: Row(
        children: [
          Icon(Icons.signal_cellular_alt, color: quality.color, size: 24),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Signal strength',
                  style: TextStyle(
                    fontSize: 12,
                    color: Color(0xFF6B7168),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$rssi dBm · ${quality.label}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          ),
          _SignalBars(rssi: rssi, color: quality.color),
        ],
      ),
    );
  }

  _SignalQuality _signalQuality(int rssi) {
    if (rssi >= -60) {
      return _SignalQuality('Strong', AppTheme.statusAdequate, 4);
    } else if (rssi >= -75) {
      return _SignalQuality('Good', const Color(0xFF0891B2), 3);
    } else if (rssi >= -85) {
      return _SignalQuality('Fair', AppTheme.statusLow, 2);
    } else {
      return _SignalQuality('Weak', AppTheme.statusDeficient, 1);
    }
  }
}

class _SignalQuality {
  final String label;
  final Color color;
  final int bars;
  const _SignalQuality(this.label, this.color, this.bars);
}

class _SignalBars extends StatelessWidget {
  final int rssi;
  final Color color;
  const _SignalBars({required this.rssi, required this.color});

  @override
  Widget build(BuildContext context) {
    final filled = rssi >= -60
        ? 4
        : rssi >= -75
            ? 3
            : rssi >= -85
                ? 2
                : 1;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: List.generate(4, (i) {
        final active = i < filled;
        return Padding(
          padding: const EdgeInsets.only(left: 3),
          child: Container(
            width: 5,
            height: 6.0 + (i * 4.0),
            decoration: BoxDecoration(
              color: active
                  ? color
                  : color.withValues(alpha: 0.20),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        );
      }),
    );
  }
}

// ── Connectability badge ────────────────────────────────────────────────────

class _ConnectableBadge extends StatelessWidget {
  final DiscoveredDevice device;
  const _ConnectableBadge({required this.device});

  @override
  Widget build(BuildContext context) {
    if (device.isSoilSense) {
      return _Badge(
        icon: Icons.verified,
        color: AppTheme.primary,
        title: 'Recognised as SoilSense hardware',
        subtitle:
            'This device advertises the SoilSense service UUID or name prefix, '
            'so the app can connect and stream sensor data.',
      );
    }

    return _Badge(
      icon: Icons.info_outline,
      color: AppTheme.statusLow,
      title: 'Not a SoilSense device',
      subtitle:
          'You can view the raw advertisement payload below for debugging. '
          'Only SoilSense hardware can stream soil data to this app.',
    );
  }
}

class _Badge extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;

  const _Badge({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.30)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: color,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: Color(0xFF1A1F18),
                    height: 1.4,
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

// ── View BLE Details (expandable) ───────────────────────────────────────────

class _ViewDetailsExpansion extends StatelessWidget {
  final DiscoveredDevice device;
  final bool expanded;
  final VoidCallback onToggle;

  const _ViewDetailsExpansion({
    required this.device,
    required this.expanded,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceTint,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.outlineVariant),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: expanded,
          onExpansionChanged: (_) => onToggle(),
          tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          shape: const RoundedRectangleBorder(
            side: BorderSide(color: Colors.transparent),
          ),
          collapsedShape: const RoundedRectangleBorder(
            side: BorderSide(color: Colors.transparent),
          ),
          leading: const Icon(
            Icons.developer_mode_outlined,
            color: Color(0xFF6B7168),
          ),
          title: const Text(
            'View BLE Details',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
          ),
          subtitle: const Text(
            'Raw advertisement payload',
            style: TextStyle(
              fontSize: 12,
              color: Color(0xFF6B7168),
            ),
          ),
          children: [
            _DetailRow(
              icon: Icons.fingerprint,
              label: 'Platform name',
              value: device.name,
            ),
            _DetailRow(
              icon: Icons.tag,
              label: 'Bluetooth address',
              value: device.id,
              monospace: true,
            ),
            _DetailRow(
              icon: Icons.radar,
              label: 'RSSI',
              value: '${device.rssi} dBm',
              monospace: true,
            ),
            const SizedBox(height: 8),
            _SectionTitle(
              icon: Icons.layers_outlined,
              title:
                  'Advertised service UUIDs (${device.advertisedServiceUuids.length})',
            ),
            const SizedBox(height: 6),
            if (device.advertisedServiceUuids.isEmpty)
              const _MutedHint('No service UUIDs advertised.')
            else
              ...device.advertisedServiceUuids.map(
                (u) => _UuidRow(uuid: u),
              ),
            const SizedBox(height: 12),
            _SectionTitle(
              icon: Icons.qr_code_2,
              title: 'Manufacturer data',
            ),
            const SizedBox(height: 6),
            if (device.manufacturerDataHex == null ||
                device.manufacturerDataHex!.isEmpty)
              const _MutedHint('No manufacturer-specific data in this packet.')
            else
              _MonoBlock(text: device.manufacturerDataHex!),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final IconData icon;
  final String title;
  const _SectionTitle({required this.icon, required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6, bottom: 2),
      child: Row(
        children: [
          Icon(icon, size: 14, color: const Color(0xFF6B7168)),
          const SizedBox(width: 6),
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 12,
              color: Color(0xFF6B7168),
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool monospace;

  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
    this.monospace = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: const Color(0xFF6B7168)),
          const SizedBox(width: 10),
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12.5,
                color: Color(0xFF6B7168),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value.isEmpty ? '—' : value,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                fontFamily: monospace ? 'monospace' : null,
                color: const Color(0xFF1A1F18),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _UuidRow extends StatelessWidget {
  final Guid uuid;
  const _UuidRow({required this.uuid});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: const BoxDecoration(
              color: AppTheme.primary,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              uuid.toString(),
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 12,
                color: Color(0xFF1A1F18),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MonoBlock extends StatelessWidget {
  final String text;
  const _MonoBlock({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.outlineVariant),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontFamily: 'monospace',
          fontSize: 11.5,
          height: 1.4,
          color: Color(0xFF1A1F18),
        ),
      ),
    );
  }
}

class _MutedHint extends StatelessWidget {
  final String text;
  const _MutedHint(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 12,
          color: Color(0xFF9CA39B),
          fontStyle: FontStyle.italic,
        ),
      ),
    );
  }
}

// ── Status (connecting / connected) ────────────────────────────────────────

class _StatusCard extends StatelessWidget {
  final bool connecting;
  final bool connected;

  const _StatusCard({
    required this.connecting,
    required this.connected,
  });

  @override
  Widget build(BuildContext context) {
    if (connected) {
      return _statusBox(
        icon: Icons.check_circle,
        color: AppTheme.statusAdequate,
        title: 'Connected',
        subtitle: 'Returning to device screen…',
      );
    }
    return _statusBox(
      icon: Icons.sync,
      color: AppTheme.primary,
      title: 'Connecting…',
      subtitle:
          'Establishing a Bluetooth connection. This usually takes a few seconds.',
      spinning: true,
    );
  }

  Widget _statusBox({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    bool spinning = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.30)),
      ),
      child: Row(
        children: [
          spinning
              ? SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: color,
                  ),
                )
              : Icon(icon, color: color, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: color,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: Color(0xFF1A1F18),
                    height: 1.4,
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
