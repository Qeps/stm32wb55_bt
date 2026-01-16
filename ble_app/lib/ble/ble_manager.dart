import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_blue_plus/flutter_blue_plus.dart';

class BleDeviceEntry {
  final BluetoothDevice device;
  int rssi;
  final String name;

  BleDeviceEntry({
    required this.device,
    required this.name,
    required this.rssi,
  });
}

class BleManager {
  /* ==== UUIDs (from CubeMX custom service) ==== */

  static final Guid serviceFe40 =
      Guid("0000fe40-cc7a-482a-984a-7f2ed5b3e58f");

  static bool isFe40(Guid g) => g.str.toLowerCase().startsWith("0000fe40");
  static bool isFe41(Guid g) => g.str.toLowerCase().startsWith("0000fe41"); // LED_C, write no resp
  static bool isFe42(Guid g) => g.str.toLowerCase().startsWith("0000fe42"); // SWITCH_C (unused)
  static bool isFe43(Guid g) => g.str.toLowerCase().startsWith("0000fe43"); // LONG_C, notifications

  /* ==== State ==== */

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

  BluetoothCharacteristic? _fe41; // write (AA xx)
  BluetoothCharacteristic? _fe43; // notify (BB xx payload)

  BluetoothCharacteristic? get fe41 => _fe41;
  BluetoothCharacteristic? get fe43 => _fe43;

  final List<BleLogEntry> _logs = [];
  List<BleLogEntry> get logs => List.unmodifiable(_logs);

  final StreamController<void> _changes = StreamController.broadcast();
  Stream<void> get changes => _changes.stream;
  void _notify() => _changes.add(null);

  StreamSubscription<List<ScanResult>>? _scanSub;
  StreamSubscription<List<int>>? _notifySub;

  /* ==== Protocol ==== */

  static const int _rxPreamble = 0xBB;
  static const int _txPreamble = 0xAA;

  Completer<Uint8List>? _pending;
  int? _pendingCmd;

  /* ========================================================= */
  /* =================== SCANNING ============================ */
  /* ========================================================= */

  Future<void> startScanMyCst() async {
    if (_isScanning) return;

    await FlutterBluePlus.adapterState
        .firstWhere((s) => s == BluetoothAdapterState.on);

    _isScanning = true;
    _addLog("Scan start");
    _notify();

    await FlutterBluePlus.startScan(timeout: const Duration(seconds: 8));
    _scanSub?.cancel();

    _scanSub = FlutterBluePlus.scanResults.listen((results) {
      bool changed = false;

      for (final r in results) {
        final name = r.device.platformName;
        if (!name.contains("MyCST")) continue;

        final idx = _devices.indexWhere(
          (e) => e.device.remoteId == r.device.remoteId,
        );

        if (idx >= 0) {
          _devices[idx].rssi = r.rssi;
        } else {
          _devices.add(
            BleDeviceEntry(device: r.device, name: name, rssi: r.rssi),
          );
          changed = true;
        }
      }

      if (changed) {
        _devices.sort((a, b) => b.rssi.compareTo(a.rssi));
      }

      _notify();
    });

    Future.delayed(const Duration(seconds: 8), stopScan);
  }

  Future<void> stopScan() async {
    if (!_isScanning) return;
    _isScanning = false;
    _addLog("Scan stop");
    _notify();
    _scanSub?.cancel();
    _scanSub = null;
    await FlutterBluePlus.stopScan();
  }

  /* ========================================================= */
  /* =================== CONNECTION ========================== */
  /* ========================================================= */

  Future<void> connect(BluetoothDevice d, {int? rssiHint}) async {
    if (_connected != null && _connected!.remoteId != d.remoteId) {
      await disconnect();
    }

    await stopScan();

    _connected = d;
    _connectedName = d.platformName;
    _lastRssi = rssiHint;
    _addLog("Connect ${d.platformName}");
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
    _fe43 = null;

    for (final s in _services) {
      if (!isFe40(s.uuid)) continue;

      for (final c in s.characteristics) {
        if (isFe41(c.uuid)) _fe41 = c;
        if (isFe43(c.uuid)) _fe43 = c;
      }
    }

    if (_fe43 != null) {
      await _fe43!.setNotifyValue(true);
      _notifySub?.cancel();
      _notifySub = _fe43!.lastValueStream.listen(_onNotify);
    }

    _addLog("Discover done (FE41=${_fe41 != null}, FE43=${_fe43 != null})");
    _notify();
  }

  Future<void> disconnect() async {
    await stopScan();

    _notifySub?.cancel();
    _notifySub = null;

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
    _fe43 = null;

    _addLog("Disconnected");
    _notify();
  }

  bool isConnectedTo(BluetoothDevice d) {
    return _connected != null && _connected!.remoteId == d.remoteId;
  }

  /* ========================================================= */
  /* =================== PROTOCOL CORE ======================= */
  /* ========================================================= */

  void _onNotify(List<int> data) {
    if (data.length < 2) return;
    if (data[0] != _rxPreamble) return;
    if (_pending == null) return;
    if (data[1] != _pendingCmd) return;

    _pending!.complete(Uint8List.fromList(data));
    _addLog("BB ${data[1].toRadixString(16).padLeft(2, '0')} rsp len=${data.length}");
    _pending = null;
    _pendingCmd = null;
  }

  Future<Uint8List> _sendCmd(
    int cmd, {
    Duration timeout = const Duration(seconds: 2),
  }) async {
    final c = _fe41;
    if (c == null) {
      throw StateError("FE41 not available");
    }

    if (_pending != null) {
      throw StateError("Protocol busy");
    }

    _pending = Completer<Uint8List>();
    _pendingCmd = cmd;

    await c.write(
      Uint8List.fromList([_txPreamble, cmd]),
      // firmware handles WRITE_NO_RESP for LED_C
      withoutResponse: true,
    );

    _addLog("AA ${cmd.toRadixString(16).padLeft(2, '0')}");

    return _pending!.future.timeout(timeout, onTimeout: () {
      _pending = null;
      _pendingCmd = null;
      _addLog("Timeout cmd 0x${cmd.toRadixString(16)}");
      throw TimeoutException("No response for cmd 0x${cmd.toRadixString(16)}");
    });
  }

  /* ========================================================= */
  /* =================== PUBLIC API ========================== */
  /* ========================================================= */

  /// AA 01 -> BB 01 rssi
  Future<int> getRssi() async {
    final rsp = await _sendCmd(0x01);
    final rssi = rsp[2].toSigned(8);
    _addLog("RSSI $rssi dBm");
    return rssi;
  }

  /// AA 02 -> BB 02 major minor sub status
  Future<List<int>> getFwBuild() async {
    final rsp = await _sendCmd(0x02);
    return [rsp[2], rsp[3], rsp[4], rsp[5]];
  }

  /// AA 03 -> BB 03 1/0
  Future<bool> ledTest() async {
    final rsp = await _sendCmd(0x03);
    return rsp[2] != 0;
  }

  /// RAW LED test, identical do ST Toolbox: WRITE AA 03
  Future<void> ledTestRaw() async {
    final c = _fe41;
    if (c == null) {
      throw StateError("FE41 not available");
    }

    await c.write(
      Uint8List.fromList([_txPreamble, 0x03]),
      withoutResponse: true,
    );
  }

  /// AA 04 -> BB 04 link_status[0]
  Future<int> getLinkStatus() async {
    final rsp = await _sendCmd(0x04);
    return rsp[2];
  }

  void dispose() {
    _scanSub?.cancel();
    _notifySub?.cancel();
    _changes.close();
  }

  void log(String msg) => _addLog(msg);

  void _addLog(String msg) {
    _logs.add(BleLogEntry(DateTime.now(), msg));
    if (_logs.length > 200) {
      _logs.removeRange(0, _logs.length - 200);
    }
    _notify();
  }
}

class BleLogEntry {
  final DateTime time;
  final String message;
  BleLogEntry(this.time, this.message);
}
