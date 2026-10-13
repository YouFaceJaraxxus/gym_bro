// Merges lib/l10n/fragments/<area>_<locale>.arb into lib/l10n/app_<locale>.arb.
//
// Each feature area keeps its own fragment so several people can add strings
// without editing one giant file. Keys must be unique across fragments.
// Serbian is written in Latin script; it's emitted both as `sr` (fallback) and
// `sr_Latn` (what the app selects, so Material widgets also use Latin script).
//
// Usage: dart run tool/merge_l10n.dart && flutter gen-l10n
import 'dart:convert';
import 'dart:io';

const locales = ['en', 'sr'];

void main() {
  final dir = Directory('lib/l10n/fragments');
  final merged = {for (final l in locales) l: <String, dynamic>{}};
  final owners = <String, String>{};
  var failed = false;

  final files = dir.listSync().whereType<File>().where((f) => f.path.endsWith('.arb')).toList()
    ..sort((a, b) => a.path.compareTo(b.path));
  for (final file in files) {
    final name = file.uri.pathSegments.last.replaceAll('.arb', '');
    final locale = name.substring(name.lastIndexOf('_') + 1);
    if (!locales.contains(locale)) {
      stderr.writeln('Skipping ${file.path}: unknown locale "$locale"');
      continue;
    }
    final Map<String, dynamic> data;
    try {
      data = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
    } on FormatException catch (e) {
      stderr.writeln('Invalid JSON in ${file.path}: $e');
      failed = true;
      continue;
    }
    for (final entry in data.entries) {
      if (entry.key.startsWith('@@')) continue;
      final ownerKey = '$locale:${entry.key}';
      if (owners.containsKey(ownerKey)) {
        stderr.writeln('Duplicate key "${entry.key}" in ${file.path} (already in ${owners[ownerKey]})');
        failed = true;
        continue;
      }
      owners[ownerKey] = file.path;
      merged[locale]![entry.key] = entry.value;
    }
  }

  final en = merged['en']!;
  final sr = merged['sr']!;
  final missing = en.keys.where((k) => !k.startsWith('@') && !sr.containsKey(k)).toList();
  if (missing.isNotEmpty) {
    stderr.writeln('Missing Serbian translations (${missing.length}): ${missing.take(20).join(', ')}${missing.length > 20 ? ', …' : ''}');
    failed = true;
  }
  final extra = sr.keys.where((k) => !k.startsWith('@') && !en.containsKey(k)).toList();
  if (extra.isNotEmpty) {
    stderr.writeln('Serbian keys with no English source: ${extra.join(', ')}');
    failed = true;
  }

  const encoder = JsonEncoder.withIndent('  ');
  void write(String fileLocale, Map<String, dynamic> body) {
    final sorted = Map.fromEntries(body.entries.toList()..sort((a, b) => a.key.compareTo(b.key)));
    File('lib/l10n/app_$fileLocale.arb')
        .writeAsStringSync('${encoder.convert({'@@locale': fileLocale, ...sorted})}\n');
  }

  write('en', en);
  // Translations only; placeholder metadata lives in the English template.
  final srText = {for (final e in sr.entries) if (!e.key.startsWith('@')) e.key: e.value};
  write('sr', srText);
  write('sr_Latn', srText);

  stdout.writeln('Merged ${files.length} fragments: ${en.keys.where((k) => !k.startsWith('@')).length} strings.');
  if (failed) exit(1);
}
