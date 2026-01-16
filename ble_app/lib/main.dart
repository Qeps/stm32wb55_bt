import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'ble/ble_manager.dart';
import 'screens/device_list_screen.dart';
import 'screens/device_control_screen.dart';
import 'screens/logs_screen.dart';

void main() => runApp(const BleApp());

class BleApp extends StatelessWidget {
  const BleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Provider<BleManager>(
      create: (_) => BleManager(),
      dispose: (_, m) => m.dispose(),
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.blue),
        home: const _HomeShell(),
      ),
    );
  }
}

class _HomeShell extends StatefulWidget {
  const _HomeShell();

  @override
  State<_HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<_HomeShell> {
  int _index = 0;

  final _pages = const [
    DeviceListScreen(),
    DeviceControlScreen(),
    LogsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: _pages,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.bluetooth_searching_outlined),
            selectedIcon: Icon(Icons.bluetooth_searching),
            label: "Devices",
          ),
          NavigationDestination(
            icon: Icon(Icons.tune_outlined),
            selectedIcon: Icon(Icons.tune),
            label: "Control",
          ),
          NavigationDestination(
            icon: Icon(Icons.article_outlined),
            selectedIcon: Icon(Icons.article),
            label: "Logs",
          ),
        ],
      ),
    );
  }
}
