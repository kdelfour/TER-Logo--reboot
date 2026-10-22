import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:logo_core/logo_core.dart';
import 'package:path/path.dart' as p;
import 'package:re_editor/re_editor.dart';

import 'canvas_controller.dart';

enum ConsoleKind { output, command, system, error }

class ConsoleLine {
  final String text;
  final ConsoleKind kind;
  const ConsoleLine(this.text, this.kind);
}

enum RunState { idle, running, paused }

/// Un onglet de l'éditeur.
class EditorDocument {
  final CodeLineEditingController controller;
  String? path;
  String _title;
  String _savedText;
  bool dirty = false;

  EditorDocument({String text = '', this.path, String? title})
    : controller = CodeLineEditingController.fromText(text),
      _savedText = text,
      _title = title ?? (path != null ? p.basename(path) : 'sans titre.logo');

  String get title => _title;
  String get text => controller.text;

  /// Met à jour l'indicateur de modification ; renvoie vrai s'il a changé.
  bool refreshDirty() {
    final d = controller.text != _savedText;
    if (d == dirty) return false;
    dirty = d;
    return true;
  }

  void markSaved(String path) {
    this.path = path;
    _title = p.basename(path);
    _savedText = controller.text;
    dirty = false;
  }
}

/// Fait le lien entre l'interpréteur et l'interface.
class _AppHost implements LogoHost {
  final AppController app;
  _AppHost(this.app);

  @override
  void write(String text) {
    // Le texte apparaît quand l'animation a rattrapé le programme.
    app.canvas.pushAction(() => app.consoleWrite(text));
  }

  @override
  Future<String?> readLine(String prompt) async {
    await app.canvas.whenIdle();
    final ask = app.onReadLine;
    if (ask == null) return null;
    return ask(prompt);
  }

  @override
  FutureOr<void> onTurtle(TurtleEvent event) => app.canvas.push(event);
}

class AppController extends ChangeNotifier {
  final CanvasController canvas = CanvasController();
  late final Interpreter interpreter = Interpreter(_AppHost(this));

  final List<ConsoleLine> console = [];
  final StringBuffer _partialLine = StringBuffer();
  int consoleVersion = 0;

  final List<EditorDocument> documents = [];
  int _active = 0;

  RunState state = RunState.idle;
  String status = 'Prêt';
  LogoError? lastError;

  /// Pour `lis` : demande une saisie à l'utilisateur.
  Future<String?> Function(String prompt)? onReadLine;

  bool showGrid = true;
  bool showRemote = false;

  AppController() {
    newDocument(text: _welcome);
    consoleSystem('TER Logo Reboot — tape une commande ci-dessous ou écris un programme et appuie sur F5.');
  }

  static const _welcome = '''; Bienvenue dans TER Logo Reboot !
; Appuie sur F5 (ou ▶) pour lancer le programme.

pour carre :cote
  repete 4 [av :cote td 90]
fin

pour rosace :n
  repete :n [carre 100 td 360 / :n]
fin

ve
fcc "bleu
rosace 12
''';

  // -------------------------------------------------------------------------
  // Documents
  // -------------------------------------------------------------------------

  int get activeIndex => _active;
  EditorDocument? get activeDocument => documents.isEmpty ? null : documents[_active];

  set activeIndex(int i) {
    _active = i.clamp(0, documents.length - 1);
    notifyListeners();
  }

  EditorDocument newDocument({String text = '', String? path, String? title}) {
    final doc = EditorDocument(text: text, path: path, title: title);
    doc.controller.addListener(() {
      if (doc.refreshDirty()) notifyListeners();
    });
    documents.add(doc);
    _active = documents.length - 1;
    notifyListeners();
    return doc;
  }

  Future<void> openFile(String path) async {
    final existing = documents.indexWhere((d) => d.path == path);
    if (existing >= 0) {
      activeIndex = existing;
      return;
    }
    final text = await File(path).readAsString();
    final active = activeDocument;
    // Remplace l'onglet vide et inchangé de départ.
    if (active != null && active.path == null && !active.dirty && documents.length == 1 && active.text == _welcome) {
      documents.removeAt(0);
    }
    newDocument(text: text, path: path);
    consoleSystem('Ouverture de $path');
  }

  void openExample(String name, String text) => newDocument(text: text, title: name);

  Future<void> saveDocument(EditorDocument doc, String path) async {
    var target = path;
    if (p.extension(target).isEmpty) target = '$target.logo';
    await File(target).writeAsString(doc.text);
    doc.markSaved(target);
    consoleSystem('Enregistré : $target');
    notifyListeners();
  }

  void closeDocument(int index) {
    documents.removeAt(index);
    if (documents.isEmpty) newDocument();
    if (_active >= documents.length) _active = documents.length - 1;
    notifyListeners();
  }

  // -------------------------------------------------------------------------
  // Console
  // -------------------------------------------------------------------------

  void consoleWrite(String text) {
    final parts = text.split('\n');
    for (var i = 0; i < parts.length; i++) {
      _partialLine.write(parts[i]);
      if (i < parts.length - 1) {
        console.add(ConsoleLine(_partialLine.toString(), ConsoleKind.output));
        _partialLine.clear();
      }
    }
    _consoleChanged();
  }

  void _flushPartial() {
    if (_partialLine.isNotEmpty) {
      console.add(ConsoleLine(_partialLine.toString(), ConsoleKind.output));
      _partialLine.clear();
    }
  }

  void consoleSystem(String text) {
    _flushPartial();
    console.add(ConsoleLine(text, ConsoleKind.system));
    _consoleChanged();
  }

  void consoleError(String text) {
    _flushPartial();
    console.add(ConsoleLine(text, ConsoleKind.error));
    _consoleChanged();
  }

  void clearConsole() {
    console.clear();
    _partialLine.clear();
    _consoleChanged();
  }

  /// Ligne en cours d'écriture (après un `tape`).
  String get partialLine => _partialLine.toString();

  void _consoleChanged() {
    if (console.length > 5000) console.removeRange(0, console.length - 5000);
    consoleVersion++;
    notifyListeners();
  }

  // -------------------------------------------------------------------------
  // Exécution
  // -------------------------------------------------------------------------

  bool get isRunning => state != RunState.idle;

  Future<void> runActiveDocument() async {
    final doc = activeDocument;
    if (doc == null) return;
    await _run(doc.text, label: doc.title, document: doc);
  }

  /// Exécute la sélection si elle existe, sinon tout le document.
  Future<void> runSelectionOrDocument() async {
    final doc = activeDocument;
    if (doc == null) return;
    final sel = doc.controller.selectedText;
    if (sel.trim().isEmpty) return runActiveDocument();
    await _run(sel, label: 'sélection');
  }

  Future<void> runCommand(String command) async {
    if (command.trim().isEmpty) return;
    _flushPartial();
    console.add(ConsoleLine('? $command', ConsoleKind.command));
    _consoleChanged();
    await _run(command, quiet: true);
  }

  /// Exécute du code produit par la télécommande et l'ajoute à l'éditeur.
  Future<void> runRemote(String code) async {
    final doc = activeDocument;
    if (doc != null) {
      final t = doc.text;
      final sep = t.isEmpty || t.endsWith('\n') ? '' : '\n';
      doc.controller.text = '$t$sep$code\n';
    }
    await _run(code, quiet: true);
  }

  Future<void> _run(String source, {String? label, EditorDocument? document, bool quiet = false}) async {
    if (isRunning) {
      consoleError('Un programme est déjà en cours : arrête-le d\'abord (Échap).');
      return;
    }
    state = RunState.running;
    status = 'Exécution…';
    lastError = null;
    if (!quiet) consoleSystem('▶ Exécution de ${label ?? 'programme'}');
    notifyListeners();
    final sw = Stopwatch()..start();
    var halted = false;
    try {
      await interpreter.run(source);
      await canvas.whenIdle();
    } on LogoHalt {
      halted = true;
    } on LogoError catch (e) {
      canvas.finishNow();
      lastError = e;
      consoleError(e.describe());
      if (document != null && e.pos != null) _showErrorIn(document, e.pos!);
    } catch (e) {
      canvas.finishNow();
      consoleError('Erreur interne : $e');
    }
    _flushPartial();
    state = RunState.idle;
    if (halted) {
      canvas.finishNow();
      status = 'Arrêté';
      consoleSystem('■ Programme arrêté');
    } else if (lastError != null) {
      status = 'Erreur ligne ${lastError!.pos?.line ?? '?'}';
    } else {
      status = 'Terminé en ${_duration(sw.elapsed)}';
    }
    notifyListeners();
  }

  void _showErrorIn(EditorDocument doc, SourcePos pos) {
    final c = doc.controller;
    final line = (pos.line - 1).clamp(0, c.codeLines.length - 1);
    final len = c.codeLines[line].text.length;
    final start = (pos.column - 1).clamp(0, len);
    final end = (start + pos.length).clamp(0, len);
    c.selection = CodeLineSelection(baseIndex: line, baseOffset: start, extentIndex: line, extentOffset: end);
    c.makeCursorCenterIfInvisible();
  }

  static String _duration(Duration d) =>
      d.inMilliseconds < 1000 ? '${d.inMilliseconds} ms' : '${(d.inMilliseconds / 1000).toStringAsFixed(1)} s';

  void stop() {
    if (!isRunning) return;
    canvas.resume();
    interpreter.halt();
  }

  void togglePause() {
    if (state == RunState.running) {
      interpreter.pause();
      canvas.pause();
      state = RunState.paused;
      status = 'En pause';
    } else if (state == RunState.paused) {
      interpreter.resume();
      canvas.resume();
      state = RunState.running;
      status = 'Exécution…';
    }
    notifyListeners();
  }

  /// Efface l'écran et replace la tortue (bouton « Effacer »).
  void clearScreen() {
    if (isRunning) return;
    canvas.reset();
    interpreter.turtle.reset();
    status = 'Écran effacé';
    notifyListeners();
  }

  /// Oublie les procédures et variables définies.
  void resetWorkspace() {
    if (isRunning) return;
    interpreter.resetWorkspace();
    consoleSystem('Espace de travail réinitialisé : procédures et variables oubliées.');
  }

  set speed(int v) {
    canvas.speed = v;
    notifyListeners();
  }

  void toggleGrid() {
    showGrid = !showGrid;
    notifyListeners();
  }

  void toggleRemote() {
    showRemote = !showRemote;
    notifyListeners();
  }

  @override
  void dispose() {
    canvas.dispose();
    for (final d in documents) {
      d.controller.dispose();
    }
    super.dispose();
  }
}
