// lib/features/fields/fields_screen.dart
// List of farmer's fields + add field dialog.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:geolocator/geolocator.dart';
import 'package:drift/drift.dart' show Value;

import '../../core/theme.dart';
import '../../data/database.dart';
import '../../data/models.dart';
import '../../data/providers.dart';
import 'field_details_screen.dart';

class FieldsScreen extends ConsumerWidget {
  const FieldsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.watch(databaseProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('My Fields')),
      body: StreamBuilder<List<Field>>(
        stream: db.watchAllFields(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final fields = snapshot.data ?? [];

          if (fields.isEmpty) {
            return const _EmptyFieldsView();
          }

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
            itemCount: fields.length,
            separatorBuilder: (context, index) => const SizedBox(height: 10),
            itemBuilder: (context, i) => _FieldCard(field: fields[i]),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddFieldDialog(context),
        icon: const Icon(Icons.add, size: 20),
        label: const Text('Add Field'),
      ),
    );
  }

  void _showAddFieldDialog(BuildContext context) {
    showDialog(context: context, builder: (ctx) => const _AddFieldDialog());
  }
}

class _EmptyFieldsView extends StatelessWidget {
  const _EmptyFieldsView();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 120,
              height: 120,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.primary.withValues(alpha: 0.08),
              ),
              child: Icon(
                Icons.grass_outlined,
                size: 56,
                color: AppTheme.primary.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No fields yet',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              'Add your first field to start recording soil tests and '
              'tracking fertilizer recommendations.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFF6B7168), height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}

class _FieldCard extends ConsumerWidget {
  final Field field;

  const _FieldCard({required this.field});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isMaize = field.crop == Crop.maize;
    final cropColor = isMaize ? AppTheme.primary : AppTheme.accent;
    final cropIcon = isMaize ? Icons.agriculture : Icons.rice_bowl;
    final cropLabel = isMaize ? 'Maize' : 'Rice';
    final dateFormat = DateFormat('MMM d, yyyy');

    return Material(
      color: AppTheme.surfaceTint,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => FieldDetailsScreen(field: field)),
        ),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.outlineVariant),
          ),
          child: Row(
            children: [
              // Accent strip
              Container(
                width: 5,
                height: 78,
                margin: const EdgeInsets.only(left: 6, top: 6, bottom: 6),
                decoration: BoxDecoration(
                  color: cropColor,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 14,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              field.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 16,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          PopupMenuButton<String>(
                            icon: const Icon(
                              Icons.more_vert,
                              size: 20,
                              color: Color(0xFF6B7168),
                            ),
                            padding: EdgeInsets.zero,
                            onSelected: (action) {
                              if (action == 'delete') {
                                _confirmDelete(context, ref);
                              }
                            },
                            itemBuilder: (_) => const [
                              PopupMenuItem(
                                value: 'delete',
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.delete_outline,
                                      size: 18,
                                      color: AppTheme.error,
                                    ),
                                    SizedBox(width: 8),
                                    Text('Delete field'),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          _Chip(
                            icon: cropIcon,
                            label: cropLabel,
                            color: cropColor,
                          ),
                          const SizedBox(width: 8),
                          _Chip(
                            icon: field.latitude == null
                                ? Icons.event_outlined
                                : Icons.location_on_outlined,
                            label: field.latitude == null
                                ? dateFormat.format(field.createdAt)
                                : 'Location saved',
                            color: field.latitude == null
                                ? const Color(0xFF6B7168)
                                : const Color(0xFF2563EB),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.delete_outline, size: 36, color: AppTheme.error),
        title: const Text('Delete field?'),
        content: Text(
          'This will permanently delete "${field.name}" and all its test '
          'records. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppTheme.error),
            onPressed: () {
              ref.read(databaseProvider).deleteField(field.id);
              Navigator.pop(ctx);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _Chip({required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _AddFieldDialog extends ConsumerStatefulWidget {
  const _AddFieldDialog();

  @override
  ConsumerState<_AddFieldDialog> createState() => _AddFieldDialogState();
}

class _AddFieldDialogState extends ConsumerState<_AddFieldDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  Crop _selectedCrop = Crop.rice;
  bool _saving = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      icon: Icon(
        Icons.add_location_alt_outlined,
        size: 36,
        color: AppTheme.primary,
      ),
      title: const Text('Add Field'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Field name',
                hintText: 'e.g. North Plot, Riverside Farm',
              ),
              validator: (v) => v == null || v.trim().isEmpty
                  ? 'Please enter a field name'
                  : null,
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<Crop>(
              initialValue: _selectedCrop,
              decoration: const InputDecoration(labelText: 'Crop'),
              items: Crop.values.map((c) {
                return DropdownMenuItem(
                  value: c,
                  child: Row(
                    children: [
                      Icon(
                        c == Crop.maize ? Icons.agriculture : Icons.rice_bowl,
                        size: 18,
                        color: c == Crop.maize
                            ? AppTheme.primary
                            : AppTheme.accent,
                      ),
                      const SizedBox(width: 10),
                      Text(c == Crop.maize ? 'Maize' : 'Rice'),
                    ],
                  ),
                );
              }).toList(),
              onChanged: (v) => setState(() => _selectedCrop = v!),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Save & get location'),
        ),
      ],
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        if (!mounted) return;
        final open = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            icon: const Icon(Icons.location_off, size: 38),
            title: const Text('Turn on location'),
            content: const Text(
              'SoilSense uses your phone location to save the precise position of this field. You do not need to type it yourself.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Open settings'),
              ),
            ],
          ),
        );
        if (open == true) await Geolocator.openLocationSettings();
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Location permission is required to save a field.'),
          ),
        );
        if (permission == LocationPermission.deniedForever) {
          await Geolocator.openAppSettings();
        }
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 20),
        ),
      );

      await ref
          .read(databaseProvider)
          .insertField(
            FieldsCompanion.insert(
              name: _nameController.text.trim(),
              crop: _selectedCrop,
              latitude: Value(position.latitude),
              longitude: Value(position.longitude),
            ),
          );

      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Could not get a precise location. Move outdoors and try again.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}
