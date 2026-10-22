import 'package:flutter/material.dart';
import 'package:logo_core/logo_core.dart';
import 'package:re_highlight/re_highlight.dart';

/// Définition du langage Logo pour la coloration de l'éditeur, construite à
/// partir de la table des primitives de l'interpréteur.
Mode buildLogoMode(Iterable<Primitive> primitives) {
  final control = <String>{'pour', 'fin'};
  final turtle = <String>{};
  final other = <String>{};
  for (final prim in primitives) {
    final target = switch (prim.category) {
      'Contrôle' || 'Procédures' || 'Variables' => control,
      'Tortue' || 'Crayon et couleurs' => turtle,
      _ => other,
    };
    target.addAll(prim.names);
  }
  // Les noms avec « ? » ou « . » ne sont pas des mots au sens des
  // expressions régulières : on définit le motif d'un mot Logo.
  const word = r'[^\s\[\]\(\);"+\-*/=<>]+';
  return Mode(
    name: 'logo',
    caseInsensitive: true,
    keywords: {
      r'$pattern': word,
      'keyword': control.join(' '),
      'built_in': turtle.join(' '),
      'title': other.join(' '),
      'literal': 'vrai faux',
    },
    contains: [
      Mode(scope: 'comment', begin: ';', end: r'$'),
      Mode(scope: 'string', begin: r'"[^\s\[\]\(\)]*'),
      Mode(scope: 'variable', begin: r':[^\s\[\]\(\)+\-*/=<>]+'),
      Mode(scope: 'number', begin: r'(?<![\w:"])-?\d+(\.\d+)?([eE][-+]?\d+)?'),
      Mode(scope: 'punctuation', begin: r'[\[\]\(\)]'),
    ],
  );
}

Map<String, TextStyle> logoTheme(Brightness b) {
  final dark = b == Brightness.dark;
  return {
    'root': TextStyle(color: dark ? const Color(0xFFE3E6E8) : const Color(0xFF1F2328)),
    'comment': TextStyle(color: dark ? const Color(0xFF7D8A80) : const Color(0xFF6A7A6E), fontStyle: FontStyle.italic),
    'keyword': TextStyle(color: dark ? const Color(0xFFFF8F70) : const Color(0xFFC2410C), fontWeight: FontWeight.w600),
    'built_in': TextStyle(color: dark ? const Color(0xFF7FD48A) : const Color(0xFF15803D), fontWeight: FontWeight.w600),
    'title': TextStyle(color: dark ? const Color(0xFF8AB4FF) : const Color(0xFF1D4ED8)),
    'literal': TextStyle(color: dark ? const Color(0xFFD7A8FF) : const Color(0xFF7E22CE)),
    'string': TextStyle(color: dark ? const Color(0xFFF2C46B) : const Color(0xFFA16207)),
    'variable': TextStyle(color: dark ? const Color(0xFFC6A5FF) : const Color(0xFF7C3AED), fontWeight: FontWeight.w500),
    'number': TextStyle(color: dark ? const Color(0xFF6CD3D9) : const Color(0xFF0E7490)),
    'punctuation': TextStyle(color: dark ? const Color(0xFF9AA4AD) : const Color(0xFF57606A)),
  };
}
