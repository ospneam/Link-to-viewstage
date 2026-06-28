import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:image_picker/image_picker.dart';

import '../models/connection_info.dart';

class UploadResult {
  final bool success;
  final String? path;
  final String? name;
  final int? size;
  final String? error;

  UploadResult({
    required this.success,
    this.path,
    this.name,
    this.size,
    this.error,
  });

  factory UploadResult.fromJson(Map<String, dynamic> json) {
    return UploadResult(
      success: json['success'] as bool? ?? false,
      path: json['path'] as String?,
      name: json['name'] as String?,
      size: json['size'] as int?,
    );
  }

  factory UploadResult.error(String message) {
    return UploadResult(success: false, error: message);
  }
}

class UploadService {
  static const int _maxFileSize = 50 * 1024 * 1024; // 50MB

  static const Map<String, String> _mimeTypes = {
    'pdf': 'application/pdf',
    'doc': 'application/msword',
    'docx': 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    'jpg': 'image/jpeg',
    'jpeg': 'image/jpeg',
    'png': 'image/png',
    'bmp': 'image/bmp',
    'gif': 'image/gif',
    'webp': 'image/webp',
  };

  static String _getMimeType(String fileName) {
    final ext = fileName.split('.').last.toLowerCase();
    return _mimeTypes[ext] ?? 'application/octet-stream';
  }

  static bool _isAllowedFile(String fileName) {
    final ext = fileName.split('.').last.toLowerCase();
    return _mimeTypes.containsKey(ext);
  }

  /// 从相册选择图片并上传
  static Future<UploadResult> pickAndUploadImage({
    required ConnectionInfo connection,
    void Function(double progress)? onProgress,
  }) async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 100,
      );

      if (pickedFile == null) {
        return UploadResult.error('未选择文件');
      }

      final file = File(pickedFile.path);
      final fileName = pickedFile.name;

      return await uploadFile(
        connection: connection,
        file: file,
        fileName: fileName,
        onProgress: onProgress,
      );
    } catch (e) {
      developer.log('[Upload] 选择图片错误: $e', name: 'viewstage');
      return UploadResult.error('选择图片失败: $e');
    }
  }

  /// 上传文件
  static Future<UploadResult> uploadFile({
    required ConnectionInfo connection,
    required File file,
    required String fileName,
    void Function(double progress)? onProgress,
  }) async {
    // 检查文件大小
    final fileSize = await file.length();
    if (fileSize > _maxFileSize) {
      return UploadResult.error('文件超过 50MB 限制');
    }

    // 检查文件类型
    if (!_isAllowedFile(fileName)) {
      return UploadResult.error('不支持的文件类型');
    }

    developer.log('[Upload] 开始上传: $fileName ($fileSize bytes)', name: 'viewstage');

    try {
      final uri = Uri.parse('${connection.baseUrl}/file/upload');
      final request = http.MultipartRequest('POST', uri)
        ..headers['Authorization'] = 'Bearer ${connection.sessionId}'
        ..files.add(await http.MultipartFile.fromPath(
          'file',
          file.path,
          filename: fileName,
          contentType: MediaType.parse(_getMimeType(fileName)),
        ));

      final response = await request.send().timeout(
        const Duration(minutes: 5),
        onTimeout: () => throw Exception('上传超时'),
      );

      final responseBody = await response.stream.bytesToString();

      developer.log(
        '[Upload] 响应: ${response.statusCode} $responseBody',
        name: 'viewstage',
      );

      if (response.statusCode == 200) {
        final json = jsonDecode(responseBody) as Map<String, dynamic>;
        return UploadResult.fromJson(json);
      } else if (response.statusCode == 401) {
        return UploadResult.error('会话已过期，请重新连接');
      } else {
        return UploadResult.error('上传失败 (${response.statusCode}): $responseBody');
      }
    } catch (e) {
      developer.log('[Upload] 错误: $e', name: 'viewstage');
      return UploadResult.error('上传失败: $e');
    }
  }
}
