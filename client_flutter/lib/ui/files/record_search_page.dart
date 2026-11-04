import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:notee/config/app_env.dart';
import 'package:notee/filesync/record_tree.dart';
import 'package:notee/filesync/table_record.dart';
import 'package:notee/filesync/repository.dart';
import 'package:notee/filesync/search_index.dart';
import 'package:notee/model/record_opened_state.dart';
import 'package:notee/ui/common/app_bar.dart';
import 'package:notee/ui/base_app.dart';
import 'package:notee/config/language_manager.dart';
import 'package:notee/utils/state_ext.dart';

/// Full-page record search: app bar with a back button and a search input,
/// body shows FTS5 content matches with title + snippet highlights.
class RecordSearchPage extends StatefulWidget {
  final bool shrink;
  final VoidCallback onBack;

  const RecordSearchPage({super.key, required this.shrink, required this.onBack});

  @override
  State<RecordSearchPage> createState() => _RecordSearchPageState();
}

class _RecordSearchPageState extends State<RecordSearchPage> {
  static const int _historyLimit = 10;
  static const Duration _historyDebounce = Duration(seconds: 2);
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  String _query = "";
  List<String> _history = const [];
  Timer? _historyTimer;

  @override
  void initState() {
    super.initState();
    _loadHistory();
    _controller.addListener(() {
      final q = _controller.text.trim();
      if (q == _query) return;
      setState(() => _query = q);
      _historyTimer?.cancel();
      if (q.isNotEmpty) {
        // Auto-searched queries are recorded once typing settles, not only on Enter.
        _historyTimer = Timer(_historyDebounce, () => _addHistory(q));
      }
    });
  }

  @override
  void dispose() {
    _historyTimer?.cancel();
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _loadHistory() async {
    final raw = await Repository.get().db?.getConfigStr(KVConfigs.searchHistory, null);
    if (raw == null || raw.isEmpty || !mounted) return;
    try {
      setState(() => _history = (jsonDecode(raw) as List).cast<String>());
    } catch (_) {
      // ignore malformed history
    }
  }

  Future<void> _saveHistory(List<String> history) async {
    await Repository.get().db?.setStringValue(KVConfigs.searchHistory, jsonEncode(history));
  }

  void _addHistory(String query) {
    final q = query.trim();
    if (q.isEmpty) return;
    final next = [q, ..._history.where((e) => e != q)].take(_historyLimit).toList();
    _saveHistory(next);
    setState(() => _history = next);
  }

  void _removeHistory(String query) {
    final next = _history.where((e) => e != query).toList();
    _saveHistory(next);
    setState(() => _history = next);
  }

  void _clearHistory() {
    _saveHistory(const []);
    setState(() => _history = const []);
  }

  void _applyQuery(String query) {
    _controller.value = TextEditingValue(
      text: query,
      selection: TextSelection.collapsed(offset: query.length),
    );
    _focusNode.requestFocus();
  }

  void _clear() {
    _controller.clear();
    _focusNode.requestFocus();
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    final fg = Theme.of(context).appBarTheme.foregroundColor;
    return createAppBar(
      automaticallyImplyLeading: false,
      onBack: widget.onBack,
      titleWidget: TextField(
        controller: _controller,
        focusNode: _focusNode,
        autofocus: true,
        textAlignVertical: TextAlignVertical.center,
        onTapOutside: (_) => _focusNode.unfocus(),
        textInputAction: TextInputAction.search,
        onSubmitted: (q) {
          _historyTimer?.cancel();
          _addHistory(q);
        },
        style: TextStyle(fontSize: 16, color: fg),
        cursorColor: fg,
        decoration: InputDecoration(
          isDense: true,
          hintText: l10n.searchRecords,
          hintStyle: TextStyle(fontSize: 16, color: fg?.withAlpha(150)),
          suffixIcon: _controller.text.isEmpty
              ? null
              : IconButton(
                  icon: Icon(Icons.close, color: fg),
                  onPressed: _clear,
                ),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
        ),
      ),
    );
  }

  Widget _buildHistory(BuildContext context) {
    if (_history.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.history, size: 16, color: theme.colorScheme.outline),
              const SizedBox(width: 6),
              Text(l10n.searchHistory, style: TextStyle(fontSize: 13, color: theme.colorScheme.outline)),
              const Spacer(),
              GestureDetector(
                onTap: _clearHistory,
                child: Text(l10n.clearSearchHistory, style: TextStyle(fontSize: 13, color: theme.colorScheme.outline)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final q in _history)
                InputChip(
                  label: Text(q, style: const TextStyle(fontSize: 12)),
                  onPressed: () {
                    _addHistory(q);
                    _applyQuery(q);
                  },
                  onDeleted: () => _removeHistory(q),
                  visualDensity: VisualDensity.compact,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(context),
      body: _query.isEmpty
          ? _buildHistory(context)
          : RecordSearchResultsControl(
              query: _query,
              shrink: widget.shrink,
              onCommitQuery: (q) {
                _historyTimer?.cancel();
                _addHistory(q);
              },
            ),
    );
  }
}

class _SearchResult {
  final String uuid;
  final String snippet;
  final String title;
  final String path;
  _SearchResult(this.uuid, this.snippet, this.title, this.path);
}

/// Flat list of records matching [query] via FTS5 content search.
class RecordSearchResultsControl extends StatefulWidget {
  final String query;
  final bool shrink;

  /// Called when the user commits to the current query (opens a result).
  final ValueChanged<String>? onCommitQuery;

  const RecordSearchResultsControl({
    super.key,
    required this.query,
    required this.shrink,
    this.onCommitQuery,
  });

  @override
  State<RecordSearchResultsControl> createState() => _RecordSearchResultsControlState();
}

class _RecordSearchResultsControlState extends BaseState<RecordSearchResultsControl> {
  final RecordTree recordTree = Repository.get().recordTree;
  SearchIndex? get _searchIndex => Repository.get().searchIndex;
  List<_SearchResult> _results = const [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    subscribe(recordTree.onEvent, (_) => _runSearch());
    listen(RecordOpenedState.get().openedFileNotifier, safeSetState);
    _runSearch();
  }

  @override
  void didUpdateWidget(covariant RecordSearchResultsControl oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.query != widget.query) _runSearch();
  }

  Future<void> _runSearch() async {
    final q = widget.query.trim();
    if (q.isEmpty || _searchIndex == null) {
      setState(() {
        _results = const [];
        _loading = false;
      });
      return;
    }
    setState(() => _loading = true);
    final rows = await _searchIndex!.search(q);
    final results = <_SearchResult>[];
    for (final row in rows) {
      final uuid = row[0];
      final snippet = row[1];
      final entry = recordTree.findRecord(uuid);
      final title = entry?.local.name ?? '(deleted)';
      final path = entry?.local.path ?? '';
      results.add(_SearchResult(uuid, snippet, title, path));
    }
    if (!mounted) return;
    setState(() {
      _results = results;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.query.isEmpty) return const SizedBox.shrink();
    if (_loading) {
      return const Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)));
    }
    if (_results.isEmpty) {
      final theme = Theme.of(context);
      return Center(
        child: Text(l10n.searchNoResults, style: TextStyle(fontSize: 13, color: theme.colorScheme.onSurface)),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: Text(
            '${l10n.searchRecords}: ${_results.length}',
            style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurface),
          ),
        ),
        Expanded(
          child: ListView.separated(
            itemCount: _results.length,
            itemBuilder: (BuildContext context, int index) {
              final r = _results[index];
              final isSelected = RecordOpenedState.get().openedFile?.uuid == r.uuid;
              return _SearchResultTile(
                result: r,
                shrink: widget.shrink,
                isSelected: isSelected,
                onTap: () {
                  widget.onCommitQuery?.call(widget.query);
                  AppNavigator.of(context).navigate('${AppNavigator.uriRecord}${r.uuid}?keyword=${widget.query}');
                },
              );
            },
            separatorBuilder: (context, index) => AppEnv.listViewDivider(context),
          ),
        ),
      ],
    );
  }
}

class _SearchResultTile extends StatelessWidget {
  final _SearchResult result;
  final bool shrink;
  final bool isSelected;
  final VoidCallback onTap;

  const _SearchResultTile({
    required this.result,
    required this.shrink,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bg = isSelected ? theme.colorScheme.primary.withAlpha(70) : Colors.transparent;
    return InkWell(
      onTap: onTap,
      child: Container(
        color: bg,
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: shrink ? 4 : 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.description, size: 16, color: theme.colorScheme.outline),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    result.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                  ),
                ),
                if (result.path.isNotEmpty)
                  Text(
                    result.path,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 11, color: theme.colorScheme.outline),
                  ),
              ],
            ),
            const SizedBox(height: 2),
            _HighlightSnippet(text: result.snippet),
          ],
        ),
      ),
    );
  }
}

class _HighlightSnippet extends StatelessWidget {
  /// FTS5 snippet text: U+0001/U+0002 mark highlight start/end.
  final String text;
  const _HighlightSnippet({required this.text});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final baseStyle = TextStyle(fontSize: 12, color: theme.colorScheme.onSurface.withAlpha(120));
    final highlightStyle = TextStyle(
      backgroundColor: theme.colorScheme.tertiaryContainer.withAlpha(120),
      color: theme.colorScheme.onSurface,
    );

    final spans = <InlineSpan>[];
    final buffer = StringBuffer();
    bool highlighted = false;

    void flush() {
      if (buffer.isNotEmpty) {
        spans.add(TextSpan(text: buffer.toString(), style: highlighted ? highlightStyle : null));
        buffer.clear();
      }
    }

    for (final cu in text.codeUnits) {
      if (cu == 0x01) {
        flush();
        highlighted = true;
      } else if (cu == 0x02) {
        flush();
        highlighted = false;
      } else {
        buffer.writeCharCode(cu);
      }
    }
    flush();

    return RichText(
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      text: TextSpan(style: baseStyle, children: spans),
    );
  }
}
