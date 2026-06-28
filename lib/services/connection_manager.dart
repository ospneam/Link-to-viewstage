import 'dart:async';
import 'dart:io' show Platform, Socket, SocketException;
import 'package:flutter/foundation.dart';
import 'package:device_info_plus/device_info_plus.dart';
import '../models/connection_info.dart';
import 'api_service.dart';

class ConnectionManager extends ChangeNotifier {
  ConnectionInfo? _connection;
  bool _isLoading = false;
  String? _error;
  Timer? _heartbeatTimer;

  ConnectionInfo? get connection => _connection;
  bool get isConnected => _connection != null;
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// 尝试 TCP 连接以检查服务器是否可达
  Future<String?> _checkConnectivity(String ip, int port) async {
    try {
      final socket = await Socket.connect(
        ip,
        port,
        timeout: const Duration(seconds: 3),
      );
      socket.destroy();
      return null;
    } on SocketException catch (e) {
      if (e.message.contains('Connection refused')) {
        return '服务器拒绝连接，请确认 ViewStage 已打开「手机互联」面板';
      }
      if (e.message.contains('No route to host') ||
          e.message.contains('Network is unreachable') ||
          e.message.contains('连接超时')) {
        return '无法访问服务器，请确认手机和电脑在同一 WiFi 网络';
      }
      return '网络连接失败: ${e.message}';
    } catch (e) {
      return '网络检测异常: $e';
    }
  }

  Future<bool> connect({
    required String ip,
    required int port,
    required String token,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final connectivityError = await _checkConnectivity(ip, port);
      if (connectivityError != null) {
        _error = connectivityError;
        _isLoading = false;
        notifyListeners();
        return false;
      }

      String? deviceName;
      if (Platform.isAndroid) {
        final deviceInfo = DeviceInfoPlugin();
        final androidInfo = await deviceInfo.androidInfo;
        deviceName = androidInfo.model;
      }

      final info = await ApiService.connect(
        ip: ip,
        port: port,
        token: token,
        deviceName: deviceName,
      );

      _connection = info;
      _isLoading = false;
      notifyListeners();
      _startHeartbeat();
      return true;
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _sendHeartbeat(),
    );
  }

  Future<void> _sendHeartbeat() async {
    if (_connection == null) return;
    try {
      final ok = await ApiService.sendHeartbeat(connection: _connection!);
      if (!ok) {
        disconnect();
      }
    } catch (e) {
      if (e.toString().contains('会话已过期')) {
        disconnect();
      }
    }
  }

  Future<void> disconnect() async {
    if (_connection != null) {
      await ApiService.sendDisconnect(connection: _connection!);
    }
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    _connection = null;
    _error = null;
    notifyListeners();
  }

  Future<bool> sendControl(String action, {Map<String, dynamic>? params}) async {
    if (_connection == null) return false;
    try {
      return await ApiService.sendControl(
        connection: _connection!,
        action: action,
        params: params,
      );
    } catch (e) {
      if (e.toString().contains('会话已过期')) {
        disconnect();
      }
      return false;
    }
  }
}
