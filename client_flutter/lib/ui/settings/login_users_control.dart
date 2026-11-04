import 'package:flutter/material.dart';
import 'package:notee/filesync/user.dart';
import 'package:notee/config/language_manager.dart';

import 'login_dialog.dart';
import 'change_password_dialog.dart';
import 'package:notee/ui/common/toast.dart';

String getUserInfo(BuildContext context, User user) {
  String info = '';
  String serverUrl = '';
  if (user.isGuest) {
    info = l10n.notLoggedIn;
  } else if (user.token == null || user.token!.isEmpty) {
    info = l10n.loginExpired;
  } else {
    info = user.name ?? user.id.toString();
  }
  serverUrl = (user.apiUrl ?? '').isEmpty ? l10n.needServer : user.apiUrl ?? '';
  return '$info\n$serverUrl';
}

/// 账号列表底部弹层内容：列出已保存账号，支持切换 / 删除 / 添加 / 登出。
///
/// [onChanged] 在账号被删除或登出后回调，供父页面刷新状态。
class LoginUsersControl extends StatelessWidget {
  final List<User> savedList;
  final VoidCallback? onChanged;

  const LoginUsersControl({super.key, required this.savedList, this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(l10n.account, style: Theme.of(context).textTheme.titleMedium),
        ),
        for (final saved in savedList) ...[
          () {
            final isCurrent = saved.key == UserManager.current.key;
            final hasPassword = (saved.password ?? '').isNotEmpty;
            final hasApiUrl = (saved.apiUrl ?? '').isNotEmpty;
            final theme = Theme.of(context);
            return ListTile(
              leading: CircleAvatar(
                child: Text((saved.name ?? '').isNotEmpty ? saved.name![0].toUpperCase() : '?'),
              ),
              title: Text(
                getUserInfo(context, saved),
                style: TextStyle(color: saved.isLoggedIn ? null : theme.colorScheme.error),
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isCurrent) IconButton(icon: const Icon(Icons.check), onPressed: null),
                  if (!isCurrent)
                    IconButton(
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () async {
                        Navigator.pop(context);
                        final confirm = await showDialog<bool>(
                          context: context,
                          useRootNavigator: false,
                          builder: (dctx) => AlertDialog(
                            title: Text(l10n.confirmDelete),
                            content: Text('${saved.name} (id:${saved.id})'),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(dctx, false), child: Text(l10n.cancel)),
                              TextButton(onPressed: () => Navigator.pop(dctx, true), child: Text(l10n.delete)),
                            ],
                          ),
                        );
                        if (confirm == true) {
                          await UserManager.removeAccount(saved);
                          onChanged?.call();
                        }
                      },
                    ),
                ],
              ),
              onTap: () async {
                if (isCurrent && saved.isLoggedIn) return;
                Navigator.pop(context);
                if (hasPassword && hasApiUrl) {
                  final ok = await UserManager.switchTo(saved);
                  if (ok) return;
                  if (!context.mounted) return;
                  Toast.show(context, l10n.switchAccountFailed);
                }
                if (!context.mounted) return;
                LoginDialog.show(context, initialUrl: saved.apiUrl ?? '', initialName: saved.name ?? '');
              },
            );
          }(),
        ],
        const Divider(),
        ListTile(
          leading: const Icon(Icons.add),
          title: Text(l10n.addAccount),
          onTap: () {
            Navigator.pop(context);
            LoginDialog.show(context, initialUrl: UserManager.current.apiUrl ?? '', initialName: '');
          },
        ),
        if (UserManager.current.isLoggedIn)
          ListTile(
            leading: const Icon(Icons.lock_outline),
            title: Text(l10n.changePassword),
            onTap: () {
              Navigator.pop(context);
              ChangePasswordDialog.show(context);
            },
          ),
        if (UserManager.current.isLoggedIn)
          ListTile(
            leading: const Icon(Icons.logout),
            title: Text(l10n.logout),
            onTap: () async {
              Navigator.pop(context);
              final confirm = await showDialog<bool>(
                context: context,
                useRootNavigator: false,
                builder: (dctx) => AlertDialog(
                  title: Text(l10n.logout),
                  content: Text(l10n.confirmLogout),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(dctx, true), child: Text(l10n.logout)),
                    TextButton(onPressed: () => Navigator.pop(dctx, false), child: Text(l10n.cancel)),
                  ],
                ),
              );
              if (confirm == true) {
                await UserManager.current.logout();
                onChanged?.call();
              }
            },
          ),
      ],
    );
  }
}
