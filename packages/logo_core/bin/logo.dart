import 'dart:io';

import 'package:logo_core/logo_core.dart';

/// Exécute un programme Logo sans interface graphique.
///
///   dart run logo_core:logo programme.logo [-o dessin.svg]
Future<void> main(List<String> args) async {
  String? file;
  String? svgOut;
  for (var i = 0; i < args.length; i++) {
    if (args[i] == '-o' && i + 1 < args.length) {
      svgOut = args[++i];
    } else if (args[i] == '-h' || args[i] == '--help') {
      stdout.writeln('Usage : logo [programme.logo] [-o dessin.svg]');
      return;
    } else {
      file = args[i];
    }
  }

  final source = file == null
      ? await stdin.transform(const SystemEncoding().decoder).join()
      : File(file).readAsStringSync();
  final host = _CliHost();
  final ip = Interpreter(host);
  var code = 0;
  try {
    await ip.run(source);
  } on LogoError catch (e) {
    stderr.writeln('Erreur : ${e.describe()}');
    code = 1;
  }
  if (svgOut != null) {
    File(svgOut).writeAsStringSync(host.toSvg());
    stderr.writeln('${host.drawnSegments} segments → $svgOut');
  }
  exit(code);
}

class _CliHost extends RecordingHost {
  @override
  void write(String text) => stdout.write(text);

  @override
  Future<String?> readLine(String prompt) async {
    if (prompt.isNotEmpty) stdout.write(prompt);
    return stdin.readLineSync();
  }
}
