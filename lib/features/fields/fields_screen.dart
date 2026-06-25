// lib/features/fields/fields_screen.dart
// List of farmer's fields + add field dialog.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database.dart';
import '../../data/models.dart';
import '../../data/providers.dart';

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

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: fields.length,
            itemBuilder: (context, i) => _FieldCard(field: fields[i]),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddFieldDialog(context),
        icon: const Icon(Icons.add),
        label: const Text('Add Field'),
      ),
    );
  }

  void _showAddFieldDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => const _AddFieldDialog(),
    );
  }
}

class _EmptyFieldsView extends StatelessWidget {
  const _EmptyFieldsView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.grass_outlined,
              size: 80,
              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 16),
            Text(
              'No fields yet',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              'Add your first field to start recording soil tests.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey[600],
                  ),
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
    final crop = field.crop == Crop.maize ? 'Maize 🌽' : 'Rice 🌾';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
          child: Icon(
            Icons.terrain,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        title: Text(
          field.name,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Row(
          children: [
            Icon(Icons.eco, size: 14, color: Colors.grey[500]),
            const SizedBox(width: 4),
            Text(crop),
            const SizedBox(width: 12),
            Icon(Icons.calendar_today, size: 14, color: Colors.grey[500]),
            const SizedBox(width: 4),
            Text(_formatDate(field.createdAt)),
          ],
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (action) {
            if (action == 'delete') {
              _confirmDelete(context, ref);
            }
          },
          itemBuilder: (_) => [
            const PopupMenuItem(value: 'delete', child: Text('Delete field')),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime dt) {
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  void _confirmDelete(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete field?'),
        content: Text(
          'This will permanently delete "${field.name}" and all its test records. '
          'This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              ref.read(databaseProvider).deleteField(field.id);
              Navigator.pop(ctx);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
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
  Crop _selectedCrop = Crop.rice; // default

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
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
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<Crop>(
              initialValue: _selectedCrop,
              decoration: const InputDecoration(labelText: 'Crop'),
              items: Crop.values.map((c) {
                return DropdownMenuItem(
                  value: c,
                  child: Text(c == Crop.maize ? 'Maize 🌽' : 'Rice 🌾'),
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
        ElevatedButton(
          onPressed: _save,
          child: const Text('Save'),
        ),
      ],
    );
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;

    ref.read(databaseProvider).insertField(
          FieldsCompanion.insert(
            name: _nameController.text.trim(),
            crop: _selectedCrop,
          ),
        );

    Navigator.pop(context);
  }
}
