import 'dart:convert';
import 'dart:developer' as developer;
import 'package:http/http.dart' as http;
import '../models/connection_info.dart';

class ApiService {
  static Future<ConnectionInfo> connect({
    required String ip,
    required int port,
    required String token,
    String? deviceName,
  }) async {
    final uri = Uri.parse('http://$ip:$port/connect').replace(
      queryParameters: {
        'token': token,
        if (deviceName != null && deviceName.isNotEmpty)
          'device_name': deviceName,
      },
    );

    developer.log('[ApiService] 连接: $uri', name: 'viewstage');

    final response = await http.get(uri).timeout(
          const Duration(seconds: 5),
          onTimeout: () => throw Exception('连接超时，请检查网络'),
        );

    developer.log(
      '[ApiService] 响应: ${response.statusCode} ${response.body}',
      name: 'viewstage',
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final sessionId = data['session'] as String;
      return ConnectionInfo(
        ip: ip,
        port: port,
        token: token,
        sessionId: sessionId,
        deviceName: deviceName,
      );
    } else if (response.statusCode == 403) {
      final body = response.body.isNotEmpty ? ': ${response.body}' : '';
      throw Exception('验证码错误$body');
    } else {
      throw Exception('连接失败 (${response.statusCode}): ${response.body}');
    }
  }

  static Future<bool> sendControl({
    required ConnectionInfo connection,
    required String action,
    Map<String, dynamic>? params,
  }) async {
    final uri = Uri.parse('${connection.baseUrl}/control/$action');
    final response = await http
        .post(
          uri,
          headers: {
            'Content-Type': 'application/json',
            ...connection.authHeaders,
          },
          body: json.encode({'params': params}),
        )
        .timeout(const Duration(seconds: 3));

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return data['success'] as bool? ?? false;
    } else if (response.statusCode == 401) {
      throw Exception('会话已过期，请重新连接');
    }
    return false;
  }

  static Future<bool> sendHeartbeat({
    required ConnectionInfo connection,
  }) async {
    final uri = Uri.parse('${connection.baseUrl}/heartbeat');
    final response = await http
        .post(
          uri,
          headers: {
            'Content-Type': 'application/json',
            ...connection.authHeaders,
          },
          body: '{}',
        )
        .timeout(const Duration(seconds: 5));

    developer.log(
      '[ApiService] 心跳: ${response.statusCode}',
      name: 'viewstage',
    );

    if (response.statusCode == 200) {
      return true;
    } else if (response.statusCode == 401) {
      throw Exception('会话已过期，请重新连接');
    }
    return false;
  }

  static Future<void> sendDisconnect({
    required ConnectionInfo connection,
  }) async {
    try {
      final uri = Uri.parse('${connection.baseUrl}/disconnect');
      await http
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json',
              ...connection.authHeaders,
            },
            body: '{}',
          )
          .timeout(const Duration(seconds: 3));
      developer.log('[ApiService] 已发送断开请求', name: 'viewstage');
    } catch (e) {
      developer.log('[ApiService] 断开请求失败: $e', name: 'viewstage');
    }
  }
}
