import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:web_socket_channel/web_socket_channel.dart';

import '../models/connection_info.dart';

enum CameraState {
  idle,
  starting,
  streaming,
  stopping,
  error,
}

class CameraService extends ChangeNotifier {
  // Platform channels for H.264 encoder
  static const MethodChannel _methodChannel = MethodChannel('com.viewstage/h264_encoder');
  static const EventChannel _eventChannel = EventChannel('com.viewstage/h264_events');

  WebSocketChannel? _wsChannel;
  CameraState _state = CameraState.idle;
  String? _errorMessage;
  ConnectionInfo? _connection;
  StreamSubscription? _frameSubscription;

  CameraState get state => _state;
  String? get errorMessage => _errorMessage;
  bool get isStreaming => _state == CameraState.streaming;

  Future<bool> startStreaming(ConnectionInfo connection) async {
    if (_state == CameraState.streaming || _state == CameraState.starting) {
      return true;
    }

    _connection = connection;
    _state = CameraState.starting;
    _errorMessage = null;
    notifyListeners();

    try {
      // 1. Notify server to start camera
      final startResult = await _notifyServerStart();
      if (!startResult) {
        throw Exception('服务器拒绝启动摄像头');
      }

      // 2. Establish WebSocket connection
      final wsUrl = 'ws://${connection.ip}:${connection.port}/camera/stream';
      developer.log('[Camera] 连接 WebSocket: $wsUrl', name: 'viewstage');

      _wsChannel = WebSocketChannel.connect(Uri.parse(wsUrl));
      await _wsChannel!.ready;

      // 3. Start native H.264 encoder
      await _startNativeEncoder();

      // 4. Listen for encoded frames from native side
      _frameSubscription = _eventChannel.receiveBroadcastStream().listen(
        (data) {
          if (data is Uint8List && data.isNotEmpty) {
            _sendFrameToWebSocket(data);
          }
        },
        onError: (error) {
          developer.log('[Camera] EventChannel 错误: $error', name: 'viewstage');
        },
      );

      _state = CameraState.streaming;
      notifyListeners();

      developer.log('[Camera] H.264 推流已开始', name: 'viewstage');
      return true;
    } catch (e) {
      developer.log('[Camera] 启动失败: $e', name: 'viewstage');
      _state = CameraState.error;
      _errorMessage = e.toString();
      notifyListeners();
      await _cleanup();
      return false;
    }
  }

  Future<void> _startNativeEncoder() async {
    try {
      final result = await _methodChannel.invokeMethod('start');
      if (result != true) {
        throw Exception('编码器启动失败');
      }
    } on PlatformException catch (e) {
      throw Exception('编码器错误: ${e.message}');
    }
  }

  void _sendFrameToWebSocket(Uint8List data) {
    if (_wsChannel == null || _wsChannel!.closeCode != null) {
      developer.log('[Camera] WebSocket 已断开', name: 'viewstage');
      stopStreaming();
      return;
    }

    try {
      // Data from native side already has the type prefix byte
      // 0x01 = init segment, 0x02 = video segment
      final type = data[0];
      if (type == 0x01) {
        developer.log('[Camera] 发送 init segment (${data.length} bytes)', name: 'viewstage');
      }

      // Send the entire binary frame to WebSocket
      _wsChannel!.sink.add(data);
    } catch (e) {
      developer.log('[Camera] 发送帧失败: $e', name: 'viewstage');
    }
  }

  Future<bool> _notifyServerStart() async {
    if (_connection == null) return false;

    try {
      final uri = Uri.parse('${_connection!.baseUrl}/camera/start');
      final response = await http.post(
        uri,
        headers: {
          'Authorization': 'Bearer ${_connection!.sessionId}',
          'Content-Type': 'application/json',
        },
      ).timeout(const Duration(seconds: 5));

      developer.log('[Camera] 服务器响应: ${response.statusCode}', name: 'viewstage');

      if (response.statusCode == 200) {
        return true;
      } else if (response.statusCode == 409) {
        throw Exception('摄像头被其他设备占用');
      } else {
        throw Exception('服务器拒绝: ${response.statusCode}');
      }
    } catch (e) {
      developer.log('[Camera] 通知服务器失败: $e', name: 'viewstage');
      rethrow;
    }
  }

  Future<void> stopStreaming() async {
    if (_state == CameraState.idle || _state == CameraState.stopping) {
      return;
    }

    _state = CameraState.stopping;
    notifyListeners();

    try {
      // Stop native encoder first
      await _stopNativeEncoder();
    } catch (e) {
      developer.log('[Camera] 停止编码器失败: $e', name: 'viewstage');
    }

    try {
      await _notifyServerStop();
    } catch (e) {
      developer.log('[Camera] 通知服务器停止失败: $e', name: 'viewstage');
    }

    await _cleanup();

    _state = CameraState.idle;
    _errorMessage = null;
    notifyListeners();

    developer.log('[Camera] 推流已停止', name: 'viewstage');
  }

  Future<void> _stopNativeEncoder() async {
    try {
      await _methodChannel.invokeMethod('stop');
    } on PlatformException catch (e) {
      developer.log('[Camera] 停止编码器异常: ${e.message}', name: 'viewstage');
    }
  }

  Future<void> _notifyServerStop() async {
    if (_connection == null) return;

    try {
      final uri = Uri.parse('${_connection!.baseUrl}/camera/stop');
      await http.post(
        uri,
        headers: {
          'Authorization': 'Bearer ${_connection!.sessionId}',
          'Content-Type': 'application/json',
        },
      ).timeout(const Duration(seconds: 5));
    } catch (e) {
      developer.log('[Camera] 通知服务器停止失败: $e', name: 'viewstage');
    }
  }

  Future<void> _cleanup() async {
    _frameSubscription?.cancel();
    _frameSubscription = null;

    try {
      await _wsChannel?.sink.close();
    } catch (e) {
      developer.log('[Camera] 关闭 WebSocket 失败: $e', name: 'viewstage');
    }
    _wsChannel = null;
  }

  @override
  void dispose() {
    if (_state != CameraState.idle) {
      _cleanup();
      _state = CameraState.idle;
    }
    super.dispose();
  }
}
