import 'package:notee/filesync/http_api.dart';
import 'package:notee/filesync/user.dart';
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

    final name = UserManager.current.name ?? '';
    final oldHash = Utils.generateMd5('${name}_$oldPwd').toUpperCase();
    final newHash = Utils.generateMd5('${name}_$newPwd').toUpperCase();

    final result = await HttpApi.changePassword(oldHash, newHash);
    if (!mounted) return;

    if (result.isSuccess()) {
      // 密码已改, 清除本地 token, 让用户重新登录
      await UserManager.current.logout();
      if (!mounted) return;
      Navigator.of(context).pop();
      Toast.show(context, l10n.passwordChanged);
    } else {
      setState(() {
        _loading = false;
        if (result.code == HttpApi.kResultErrorUserPasswordError) {
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
      title: Text('${l10n.changePassword} - ${UserManager.current.name ?? ''}'),
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
