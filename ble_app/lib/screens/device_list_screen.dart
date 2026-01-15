import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../ble/ble_manager.dart';
import '../widgets/device_tile.dart';

class DeviceListScreen extends StatefulWidget {
  const DeviceListScreen({super.key});

  @override
  State<DeviceListScreen> createState() => _DeviceListScreenState();
}

class _DeviceListScreenState extends State<DeviceListScreen>
    with AutomaticKeepAliveClientMixin {
  StreamSubscription<void>? _sub;

  @override
  bool get wantKeepAlive => true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sub?.cancel();
    final m = context.read<BleManager>();
    _sub = m.changes.listen((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final m = context.read<BleManager>();

    return Scaffold(
      appBar: AppBar(
        title: const Text("Device list"),
        actions: [
          IconButton(
            onPressed: m.isScanning ? null : () => m.startScanMyCst(),
            icon: const Icon(Icons.refresh),
            tooltip: "Scan",
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              children: [
                FilledButton.icon(
                  onPressed: m.isScanning ? null : () => m.startScanMyCst(),
                  icon: const Icon(Icons.bluetooth_searching),
                  label: Text(m.isScanning ? "Scanning..." : "Scan"),
                ),
                const SizedBox(width: 10),
                Text(
                  m.connectedDevice != null ? "Connected: ${m.connectedName}" : "Not connected",
                  style: TextStyle(color: Colors.grey.shade700),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: m.devices.isEmpty
                  ? Center(
                      child: Text(
                        "Press Scan to find MyCST",
                        style: TextStyle(color: Colors.grey.shade700),
                      ),
                    )
                  : ListView.separated(
                      itemCount: m.devices.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (ctx, i) {
                        final e = m.devices[i];
                        final connected = m.isConnectedTo(e.device);

                        return DeviceTile(
                          name: e.name,
                          rssi: e.rssi,
                          isConnected: connected,
                          onConnect: () => m.connect(e.device, rssiHint: e.rssi),
                          onDisconnect: () => m.disconnect(),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
