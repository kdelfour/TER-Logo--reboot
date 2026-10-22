import 'dart:async';
import 'dart:math' as math;

import 'errors.dart';
import 'parser.dart';
import 'primitives/all.dart';
import 'reader.dart';
import 'turtle.dart';
import 'values.dart';

typedef PrimFn = FutureOr<LogoValue?> Function(PrimCall c);

/// Primitive du langage. Le premier nom est le nom canonique, les suivants
/// sont des synonymes (abréviations).
class Primitive {
  final List<String> names;
  final Arity arity;
  final PrimFn fn;
  final String category;
  final String doc;

  Primitive(this.names, this.arity, this.fn, {this.category = '', this.doc = ''});

  String get name => names.first;
}

/// Contexte d'appel d'une primitive : arguments déjà évalués et accesseurs
/// typés qui produisent des messages d'erreur clairs.
class PrimCall {
  final Interpreter ip;
  final List<LogoValue> args;
  final CallNode node;

  PrimCall(this.ip, this.args, this.node);

  String get name => node.written;
  int get count => args.length;
  LogoValue operator [](int i) => args[i];

  LogoError badArg(int i, [String? what]) =>
      LogoError('« $name » n\'aime pas « ${args[i].show()} » comme ${what ?? 'argument'}', node.pos);

  num number(int i) {
    final a = args[i];
    if (a is LogoWord) {
      final n = a.asNumber;
      if (n != null) return n;
    }
    throw badArg(i);
  }

  double dbl(int i) => number(i).toDouble();

  int integer(int i) {
    final n = number(i);
    if (n is int) return n;
    if (n.isFinite) return n.truncate();
    throw badArg(i);
  }

  LogoList list(int i) {
    final a = args[i];
    if (a is LogoList) return a;
    throw badArg(i);
  }

  LogoWord word(int i) {
    final a = args[i];
    if (a is LogoWord) return a;
    throw badArg(i);
  }

  bool boolean(int i) {
    final b = asLogoBool(args[i]);
    if (b == null) throw badArg(i);
    return b;
  }

  /// Liste de deux nombres [x y].
  (double, double) point(int i) {
    final a = args[i];
    if (a is LogoList && a.length == 2) {
      final x = a.items[0], y = a.items[1];
      final nx = x is LogoWord ? x.asNumber : null;
      final ny = y is LogoWord ? y.asNumber : null;
      if (nx != null && ny != null) return (nx.toDouble(), ny.toDouble());
    }
    throw badArg(i);
  }
}

/// Procédure définie par l'utilisateur avec `pour … fin`.
class UserProcedure {
  final String name;
  final List<String> required;
  final List<(String, LogoList)> optional;
  final String? rest;
  final List<LogoList> body;
  final String source;

  UserProcedure(this.name, this.required, this.optional, this.rest, this.body, this.source);

  Arity get arity => Arity(required.length, required.length, rest != null ? -1 : required.length + optional.length);
}

class Frame {
  final Map<String, LogoValue?> vars = {};
  final Frame? parent;
  final UserProcedure? procedure;
  Frame(this.parent, [this.procedure]);
}

class OutputSignal implements Exception {
  final LogoValue value;
  OutputSignal(this.value);
}

class _TailCall {
  final UserProcedure proc;
  final List<LogoValue> args;
  final SourcePos? pos;
  final bool isOutput;
  _TailCall(this.proc, this.args, this.pos, this.isOutput);
}

class StopSignal implements Exception {
  const StopSignal();
}

/// Ce que l'interpréteur attend de son environnement (interface graphique,
/// ligne de commande, tests).
abstract class LogoHost {
  /// Affiche du texte dans la console (les fins de ligne sont incluses).
  void write(String text);

  /// Demande une ligne à l'utilisateur ; `null` si aucune entrée possible.
  Future<String?> readLine(String prompt);

  /// Reçoit un événement de la tortue. Peut renvoyer un Future pour
  /// ralentir l'interpréteur pendant l'animation.
  FutureOr<void> onTurtle(TurtleEvent event);
}

class Interpreter {
  final LogoHost host;
  final Map<String, Primitive> primitives = {};
  final List<Primitive> primitiveList = [];
  final Map<String, UserProcedure> procedures = {};
  final Frame global = Frame(null);
  late Frame _frame = global;
  final TurtleState turtle = TurtleState();
  final math.Random random;

  /// Incrémenté à chaque (re)définition de procédure pour invalider les
  /// listes d'instructions déjà analysées.
  int _generation = 0;
  final List<int> _repcount = [];
  int _depth = 0;
  static const maxDepth = 100000;

  bool _halt = false;
  Completer<void>? _pause;
  int _steps = 0;
  final Stopwatch _sinceYield = Stopwatch()..start();

  Interpreter(this.host, {math.Random? random, List<Primitive> Function()? extraPrimitives})
    : random = random ?? math.Random() {
    for (final p in allPrimitives()) {
      definePrimitive(p);
    }
    if (extraPrimitives != null) {
      for (final p in extraPrimitives()) {
        definePrimitive(p);
      }
    }
  }

  void definePrimitive(Primitive p) {
    primitiveList.add(p);
    for (final n in p.names) {
      primitives[n] = p;
    }
  }

  Frame get frame => _frame;
  int get repcount => _repcount.isEmpty ? -1 : _repcount.last;

  Arity? arityOf(String lowerName) => primitives[lowerName]?.arity ?? procedures[lowerName]?.arity;

  // -------------------------------------------------------------------------
  // Contrôle de l'exécution
  // -------------------------------------------------------------------------

  bool get isPaused => _pause != null;

  /// Demande l'arrêt du programme en cours (bouton Stop).
  void halt() {
    _halt = true;
    resume();
  }

  void pause() => _pause ??= Completer<void>();

  void resume() {
    _pause?.complete();
    _pause = null;
  }

  /// Point de coopération : rend la main à la boucle d'événements de temps
  /// en temps pour garder l'interface réactive, et gère stop/pause.
  FutureOr<void> tick() {
    if (_halt) throw const LogoHalt();
    if ((++_steps & 63) == 0 && (_sinceYield.elapsedMilliseconds >= 8 || _pause != null)) {
      return _yield();
    }
    return null;
  }

  Future<void> _yield() async {
    await Future<void>.delayed(Duration.zero);
    while (_pause != null) {
      await _pause!.future;
    }
    _sinceYield.reset();
    if (_halt) throw const LogoHalt();
  }

  /// Attente interruptible (pour `attends`).
  Future<void> sleep(Duration d) async {
    final sw = Stopwatch()..start();
    while (sw.elapsed < d) {
      if (_halt) throw const LogoHalt();
      final left = d - sw.elapsed;
      await Future<void>.delayed(left < const Duration(milliseconds: 50) ? left : const Duration(milliseconds: 50));
    }
    _sinceYield.reset();
  }

  FutureOr<LogoValue?> emit(TurtleEvent e) {
    final r = host.onTurtle(e);
    if (r is Future<void>) return r.then((_) => null);
    return null;
  }

  // -------------------------------------------------------------------------
  // Programme
  // -------------------------------------------------------------------------

  /// Exécute un programme complet (contenu de l'éditeur ou de la console).
  /// Lève [LogoError] en cas d'erreur, [LogoHalt] en cas d'arrêt.
  Future<void> run(String source) async {
    _halt = false;
    _steps = 0;
    _depth = 0;
    _repcount.clear();
    _frame = global;
    _sinceYield.reset();
    final lines = Reader.readProgram(source);
    var i = 0;
    try {
      while (i < lines.length) {
        final line = lines[i];
        if (_isWord(line.items, 0, 'pour')) {
          i = _define(lines, i);
          continue;
        }
        if (_isWord(line.items, 0, 'fin')) {
          throw LogoError('« fin » sans « pour »', (line.items.items.first as LogoWord).pos);
        }
        final nodes = Parser.parseList(line.items, arityOf);
        for (final n in nodes) {
          final v = await eval(n);
          if (v != null) throw _whatToDo(v, n.pos);
        }
        i++;
      }
    } on StopSignal {
      // `stop` hors procédure : fin du programme.
    } on OutputSignal {
      throw LogoError('« retourne » ne peut être utilisé que dans une procédure');
    } finally {
      _frame = global;
    }
  }

  static bool _isWord(LogoList l, int i, String w) {
    if (l.items.length <= i) return false;
    final it = l.items[i];
    return it is LogoWord && it.text.toLowerCase() == w;
  }

  /// Analyse une définition `pour nom :a :b … fin` et renvoie l'indice de la
  /// ligne suivante.
  int _define(List<LogicalLine> lines, int start) {
    final header = lines[start];
    final items = header.items.items;
    final pourPos = (items[0] as LogoWord).pos;
    if (items.length < 2 || items[1] is! LogoWord) {
      throw LogoError('« pour » doit être suivi du nom de la procédure', pourPos);
    }
    final nameWord = items[1] as LogoWord;
    final name = nameWord.text;
    final lower = name.toLowerCase();
    if (primitives.containsKey(lower)) {
      throw LogoError('« $name » est une primitive, choisis un autre nom', nameWord.pos);
    }
    if (parseLogoNumber(name) != null || name.startsWith(':') || name.startsWith('"')) {
      throw LogoError('« $name » n\'est pas un nom de procédure valide', nameWord.pos);
    }

    final required = <String>[];
    final optional = <(String, LogoList)>[];
    String? rest;
    var k = 2;
    for (; k < items.length; k++) {
      final it = items[k];
      if (it is LogoWord && it.text.startsWith(':') && it.text.length > 1) {
        if (optional.isNotEmpty || rest != null) {
          throw LogoError('Les entrées obligatoires doivent précéder les entrées optionnelles', it.pos);
        }
        required.add(it.text.substring(1).toLowerCase());
      } else if (it is LogoList &&
          it.items.isNotEmpty &&
          it.items.first is LogoWord &&
          (it.items.first as LogoWord).text.startsWith(':')) {
        final v = (it.items.first as LogoWord).text.substring(1).toLowerCase();
        if (it.items.length == 1) {
          rest = v;
        } else {
          optional.add((v, LogoList(it.items.sublist(1), it.pos)));
        }
      } else {
        break;
      }
    }

    final body = <LogoList>[];
    final src = StringBuffer(header.source);
    var i = start + 1;
    // Forme sur une seule ligne : pour carre :c repete 4 [av :c td 90] fin
    if (k < items.length) {
      final last = items.last;
      if (last is LogoWord && last.text.toLowerCase() == 'fin') {
        body.add(LogoList(items.sublist(k, items.length - 1), header.items.pos));
        _install(UserProcedure(name, required, optional, rest, body, header.source));
        return i;
      }
      throw LogoError(
        'Entrée inattendue « ${items[k].show()} » dans la définition de « $name »',
        items[k] is LogoWord ? (items[k] as LogoWord).pos : (items[k] as LogoList).pos,
      );
    }
    while (true) {
      if (i >= lines.length) {
        throw LogoError('Il manque « fin » pour terminer « $name »', pourPos);
      }
      final l = lines[i];
      src.write('\n${l.source}');
      if (_isWord(l.items, 0, 'fin')) {
        if (l.items.length > 1) {
          throw LogoError('« fin » doit être seul sur sa ligne', (l.items.items.first as LogoWord).pos);
        }
        i++;
        break;
      }
      if (_isWord(l.items, 0, 'pour')) {
        throw LogoError('Il manque « fin » pour terminer « $name »', pourPos);
      }
      body.add(l.items);
      i++;
    }
    _install(UserProcedure(name, required, optional, rest, body, src.toString()));
    return i;
  }

  void _install(UserProcedure p) {
    procedures[p.name.toLowerCase()] = p;
    _generation++;
  }

  /// Définit une procédure à partir de son texte (`pour … fin`).
  void defineFromSource(String source) {
    final lines = Reader.readProgram(source);
    if (lines.isEmpty || !_isWord(lines.first.items, 0, 'pour')) {
      throw LogoError('Une définition doit commencer par « pour »');
    }
    _define(lines, 0);
  }

  // -------------------------------------------------------------------------
  // Évaluation
  // -------------------------------------------------------------------------

  LogoError _whatToDo(LogoValue v, SourcePos? pos) => LogoError('Je ne sais que faire de « ${v.show()} »', pos);

  List<Node> parseCached(LogoList list) {
    if (list.parseCacheGeneration == _generation && list.parseCache != null) {
      return list.parseCache as List<Node>;
    }
    final nodes = Parser.parseList(list, arityOf);
    list.parseCache = nodes;
    list.parseCacheGeneration = _generation;
    return nodes;
  }

  /// Exécute une liste d'instructions. Si [allowValue], la valeur de la
  /// dernière expression est renvoyée (pour `exec`, `si`…).
  Future<LogoValue?> runList(LogoList list, {bool allowValue = false}) async {
    final nodes = parseCached(list);
    for (var i = 0; i < nodes.length; i++) {
      final v = await eval(nodes[i]);
      if (v != null) {
        if (allowValue && i == nodes.length - 1) return v;
        throw _whatToDo(v, nodes[i].pos);
      }
    }
    return null;
  }

  /// Évalue une liste qui doit produire une valeur (ex. condition de `tantque`).
  Future<LogoValue> evalListValue(LogoList list, String forWhom) async {
    final v = await runList(list, allowValue: true);
    if (v == null) throw LogoError('« ${list.show()} » ne donne pas de valeur à « $forWhom »', list.pos);
    return v;
  }

  Future<LogoValue?> eval(Node n) async {
    switch (n) {
      case LiteralNode():
        return n.value;
      case VarNode():
        return lookup(n.name, n.pos);
      case NegateNode():
        final v = await _value(n.operand, '-');
        final x = v is LogoWord ? v.asNumber : null;
        if (x == null) throw LogoError('« - » n\'aime pas « ${v.show()} » comme argument', n.pos);
        return LogoNumber(-x);
      case BinaryNode():
        final l = await _value(n.left, n.op);
        final r = await _value(n.right, n.op);
        return binary(n.op, l, r, n.pos);
      case CallNode():
        return await call(n);
    }
  }

  Future<LogoValue> _value(Node n, String forWhom) async {
    final LogoValue? v;
    if (n is LiteralNode) {
      v = n.value;
    } else if (n is VarNode) {
      v = lookup(n.name, n.pos);
    } else {
      v = await eval(n);
    }
    if (v == null) {
      final who = n is CallNode ? n.written : '?';
      throw LogoError('« $who » ne retourne rien à « $forWhom »', n.pos);
    }
    return v;
  }

  LogoValue binary(String op, LogoValue l, LogoValue r, SourcePos? pos) {
    switch (op) {
      case '=':
        return logoBool(logoEquals(l, r));
      case '<>':
        return logoBool(!logoEquals(l, r));
    }
    final a = l is LogoWord ? l.asNumber : null;
    final b = r is LogoWord ? r.asNumber : null;
    if (a == null) throw LogoError('« $op » n\'aime pas « ${l.show()} » comme argument', pos);
    if (b == null) throw LogoError('« $op » n\'aime pas « ${r.show()} » comme argument', pos);
    switch (op) {
      case '+':
        return LogoNumber(a + b);
      case '-':
        return LogoNumber(a - b);
      case '*':
        return LogoNumber(a * b);
      case '/':
        if (b == 0) throw LogoError('Division par zéro', pos);
        return LogoNumber(a / b);
      case '<':
        return logoBool(a < b);
      case '>':
        return logoBool(a > b);
      case '<=':
        return logoBool(a <= b);
      case '>=':
        return logoBool(a >= b);
    }
    throw LogoError('Opérateur inconnu « $op »', pos);
  }

  Future<LogoValue?> call(CallNode n) async {
    final t = tick();
    if (t != null) await t;
    final args = List<LogoValue>.filled(n.args.length, emptyWord);
    for (var i = 0; i < n.args.length; i++) {
      args[i] = await _value(n.args[i], n.written);
    }
    final prim = primitives[n.name];
    if (prim != null) {
      try {
        final r = prim.fn(PrimCall(this, args, n));
        return r is Future<LogoValue?> ? await r : r;
      } on LogoError catch (e) {
        e.pos ??= n.pos;
        rethrow;
      }
    }
    final proc = procedures[n.name];
    if (proc == null) throw LogoError('Je ne sais pas faire « ${n.written} »', n.pos);
    return await callProcedure(proc, args, n.pos);
  }

  // Attention : dans une fonction async, « return unFuture » (sans await)
  // chaîne les futurs et rend la récursion profonde quadratique.
  Future<LogoValue?> callProcedure(UserProcedure proc, List<LogoValue> args, SourcePos? pos) {
    if ((_depth + 1) % 64 != 0) return _callProcedure(proc, args, pos);
    return _callProcedureWithYield(proc, args, pos);
  }

  /// Une chaîne d'appels async descend et remonte de façon synchrone : on
  /// force une vraie suspension de temps en temps pour borner la pile native.
  Future<LogoValue?> _callProcedureWithYield(UserProcedure proc, List<LogoValue> args, SourcePos? pos) async {
    await Future<void>.value();
    try {
      return await _callProcedure(proc, args, pos);
    } finally {
      await Future<void>.value();
    }
  }

  Future<LogoValue?> _callProcedure(UserProcedure proc, List<LogoValue> args, SourcePos? pos) async {
    if (_depth >= maxDepth) {
      throw LogoError('Trop d\'appels imbriqués (récursion infinie ?) dans « ${proc.name} »', pos);
    }
    _depth++;
    final previous = _frame;
    var parent = previous;
    var statementTail = false;
    try {
      while (true) {
        final a = proc.arity;
        if (args.length < a.min) {
          throw LogoError('Pas assez d\'arguments pour « ${proc.name} »', pos);
        }
        if (a.max >= 0 && args.length > a.max) {
          throw LogoError('Trop d\'arguments pour « ${proc.name} »', pos);
        }
        final f = Frame(parent, proc);
        var k = 0;
        for (final p in proc.required) {
          f.vars[p] = args[k++];
        }
        _frame = f;
        _TailCall? tail;
        try {
          for (final (name, defaultExpr) in proc.optional) {
            if (k < args.length) {
              f.vars[name] = args[k++];
            } else {
              f.vars[name] = await evalListValue(defaultExpr, proc.name);
            }
          }
          if (proc.rest != null) {
            f.vars[proc.rest!] = LogoList(k < args.length ? args.sublist(k) : const []);
          }
          tail = await _runBody(proc);
        } on OutputSignal catch (s) {
          if (statementTail) throw _whatToDo(s.value, pos);
          return s.value;
        } on StopSignal {
          return null;
        } on LogoError catch (e) {
          e.procedure ??= proc.name;
          rethrow;
        }
        if (tail == null) return null;
        // Appel terminal : on remplace la procédure courante au lieu
        // d'empiler un nouvel appel (comme UCBLogo), ce qui permet les
        // boucles infinies par récursivité.
        statementTail |= !tail.isOutput;
        // Portée dynamique : la procédure appelée doit encore voir les
        // variables de l'appelant. Pour une auto-récursion, les entrées du
        // nouvel appel masquent celles de l'ancien : on peut le libérer.
        if (!identical(tail.proc, proc)) parent = f;
        proc = tail.proc;
        args = tail.args;
        pos = tail.pos;
        _frame = previous;
        final t = tick();
        if (t != null) await t;
      }
    } finally {
      _frame = previous;
      _depth--;
    }
  }

  /// Exécute le corps d'une procédure. Si la dernière instruction est un
  /// appel à une procédure utilisateur (éventuellement via `retourne`), ses
  /// arguments sont évalués et l'appel est renvoyé au lieu d'être exécuté.
  Future<_TailCall?> _runBody(UserProcedure proc) async {
    final body = proc.body;
    for (var li = 0; li < body.length; li++) {
      final nodes = parseCached(body[li]);
      final lastLine = li == body.length - 1;
      for (var ni = 0; ni < nodes.length; ni++) {
        final node = nodes[ni];
        if (lastLine && ni == nodes.length - 1) {
          var target = node;
          var isOutput = false;
          if (target is CallNode && (target.name == 'retourne' || target.name == 'rends') && target.args.length == 1) {
            target = target.args.first;
            isOutput = true;
          }
          if (target is CallNode && !primitives.containsKey(target.name)) {
            final next = procedures[target.name];
            if (next != null) {
              final t = tick();
              if (t != null) await t;
              final args = <LogoValue>[];
              for (final a in target.args) {
                args.add(await _value(a, target.written));
              }
              return _TailCall(next, args, target.pos, isOutput);
            }
          }
        }
        final v = await eval(node);
        if (v != null) throw _whatToDo(v, node.pos);
      }
    }
    return null;
  }

  /// Appelle une procédure (primitive ou utilisateur) par son nom.
  Future<LogoValue?> invoke(String name, List<LogoValue> args, CallNode site) async {
    final lower = name.toLowerCase();
    final prim = primitives[lower];
    if (prim != null) {
      final a = prim.arity;
      if (args.length < a.min || (a.max >= 0 && args.length > a.max)) {
        throw LogoError('Mauvais nombre d\'arguments pour « $name »', site.pos);
      }
      final node = CallNode(lower, name, const [], site.pos);
      var r = prim.fn(PrimCall(this, args, node));
      if (r is Future<LogoValue?>) r = await r;
      return r;
    }
    final proc = procedures[lower];
    if (proc == null) throw LogoError('Je ne sais pas faire « $name »', site.pos);
    return await callProcedure(proc, args, site.pos);
  }

  // -------------------------------------------------------------------------
  // Variables (portée dynamique, comme en Logo)
  // -------------------------------------------------------------------------

  LogoValue lookup(String name, [SourcePos? pos]) {
    for (Frame? f = _frame; f != null; f = f.parent) {
      if (f.vars.containsKey(name)) {
        final v = f.vars[name];
        if (v == null) break;
        return v;
      }
    }
    throw LogoError('« $name » n\'a pas de valeur', pos);
  }

  bool hasValue(String name) {
    for (Frame? f = _frame; f != null; f = f.parent) {
      if (f.vars.containsKey(name)) return f.vars[name] != null;
    }
    return false;
  }

  void setVariable(String name, LogoValue v) {
    for (Frame? f = _frame; f != null; f = f.parent) {
      if (f.vars.containsKey(name)) {
        f.vars[name] = v;
        return;
      }
    }
    global.vars[name] = v;
  }

  void makeLocal(String name, [LogoValue? v]) {
    _frame.vars[name] = v;
  }

  /// Exécute [body] avec un nouveau cadre local (utilisé par `repetepour`).
  Future<T> withFrame<T>(Future<T> Function(Frame f) body) async {
    final previous = _frame;
    final f = Frame(previous, previous.procedure);
    _frame = f;
    try {
      return await body(f);
    } finally {
      _frame = previous;
    }
  }

  void pushRepcount(int n) => _repcount.add(n);
  void setRepcount(int n) => _repcount[_repcount.length - 1] = n;
  void popRepcount() => _repcount.removeLast();

  /// Remet la tortue et l'écran à zéro (bouton « Effacer »).
  FutureOr<void> resetScreen() {
    turtle.reset();
    host.onTurtle(BackgroundEvent(turtle.background));
    host.onTurtle(VisibilityEvent(true));
    return host.onTurtle(const ClearEvent(true));
  }

  /// Oublie procédures et variables.
  void resetWorkspace() {
    procedures.clear();
    global.vars.clear();
    _generation++;
  }
}
