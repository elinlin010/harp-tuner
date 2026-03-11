// tool/gen_arb.dart
//
// Converts lib/l10n/translations.csv → one ARB file per locale.
//
// Usage (run from project root):
//   dart run tool/gen_arb.dart
//
// After running, execute `flutter gen-l10n` (or `flutter pub get` with
// `generate: true` in pubspec.yaml) to regenerate the Dart localizations.

import 'dart:convert';
import 'dart:io';

void main() {
  final csvFile = File('lib/l10n/translations.csv');
  if (!csvFile.existsSync()) {
    stderr.writeln('Error: lib/l10n/translations.csv not found.');
    stderr.writeln('Run this script from the project root directory.');
    exit(1);
  }

  final rows = _parseCsv(csvFile.readAsStringSync());
  if (rows.length < 2) {
    stderr.writeln('Error: translations.csv has no data rows.');
    exit(1);
  }

  // First row is headers: key, en, zh_TW, de, fr, it, …
  final headers = rows.first;
  final locales = headers.sublist(1);

  for (var col = 0; col < locales.length; col++) {
    final locale = locales[col].trim();
    final arb = <String, Object>{'@@locale': locale};

    for (final row in rows.skip(1)) {
      final key = row.isNotEmpty ? row[0].trim() : '';
      if (key.isEmpty) continue;

      final value = (col + 1 < row.length) ? row[col + 1] : '';
      arb[key] = value;

      // Auto-generate @key metadata for any {placeholder} patterns.
      final matches = RegExp(r'\{(\w+)\}').allMatches(value).toList();
      if (matches.isNotEmpty) {
        arb['@$key'] = {
          'placeholders': {
            for (final m in matches) m.group(1)!: {'type': 'String'},
          },
        };
      }
    }

    final json = const JsonEncoder.withIndent('  ').convert(arb);
    final outPath = 'lib/l10n/app_$locale.arb';
    File(outPath).writeAsStringSync('$json\n');
    stdout.writeln('✓ $outPath');

    // Flutter requires a base-language fallback when a regional locale exists
    // (e.g. app_zh.arb must exist for app_zh_TW.arb to be valid).
    if (locale.contains('_')) {
      final baseLang = locale.split('_').first;
      final basePath = 'lib/l10n/app_$baseLang.arb';
      if (!File(basePath).existsSync() &&
          !locales.contains(baseLang)) {
        final baseArb = Map<String, Object>.from(arb)
          ..['@@locale'] = baseLang;
        final baseJson = const JsonEncoder.withIndent('  ').convert(baseArb);
        File(basePath).writeAsStringSync('$baseJson\n');
        stdout.writeln('✓ $basePath (fallback for $locale)');
      }
    }
  }

  stdout.writeln('\nDone. Run `flutter gen-l10n` to regenerate Dart localizations.');
}

// ── RFC 4180 CSV parser ───────────────────────────────────────────────────────

List<List<String>> _parseCsv(String input) {
  final rows = <List<String>>[];
  final text = input.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
  var i = 0;

  while (i < text.length) {
    final row = <String>[];

    do {
      String field;

      if (i < text.length && text[i] == '"') {
        // Quoted field — read until closing unescaped quote.
        i++; // skip opening quote
        final buf = StringBuffer();
        while (i < text.length) {
          if (text[i] == '"' && i + 1 < text.length && text[i + 1] == '"') {
            buf.write('"'); // escaped quote ""
            i += 2;
          } else if (text[i] == '"') {
            i++; // skip closing quote
            break;
          } else {
            buf.write(text[i++]);
          }
        }
        field = buf.toString();
      } else {
        // Unquoted field — read until comma or newline.
        final start = i;
        while (i < text.length && text[i] != ',' && text[i] != '\n') {
          i++;
        }
        field = text.substring(start, i);
      }

      row.add(field);

      // Consume the comma separator (if present) before next field.
      if (i < text.length && text[i] == ',') i++;
    } while (i < text.length && text[i] != '\n');

    if (row.any((f) => f.isNotEmpty)) rows.add(row);
    if (i < text.length && text[i] == '\n') i++; // consume newline
  }

  return rows;
}
