import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../ble/ble_manager.dart';

class DeviceControlScreen extends StatefulWidget {
  const DeviceControlScreen({super.key});

  @override
  State<DeviceControlScreen> createState() => _DeviceControlScreenState();
}

class _DeviceControlScreenState extends State<DeviceControlScreen>
    with AutomaticKeepAliveClientMixin {
  StreamSubscription<void>? _sub;

  final _frameField1 = TextEditingController();
  final _frameField2 = TextEditingController();
  final _frameField3 = TextEditingController();

  bool _busy = false;

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
    _frameField1.dispose();
    _frameField2.dispose();
    _frameField3.dispose();
    super.dispose();
  }

  Future<void> _runTest(BleManager m) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await m.testLed3x();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("LED test done")),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Test failed: $e")),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final m = context.read<BleManager>();
    final connected = m.connectedDevice != null;

    return Scaffold(
      appBar: AppBar(title: const Text("Device control")),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: ListView(
          children: [
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      connected ? m.connectedName : "Not connected",
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      connected ? "GATT services: ${m.services.length}" : "Connect on Devices tab",
                      style: TextStyle(color: Colors.grey.shade700),
                    ),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: (connected && m.fe41 != null && !_busy) ? () => _runTest(m) : null,
                      child: Text(_busy ? "Running..." : "Test Connection (LED x3)"),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      m.fe41 != null ? "FE41: ready (writeWithoutResponse)" : "FE41: not available",
                      style: TextStyle(color: Colors.grey.shade700),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Frame editor (placeholder)",
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _frameField1,
                      decoration: const InputDecoration(
                        labelText: "Field 1",
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _frameField2,
                      decoration: const InputDecoration(
                        labelText: "Field 2",
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _frameField3,
                      decoration: const InputDecoration(
                        labelText: "Payload (hex)",
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Readable info (placeholder)",
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    Text(
                      connected
                          ? "Later: read characteristics / device info"
                          : "Connect first",
                      style: TextStyle(color: Colors.grey.shade700),
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
}
