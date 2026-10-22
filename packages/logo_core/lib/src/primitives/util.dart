import '../interpreter.dart';
import '../parser.dart';

/// Déclare une primitive ; [names] contient le nom et ses synonymes séparés
/// par des espaces.
Primitive prim(String names, Arity arity, PrimFn fn, {String cat = '', String doc = ''}) =>
    Primitive(names.split(' '), arity, fn, category: cat, doc: doc);
