import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../state/app_controller.dart';

/// Console : sortie des programmes, messages et erreurs, plus une ligne de
/// commande pour exécuter des instructions pas à pas.
class ConsolePanel extends StatefulWidget {
  final AppController app;

  const ConsolePanel({super.key, required this.app});

  @override
  State<ConsolePanel> createState() => _ConsolePanelState();
}

class _ConsolePanelState extends State<ConsolePanel> {
  final _input = TextEditingController();
  final _focus = FocusNode();
  final _scroll = ScrollController();
  final List<String> _history = [];
  int _historyIndex = 0;
  int _seenVersion = -1;

  @override
  void dispose() {
    _input.dispose();
    _focus.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _submit(String text) {
    if (text.trim().isEmpty) return;
    if (_history.isEmpty || _history.last != text) _history.add(text);
    _historyIndex = _history.length;
    _input.clear();
    widget.app.runCommand(text);
    _focus.requestFocus();
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent e) {
    if (e is! KeyDownEvent && e is! KeyRepeatEvent) return KeyEventResult.ignored;
    if (e.logicalKey == LogicalKeyboardKey.arrowUp && _history.isNotEmpty) {
      _historyIndex = (_historyIndex - 1).clamp(0, _history.length - 1);
      _setInput(_history[_historyIndex]);
      return KeyEventResult.handled;
    }
    if (e.logicalKey == LogicalKeyboardKey.arrowDown && _history.isNotEmpty) {
      _historyIndex = (_historyIndex + 1).clamp(0, _history.length);
      _setInput(_historyIndex == _history.length ? '' : _history[_historyIndex]);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  void _setInput(String s) {
    _input.value = TextEditingValue(
      text: s,
      selection: TextSelection.collapsed(offset: s.length),
    );
  }

  @override
  Widget build(BuildContext context) {
    final app = widget.app;
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    if (_seenVersion != app.consoleVersion) {
      _seenVersion = app.consoleVersion;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scroll.hasClients) _scroll.jumpTo(_scroll.position.maxScrollExtent);
      });
    }
    Color colorOf(ConsoleKind k) => switch (k) {
      ConsoleKind.output => scheme.onSurface,
      ConsoleKind.command => scheme.onSurfaceVariant,
      ConsoleKind.system => dark ? const Color(0xFF7FB2FF) : const Color(0xFF2155C4),
      ConsoleKind.error => dark ? const Color(0xFFFF8A80) : const Color(0xFFC62828),
    };
    const mono = TextStyle(
      fontFamily: 'monospace',
      fontFamilyFallback: ['DejaVu Sans Mono'],
      fontSize: 13.5,
      height: 1.4,
    );
    final lines = app.console;
    final partial = app.partialLine;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          height: 32,
          padding: const EdgeInsets.only(left: 12, right: 4),
          color: scheme.surfaceContainerLow,
          child: Row(
            children: [
              Icon(Icons.terminal, size: 16, color: scheme.onSurfaceVariant),
              const SizedBox(width: 8),
              Text(
                'Console',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: scheme.onSurfaceVariant),
              ),
              const Spacer(),
              IconButton(
                tooltip: 'Vider la console',
                iconSize: 16,
                visualDensity: VisualDensity.compact,
                onPressed: app.clearConsole,
                icon: const Icon(Icons.delete_sweep_outlined),
              ),
            ],
          ),
        ),
        Divider(height: 1, color: scheme.outlineVariant),
        Expanded(
          child: Container(
            color: scheme.surface,
            child: SelectionArea(
              child: ListView.builder(
                controller: _scroll,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                itemCount: lines.length + (partial.isEmpty ? 0 : 1),
                itemBuilder: (context, i) {
                  if (i == lines.length) return Text(partial, style: mono.copyWith(color: scheme.onSurface));
                  final l = lines[i];
                  return Text(
                    l.text,
                    style: mono.copyWith(
                      color: colorOf(l.kind),
                      fontWeight: l.kind == ConsoleKind.error ? FontWeight.w600 : null,
                    ),
                  );
                },
              ),
            ),
          ),
        ),
        Divider(height: 1, color: scheme.outlineVariant),
        Container(
          color: scheme.surfaceContainerLowest,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            children: [
              Text(
                '?',
                style: mono.copyWith(color: scheme.primary, fontWeight: FontWeight.w700, fontSize: 15),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Focus(
                  onKeyEvent: _onKey,
                  child: TextField(
                    controller: _input,
                    focusNode: _focus,
                    style: mono,
                    decoration: const InputDecoration(
                      isDense: true,
                      border: InputBorder.none,
                      hintText: 'Tape une commande Logo, par exemple : repete 4 [av 100 td 90]',
                    ),
                    onSubmitted: _submit,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Exécuter (Entrée)',
                iconSize: 18,
                visualDensity: VisualDensity.compact,
                onPressed: () => _submit(_input.text),
                icon: Icon(Icons.keyboard_return, color: scheme.primary),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
