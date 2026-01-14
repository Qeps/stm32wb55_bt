import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_blue_plus/flutter_blue_plus.dart';

class BleDeviceEntry {
  final BluetoothDevice device;
  int rssi;
  final String name;

  BleDeviceEntry({required this.device, required this.name, required this.rssi});
}

class BleManager {
  // CubeMX custom 
  static final Guid serviceFe40 = Guid("0000fe40-cc7a-482a-984a-7f2ed5b3e58f");

  // Szukamy po prefiksie 16-bit:
  static bool isFe40(Guid g) => g.str.toLowerCase().startsWith("0000fe40");
  static bool isFe41(Guid g) => g.str.toLowerCase().startsWith("0000fe41");

  final List<BleDeviceEntry> _devices = [];
  List<BleDeviceEntry> get devices => List.unmodifiable(_devices);

  bool _isScanning = false;
  bool get isScanning => _isScanning;

  BluetoothDevice? _connected;
  BluetoothDevice? get connectedDevice => _connected;

  String _connectedName = "";
  String get connectedName => _connectedName;

  int? _lastRssi;
  int? get lastRssi => _lastRssi;

  List<BluetoothService> _services = [];
  List<BluetoothService> get services => List.unmodifiable(_services);

  BluetoothCharacteristic? _fe41;
  BluetoothCharacteristic? get fe41 => _fe41;

  final StreamController<void> _changes = StreamController.broadcast();
  Stream<void> get changes => _changes.stream;
  void _notify() => _changes.add(null);

  StreamSubscription<List<ScanResult>>? _scanSub;

  Future<void> startScanMyCst() async {
    if (_isScanning) return;

    await FlutterBluePlus.adapterState
        .firstWhere((s) => s == BluetoothAdapterState.on);

    _isScanning = true;
    _notify();

    await FlutterBluePlus.startScan(timeout: const Duration(seconds: 8));
    _scanSub?.cancel();
    _scanSub = FlutterBluePlus.scanResults.listen((results) {
      bool changed = false;

      for (final r in results) {
        final name = r.device.platformName;
        if (!name.contains("MyCST")) continue;

        final idx = _devices.indexWhere((e) => e.device.remoteId == r.device.remoteId);
        if (idx >= 0) {
          _devices[idx].rssi = r.rssi;
        } else {
          _devices.add(BleDeviceEntry(device: r.device, name: name, rssi: r.rssi));
          changed = true;
        }
      }

      if (changed) {
        //sortuj po RSSI
        _devices.sort((a, b) => (b.rssi).compareTo(a.rssi));
      }

      _notify();
    });

    // timeout startScan sam wyłączy scanning w platformie
    Future.delayed(const Duration(seconds: 8), () async {
      await stopScan();
    });
  }

  Future<void> stopScan() async {
    if (!_isScanning) return;
    _isScanning = false;
    _notify();
    _scanSub?.cancel();
    _scanSub = null;
    await FlutterBluePlus.stopScan();
  }

  bool isConnectedTo(BluetoothDevice d) {
    return _connected != null && _connected!.remoteId == d.remoteId;
  }

  Future<void> connect(BluetoothDevice d, {int? rssiHint}) async {
    // only-one policy
    if (_connected != null && _connected!.remoteId != d.remoteId) {
      await disconnect();
    }

    await stopScan();

    _connected = d;
    _connectedName = d.platformName;
    _lastRssi = rssiHint;
    _notify();

    await _connected!.connect(
      license: License.free,
      timeout: const Duration(seconds: 10),
    );

    await _discover();
  }

  Future<void> _discover() async {
    if (_connected == null) return;

    _services = await _connected!.discoverServices();
    _fe41 = null;

    for (final s in _services) {
      if (isFe40(s.uuid)) {
        for (final c in s.characteristics) {
          if (isFe41(c.uuid)) {
            _fe41 = c;
          }
        }
      }
    }

    _notify();
  }

  Future<void> disconnect() async {
    await stopScan();

    if (_connected != null) {
      try {
        await _connected!.disconnect();
      } catch (_) {}
    }

    _connected = null;
    _connectedName = "";
    _lastRssi = null;
    _services = [];
    _fe41 = null;

    _notify();
  }

  Future<void> testLed3x() async {
    final c = _fe41;
    if (c == null) throw StateError("FE41 not available");

    // ST Toolbox: 0001 = ON, 0000 = OFF
    final on = Uint8List.fromList([0x00, 0x01]);
    final off = Uint8List.fromList([0x00, 0x00]);

    for (int i = 0; i < 3; i++) {
      await c.write(on, withoutResponse: true);
      await Future.delayed(const Duration(milliseconds: 300));
      await c.write(off, withoutResponse: true);
      await Future.delayed(const Duration(milliseconds: 300));
    }
  }

  void dispose() {
    _scanSub?.cancel();
    _changes.close();
  }
}
