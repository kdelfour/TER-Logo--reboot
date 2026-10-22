import 'dart:io';
import 'dart:ui' as ui;

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:logo_core/logo_core.dart';
import 'package:multi_split_view/multi_split_view.dart';
import 'package:path/path.dart' as p;

import '../state/app_controller.dart';
import 'canvas_view.dart';
import 'console_panel.dart';
import 'editor_panel.dart';
import 'help_dialog.dart';
import 'remote_panel.dart';

const _logoFiles = XTypeGroup(label: 'Programmes Logo', extensions: ['logo', 'lgo', 'lg', 'txt']);

class HomePage extends StatefulWidget {
  final ValueNotifier<ThemeMode> themeMode;

  const HomePage({super.key, required this.themeMode});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final AppController app = AppController();
  final CanvasViewport viewport = CanvasViewport();
  final _canvasKey = GlobalKey();
  List<(String, String)> _examples = const [];

  @override
  void initState() {
    super.initState();
    app.onReadLine = _askLine;
    _loadExamples();
  }

  @override
  void dispose() {
    app.dispose();
    viewport.dispose();
    super.dispose();
  }

  Future<void> _loadExamples() async {
    final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
    final paths = manifest.listAssets().where((a) => a.startsWith('examples/') && a.endsWith('.logo')).toList()..sort();
    final list = <(String, String)>[];
    for (final path in paths) {
      list.add((p.basename(path), await rootBundle.loadString(path)));
    }
    if (mounted) setState(() => _examples = list);
  }

  Size get _canvasSize => (_canvasKey.currentContext?.findRenderObject() as RenderBox?)?.size ?? const Size(800, 600);

  // -------------------------------------------------------------------------
  // Fichiers
  // -------------------------------------------------------------------------

  Future<void> _open() async {
    final file = await openFile(acceptedTypeGroups: const [_logoFiles]);
    if (file == null) return;
    try {
      await app.openFile(file.path);
    } catch (e) {
      app.consoleError('Impossible d\'ouvrir ${file.path} : $e');
    }
  }

  Future<bool> _save({bool saveAs = false, EditorDocument? doc}) async {
    final d = doc ?? app.activeDocument;
    if (d == null) return false;
    var path = d.path;
    if (path == null || saveAs) {
      final loc = await getSaveLocation(
        suggestedName: d.path != null ? p.basename(d.path!) : (d.title.endsWith('.logo') ? d.title : '${d.title}.logo'),
        acceptedTypeGroups: const [_logoFiles],
      );
      if (loc == null) return false;
      path = loc.path;
    }
    try {
      await app.saveDocument(d, path);
      return true;
    } catch (e) {
      app.consoleError('Impossible d\'enregistrer $path : $e');
      return false;
    }
  }

  Future<void> _closeTab(int index) async {
    final doc = app.documents[index];
    if (doc.dirty) {
      final choice = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Enregistrer « ${doc.title} » ?'),
          content: const Text('Les modifications seront perdues si tu ne les enregistres pas.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, 'cancel'), child: const Text('Annuler')),
            TextButton(onPressed: () => Navigator.pop(context, 'discard'), child: const Text('Ne pas enregistrer')),
            FilledButton(onPressed: () => Navigator.pop(context, 'save'), child: const Text('Enregistrer')),
          ],
        ),
      );
      if (choice == null || choice == 'cancel') return;
      if (choice == 'save' && !await _save(doc: doc)) return;
    }
    app.closeDocument(index);
  }

  Future<void> _exportPng() async {
    final loc = await getSaveLocation(
      suggestedName: 'dessin.png',
      acceptedTypeGroups: const [
        XTypeGroup(label: 'Image PNG', extensions: ['png']),
      ],
    );
    if (loc == null) return;
    final image = await renderDrawingImage(app.canvas);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    final path = p.extension(loc.path).isEmpty ? '${loc.path}.png' : loc.path;
    await File(path).writeAsBytes(bytes!.buffer.asUint8List());
    app.consoleSystem('Image enregistrée : $path');
  }

  Future<void> _exportSvg() async {
    final loc = await getSaveLocation(
      suggestedName: 'dessin.svg',
      acceptedTypeGroups: const [
        XTypeGroup(label: 'Image SVG', extensions: ['svg']),
      ],
    );
    if (loc == null) return;
    final rec = RecordingHost();
    rec.events.addAll(app.canvas.history);
    final path = p.extension(loc.path).isEmpty ? '${loc.path}.svg' : loc.path;
    await File(path).writeAsString(rec.toSvg());
    app.consoleSystem('Image enregistrée : $path');
  }

  Future<String?> _askLine(String prompt) {
    final ctrl = TextEditingController();
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text(prompt.isEmpty ? 'Le programme attend une réponse' : prompt),
        content: TextField(controller: ctrl, autofocus: true, onSubmitted: (v) => Navigator.pop(context, v)),
        actions: [FilledButton(onPressed: () => Navigator.pop(context, ctrl.text), child: const Text('Valider'))],
      ),
    );
  }

  void _about() {
    showAboutDialog(
      context: context,
      applicationName: 'TER Logo Reboot',
      applicationVersion: '1.0.0',
      applicationIcon: const _AppIcon(size: 48),
      children: const [
        Text(
          'Un interpréteur Logo francophone pour le bureau.\n\n'
          'Réécriture en Flutter du TER « Interpréteur Logo » (M1 Informatique, '
          'Université Montpellier II, 2006-2007) de Simon Allier, Naïtan Grollemund, '
          'Renaud Lalluque et Kevin Delfour, encadré par Michel Meynard.',
        ),
      ],
    );
  }

  // -------------------------------------------------------------------------
  // Interface
  // -------------------------------------------------------------------------

  Map<ShortcutActivator, VoidCallback> get _shortcuts => {
    const SingleActivator(LogicalKeyboardKey.f5): app.runActiveDocument,
    const SingleActivator(LogicalKeyboardKey.enter, control: true): app.runSelectionOrDocument,
    const SingleActivator(LogicalKeyboardKey.escape): app.stop,
    const SingleActivator(LogicalKeyboardKey.f6): app.togglePause,
    const SingleActivator(LogicalKeyboardKey.keyN, control: true): () => app.newDocument(),
    const SingleActivator(LogicalKeyboardKey.keyO, control: true): _open,
    const SingleActivator(LogicalKeyboardKey.keyS, control: true): _save,
    const SingleActivator(LogicalKeyboardKey.keyS, control: true, shift: true): () => _save(saveAs: true),
    const SingleActivator(LogicalKeyboardKey.keyW, control: true): () => _closeTab(app.activeIndex),
    const SingleActivator(LogicalKeyboardKey.f1): () => HelpDialog.show(context, app.interpreter.primitiveList),
    const SingleActivator(LogicalKeyboardKey.keyL, control: true, shift: true): app.clearScreen,
  };

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return CallbackShortcuts(
      bindings: _shortcuts,
      child: Focus(
        autofocus: true,
        child: Scaffold(
          body: ListenableBuilder(
            listenable: app,
            builder: (context, _) => Column(
              children: [
                _toolbar(context),
                Divider(height: 1, color: scheme.outlineVariant),
                Expanded(child: _body(context)),
                Divider(height: 1, color: scheme.outlineVariant),
                _StatusBar(app: app, viewport: viewport),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _body(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final divider = MultiSplitViewThemeData(
      dividerThickness: 5,
      dividerPainter: DividerPainters.background(
        color: scheme.outlineVariant.withValues(alpha: 0.5),
        highlightedColor: scheme.primary,
      ),
    );
    final canvas = Container(
      key: _canvasKey,
      child: CanvasView(controller: app.canvas, viewport: viewport, showGrid: app.showGrid),
    );
    return MultiSplitViewTheme(
      data: divider,
      child: Row(
        children: [
          Expanded(
            child: MultiSplitView(
              initialAreas: [
                Area(
                  flex: 4,
                  min: 280,
                  builder: (context, area) => MultiSplitView(
                    axis: Axis.vertical,
                    initialAreas: [
                      Area(
                        flex: 3,
                        min: 120,
                        builder: (context, area) => EditorPanel(app: app, onCloseTab: _closeTab),
                      ),
                      Area(flex: 1.4, min: 90, builder: (context, area) => ConsolePanel(app: app)),
                    ],
                  ),
                ),
                Area(flex: 6, min: 200, builder: (context, area) => canvas),
              ],
            ),
          ),
          if (app.showRemote) ...[
            VerticalDivider(width: 1, color: scheme.outlineVariant),
            SizedBox(width: 280, child: RemotePanel(app: app)),
          ],
        ],
      ),
    );
  }

  Widget _toolbar(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final running = app.isRunning;
    final compact = MediaQuery.sizeOf(context).width < 1350;
    Widget sep() => Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: SizedBox(height: 26, child: VerticalDivider(width: 1, color: scheme.outlineVariant)),
    );
    Widget btn(IconData icon, String tip, VoidCallback? onTap, {bool selected = false}) => IconButton(
      tooltip: tip,
      onPressed: onTap,
      isSelected: selected,
      icon: Icon(icon, size: 21),
      selectedIcon: Icon(icon, size: 21, color: scheme.primary),
    );
    return Container(
      height: 54,
      color: scheme.surfaceContainer,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Row(
        children: [
          const _AppIcon(size: 30),
          if (!compact) ...[
            const SizedBox(width: 10),
            Text(
              'TER Logo',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: scheme.onSurface),
            ),
            Text(
              ' Reboot',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w300, color: scheme.primary),
            ),
          ],
          sep(),
          btn(Icons.note_add_outlined, 'Nouveau (Ctrl+N)', () => app.newDocument()),
          btn(Icons.folder_open_outlined, 'Ouvrir… (Ctrl+O)', _open),
          btn(Icons.save_outlined, 'Enregistrer (Ctrl+S)', _save),
          MenuAnchor(
            builder: (context, controller, _) => btn(
              Icons.auto_awesome_outlined,
              'Exemples',
              () => controller.isOpen ? controller.close() : controller.open(),
            ),
            menuChildren: [
              for (final (name, text) in _examples)
                MenuItemButton(
                  leadingIcon: const Icon(Icons.draw_outlined, size: 18),
                  onPressed: () => app.openExample(name, text),
                  child: Text(_exampleTitle(name, text)),
                ),
            ],
          ),
          sep(),
          Tooltip(
            message: 'Exécuter le programme (F5) — Ctrl+Entrée pour la sélection',
            child: FilledButton.icon(
              onPressed: running ? null : app.runActiveDocument,
              icon: const Icon(Icons.play_arrow_rounded),
              label: const Text('Exécuter'),
              style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 16)),
            ),
          ),
          const SizedBox(width: 4),
          btn(
            app.state == RunState.paused ? Icons.play_circle_outline : Icons.pause_circle_outline,
            app.state == RunState.paused ? 'Reprendre (F6)' : 'Pause (F6)',
            running ? app.togglePause : null,
          ),
          btn(Icons.stop_circle_outlined, 'Arrêter (Échap)', running ? app.stop : null),
          btn(Icons.layers_clear_outlined, 'Effacer l\'écran (Ctrl+Maj+L)', running ? null : app.clearScreen),
          sep(),
          _SpeedControl(app: app, compact: compact),
          Expanded(
            child: Align(
              alignment: Alignment.centerRight,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                reverse: true,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    btn(Icons.grid_4x4, 'Quadrillage', app.toggleGrid, selected: app.showGrid),
                    btn(Icons.zoom_out, 'Dézoomer', () => viewport.zoomBy(1 / 1.25, _canvasSize)),
                    btn(Icons.zoom_in, 'Zoomer', () => viewport.zoomBy(1.25, _canvasSize)),
                    btn(
                      Icons.fit_screen_outlined,
                      'Cadrer le dessin (double-clic sur le dessin)',
                      () => viewport.fit(app.canvas.bounds, _canvasSize),
                    ),
                    btn(Icons.center_focus_strong_outlined, 'Vue d\'origine', viewport.reset),
                    MenuAnchor(
                      builder: (context, controller, _) => btn(
                        Icons.image_outlined,
                        'Enregistrer le dessin',
                        () => controller.isOpen ? controller.close() : controller.open(),
                      ),
                      menuChildren: [
                        MenuItemButton(
                          leadingIcon: const Icon(Icons.image, size: 18),
                          onPressed: _exportPng,
                          child: const Text('Image PNG…'),
                        ),
                        MenuItemButton(
                          leadingIcon: const Icon(Icons.polyline, size: 18),
                          onPressed: _exportSvg,
                          child: const Text('Image SVG (vectorielle)…'),
                        ),
                      ],
                    ),
                    sep(),
                    btn(Icons.gamepad_outlined, 'Télécommande', app.toggleRemote, selected: app.showRemote),
                    btn(
                      Icons.menu_book_outlined,
                      'Aide : les mots de Logo (F1)',
                      () => HelpDialog.show(context, app.interpreter.primitiveList),
                    ),
                    ValueListenableBuilder(
                      valueListenable: widget.themeMode,
                      builder: (context, mode, _) => btn(
                        Theme.of(context).brightness == Brightness.dark
                            ? Icons.light_mode_outlined
                            : Icons.dark_mode_outlined,
                        'Thème clair / sombre',
                        () => widget.themeMode.value = Theme.of(context).brightness == Brightness.dark
                            ? ThemeMode.light
                            : ThemeMode.dark,
                      ),
                    ),
                    MenuAnchor(
                      builder: (context, controller, _) => btn(
                        Icons.more_vert,
                        'Plus',
                        () => controller.isOpen ? controller.close() : controller.open(),
                      ),
                      menuChildren: [
                        MenuItemButton(
                          onPressed: () => _save(saveAs: true),
                          child: const Text('Enregistrer sous… (Ctrl+Maj+S)'),
                        ),
                        MenuItemButton(
                          onPressed: running ? null : app.resetWorkspace,
                          child: const Text('Oublier procédures et variables'),
                        ),
                        const Divider(height: 1),
                        MenuItemButton(onPressed: _about, child: const Text('À propos')),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Le titre d'un exemple est sa première ligne de commentaire.
  String _exampleTitle(String file, String text) {
    final first = text.split('\n').first.trim();
    if (first.startsWith(';')) return first.substring(1).trim();
    return p.basenameWithoutExtension(file);
  }
}

class _SpeedControl extends StatelessWidget {
  final AppController app;
  final bool compact;

  const _SpeedControl({required this.app, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListenableBuilder(
      listenable: app.canvas,
      builder: (context, _) {
        final speed = app.canvas.speed;
        final instant = speed == 0;
        return Row(
          children: [
            Icon(Icons.speed, size: 20, color: scheme.onSurfaceVariant),
            SizedBox(
              width: compact ? 100 : 150,
              child: Slider(
                value: instant ? 500 : speed.toDouble(),
                min: 1,
                max: 500,
                onChanged: instant ? null : (v) => app.speed = v.round(),
              ),
            ),
            Tooltip(
              message: 'Dessin instantané (vitesse 0)',
              child: FilterChip(
                label: compact ? const Icon(Icons.bolt, size: 18) : const Text('Instantané'),
                selected: instant,
                visualDensity: VisualDensity.compact,
                onSelected: (on) => app.speed = on ? 0 : 100,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _StatusBar extends StatelessWidget {
  final AppController app;
  final CanvasViewport viewport;

  const _StatusBar({required this.app, required this.viewport});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final style = TextStyle(fontSize: 12, color: scheme.onSurfaceVariant);
    final (color, label) = switch (app.state) {
      RunState.running => (Colors.green, 'En cours'),
      RunState.paused => (Colors.orange, 'En pause'),
      RunState.idle => (app.lastError != null ? scheme.error : scheme.outline, 'Prêt'),
    };
    String f(double v) => v.abs() < 1e-6 ? '0' : (v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(1));
    return Container(
      height: 26,
      color: scheme.surfaceContainer,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: ListenableBuilder(
        listenable: Listenable.merge([app.canvas, viewport]),
        builder: (context, _) {
          final t = app.interpreter.turtle;
          final ptr = viewport.pointer;
          return Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 6),
              Text(label, style: style.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(app.status, style: style, overflow: TextOverflow.ellipsis),
              ),
              Text(
                'tortue  x ${f(app.canvas.turtleX)}  y ${f(app.canvas.turtleY)}  cap ${f(app.canvas.turtleHeading)}°',
                style: style,
              ),
              const SizedBox(width: 16),
              Text(t.penDown ? 'crayon baissé' : 'crayon levé', style: style),
              const SizedBox(width: 16),
              SizedBox(
                width: 150,
                child: Text(
                  ptr == null ? '' : 'pointeur  ${f(ptr.dx.roundToDouble())} ; ${f(ptr.dy.roundToDouble())}',
                  style: style,
                ),
              ),
              Text('zoom ${(viewport.zoom * 100).round()} %', style: style),
              const SizedBox(width: 16),
              Text(
                '${app.interpreter.procedures.length} procédure${app.interpreter.procedures.length > 1 ? 's' : ''}',
                style: style,
              ),
            ],
          );
        },
      ),
    );
  }
}

class _AppIcon extends StatelessWidget {
  final double size;

  const _AppIcon({required this.size});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _IconPainter()),
    );
  }
}

class _IconPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final r = RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(size.width * 0.22));
    canvas.drawRRect(
      r,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF43A047), Color(0xFF1B5E20)],
        ).createShader(Offset.zero & size),
    );
    paintTurtle(canvas, size.center(Offset.zero), 35, size.width * 0.62);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
