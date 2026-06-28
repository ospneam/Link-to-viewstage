import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/connection_info.dart';
import '../services/connection_manager.dart';
import '../widgets/control_button.dart';

class RemoteScreen extends StatelessWidget {
  const RemoteScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final manager = context.read<ConnectionManager>();
    final connection = manager.connection!;

    final buttons = [
      _ButtonDef(Icons.arrow_back, '上一页', 'prev'),
      _ButtonDef(Icons.arrow_forward, '下一页', 'next'),
      _ButtonDef(Icons.edit, '批注', 'annotate'),
      _ButtonDef(Icons.open_with, '移动', 'move'),
      _ButtonDef(Icons.auto_fix_high, '橡皮擦', 'eraser'),
      _ButtonDef(Icons.zoom_in, '放大', 'zoom-in'),
      _ButtonDef(Icons.zoom_out_map, '重置', 'zoom-reset'),
      _ButtonDef(Icons.zoom_out, '缩小', 'zoom-out'),
      _ButtonDef(Icons.camera_alt, '截图', 'screenshot'),
      _ButtonDef(Icons.rectangle_outlined, '黑板', 'toggle-blackboard'),
      _ButtonDef(Icons.flip, '镜像', 'mirror'),
      _ButtonDef(Icons.delete_sweep, '清除', 'clear-annotations'),
      _ButtonDef(Icons.undo, '撤销', 'undo'),
      _ButtonDef(Icons.settings, '设置', 'settings'),
    ];

    return SafeArea(
      child: Column(
        children: [
          _buildConnectionInfo(context, connection, manager),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 0.9,
                ),
                itemCount: buttons.length,
                itemBuilder: (context, index) {
                  final def = buttons[index];
                  return ControlButton(
                    icon: def.icon,
                    label: def.label,
                    onPressed: () => manager.sendControl(def.action),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConnectionInfo(
    BuildContext context,
    ConnectionInfo connection,
    ConnectionManager manager,
  ) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
      decoration: const BoxDecoration(
        color: Color(0xFFF5F5F5),
      ),
      child: Row(
        children: [
          const Icon(Icons.computer, size: 16, color: Color(0xFF6B7280)),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  connection.deviceName ?? 'ViewStage PC',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    fontFamily: 'Inter',
                    color: Color(0xFF111111),
                  ),
                ),
                Text(
                  '${connection.ip}:${connection.port}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontFamily: 'Inter',
                    color: Color(0xFF6B7280),
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => manager.disconnect(),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.link_off, size: 14, color: Color(0xFFEF4444)),
                  SizedBox(width: 4),
                  Text(
                    '断开',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      fontFamily: 'Inter',
                      color: Color(0xFFEF4444),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ButtonDef {
  final IconData icon;
  final String label;
  final String action;

  const _ButtonDef(this.icon, this.label, this.action);
}
