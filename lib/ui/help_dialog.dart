import 'package:flutter/material.dart';
import 'package:logo_core/logo_core.dart';

/// Référence des primitives, avec recherche.
class HelpDialog extends StatefulWidget {
  final List<Primitive> primitives;

  const HelpDialog({super.key, required this.primitives});

  static Future<void> show(BuildContext context, List<Primitive> primitives) => showDialog(
    context: context,
    builder: (_) => HelpDialog(primitives: primitives),
  );

  @override
  State<HelpDialog> createState() => _HelpDialogState();
}

class _HelpDialogState extends State<HelpDialog> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final q = _query.toLowerCase();
    final byCat = <String, List<Primitive>>{};
    for (final p in widget.primitives) {
      if (q.isNotEmpty && !p.names.any((n) => n.contains(q)) && !p.doc.toLowerCase().contains(q)) continue;
      byCat.putIfAbsent(p.category, () => []).add(p);
    }
    return Dialog(
      insetPadding: const EdgeInsets.all(40),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 820, maxHeight: 720),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 16, 8),
              child: Row(
                children: [
                  Icon(Icons.menu_book_outlined, color: scheme.primary),
                  const SizedBox(width: 10),
                  Text('Les mots de Logo', style: Theme.of(context).textTheme.titleLarge),
                  const Spacer(),
                  IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: TextField(
                autofocus: true,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search),
                  hintText: 'Chercher une primitive (av, repete, couleur…)',
                  filled: true,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                ),
                onChanged: (v) => setState(() => _query = v),
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                'Une procédure se définit avec  pour nom :entrée … fin.  Les mots entre « » sont des synonymes.',
                style: TextStyle(fontSize: 12.5, color: scheme.onSurfaceVariant),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                children: [
                  for (final entry in byCat.entries) ...[
                    Padding(
                      padding: const EdgeInsets.only(top: 16, bottom: 6),
                      child: Text(
                        entry.key.toUpperCase(),
                        style: TextStyle(
                          fontSize: 12,
                          letterSpacing: 1.2,
                          fontWeight: FontWeight.w700,
                          color: scheme.primary,
                        ),
                      ),
                    ),
                    for (final p in entry.value)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 5),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(
                              width: 250,
                              child: Text.rich(
                                TextSpan(
                                  children: [
                                    TextSpan(
                                      text: p.name,
                                      style: const TextStyle(
                                        fontFamily: 'monospace',
                                        fontWeight: FontWeight.w700,
                                        fontSize: 14,
                                      ),
                                    ),
                                    if (p.names.length > 1)
                                      TextSpan(
                                        text: '  « ${p.names.skip(1).join(', ')} »',
                                        style: TextStyle(
                                          fontFamily: 'monospace',
                                          fontSize: 12.5,
                                          color: scheme.onSurfaceVariant,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                            Expanded(child: Text(p.doc, style: const TextStyle(fontSize: 13.5))),
                          ],
                        ),
                      ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
