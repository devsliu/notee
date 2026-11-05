// Applies all .patch files in patches/ to the local libs/ directory.
// Usage: dart run patches/apply_patch.dart
//
// Patches MUST live under client_flutter/patches/ and use paths relative to
// client_flutter/ (matching the ---/+++ prefix convention in the diff).

import 'dart:io';

import 'package:path/path.dart' as p;

void main() {
  final scriptDir = p.dirname(p.fromUri(Platform.script));
  final projectRoot = p.dirname(scriptDir);
  final patchesDir = Directory(p.join(scriptDir));

  final patches = patchesDir.listSync().whereType<File>().where((f) => f.path.endsWith('.patch')).toList()
    ..sort((a, b) => a.path.compareTo(b.path));

  if (patches.isEmpty) {
    print('[patch] no .patch files found');
    return;
  }

  for (final patch in patches) {
    print('[patch] applying ${p.basename(patch.path)} ...');
    _applyPatch(patch, projectRoot);
  }

  print('[patch] done (${patches.length} patch(es))');
}

void _applyPatch(File patchFile, String projectRoot) {
  final lines = patchFile.readAsStringSync().split('\n');

  // Find --- and +++ headers (skip "diff --git" etc.)
  int minusIdx = -1, plusIdx = -1;
  for (int k = 0; k < lines.length; k++) {
    if (minusIdx < 0 && lines[k].startsWith('---')) minusIdx = k;
    if (plusIdx < 0 && lines[k].startsWith('+++')) {
      plusIdx = k;
      break;
    }
  }
  if (minusIdx < 0 || plusIdx < 0) {
    stderr.writeln('  skipped: missing ---/+++ headers');
    return;
  }

  final targetRel = lines[plusIdx].substring(4).trim(); // strip "+++ "
  // Strip "a/" or "b/" prefix that diff adds
  String stripAB(String s) => (s.startsWith('a/') || s.startsWith('b/')) ? s.substring(2) : s;
  final targetPath = stripAB(targetRel);
  final target = File(p.join(projectRoot, targetPath));
  if (!target.existsSync()) {
    stderr.writeln('  SKIP: target not found: $targetPath');
    return;
  }

  final content = target.readAsStringSync();
  final result = _applyUnified(content, lines, plusIdx + 1);

  if (result == null) {
    stderr.writeln('  FAILED to apply');
    exitCode = 1;
    return;
  }

  if (result == content) {
    print('  already applied, skipping');
    return;
  }

  target.writeAsStringSync(result);
  print('  OK → $targetRel');
}

String? _applyUnified(String content, List<String> diff, int startLine) {
  final out = StringBuffer();
  final input = content.split('\n');
  int i = startLine; // start after +++ line
  int srcIdx = 0;

  while (i < diff.length) {
    final line = diff[i];

    if (line.startsWith('@@')) {
      // Parse @@ -a,b +c,d @@
      final match = RegExp(r'@@ -(\d+)(?:,(\d+))? \+(\d+)(?:,(\d+))? @@').firstMatch(line);
      if (match == null) {
        stderr.writeln('  bad hunk header: $line');
        return null;
      }
      final srcStart = int.parse(match.group(1)!) - 1;
      // Skip context lines that exist in content before this hunk
      while (srcIdx < srcStart && srcIdx < input.length) {
        out.writeln(input[srcIdx++]);
      }
      i++;
      continue;
    }

    if (line.isEmpty) {
      i++;
      continue;
    }

    final prefix = line[0];
    final text = line.substring(1);

    switch (prefix) {
      case ' ': // context
        if (srcIdx >= input.length || input[srcIdx] != text) {
          stderr.writeln('  context mismatch at src line ${srcIdx + 1}');
          return null;
        }
        out.writeln(input[srcIdx++]);
        break;
      case '+': // add
        out.writeln(text);
        break;
      case '-': // remove (skip from source)
        if (srcIdx >= input.length || input[srcIdx] != text) {
          stderr.writeln('  remove mismatch at src line ${srcIdx + 1}');
          return null;
        }
        srcIdx++;
        break;
      default:
        stderr.writeln('  unknown line prefix: "$prefix"');
        return null;
    }
    i++;
  }

  // Remaining source lines (tail of file after last hunk)
  while (srcIdx < input.length) {
    out.writeln(input[srcIdx++]);
  }

  // File might not end with newline in original; but we always output \n terminated
  return out.toString();
}
