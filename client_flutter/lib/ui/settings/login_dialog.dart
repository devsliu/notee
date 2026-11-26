import 'dart:math' as math;

import 'package:notee/filesync/backends/sync_backend.dart';
import 'package:notee/filesync/repository.dart';
import 'package:notee/filesync/backends/http/http_sync_backend.dart';
import 'package:notee/config/language_manager.dart';
import 'package:notee/utils/utils.dart';
import 'package:flutter/material.dart';

class LoginDialog extends StatefulWidget {
  final String? initialUrl;
  final String? initialName;
  const LoginDialog({super.key, this.initialUrl, this.initialName});

  @override
  State<LoginDialog> createState() => _LoginDialogState();

  static Future<T?> show<T>(BuildContext context, {String? initialUrl, String? initialName}) async {
    return await showDialog(
      context: context,
      useRootNavigator: false,
      builder: (context) => LoginDialog(initialUrl: initialUrl, initialName: initialName),
    );
  }
}

class _LoginDialogState extends State<LoginDialog> {
  late final TextEditingController _apiUrlController = TextEditingController(
    text: widget.initialUrl ?? (Repository.get().backend as HttpSyncBackend?)?.apiUrl ?? '',
  );
  late final TextEditingController _usernameController = TextEditingController(
    text: widget.initialName ?? (Repository.get().backend as HttpSyncBackend?)?.name ?? '',
  );
  final TextEditingController _passwordController = TextEditingController();
  bool _loading = false;
  String? _error;

  void _login() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    var apiUrl = _apiUrlController.text.trim();
    if (apiUrl.isEmpty) {
      setState(() {
        _error = l10n.emptyInputCheck(l10n.syncServer);
        _loading = false;
      });
      return;
    }
    var userName = _usernameController.text.trim();
    if (userName.isEmpty) {
      setState(() {
        _error = l10n.emptyInputCheck(l10n.username);
        _loading = false;
      });
      return;
    }
    var password = _passwordController.text.trim();
    if (password.isEmpty) {
      setState(() {
        _error = l10n.emptyInputCheck(l10n.password);
        _loading = false;
      });
      return;
    }

    await Repository.get().waitForSync(); // Ensure sync service is ready
    var pass = _generateMd5Pass(userName, password);
    // 先构造空 token 实例承载 HttpApi 连接池，再调实例方法 .login()。
    // 成功时同一对象被更新 token/id，直接交给 Repository.setBackend 接管（不再手动 close）；
    // 失败/抛异常时 finally 里释放临时连接池。
    final backend = HttpSyncBackend(
      id: 0,
      name: userName,
      token: '',
      password: pass,
      apiUrl: apiUrl,
    );
    bool handedToRepo = false;
    try {
      final result = await backend.login(userName, pass);
      if (result.isSuccess() && result.data != null) {
        Repository.get().setBackend(result.data!);
        handedToRepo = true;
        if (mounted) {
          Navigator.of(context).pop(true);
        }
      } else {
        if (!mounted) return;
        setState(() {
          _error = result.code == SyncBackend.codeUserPasswordError
              ? l10n.loginInvalidCredentials
              : result.message;
          _loading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    } finally {
      if (!handedToRepo) backend.api.close();
    }
  }

  String _generateMd5Pass(String userName, String password) {
    return Utils.generateMd5("${userName}_$password").toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    double screenWidth = MediaQuery.of(context).size.width;
    return AlertDialog(
      title: Text(l10n.login),
      content: SizedBox(
        width: math.min(400, screenWidth * 0.85),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _apiUrlController,
              decoration: InputDecoration(labelText: l10n.syncServer),
            ),
            TextField(
              controller: _usernameController,
              decoration: InputDecoration(labelText: l10n.username),
            ),
            TextField(
              controller: _passwordController,
              decoration: InputDecoration(labelText: l10n.password),
              obscureText: true,
              onSubmitted: (_) => _login(),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(_error!, style: const TextStyle(color: Colors.red)),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: _loading ? null : () => Navigator.of(context).pop(false), child: Text(l10n.cancel)),
        TextButton(
          onPressed: _loading ? null : _login,
          child: _loading
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : Text(l10n.login),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _apiUrlController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
}

// Usage
// showDialog(context: context, builder: (_) => const LoginDialog());
