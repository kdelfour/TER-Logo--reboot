import 'package:flutter/material.dart';
import 'package:logo_core/logo_core.dart';

import '../state/app_controller.dart';

/// La télécommande du TER : piloter la tortue à la souris. Chaque action
/// est exécutée tout de suite et le code Logo correspondant est ajouté à
/// l'éditeur, pour faire le lien entre le geste et le programme.
class RemotePanel extends StatefulWidget {
  final AppController app;

  const RemotePanel({super.key, required this.app});

  @override
  State<RemotePanel> createState() => _RemotePanelState();
}

class _RemotePanelState extends State<RemotePanel> {
  double _distance = 50;
  double _angle = 90;

  void _send(String code) => widget.app.runRemote(code);

  String _n(double v) => v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(1);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final busy = widget.app.isRunning;
    Widget pad(IconData icon, String tip, String code, {Color? color}) => Padding(
      padding: const EdgeInsets.all(4),
      child: Tooltip(
        message: '$tip\n$code',
        child: FilledButton.tonal(
          style: FilledButton.styleFrom(
            minimumSize: const Size(64, 56),
            padding: EdgeInsets.zero,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            backgroundColor: color,
          ),
          onPressed: busy ? null : () => _send(code),
          child: Icon(icon, size: 28),
        ),
      ),
    );

    return Container(
      color: scheme.surfaceContainerLow,
      child: ListView(
        padding: const EdgeInsets.all(14),
        children: [
          Row(
            children: [
              Icon(Icons.gamepad_outlined, color: scheme.primary),
              const SizedBox(width: 8),
              Text('Télécommande', style: Theme.of(context).textTheme.titleMedium),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Chaque bouton fait bouger la tortue et écrit l\'instruction dans l\'éditeur.',
            style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 16),
          Center(
            child: Column(
              children: [
                pad(Icons.arrow_upward_rounded, 'Avancer', 'av ${_n(_distance)}'),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    pad(Icons.rotate_left_rounded, 'Tourner à gauche', 'tg ${_n(_angle)}'),
                    pad(Icons.home_rounded, 'Retour à l\'origine', 'origine'),
                    pad(Icons.rotate_right_rounded, 'Tourner à droite', 'td ${_n(_angle)}'),
                  ],
                ),
                pad(Icons.arrow_downward_rounded, 'Reculer', 're ${_n(_distance)}'),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _slider('Distance', _distance, 5, 200, (v) => setState(() => _distance = v.roundToDouble()), 'pas'),
          _slider('Angle', _angle, 5, 180, (v) => setState(() => _angle = (v / 5).round() * 5.0), '°'),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ActionChip(
                avatar: const Icon(Icons.edit_off, size: 16),
                label: const Text('Lever'),
                onPressed: busy ? null : () => _send('lc'),
              ),
              ActionChip(
                avatar: const Icon(Icons.edit, size: 16),
                label: const Text('Baisser'),
                onPressed: busy ? null : () => _send('bc'),
              ),
              ActionChip(
                avatar: const Icon(Icons.layers_clear, size: 16),
                label: const Text('Tout effacer'),
                onPressed: busy ? null : () => _send('ve'),
              ),
              ActionChip(
                avatar: const Icon(Icons.circle_outlined, size: 16),
                label: Text('Cercle ${_n(_distance)}'),
                onPressed: busy ? null : () => _send('cercle ${_n(_distance)}'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text('Couleur du crayon', style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final entry in colorNames.entries.where((e) => e.value <= 16))
                Tooltip(
                  message: 'fcc "${entry.key}',
                  child: InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: busy ? null : () => _send('fcc "${entry.key}'),
                    child: Container(
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(
                        color: Color(logoPalette[entry.value]),
                        shape: BoxShape.circle,
                        border: Border.all(color: scheme.outline, width: 1),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _slider(String label, double value, double min, double max, ValueChanged<double> onChanged, String unit) {
    return Row(
      children: [
        SizedBox(width: 64, child: Text(label, style: const TextStyle(fontSize: 13))),
        Expanded(
          child: Slider(value: value, min: min, max: max, onChanged: onChanged),
        ),
        SizedBox(
          width: 44,
          child: Text('${_n(value)} $unit', textAlign: TextAlign.right, style: const TextStyle(fontSize: 12)),
        ),
      ],
    );
  }
}
