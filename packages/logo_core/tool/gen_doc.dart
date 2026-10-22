import 'dart:io';

import 'package:logo_core/logo_core.dart';

/// Génère docs/primitives.md à partir de la table des primitives.
///
///   dart run tool/gen_doc.dart > ../../docs/primitives.md
void main() {
  final ip = Interpreter(RecordingHost());
  final byCat = <String, List<Primitive>>{};
  for (final p in ip.primitiveList) {
    byCat.putIfAbsent(p.category, () => []).add(p);
  }
  final out = StringBuffer()
    ..writeln('# Les primitives de TER Logo Reboot')
    ..writeln()
    ..writeln('_Fichier généré par `packages/logo_core/tool/gen_doc.dart`._')
    ..writeln();
  for (final entry in byCat.entries) {
    out
      ..writeln('## ${entry.key}')
      ..writeln()
      ..writeln('| Primitive | Synonymes | Description |')
      ..writeln('|---|---|---|');
    for (final p in entry.value) {
      final syn = p.names.skip(1).map((n) => '`$n`').join(', ');
      out.writeln('| `${p.name}` | $syn | ${p.doc.replaceAll('|', '\\|')} |');
    }
    out.writeln();
  }
  stdout.write(out);
}
