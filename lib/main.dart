// lib/main.dart
// Root entry point + app shell with bottom navigation.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme.dart';
import 'features/fields/fields_screen.dart';
import 'features/device/device_screen.dart';
import 'features/history/history_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: SoilSenseApp()));
}

class SoilSenseApp extends StatelessWidget {
  const SoilSenseApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SoilSense',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: const AppShell(),
    );
  }
}

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _selectedIndex = 0;

  final _pages = const [
    FieldsScreen(),
    DeviceScreen(),
    HistoryScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: _pages,
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(
            top: BorderSide(color: AppTheme.outlineVariant, width: 1),
          ),
        ),
        child: NavigationBar(
          selectedIndex: _selectedIndex,
          onDestinationSelected: (i) => setState(() => _selectedIndex = i),
          height: 68,
          backgroundColor: AppTheme.surfaceTint,
          indicatorColor: AppTheme.primaryContainer,
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.grass_outlined),
              selectedIcon: Icon(Icons.grass),
              label: 'Fields',
            ),
            NavigationDestination(
              icon: Icon(Icons.bluetooth_searching_outlined),
              selectedIcon: Icon(Icons.bluetooth_searching),
              label: 'Device',
            ),
            NavigationDestination(
              icon: Icon(Icons.timeline_outlined),
              selectedIcon: Icon(Icons.timeline),
              label: 'History',
            ),
          ],
        ),
      ),
    );
  }
}
