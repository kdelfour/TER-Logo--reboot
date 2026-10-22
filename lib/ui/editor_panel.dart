import 'package:flutter/material.dart';
import 'package:re_editor/re_editor.dart';
import 'package:re_highlight/re_highlight.dart';

import '../state/app_controller.dart';
import 'logo_language.dart';

class EditorPanel extends StatefulWidget {
  final AppController app;
  final Future<void> Function(int index) onCloseTab;

  const EditorPanel({super.key, required this.app, required this.onCloseTab});

  @override
  State<EditorPanel> createState() => _EditorPanelState();
}

class _EditorPanelState extends State<EditorPanel> {
  late final Mode _mode = buildLogoMode(widget.app.interpreter.primitiveList);

  @override
  Widget build(BuildContext context) {
    final app = widget.app;
    final scheme = Theme.of(context).colorScheme;
    final doc = app.activeDocument;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _TabStrip(app: app, onClose: widget.onCloseTab),
        Divider(height: 1, color: scheme.outlineVariant),
        Expanded(
          child: doc == null ? const SizedBox() : _LogoEditor(key: ObjectKey(doc), document: doc, mode: _mode),
        ),
      ],
    );
  }
}

class _TabStrip extends StatelessWidget {
  final AppController app;
  final Future<void> Function(int index) onClose;

  const _TabStrip({required this.app, required this.onClose});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      height: 38,
      color: scheme.surfaceContainerLow,
      child: Row(
        children: [
          Expanded(
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                for (var i = 0; i < app.documents.length; i++)
                  _Tab(
                    title: app.documents[i].title,
                    dirty: app.documents[i].dirty,
                    selected: i == app.activeIndex,
                    onTap: () => app.activeIndex = i,
                    onClose: () => onClose(i),
                  ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Nouvel onglet (Ctrl+N)',
            iconSize: 18,
            onPressed: () => app.newDocument(),
            icon: const Icon(Icons.add),
          ),
        ],
      ),
    );
  }
}

class _Tab extends StatefulWidget {
  final String title;
  final bool dirty;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onClose;

  const _Tab({
    required this.title,
    required this.dirty,
    required this.selected,
    required this.onTap,
    required this.onClose,
  });

  @override
  State<_Tab> createState() => _TabState();
}

class _TabState extends State<_Tab> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final selected = widget.selected;
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        onTertiaryTapUp: (_) => widget.onClose(),
        child: Container(
          padding: const EdgeInsets.only(left: 14, right: 4),
          decoration: BoxDecoration(
            color: selected ? scheme.surface : (_hover ? scheme.surfaceContainerHigh : Colors.transparent),
            border: Border(
              top: BorderSide(color: selected ? scheme.primary : Colors.transparent, width: 2),
              right: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.6)),
            ),
          ),
          child: Row(
            children: [
              Icon(Icons.description_outlined, size: 15, color: selected ? scheme.primary : scheme.onSurfaceVariant),
              const SizedBox(width: 6),
              Text(
                widget.title,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                  color: selected ? scheme.onSurface : scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: 2),
              SizedBox(
                width: 26,
                height: 26,
                child: widget.dirty && !_hover
                    ? Center(
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(color: scheme.primary, shape: BoxShape.circle),
                        ),
                      )
                    : IconButton(
                        padding: EdgeInsets.zero,
                        iconSize: 14,
                        tooltip: 'Fermer',
                        onPressed: widget.onClose,
                        icon: Icon(
                          Icons.close,
                          color: _hover || selected ? scheme.onSurfaceVariant : Colors.transparent,
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LogoEditor extends StatefulWidget {
  final EditorDocument document;
  final Mode mode;

  const _LogoEditor({super.key, required this.document, required this.mode});

  @override
  State<_LogoEditor> createState() => _LogoEditorState();
}

class _LogoEditorState extends State<_LogoEditor> {
  late final CodeFindController _find = CodeFindController(widget.document.controller);
  final _scroll = CodeScrollController();

  @override
  void dispose() {
    _find.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final dark = theme.brightness == Brightness.dark;
    return CodeEditor(
      controller: widget.document.controller,
      findController: _find,
      scrollController: _scroll,
      autofocus: true,
      wordWrap: false,
      // En Logo, « " » ouvre un mot et ne se referme pas.
      autocompleteSymbols: false,
      padding: const EdgeInsets.only(left: 6, top: 8, right: 8, bottom: 40),
      commentFormatter: DefaultCodeCommentFormatter(singleLinePrefix: ';'),
      style: CodeEditorStyle(
        fontSize: 15,
        fontHeight: 1.45,
        fontFamily: 'monospace',
        fontFamilyFallback: const ['DejaVu Sans Mono', 'Liberation Mono', 'Noto Sans Mono'],
        backgroundColor: scheme.surface,
        textColor: scheme.onSurface,
        cursorColor: scheme.primary,
        cursorLineColor: scheme.primary.withValues(alpha: dark ? 0.08 : 0.05),
        selectionColor: scheme.primary.withValues(alpha: 0.25),
        highlightColor: Colors.amber.withValues(alpha: 0.35),
        chunkIndicatorColor: scheme.onSurfaceVariant,
        codeTheme: CodeHighlightTheme(
          languages: {'logo': CodeHighlightThemeMode(mode: widget.mode)},
          theme: logoTheme(theme.brightness),
        ),
      ),
      indicatorBuilder: (context, editingController, chunkController, notifier) => Row(
        children: [
          DefaultCodeLineNumber(
            controller: editingController,
            notifier: notifier,
            textStyle: TextStyle(color: scheme.onSurfaceVariant.withValues(alpha: 0.55), fontSize: 13),
            focusedTextStyle: TextStyle(color: scheme.primary, fontSize: 13, fontWeight: FontWeight.w600),
            minNumberCount: 3,
          ),
          DefaultCodeChunkIndicator(width: 18, controller: chunkController, notifier: notifier),
        ],
      ),
      leadingDivider: Container(width: 1, color: scheme.outlineVariant.withValues(alpha: 0.5)),
      findBuilder: (context, controller, readOnly) => _FindBar(controller: controller),
      toolbarController: const _ContextMenu(),
    );
  }
}

/// Barre de recherche (Ctrl+F) et remplacement (Ctrl+H).
class _FindBar extends StatelessWidget implements PreferredSizeWidget {
  final CodeFindController controller;

  const _FindBar({required this.controller});

  @override
  Size get preferredSize =>
      Size(double.infinity, controller.value == null ? 0 : (controller.value!.replaceMode ? 88 : 48));

  @override
  Widget build(BuildContext context) {
    final value = controller.value;
    if (value == null) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    final result = value.result == null || value.result!.matches.isEmpty
        ? 'aucun'
        : '${value.result!.index + 1}/${value.result!.matches.length}';
    InputDecoration deco(String hint) => InputDecoration(
      isDense: true,
      hintText: hint,
      filled: true,
      fillColor: scheme.surfaceContainerHighest,
      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide.none),
    );
    return Container(
      alignment: Alignment.topRight,
      padding: const EdgeInsets.fromLTRB(8, 6, 12, 2),
      child: Material(
        elevation: 3,
        borderRadius: BorderRadius.circular(8),
        color: scheme.surfaceContainer,
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: controller.findInputController,
                        focusNode: controller.findInputFocusNode,
                        style: const TextStyle(fontSize: 13),
                        decoration: deco('Rechercher'),
                        onSubmitted: (_) => controller.nextMatch(),
                      ),
                    ),
                    SizedBox(
                      width: 56,
                      child: Text(result, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12)),
                    ),
                    _iconBtn(
                      Icons.text_fields,
                      'Respecter la casse',
                      controller.toggleCaseSensitive,
                      selected: value.option.caseSensitive,
                      scheme: scheme,
                    ),
                    _iconBtn(Icons.arrow_upward, 'Précédent', controller.previousMatch, scheme: scheme),
                    _iconBtn(Icons.arrow_downward, 'Suivant', controller.nextMatch, scheme: scheme),
                    _iconBtn(
                      Icons.find_replace,
                      'Remplacer',
                      controller.toggleMode,
                      selected: value.replaceMode,
                      scheme: scheme,
                    ),
                    _iconBtn(Icons.close, 'Fermer (Échap)', controller.close, scheme: scheme),
                  ],
                ),
                if (value.replaceMode)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: controller.replaceInputController,
                            focusNode: controller.replaceInputFocusNode,
                            style: const TextStyle(fontSize: 13),
                            decoration: deco('Remplacer par'),
                          ),
                        ),
                        TextButton(onPressed: controller.replaceMatch, child: const Text('Remplacer')),
                        TextButton(onPressed: controller.replaceAllMatches, child: const Text('Tout')),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _iconBtn(
    IconData icon,
    String tip,
    VoidCallback onTap, {
    bool selected = false,
    required ColorScheme scheme,
  }) => IconButton(
    tooltip: tip,
    iconSize: 17,
    visualDensity: VisualDensity.compact,
    isSelected: selected,
    color: selected ? scheme.primary : null,
    onPressed: onTap,
    icon: Icon(icon),
  );
}

class _ContextMenu implements SelectionToolbarController {
  const _ContextMenu();

  @override
  void hide(BuildContext context) {}

  @override
  void show({
    required BuildContext context,
    required CodeLineEditingController controller,
    required TextSelectionToolbarAnchors anchors,
    Rect? renderRect,
    required LayerLink layerLink,
    required ValueNotifier<bool> visibility,
  }) {
    PopupMenuItem<void> item(String text, String shortcut, VoidCallback onTap) => PopupMenuItem<void>(
      height: 34,
      onTap: onTap,
      child: Row(
        children: [
          Expanded(child: Text(text, style: const TextStyle(fontSize: 13))),
          Text(shortcut, style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
        ],
      ),
    );
    showMenu<void>(
      context: context,
      position: RelativeRect.fromSize(
        anchors.primaryAnchor & const Size(200, double.infinity),
        MediaQuery.of(context).size,
      ),
      items: [
        item('Annuler', 'Ctrl+Z', controller.undo),
        item('Rétablir', 'Ctrl+Y', controller.redo),
        const PopupMenuDivider(),
        item('Couper', 'Ctrl+X', controller.cut),
        item('Copier', 'Ctrl+C', controller.copy),
        item('Coller', 'Ctrl+V', controller.paste),
        const PopupMenuDivider(),
        item('Tout sélectionner', 'Ctrl+A', controller.selectAll),
      ],
    );
  }
}
