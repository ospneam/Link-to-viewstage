class ConnectionInfo {
  final String ip;
  final int port;
  final String token;
  final String sessionId;
  final String? deviceName;

  const ConnectionInfo({
    required this.ip,
    required this.port,
    required this.token,
    required this.sessionId,
    this.deviceName,
  });

  String get baseUrl => 'http://$ip:$port';

  Map<String, String> get authHeaders => {
        'Authorization': 'Bearer $sessionId',
      };

  @override
  String toString() =>
      'ConnectionInfo(ip: $ip, port: $port, sessionId: $sessionId)';
}
