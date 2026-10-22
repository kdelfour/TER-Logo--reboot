import '../errors.dart';
import '../interpreter.dart';
import '../parser.dart';
import '../reader.dart';
import '../values.dart';
import 'util.dart';

const _cat = 'Entrées / sorties';

List<Primitive> ioPrimitives() => [
      prim('ecris ec', const Arity(0, 1, -1), (c) {
        c.ip.host.write('${c.args.map((a) => a.print()).join(' ')}\n');
        return null;
      }, cat: _cat, doc: 'ecris valeur — affiche dans la console'),
      prim('montre', const Arity(0, 1, -1), (c) {
        c.ip.host.write('${c.args.map((a) => a.show()).join(' ')}\n');
        return null;
      }, cat: _cat, doc: 'montre valeur — affiche, listes entre crochets'),
      prim('tape', const Arity(0, 1, -1), (c) {
        c.ip.host.write(c.args.map((a) => a.print()).join(' '));
        return null;
      }, cat: _cat, doc: 'tape valeur — affiche sans aller à la ligne'),
      prim('lis lisliste', const Arity(0, 0, 1), (c) async {
        final line = await c.ip.host.readLine(c.count > 0 ? c[0].print() : '');
        if (line == null) throw LogoError('Aucune saisie possible', c.node.pos);
        return Reader.readList(line);
      }, cat: _cat, doc: 'lis — attend une ligne tapée et la renvoie comme liste'),
      prim('lismot', const Arity(0, 0, 1), (c) async {
        final line = await c.ip.host.readLine(c.count > 0 ? c[0].print() : '');
        if (line == null) throw LogoError('Aucune saisie possible', c.node.pos);
        return LogoWord(line);
      }, cat: _cat, doc: 'lismot — attend une ligne tapée et la renvoie comme mot'),
    ];
