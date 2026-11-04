import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:notee/filesync/record_ext.dart';
import 'package:notee/filesync/record_tree.dart';

/// Helpers for the pipe-separated tag storage format, e.g. `|work|todo|`.

/// Single event emitted by [TagTree] when its contents change.
class TagTreeEvent {
  static const typeRebuild = 1; // full rebuild (initial load, DB clear)
  static const typeUpsert = 2; // a record's tags changed (added/removed/modified)
  static const typeRemove = 3; // a record was removed, its tags dropped

  final int type;

  /// Affected record uuid (upsert/remove), or null for rebuild.
  final String? uuid;

  TagTreeEvent(this.type, [this.uuid]);
}

/// A single tag: its name, expanded state in the tree, and the records that
/// carry it.
class Tag {
  final String name;
  bool expanded = false;
  final List<RecordEntry> records = [];

  Tag(this.name);
}

/// One-level tag index with two synchronized maps:
///   - [_recordTags]: uuid → list of [Tag] for that record
///   - [_tagsMap]:    tag name → [Tag] (name + records carrying it)
class TagTree {
  final Map<String /*uuid*/, List<Tag>> _recordTags = {};
  final Map<String /*tagname*/, Tag> _tagsMap = {};
  StreamSubscription<RecordEvent>? _recordSub;

  /// Bind to [RecordTree] and listen to its event stream for sync.
  void bind(RecordTree recordTree) {
    _recordSub?.cancel();
    _recordSub = recordTree.onEvent.listen((event) {
      if (event.rebuildRecords != null) {
        rebuild(event.rebuildRecords!);
      }
      if (event.upsertRecords != null) {
        for (final record in event.upsertRecords!) {
          upsert(record);
        }
      }
      if (event.deleteRecords != null) {
        for (final uuid in event.deleteRecords!) {
          remove(uuid);
        }
      }
    });
  }

  final ValueNotifier<int> tagCountNotifier = ValueNotifier<int>(0);

  /// Stream of fine-grained change events (rebuild / upsert / remove).
  final StreamController<TagTreeEvent> _eventController = StreamController.broadcast();
  Stream<TagTreeEvent> get onEvent => _eventController.stream;

  bool _sortedDirty = true;
  List<Tag> _sortedTags = const [];

  /// Unbind from RecordTree and close event streams.
  void dispose() {
    _recordSub?.cancel();
    _eventController.close();
    tagCountNotifier.dispose();
  }

  /// Look up expanded state for a tag by name. Defaults to true if the tag
  /// exists but has never been toggled. Returns false if the tag is unknown.
  bool isExpanded(String name) => _tagsMap[name]?.expanded ?? false;

  /// Toggle or set the expanded state of a tag. No-op if the tag doesn't exist.
  void setExpanded(String name, bool value) {
    _tagsMap[name]?.expanded = value;
  }

  /// Full rebuild from scratch (used on initial load or after DB clear).
  void rebuild(List<RecordEntry> records) {
    _recordTags.clear();
    _tagsMap.clear();
    _sortedDirty = true;
    for (final record in records) {
      _upsertInternal(record);
    }
    _recomputeSorted();
    _eventController.add(TagTreeEvent(TagTreeEvent.typeRebuild));
  }

  /// Incremental upsert: apply tags from [record]. No-op (no event emitted)
  /// if the record's tag set hasn't actually changed.
  void upsert(RecordEntry record) {
    if (_upsertInternal(record)) {
      _recomputeSorted();
      _eventController.add(TagTreeEvent(TagTreeEvent.typeUpsert, record.uuid));
    }
  }

  /// Incremental remove: drop all tags for record with [uuid]. No-op (no
  /// event emitted) if the record wasn't tracked.
  void remove(String uuid) {
    final oldTags = _recordTags.remove(uuid);
    if (oldTags == null) return;
    for (final tag in oldTags) {
      tag.records.removeWhere((r) => r.uuid == uuid);
      if (tag.records.isEmpty) _tagsMap.remove(tag.name);
    }
    _sortedDirty = true;
    _recomputeSorted();
    _eventController.add(TagTreeEvent(TagTreeEvent.typeRemove, uuid));
  }

  /// Returns true iff the record's tag set OR its RecordEntry reference
  /// changed (so callers should refresh their UI).
  bool _upsertInternal(RecordEntry record) {
    final uuid = record.uuid;
    final newNames = record.tags;
    final oldTags = _recordTags.remove(uuid) ?? const [];

    // Tags identical — still refresh the RecordEntry reference inside each
    // Tag.records (the entry's other fields like editAt may have changed).
    if (_tagSetsEqual(oldTags.map((t) => t.name).toList(), newNames)) {
      for (final t in oldTags) {
        t.records
          ..removeWhere((r) => r.uuid == uuid)
          ..add(record);
      }
      if (oldTags.isNotEmpty) _recordTags[uuid] = oldTags;
      return oldTags.isNotEmpty;
    }

    final oldMap = <String, Tag>{for (final t in oldTags) t.name: t};

    final newTags = <Tag>[];
    for (final name in newNames) {
      final existing = oldMap[name] ?? _tagsMap[name];
      if (existing != null) {
        existing.records
          ..removeWhere((r) => r.uuid == uuid)
          ..add(record);
      } else {
        _tagsMap[name] = Tag(name)..records.add(record);
      }
      newTags.add(_tagsMap[name]!);
    }

    // Remove records from tags that are no longer on this record
    for (final t in oldTags) {
      if (newNames.contains(t.name)) continue;
      t.records.removeWhere((r) => r.uuid == uuid);
      if (t.records.isEmpty) _tagsMap.remove(t.name);
    }

    if (newTags.isNotEmpty) {
      _recordTags[uuid] = newTags;
    }
    _sortedDirty = true;
    return true;
  }

  bool _tagSetsEqual(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    return a.toSet().containsAll(b);
  }

  void _recomputeSorted() {
    if (!_sortedDirty) return;
    _sortedTags = _tagsMap.values.toList()..sort((a, b) => a.name.compareTo(b.name));
    _sortedDirty = false;
    tagCountNotifier.value = _tagsMap.length;
  }

  /// Sorted tag entries.
  List<Tag> get tags => _sortedTags;

  /// Number of distinct tags.
  int get tagCount => _tagsMap.length;
}
