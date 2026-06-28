import 'package:flutter/material.dart';

class StatusBanner extends StatelessWidget {
  final String? deviceIp;
  final VoidCallback onDisconnect;

  const StatusBanner({
    super.key,
    this.deviceIp,
    required this.onDisconnect,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: const BoxDecoration(
        color: Color(0xFFF5F5F5),
        border: Border(
          bottom: BorderSide(
            color: Color(0xFFE5E7EB),
            width: 0.5,
          ),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: Color(0xFF10B981),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  '已连接',
                  style: TextStyle(
                    color: Color(0xFF10B981),
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    fontFamily: 'Inter',
                  ),
                ),
                if (deviceIp != null)
                  Text(
                    deviceIp!,
                    style: const TextStyle(
                      color: Color(0xFF6B7280),
                      fontSize: 13,
                      fontFamily: 'Inter',
                    ),
                  ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.link_off, size: 20),
            tooltip: '断开',
            onPressed: onDisconnect,
          ),
        ],
      ),
    );
  }
}
