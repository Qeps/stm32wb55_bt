import 'package:flutter/material.dart';

class DeviceTile extends StatelessWidget {
  final String name;
  final int rssi;
  final bool isConnected;
  final VoidCallback onConnect;
  final VoidCallback onDisconnect;

  const DeviceTile({
    super.key,
    required this.name,
    required this.rssi,
    required this.isConnected,
    required this.onConnect,
    required this.onDisconnect,
  });

  @override
  Widget build(BuildContext context) {
    final rssiText = "RSSI $rssi dBm";

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            const Icon(Icons.memory, size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text(rssiText, style: TextStyle(color: Colors.grey.shade700)),
                ],
              ),
            ),
            const SizedBox(width: 10),
            isConnected
                ? FilledButton.tonal(
                    onPressed: onDisconnect,
                    child: const Text("Disconnect"),
                  )
                : FilledButton(
                    onPressed: onConnect,
                    child: const Text("Connect"),
                  ),
          ],
        ),
      ),
    );
  }
}
