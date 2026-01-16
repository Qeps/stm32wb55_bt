import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../ble/ble_manager.dart';

class LogsScreen extends StatelessWidget {
  const LogsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final m = context.read<BleManager>();

    return Scaffold(
      appBar: AppBar(title: const Text("Logs")),
      body: StreamBuilder<void>(
        stream: m.changes,
        builder: (context, _) {
          final logs = m.logs.reversed.toList(); // newest on top
          return Padding(
            padding: const EdgeInsets.all(12),
            child: logs.isEmpty
                ? Center(
                    child: Text(
                      "No logs yet",
                      style: TextStyle(color: Colors.grey.shade700),
                    ),
                  )
                : Scrollbar(
                    child: ListView.separated(
                      reverse: true,
                      itemCount: logs.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, i) {
                        final e = logs[i];
                        final t = e.time;
                        final hh = t.hour.toString().padLeft(2, '0');
                        final mm = t.minute.toString().padLeft(2, '0');
                        final ss = t.second.toString().padLeft(2, '0');
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(
                                width: 64,
                                child: Text(
                                  "$hh:$mm:$ss",
                                  style: TextStyle(
                                    fontFeatures: const [FontFeature.tabularFigures()],
                                    color: Colors.grey.shade700,
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  e.message,
                                  style: const TextStyle(fontSize: 14),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
          );
        },
      ),
    );
  }
}
