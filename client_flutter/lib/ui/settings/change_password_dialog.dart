import 'package:notee/filesync/backends/sync_backend.dart';
import 'package:notee/filesync/backends/http/http_sync_backend.dart';
import 'package:notee/filesync/repository.dart';
import 'package:notee/config/language_manager.dart';
import 'package:notee/utils/utils.dart';
import 'package:flutter/material.dart';
import 'package:notee/ui/common/toast.dart';

class ChangePasswordDialog extends StatefulWidget {
  const ChangePasswordDialog({super.key});

  @override
  State<ChangePasswordDialog> createState() => _ChangePasswordDialogState();

  static Future<T?> show<T>(BuildContext context) async {
    return await showDialog(context: context, useRootNavigator: false, builder: (context) => ChangePasswordDialog());
  }
}

class _ChangePasswordDialogState extends State<ChangePasswordDialog> {
  final TextEditingController _oldPwdController = TextEditingController();
  final TextEditingController _newPwdController = TextEditingController();
  final TextEditingController _confirmPwdController = TextEditingController();
  bool _loading = false;
  String? _error;
  bool _obscureOld = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;

  void _submit() async {
    final oldPwd = _oldPwdController.text;
    final newPwd = _newPwdController.text;
    final confirmPwd = _confirmPwdController.text;
    if (oldPwd.isEmpty || newPwd.isEmpty || confirmPwd.isEmpty) {
      setState(() => _error = l10n.passwordIncorrect);
      return;
    }
    if (newPwd != confirmPwd) {
      setState(() => _error = l10n.passwordMismatch);
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });

    final backend = Repository.get().backend as HttpSyncBackend?;
    if (backend == null) {
      setState(() {
        _loading = false;
        _error = l10n.notLoggedIn;
      });
      return;
    }
    final name = backend.name;
    final oldHash = Utils.generateMd5('${name}_$oldPwd').toUpperCase();
    final newHash = Utils.generateMd5('${name}_$newPwd').toUpperCase();

    final result = await backend.changePassword(oldHash, newHash);
    if (!mounted) return;

    if (result.isSuccess()) {
      // 密码已改：token 失效（清 token + 登录态 false）+ 变游客，让用户重新登录。
      // 登出不是独立操作，只是这两个动作的组合；wipePassword 防崩溃中间态被 autoRelogin 复活。
      await backend.clearToken(wipePassword: true);
      Repository.get().setBackend(null);
      if (!mounted) return;
      Navigator.of(context).pop();
      Toast.show(context, l10n.passwordChanged);
    } else {
      setState(() {
        _loading = false;
        if (result.code == SyncBackend.codeUserPasswordError) {
          _error = l10n.loginInvalidCredentials;
        } else {
          _error = result.message;
        }
      });
    }
  }

  @override
  void dispose() {
    _oldPwdController.dispose();
    _newPwdController.dispose();
    _confirmPwdController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('${l10n.changePassword} - ${(Repository.get().backend as HttpSyncBackend).name}'),
      content: SizedBox(
        width: 320,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _oldPwdController,
              obscureText: _obscureOld,
              decoration: InputDecoration(
                labelText: l10n.oldPassword,
                suffixIcon: IconButton(
                  icon: Icon(_obscureOld ? Icons.visibility : Icons.visibility_off),
                  onPressed: () => setState(() => _obscureOld = !_obscureOld),
                ),
              ),
              onSubmitted: (_) => _loading ? null : _submit(),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _newPwdController,
              obscureText: _obscureNew,
              decoration: InputDecoration(
                labelText: l10n.newPassword,
                suffixIcon: IconButton(
                  icon: Icon(_obscureNew ? Icons.visibility : Icons.visibility_off),
                  onPressed: () => setState(() => _obscureNew = !_obscureNew),
                ),
              ),
              onSubmitted: (_) => _loading ? null : _submit(),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _confirmPwdController,
              obscureText: _obscureConfirm,
              decoration: InputDecoration(
                labelText: l10n.confirmPassword,
                suffixIcon: IconButton(
                  icon: Icon(_obscureConfirm ? Icons.visibility : Icons.visibility_off),
                  onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                ),
              ),
              onSubmitted: (_) => _loading ? null : _submit(),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: _loading ? null : () => Navigator.of(context).pop(), child: Text(l10n.cancel)),
        TextButton(
          onPressed: _loading ? null : _submit,
          child: _loading
              ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : Text(l10n.confirm),
        ),
      ],
    );
  }
}
