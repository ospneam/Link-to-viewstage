import 'package:flutter/material.dart';

class ManualInputForm extends StatefulWidget {
  final bool isLoading;
  final String? error;
  final void Function(String ip, int port, String token) onSubmit;

  const ManualInputForm({
    super.key,
    required this.isLoading,
    this.error,
    required this.onSubmit,
  });

  @override
  State<ManualInputForm> createState() => _ManualInputFormState();
}

class _ManualInputFormState extends State<ManualInputForm> {
  final _formKey = GlobalKey<FormState>();
  final _ipController = TextEditingController();
  final _portController = TextEditingController(text: '0');
  final _tokenController = TextEditingController();

  @override
  void dispose() {
    _ipController.dispose();
    _portController.dispose();
    _tokenController.dispose();
    super.dispose();
  }

  void _handleSubmit() {
    if (_formKey.currentState?.validate() ?? false) {
      widget.onSubmit(
        _ipController.text.trim(),
        int.parse(_portController.text.trim()),
        _tokenController.text.trim().toUpperCase(),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextFormField(
            controller: _ipController,
            decoration: const InputDecoration(
              labelText: 'IP 地址',
              hintText: '192.168.1.100',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.computer),
            ),
            keyboardType: TextInputType.number,
            validator: (v) => v?.trim().isEmpty == true ? '请输入 IP' : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _portController,
            decoration: const InputDecoration(
              labelText: '端口',
              hintText: '0',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.numbers),
            ),
            keyboardType: TextInputType.number,
            validator: (v) {
              if (v?.trim().isEmpty == true) return '请输入端口';
              final port = int.tryParse(v!);
              if (port == null || port < 0 || port > 65535) return '端口无效';
              return null;
            },
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _tokenController,
            decoration: const InputDecoration(
              labelText: '验证码',
              hintText: '8位验证码',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.key),
            ),
            textCapitalization: TextCapitalization.characters,
            validator: (v) => v?.trim().isEmpty == true ? '请输入验证码' : null,
          ),
          if (widget.error != null) ...[
            const SizedBox(height: 8),
            Text(
              widget.error!,
              style: const TextStyle(
                color: Color(0xFFEF4444),
                fontSize: 14,
                fontFamily: 'Inter',
              ),
            ),
          ],
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: FilledButton(
              onPressed: widget.isLoading ? null : _handleSubmit,
              child: widget.isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('连接'),
            ),
          ),
        ],
      ),
    );
  }
}
