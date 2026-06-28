import 'dart:developer' as developer;
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../services/connection_manager.dart';
import '../services/upload_service.dart';

class UploadPage extends StatefulWidget {
  const UploadPage({super.key});

  @override
  State<UploadPage> createState() => _UploadPageState();
}

class _UploadPageState extends State<UploadPage> {
  static const _filePickerChannel = MethodChannel('com.viewstage/file_picker');

  bool _isUploading = false;
  double _uploadProgress = 0;
  String? _uploadingFileName;
  final List<_UploadRecord> _history = [];

  Future<void> _pickAndUploadImage() async {
    if (_isUploading) return;

    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 100,
      );

      if (pickedFile == null) return;

      final connection = context.read<ConnectionManager>().connection;
      if (connection == null) return;

      setState(() {
        _isUploading = true;
        _uploadProgress = 0;
        _uploadingFileName = pickedFile.name;
      });

      final result = await UploadService.uploadFile(
        connection: connection,
        file: File(pickedFile.path),
        fileName: pickedFile.name,
        onProgress: (progress) {
          if (mounted) setState(() => _uploadProgress = progress);
        },
      );

      _handleResult(result, pickedFile.name);
    } catch (e) {
      developer.log('[UploadPage] 选择图片错误: $e', name: 'viewstage');
      if (mounted) setState(() => _isUploading = false);
      _showSnack('选择图片失败: $e', isError: true);
    }
  }

  Future<void> _pickAndUploadFile() async {
    if (_isUploading) return;

    try {
      final Map<dynamic, dynamic>? fileInfo = await _filePickerChannel.invokeMethod('pickFile');

      if (fileInfo == null) return;

      final fileName = fileInfo['name'] as String;
      final filePath = fileInfo['path'] as String;

      final connection = context.read<ConnectionManager>().connection;
      if (connection == null) return;

      setState(() {
        _isUploading = true;
        _uploadProgress = 0;
        _uploadingFileName = fileName;
      });

      final result = await UploadService.uploadFile(
        connection: connection,
        file: File(filePath),
        fileName: fileName,
        onProgress: (progress) {
          if (mounted) setState(() => _uploadProgress = progress);
        },
      );

      // 删除临时文件
      try { File(filePath).deleteSync(); } catch (_) {}

      _handleResult(result, fileName);
    } catch (e) {
      developer.log('[UploadPage] 选择文件错误: $e', name: 'viewstage');
      if (mounted) setState(() => _isUploading = false);
      _showSnack('选择文件失败: $e', isError: true);
    }
  }

  void _handleResult(UploadResult result, String fileName) {
    if (!mounted) return;

    setState(() => _isUploading = false);

    if (result.success) {
      setState(() {
        _history.insert(0, _UploadRecord(
          name: result.name ?? fileName,
          size: result.size ?? 0,
          time: DateTime.now(),
          success: true,
        ));
      });
      _showSnack('上传成功: ${result.name ?? fileName}', isError: false);
    } else {
      setState(() {
        _history.insert(0, _UploadRecord(
          name: fileName,
          size: 0,
          time: DateTime.now(),
          success: false,
          error: result.error,
        ));
      });
      _showSnack(result.error ?? '上传失败', isError: true);
    }
  }

  void _showSnack(String message, {required bool isError}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? const Color(0xFFEF4444) : const Color(0xFF10B981),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: _buildButton(
                    icon: Icons.image_outlined,
                    label: '上传图片',
                    onTap: _pickAndUploadImage,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildButton(
                    icon: Icons.attach_file_outlined,
                    label: '上传文件',
                    onTap: _pickAndUploadFile,
                  ),
                ),
              ],
            ),
          ),
          if (_isUploading)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  Row(
                    children: [
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _uploadingFileName ?? '',
                          style: const TextStyle(fontSize: 13, fontFamily: 'Inter', color: Color(0xFF6B7280)),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        '${(_uploadProgress * 100).toInt()}%',
                        style: const TextStyle(fontSize: 13, fontFamily: 'Inter', fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(value: _uploadProgress),
                ],
              ),
            ),
          if (_history.isNotEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Divider(height: 1),
            ),
          Expanded(
            child: _history.isEmpty
                ? const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.cloud_upload_outlined, size: 48, color: Color(0xFFD1D5DB)),
                        SizedBox(height: 12),
                        Text('暂无上传记录', style: TextStyle(fontSize: 14, fontFamily: 'Inter', color: Color(0xFF9CA3AF))),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemCount: _history.length,
                    itemBuilder: (context, index) => _buildHistoryItem(_history[index]),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildButton({required IconData icon, required String label, required VoidCallback onTap}) {
    final disabled = _isUploading;
    return GestureDetector(
      onTap: disabled ? null : onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 24),
        decoration: BoxDecoration(
          color: disabled ? const Color(0xFFF5F5F5) : const Color(0xFFFFFFFF),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: disabled ? const Color(0xFFE5E7EB) : const Color(0xFFD1D5DB)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 32, color: disabled ? const Color(0xFFD1D5DB) : const Color(0xFF6B7280)),
            const SizedBox(height: 8),
            Text(label, style: TextStyle(
              fontSize: 14, fontWeight: FontWeight.w500, fontFamily: 'Inter',
              color: disabled ? const Color(0xFFD1D5DB) : const Color(0xFF111111),
            )),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryItem(_UploadRecord r) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: (r.success ? const Color(0xFF10B981) : const Color(0xFFEF4444)).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              r.success ? Icons.check_circle_outline : Icons.error_outline,
              size: 20,
              color: r.success ? const Color(0xFF10B981) : const Color(0xFFEF4444),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(r.name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, fontFamily: 'Inter'), overflow: TextOverflow.ellipsis),
                Text(
                  r.success ? _fmtSize(r.size) : (r.error ?? '上传失败'),
                  style: TextStyle(fontSize: 12, fontFamily: 'Inter', color: r.success ? const Color(0xFF6B7280) : const Color(0xFFEF4444)),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Text(_fmtTime(r.time), style: const TextStyle(fontSize: 12, fontFamily: 'Inter', color: Color(0xFF9CA3AF))),
        ],
      ),
    );
  }

  String _fmtSize(int b) {
    if (b < 1024) return '$b B';
    if (b < 1024 * 1024) return '${(b / 1024).toStringAsFixed(1)} KB';
    return '${(b / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  String _fmtTime(DateTime t) => '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
}

class _UploadRecord {
  final String name;
  final int size;
  final DateTime time;
  final bool success;
  final String? error;
  _UploadRecord({required this.name, required this.size, required this.time, required this.success, this.error});
}
