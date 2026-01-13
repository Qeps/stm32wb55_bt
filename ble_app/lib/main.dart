import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

void main() {
  runApp(const BleApp());
}

class BleApp extends StatelessWidget {
  const BleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: BleConnectPage(),
    );
  }
}

class BleConnectPage extends StatefulWidget {
  const BleConnectPage({super.key});

  @override
  State<BleConnectPage> createState() => _BleConnectPageState();
}

class _BleConnectPageState extends State<BleConnectPage> {
  StreamSubscription<List<ScanResult>>? _scanSub;
  BluetoothDevice? _device;

  BluetoothCharacteristic? _fe41; // RX: writeWithoutResponse

  String _log = "";

  final Guid serviceUuid = Guid("0000fe40-cc7a-482a-984a-7f2ed5b3e58f");
  final Guid fe41Uuid   = Guid("0000fe41-cc7a-482a-984a-7f2ed5b3e58f");

  void _append(String s) => setState(() => _log = "$_log$s\n");

  Future<void> _scanAndConnect() async {
    _append("Waiting for Bluetooth adapter...");
    await FlutterBluePlus.adapterState
        .firstWhere((s) => s == BluetoothAdapterState.on);

    _append("Start scan...");
    await FlutterBluePlus.startScan(timeout: const Duration(seconds: 8));

    _scanSub?.cancel();
    _scanSub = FlutterBluePlus.scanResults.listen((results) async {
      for (final r in results) {
        final name = r.device.platformName;
        if (name.isEmpty) continue;

        if (name.contains("MyCST")) {
          _append("Found: $name  RSSI=${r.rssi}");
          await FlutterBluePlus.stopScan();

          _device = r.device;

          _append("Connecting...");
          await _device!.connect(
            license: License.free,
            timeout: const Duration(seconds: 10),
          );
          _append("Connected.");

          await _discoverFe41();
          return;
        }
      }
    });
  }

  Future<void> _discoverFe41() async {
    final services = await _device!.discoverServices();
    for (final s in services) {
      if (s.uuid.str.toLowerCase().startsWith("0000fe40")) {
        for (final c in s.characteristics) {
          if (c.uuid.str.toLowerCase().startsWith("0000fe41")) {
            _fe41 = c;
            _append("FE41 ready (writeWithoutResponse).");
            return;
          }
        }
      }
    }
    _append("ERROR: FE41 not found.");
  }

  Future<void> _testLed3x() async {
    if (_fe41 == null) {
      _append("FE41 not available.");
      return;
    }

    _append("Test LED x3 start");

    // zgodnie z ST BLE Toolbox: 0001 = ON, 0000 = OFF
    final on  = Uint8List.fromList([0x00, 0x01]);
    final off = Uint8List.fromList([0x00, 0x00]);

    for (int i = 0; i < 3; i++) {
      await _fe41!.write(on, withoutResponse: true);
      await Future.delayed(const Duration(milliseconds: 300));
      await _fe41!.write(off, withoutResponse: true);
      await Future.delayed(const Duration(milliseconds: 300));
    }

    _append("Test LED x3 done");
  }

  Future<void> _disconnect() async {
    _scanSub?.cancel();
    await FlutterBluePlus.stopScan();
    if (_device != null) {
      _append("Disconnecting...");
      await _device!.disconnect();
      _append("Disconnected.");
    }
    _device = null;
    _fe41 = null;
  }

  @override
  void dispose() {
    _disconnect();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final connected = _device != null && _fe41 != null;

    return Scaffold(
      appBar: AppBar(title: const Text("STM32WB BLE connect")),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              children: [
                ElevatedButton(
                  onPressed: _scanAndConnect,
                  child: const Text("Scan + Connect"),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _disconnect,
                  child: const Text("Disconnect"),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: connected ? _testLed3x : null,
              child: const Text("Test Connection"),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: SingleChildScrollView(
                child: Text(
                  _log,
                  style: const TextStyle(fontFamily: "monospace"),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
