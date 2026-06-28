import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';

import 'package:flutter/services.dart';

class DiscoveredDevice {
  final String alias;
  final String ip;
  final int port;
  final String token;
  final String deviceModel;
  final String deviceType;
  final DateTime discoveredAt;

  DiscoveredDevice({
    required this.alias,
    required this.ip,
    required this.port,
    required this.token,
    required this.deviceModel,
    required this.deviceType,
    DateTime? discoveredAt,
  }) : discoveredAt = discoveredAt ?? DateTime.now();

  String get displayName {
    if (deviceModel.isNotEmpty && deviceModel != 'Unknown') {
      return '$alias ($deviceModel)';
    }
    return alias;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DiscoveredDevice &&
          runtimeType == other.runtimeType &&
          ip == other.ip &&
          port == other.port;

  @override
  int get hashCode => ip.hashCode ^ port.hashCode;
}

class DiscoveryService {
  static const String _multicastGroup = '224.0.0.167';
  static const int _multicastPort = 53317;
  static const Duration _deviceTimeout = Duration(seconds: 15);
  static const MethodChannel _channel = MethodChannel('com.viewstage.multicast');

  RawDatagramSocket? _multicastSocket;
  RawDatagramSocket? _broadcastSocket;
  Timer? _cleanupTimer;
  final Map<String, DiscoveredDevice> _devices = {};
  final StreamController<List<DiscoveredDevice>> _devicesController =
      StreamController<List<DiscoveredDevice>>.broadcast();

  Stream<List<DiscoveredDevice>> get devicesStream => _devicesController.stream;
  List<DiscoveredDevice> get devices => _devices.values.toList();

  Future<void> start() async {
    print('[Discovery] 启动多播监听');
    try {
      // Android 需要获取 MulticastLock
      if (Platform.isAndroid) {
        try {
          await _channel.invokeMethod('acquireMulticastLock');
          print('[Discovery] 已获取 MulticastLock');
        } catch (e) {
          print('[Discovery] 获取 MulticastLock 失败: $e');
        }
      }

      // 监听多播
      try {
        _multicastSocket = await RawDatagramSocket.bind(
          InternetAddress.anyIPv4,
          _multicastPort,
          reuseAddress: true,
        );

        _multicastSocket!.joinMulticast(InternetAddress(_multicastGroup));
        _multicastSocket!.readEventsEnabled = true;

        _multicastSocket!.listen((RawSocketEvent event) {
          if (event == RawSocketEvent.read) {
            final datagram = _multicastSocket!.receive();
            if (datagram != null) {
              _handleDatagram(datagram, 'multicast');
            }
          }
        });

        print('[Discovery] 多播监听已启动');
      } catch (e) {
        print('[Discovery] 多播监听启动失败: $e');
      }

      // 监听普通广播
      try {
        _broadcastSocket = await RawDatagramSocket.bind(
          InternetAddress.anyIPv4,
          _multicastPort,
          reuseAddress: true,
        );

        _broadcastSocket!.readEventsEnabled = true;

        _broadcastSocket!.listen((RawSocketEvent event) {
          if (event == RawSocketEvent.read) {
            final datagram = _broadcastSocket!.receive();
            if (datagram != null) {
              _handleDatagram(datagram, 'broadcast');
            }
          }
        });

        print('[Discovery] 普通广播监听已启动');
      } catch (e) {
        print('[Discovery] 普通广播监听启动失败: $e');
      }

      _cleanupTimer = Timer.periodic(
        const Duration(seconds: 5),
        (_) => _cleanupStaleDevices(),
      );

      print('[Discovery] 监听已启动');
    } catch (e) {
      print('[Discovery] 启动失败: $e');
    }
  }

  void _handleDatagram(Datagram datagram, String source) {
    try {
      final message = utf8.decode(datagram.data);
      final senderIp = datagram.address.address;

      print('[Discovery] 收到广播 ($source): $senderIp');

      final json = jsonDecode(message) as Map<String, dynamic>;

      final alias = json['alias'] as String? ?? 'Unknown';
      final port = json['port'] as int? ?? 0;
      final token = json['token'] as String? ?? '';
      final deviceModel = json['deviceModel'] as String? ?? 'Unknown';
      final deviceType = json['deviceType'] as String? ?? 'desktop';
      final announce = json['announce'] as bool? ?? true;

      if (!announce || port == 0 || token.isEmpty) {
        print('[Discovery] 忽略无效广播: announce=$announce, port=$port, token=$token');
        return;
      }

      final device = DiscoveredDevice(
        alias: alias,
        ip: senderIp,
        port: port,
        token: token,
        deviceModel: deviceModel,
        deviceType: deviceType,
      );

      _devices['$senderIp:$port'] = device;
      _devicesController.add(devices);

      print('[Discovery] 发现设备: ${device.displayName} ($senderIp:$port)');
    } catch (e) {
      print('[Discovery] 解析失败: $e');
    }
  }

  void _cleanupStaleDevices() {
    final now = DateTime.now();
    final staleKeys = _devices.entries
        .where((e) => now.difference(e.value.discoveredAt) > _deviceTimeout)
        .map((e) => e.key)
        .toList();

    if (staleKeys.isNotEmpty) {
      for (final key in staleKeys) {
        _devices.remove(key);
      }
      _devicesController.add(devices);
      developer.log('[Discovery] 清理 ${staleKeys.length} 个超时设备', name: 'viewstage');
    }
  }

  Future<void> stop() async {
    _cleanupTimer?.cancel();
    _cleanupTimer = null;
    _multicastSocket?.close();
    _multicastSocket = null;
    _broadcastSocket?.close();
    _broadcastSocket = null;
    _devices.clear();
    _devicesController.add([]);

    // 释放 MulticastLock
    if (Platform.isAndroid) {
      try {
        await _channel.invokeMethod('releaseMulticastLock');
      } catch (e) {
        print('[Discovery] 释放 MulticastLock 失败: $e');
      }
    }

    print('[Discovery] 已停止');
  }

  void dispose() {
    stop();
    _devicesController.close();
  }
}
