import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/connection_manager.dart';
import '../services/discovery_service.dart';
import '../widgets/manual_input_form.dart';

class ConnectScreen extends StatefulWidget {
  const ConnectScreen({super.key});

  @override
  State<ConnectScreen> createState() => _ConnectScreenState();
}

class _ConnectScreenState extends State<ConnectScreen> {
  bool _showManualInput = false;
  final DiscoveryService _discovery = DiscoveryService();
  List<DiscoveredDevice> _devices = [];

  @override
  void initState() {
    super.initState();
    developer.log('[ConnectScreen] initState', name: 'viewstage');
    _discovery.start();
    _discovery.devicesStream.listen((devices) {
      if (mounted) {
        setState(() => _devices = devices);
      }
    });
  }

  @override
  void dispose() {
    _discovery.dispose();
    super.dispose();
  }

  Future<void> _connectToDevice(DiscoveredDevice device) async {
    developer.log('[ConnectScreen] 连接到 ${device.displayName}', name: 'viewstage');
    final manager = context.read<ConnectionManager>();
    final success = await manager.connect(
      ip: device.ip,
      port: device.port,
      token: device.token,
    );

    if (!mounted) return;

    if (!success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('连接失败: ${manager.error ?? "未知错误"}'),
          backgroundColor: const Color(0xFFEF4444),
        ),
      );
    }
  }

  Future<void> _handleManualConnect(String ip, int port, String token) async {
    final manager = context.read<ConnectionManager>();
    final success = await manager.connect(ip: ip, port: port, token: token);

    if (!mounted) return;

    if (!success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('连接失败: ${manager.error ?? "未知错误"}'),
          backgroundColor: const Color(0xFFEF4444),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFFFFF),
      body: SafeArea(
        child: Column(
          children: [
            // 顶部栏
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
              child: Row(
                children: [
                  const Text(
                'ViewStage',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'Inter',
                  color: Color(0xFF111111),
                ),
              ),
              const Spacer(),
              IconButton(
                icon: Icon(_showManualInput ? Icons.qr_code : Icons.keyboard),
                iconSize: 20,
                color: const Color(0xFF6B7280),
                tooltip: _showManualInput ? '自动发现' : '手动输入',
                onPressed: () => setState(() {
                  _showManualInput = !_showManualInput;
                }),
              ),
            ],
          ),
        ),
        // 内容
        Expanded(
          child: _showManualInput ? _buildManualInput() : _buildDeviceList(),
        ),
        ],
      ),
      ),
    );
  }

  Widget _buildDeviceList() {
    if (_devices.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.wifi_find, size: 64, color: Color(0xFF6B7280)),
            const SizedBox(height: 16),
            const Text(
              '正在搜索 ViewStage 电脑...',
              style: TextStyle(
                fontSize: 16,
                color: Color(0xFF6B7280),
                fontFamily: 'Inter',
              ),
            ),
            const SizedBox(height: 8),
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(height: 24),
            const Text(
              '请确保电脑端已打开「手机互联」面板',
              style: TextStyle(
                fontSize: 13,
                color: Color(0xFF6B7280),
                fontFamily: 'Inter',
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: _devices.length,
      itemBuilder: (context, index) {
        final device = _devices[index];
        return _DeviceCard(
          device: device,
          onTap: () => _connectToDevice(device),
        );
      },
    );
  }

  Widget _buildManualInput() {
    return Consumer<ConnectionManager>(
      builder: (context, manager, _) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(
                Icons.wifi_find,
                size: 64,
                color: Color(0xFF111111),
              ),
              const SizedBox(height: 16),
              Text(
                '手动连接',
                style: Theme.of(context).textTheme.headlineMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                '在 ViewStage 菜单中打开「手机互联」，输入显示的连接信息',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: const Color(0xFF6B7280),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              ManualInputForm(
                isLoading: manager.isLoading,
                error: manager.error,
                onSubmit: _handleManualConnect,
              ),
            ],
          ),
        );
      },
    );
  }
}

class _DeviceCard extends StatelessWidget {
  final DiscoveredDevice device;
  final VoidCallback onTap;

  const _DeviceCard({required this.device, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: const Color(0xFFF5F5F5),
          child: Icon(
            _getDeviceIcon(),
            color: const Color(0xFF111111),
          ),
        ),
        title: Text(
          device.displayName,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontFamily: 'Inter',
          ),
        ),
        subtitle: Text(
          '${device.ip}:${device.port}',
          style: const TextStyle(
            color: Color(0xFF6B7280),
            fontFamily: 'Inter',
          ),
        ),
        trailing: FilledButton(
          onPressed: onTap,
          child: const Text('连接'),
        ),
        onTap: onTap,
      ),
    );
  }

  IconData _getDeviceIcon() {
    switch (device.deviceType) {
      case 'mobile':
        return Icons.phone_android;
      case 'desktop':
        return Icons.computer;
      case 'web':
        return Icons.web;
      default:
        return Icons.devices;
    }
  }
}
