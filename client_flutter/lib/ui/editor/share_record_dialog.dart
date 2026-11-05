import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:notee/config/language_manager.dart';
import 'package:notee/filesync/http_api.dart';
import 'package:notee/utils/utils.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:notee/ui/common/toast.dart';

/// Share dialog: enter link lifetime (days + hours), then the markdown snapshot
/// is uploaded to the server and the returned link is handed to the system share UI
/// (clipboard fallback on desktop). Re-sharing the same record overwrites the previous share.
/// Expired files are cleaned server-side.
class ShareRecordDialog extends StatefulWidget {
  final String uuid;
  final String markdown;
  final String title;
  final String? pathName;

  const ShareRecordDialog({
    super.key,
    required this.uuid,
    required this.markdown,
    required this.title,
    this.pathName,
  });

  static Future<void> show(
    BuildContext context, {
    required String uuid,
    required String markdown,
    required String title,
    String? pathName,
  }) {
    return showDialog(
      context: context,
      useRootNavigator: false,
      builder: (_) => ShareRecordDialog(uuid: uuid, markdown: markdown, title: title, pathName: pathName),
    );
  }

  @override
  State<ShareRecordDialog> createState() => _ShareRecordDialogState();
}

class _ShareRecordDialogState extends State<ShareRecordDialog> {
  static const int _maxDays = 30;

  final _daysController = TextEditingController(text: '1');
  final _hoursController = TextEditingController(text: '0');
  bool _sharing = false;

  @override
  void dispose() {
    _daysController.dispose();
    _hoursController.dispose();
    super.dispose();
  }

  int _lifeSeconds() {
    final days = int.tryParse(_daysController.text.trim()) ?? 0;
    final hours = int.tryParse(_hoursController.text.trim()) ?? 0;
    return (days * 24 + hours) * 3600;
  }

  Future<void> _share() async {
    final life = _lifeSeconds();
    if (life <= 0 || life > _maxDays * 24 * 3600) {
      Toast.show(context, l10n.shareInvalidExpire);
      return;
    }
    setState(() => _sharing = true);
    String? error;
    String? url;
    // Write markdown to a temp file for multipart upload; removed after upload
    final tmp = File('${(await getTemporaryDirectory()).path}/share_${widget.uuid}.md');
    try {
      await tmp.writeAsString(widget.markdown);
      final result = await HttpApi.shareUpload(widget.uuid, widget.title, tmp.path, life);
      if (result.isSuccess() && result.data != null) {
        url = result.data;
      } else {
        error = result.message;
      }
    } catch (e) {
      error = '$e';
    } finally {
      await tmp.delete().catchError((_) => tmp);
    }
    if (!mounted) return;
    if (url == null) {
      setState(() => _sharing = false);
      Toast.show(context, '${l10n.shareFailed}: ${error ?? ''}');
      return;
    }
    Navigator.of(context).pop();
    // Desktop: copy the link to clipboard directly (no system share sheet).
    // Mobile: hand the link to the system share SDK so the user can pick an app.
    if (Utils.isDesktop()) {
      await Clipboard.setData(ClipboardData(text: url));
      if (mounted) {
        Toast.show(context, l10n.shareLinkCopied);
      }
    } else {
      try {
        await SharePlus.instance.share(ShareParams(text: url));
      } catch (_) {
        await Clipboard.setData(ClipboardData(text: url));
        if (mounted) {
          Toast.show(context, l10n.shareLinkCopied);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final fieldDecoration = InputDecoration(isDense: true, border: const OutlineInputBorder());
    return AlertDialog(
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.share),
          if (widget.pathName != null && widget.pathName!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                widget.pathName!,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).hintColor),
              ),
            ),
        ],
      ),
      content: SizedBox(
        width: 300,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.shareExpireHint, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _daysController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: fieldDecoration.copyWith(suffixText: l10n.shareDays),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _hoursController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: fieldDecoration.copyWith(suffixText: l10n.shareHours),
                  ),
                ),
              ],
            ),
            if (_sharing) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                  const SizedBox(width: 8),
                  Text(l10n.shareCreating, style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: _sharing ? null : () => Navigator.of(context).pop(), child: Text(l10n.cancel)),
        FilledButton(onPressed: _sharing ? null : _share, child: Text(l10n.share)),
      ],
    );
  }
}
