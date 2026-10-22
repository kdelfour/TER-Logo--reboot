/// Position d'un élément dans le code source (lignes et colonnes à partir de 1).
class SourcePos {
  final int line;
  final int column;
  final int length;

  const SourcePos(this.line, this.column, [this.length = 1]);

  SourcePos shift(int offset, int len) => SourcePos(line, column + offset, len);

  @override
  String toString() => 'ligne $line, colonne $column';
}

/// Erreur signalée à l'utilisateur, avec message en français.
class LogoError implements Exception {
  final String message;
  SourcePos? pos;

  /// Procédure utilisateur dans laquelle l'erreur s'est produite.
  String? procedure;

  LogoError(this.message, [this.pos]);

  String describe() {
    final buf = StringBuffer(message);
    if (procedure != null) buf.write(' (dans « $procedure »)');
    if (pos != null) buf.write(' — ligne ${pos!.line}');
    return buf.toString();
  }

  @override
  String toString() => describe();
}

/// Arrêt demandé par l'utilisateur (bouton Stop).
class LogoHalt implements Exception {
  const LogoHalt();
}
