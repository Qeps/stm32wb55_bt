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
  bool _rssiPollInFlight = false;
  bool _rssiPollingEnabled = true;
  bool _statusLoadedOnce = false;
  int? _rssi;
  List<int>? _fwBuild;
  int? _linkStatus;
  final List<_RssiSample> _rssiHistory = [];
  Timer? _pollTimer;

  @override
  bool get wantKeepAlive => true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sub?.cancel();
    final m = context.read<BleManager>();
    _sub = m.changes.listen((_) {
      if (!mounted) return;
      setState(() {});
      _handleConnectionChange(m);
    });

    if (m.connectedDevice != null) {
      _refreshStatus(m);
      _handleConnectionChange(m);
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    _frameField1.dispose();
    _frameField2.dispose();
    _frameField3.dispose();
    _pollTimer?.cancel();
    super.dispose();
  }

  void _handleConnectionChange(BleManager m) {
    if (m.connectedDevice == null) {
      _pollTimer?.cancel();
      _pollTimer = null;
      _rssiHistory.clear();
      _rssi = null;
      _fwBuild = null;
      _linkStatus = null;
      _statusLoadedOnce = false;
      return;
    }

    _startPollingTimer(m);

    if (!_statusLoadedOnce) {
      _statusLoadedOnce = true;
      _refreshStatus(m);
    }
  }

  Future<void> _pollRssi(BleManager m) async {
    if (!_rssiPollingEnabled || _rssiPollInFlight || m.connectedDevice == null) return;
    _rssiPollInFlight = true;
    try {
      final rssi = await m.getRssi(); // AA 01
      if (!mounted) return;
      setState(() {
        _rssi = rssi;
        _pushRssiSample(rssi);
      });
    } catch (_) {
      // ignore polling errors
    } finally {
      _rssiPollInFlight = false;
    }
  }

  void _startPollingTimer(BleManager m) {
    if (!_rssiPollingEnabled || _pollTimer != null) return;
    _pollTimer = Timer.periodic(const Duration(seconds: 1), (_) => _pollRssi(m));
  }

  void _pausePolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  void _togglePolling(BleManager m) {
    setState(() => _rssiPollingEnabled = !_rssiPollingEnabled);
    if (_rssiPollingEnabled) {
      // reset chart on fresh session
      _rssiHistory.clear();
      _startPollingTimer(m);
      m.log("RSSI polling resumed");
    } else {
      _pausePolling();
      m.log("RSSI polling paused");
    }
  }

  Future<void> _refreshStatus(BleManager m) async {
    if (_busy || m.connectedDevice == null) return;

    try {
      final rssi = await m.getRssi();        // AA 01
      final fw   = await m.getFwBuild();     // AA 02
      final link = await m.getLinkStatus();  // AA 04

      if (!mounted) return;
      setState(() {
        _rssi = rssi;
        _fwBuild = fw;
        _linkStatus = link;
        _pushRssiSample(rssi);
      });
    } catch (_) {
      // cicho: ekran diagnostyczny
    }
  }

  Future<void> _runTest(BleManager m) async {
    if (_busy || m.connectedDevice == null) return;
    final wasPolling = _rssiPollingEnabled;
    if (wasPolling) {
      _pausePolling();
    }
    setState(() => _busy = true);
    try {
      final ok = await m.ledTest(); // AA 03
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(ok ? "LED test OK" : "LED test failed")),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Test failed: $e")),
        );
      }
    } finally {
      if (wasPolling) {
        _startPollingTimer(m);
      }
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final m = context.read<BleManager>();
    final connected = m.connectedDevice != null;
    final fw = _fwBuild;

    return Scaffold(
      appBar: AppBar(title: const Text("Device control")),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: ListView(
          children: [
            /// ===== Device status =====
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Device status",
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 10),
                    _statusRow(
                      "Connection",
                      connected ? "Connected" : "Not connected",
                    ),
                    _statusRow(
                      "FW build",
                      fw == null ? "-" : "${fw[0]}.${fw[1]}.${fw[2]} (st=${fw[3]})",
                    ),
                    _statusRow(
                      "Link status",
                      _linkStatus == null
                          ? "—"
                          : (_linkStatus! > 0 ? "Active (0x${_linkStatus!.toRadixString(16)})" : "Inactive"),
                    ),
                    const SizedBox(height: 8),
                    TextButton.icon(
                      onPressed: connected && !_busy ? () => _refreshStatus(m) : null,
                      icon: const Icon(Icons.refresh),
                      label: const Text("Refresh"),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 12),

            /// ===== RSSI chart =====
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                "RSSI history",
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _rssi != null ? "${_rssi} dBm" : "—",
                                style: TextStyle(color: Colors.grey.shade700),
                              ),
                            ],
                          ),
                        ),
                        TextButton.icon(
                          onPressed: connected ? () => _togglePolling(m) : null,
                          icon: Icon(_rssiPollingEnabled ? Icons.pause : Icons.play_arrow),
                          label: Text(_rssiPollingEnabled ? "Pause" : "Resume"),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 160,
                      child: _rssiHistory.length < 2
                          ? Center(
                              child: Text(
                                "Press Refresh a few times",
                                style: TextStyle(color: Colors.grey.shade700),
                              ),
                            )
                          : CustomPaint(
                              painter: _RssiPainter(
                                samples: List<_RssiSample>.from(_rssiHistory),
                              ),
                              child: Container(),
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
                      child: Text(_busy ? "Running..." : "Test AA 03 (LED)"),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      m.fe41 != null ? "FE41: ready (writeWithoutResponse)" : "FE41: not available",
                      style: TextStyle(color: Colors.grey.shade700),
                    ),
                    Text(
                      m.fe43 != null ? "FE43: notify (BB xx)" : "FE43: not available",
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

  Widget _statusRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey.shade700)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  void _pushRssiSample(int v) {
    final now = DateTime.now();
    _rssiHistory.add(_RssiSample(now, v));
    // keep rolling window of 60 samples
    if (_rssiHistory.length > 60) {
      _rssiHistory.removeRange(0, _rssiHistory.length - 60);
    }
  }
}

class _RssiSample {
  final DateTime t;
  final int rssi;
  _RssiSample(this.t, this.rssi);
}

class _RssiPainter extends CustomPainter {
  final List<_RssiSample> samples;

  _RssiPainter({required this.samples});

  @override
  void paint(Canvas canvas, Size size) {
    if (samples.length < 2) return;

    const double leftPad = 46;
    const double bottomPad = 24;
    const double rightPad = 8;
    const double topPad = 8;

    final chartWidth = size.width - leftPad - rightPad;
    final chartHeight = size.height - topPad - bottomPad;
    if (chartWidth <= 0 || chartHeight <= 0) return;

    final minRssi = samples.map((s) => s.rssi).reduce((a, b) => a < b ? a : b);
    final maxRssi = samples.map((s) => s.rssi).reduce((a, b) => a > b ? a : b);
    final rssiRange = (maxRssi - minRssi).abs().clamp(8, 80); // avoid flat line

    final start = samples.first.t.millisecondsSinceEpoch.toDouble();
    final end = samples.last.t.millisecondsSinceEpoch.toDouble();
    final timeRange = (end - start).clamp(1, 60 * 1000);

    final path = Path();
    for (int i = 0; i < samples.length; i++) {
      final s = samples[i];
      final x = leftPad + ((s.t.millisecondsSinceEpoch - start) / timeRange) * chartWidth;
      final yNorm = (s.rssi - minRssi) / rssiRange;
      final y = topPad + chartHeight - (yNorm * chartHeight);

      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    final paint = Paint()
      ..color = const Color(0xFF1565C0)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final grid = Paint()
      ..color = const Color(0xFFB0BEC5)
      ..strokeWidth = 0.5;

    // draw horizontal grid (min / mid / max) and labels
    final yMin = topPad + chartHeight;
    final yMax = topPad;
    final yMid = topPad + chartHeight / 2;
    canvas.drawLine(Offset(leftPad, yMin), Offset(size.width - rightPad, yMin), grid);
    canvas.drawLine(Offset(leftPad, yMid), Offset(size.width - rightPad, yMid), grid);
    canvas.drawLine(Offset(leftPad, yMax), Offset(size.width - rightPad, yMax), grid);

    _drawText(canvas, "${minRssi} dBm", Offset(4, yMin - 8));
    _drawText(canvas, "${(minRssi + maxRssi) ~/ 2} dBm", Offset(4, yMid - 8));
    _drawText(canvas, "${maxRssi} dBm", Offset(4, yMax - 8));

    // X-axis: only show elapsed seconds in bottom-right
    final spanSec = (timeRange / 1000).round();
    _drawText(canvas, "${spanSec}s", Offset(size.width - rightPad - 32, size.height - bottomPad + 4));

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _RssiPainter oldDelegate) => true;

  void _drawText(Canvas canvas, String text, Offset offset) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: const TextStyle(fontSize: 11, color: Color(0xFF455A64)),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, offset);
  }
}
