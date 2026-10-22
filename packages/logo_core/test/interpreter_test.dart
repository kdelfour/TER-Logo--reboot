import 'dart:async';
import 'dart:io';

import 'package:logo_core/logo_core.dart';
import 'package:test/test.dart';

Future<(RecordingHost, Interpreter)> run(String src, {List<String>? inputs}) async {
  final host = RecordingHost(inputs: inputs);
  final ip = Interpreter(host);
  await ip.run(src);
  return (host, ip);
}

Future<String> out(String src) async => (await run(src)).$1.output.toString();

Future<String> error(String src) async {
  try {
    await run(src);
  } on LogoError catch (e) {
    return e.describe();
  }
  fail('Aucune erreur pour : $src');
}

void main() {
  group('calcul', () {
    test('priorités des opérateurs', () async {
      expect(await out('ecris 2 + 3 * 4'), '14\n');
      expect(await out('ecris (2 + 3) * 4'), '20\n');
      expect(await out('ecris 10 - 2 - 3'), '5\n');
      expect(await out('ecris 7 / 2'), '3.5\n');
      expect(await out('ecris 2 * -3'), '-6\n');
      expect(await out('ecris -3 + 1'), '-2\n');
      expect(await out('ecris 1 < 2'), 'vrai\n');
      expect(await out('ecris 3 <> 3'), 'faux\n');
    });

    test('les arguments préfixes englobent les opérateurs infixes', () async {
      expect(await out('ecris somme 2 3 * 4'), '14\n');
      expect(await out('ecris racine 9 + 7'), '4\n');
    });

    test('forme parenthésée à nombre variable d\'arguments', () async {
      expect(await out('ecris (somme 1 2 3 4)'), '10\n');
      expect(await out('ecris (produit 2 3 4)'), '24\n');
      expect(await out('ecris (pi * 2) > 6'), 'vrai\n');
    });

    test('moins unaire et binaire', () async {
      expect(await out('donne "x 5 ecris :x - 1'), '4\n');
      expect(await out('donne "x 5 ecris :x-1'), '4\n');
      expect(await out('donne "x 5 (ecris :x -1)'), '5 -1\n');
      expect(await out('donne "x 5 ecris - :x'), '-5\n');
    });

    test('fonctions', () async {
      expect(await out('ecris modulo -7 3'), '2\n');
      expect(await out('ecris reste -7 3'), '-1\n');
      expect(await out('ecris arrondi 2.6'), '3\n');
      expect(await out('ecris sin 90'), '1\n');
      expect(await out('ecris cos 90'), '0\n');
      expect(await out('ecris puissance 2 10'), '1024\n');
      expect(await out('ecris 0.1 + 0.2'), '0.3\n');
    });

    test('division par zéro', () async {
      expect(await error('ecris 1 / 0'), contains('Division par zéro'));
    });
  });

  group('mots et listes', () {
    test('accès', () async {
      expect(await out('ecris premier [a b c]'), 'a\n');
      expect(await out('ecris dernier "abc'), 'c\n');
      expect(await out('montre saufpremier [1 2 3]'), '[2 3]\n');
      expect(await out('ecris saufdernier "abc'), 'ab\n');
      expect(await out('ecris item 2 [a [b c] d]'), 'b c\n');
      expect(await out('ecris compte "abc'), '3\n');
    });

    test('construction', () async {
      expect(await out('ecris mot "Lo "go'), 'Logo\n');
      expect(await out('montre liste "a [b c]'), '[a [b c]]\n');
      expect(await out('montre phrase "a [b c]'), '[a b c]\n');
      expect(await out('montre metspremier 0 [1 2]'), '[0 1 2]\n');
      expect(await out('montre metsdernier 8 [1 1 2 3 5]'), '[1 1 2 3 5 8]\n');
      expect(await out('montre inverse [1 2 3]'), '[3 2 1]\n');
    });

    test('prédicats', () async {
      expect(await out('ecris membre? "b [a b c]'), 'vrai\n');
      expect(await out('ecris vide? []'), 'vrai\n');
      expect(await out('ecris nombre? "12'), 'vrai\n');
      expect(await out('ecris mot? [a]'), 'faux\n');
      expect(await out('ecris egal? 3 3.0'), 'vrai\n');
      expect(await out('ecris "ABC = "abc'), 'vrai\n');
    });

    test('ecris omet les crochets externes, montre les garde', () async {
      expect(await out('ecris [a [b] c]'), 'a [b] c\n');
      expect(await out('montre [a [b] c]'), '[a [b] c]\n');
    });
  });

  group('procédures', () {
    test('pour … fin avec retourne', () async {
      expect(await out('pour carre :x\n  retourne :x * :x\nfin\necris carre 7'), '49\n');
    });

    test('récursivité', () async {
      const src = '''
pour fact :n
  si :n < 2 [retourne 1]
  retourne :n * fact :n - 1
fin
ecris fact 20
''';
      expect(await out(src), '2432902008176640000\n');
    });

    test('forme sur une seule ligne', () async {
      expect(await out('pour double :x retourne 2 * :x fin\necris double 21'), '42\n');
    });

    test('entrées optionnelles et entrée reste', () async {
      const src = '''
pour f :a [:b 10] [:reste]
  montre (liste :a :b :reste)
fin
f 1
(f 1 2)
(f 1 2 3 4)
''';
      expect(await out(src), '[1 10 []]\n[1 2 []]\n[1 2 [3 4]]\n');
    });

    test('la valeur par défaut peut dépendre des entrées précédentes', () async {
      expect(await out('pour f :a [:b :a * 2]\necris :b\nfin\nf 4'), '8\n');
    });

    test('portée dynamique', () async {
      const src = '''
pour a :x
  b
fin
pour b
  ecris :x
fin
a 42
''';
      expect(await out(src), '42\n');
    });

    test('variables locales et globales', () async {
      const src = '''
donne "x 1
pour f
  locale "x
  donne "x 2
  ecris :x
fin
f
ecris :x
pour g
  donne "x 3
fin
g
ecris :x
''';
      expect(await out(src), '2\n1\n3\n');
    });

    test('stop termine la procédure', () async {
      expect(await out('pour f :n\nsi :n = 0 [stop]\necris :n\nf :n - 1\nfin\nf 3'), '3\n2\n1\n');
    });

    test('une procédure peut être appelée avant sa définition dans une autre procédure', () async {
      expect(await out('pour a\nb\nfin\npour b\necris "ok\nfin\na'), 'ok\n');
    });

    test('redéfinir une procédure change son nombre d\'entrées', () async {
      const src = '''
pour f :a
  ecris :a
fin
pour g
  f 1
fin
g
pour f :a :b
  ecris :a + :b
fin
pour g
  f 1 2
fin
g
''';
      expect(await out(src), '1\n3\n');
    });

    test('detaille et procedures', () async {
      final (host, ip) = await run('pour f :x\n  av :x\nfin\ndetaille "f\nmontre procedures');
      expect(host.output.toString(), 'pour f :x\n  av :x\nfin\n[f]\n');
      expect(ip.procedures.containsKey('f'), isTrue);
    });
  });

  group('contrôle', () {
    test('repete et compteur', () async {
      expect(await out('repete 3 [tape compteur]'), '123');
      expect(await out('repete 2 [repete 2 [tape compteur] tape "|-|]'), '12-12-');
    });

    test('repetepour', () async {
      expect(await out('repetepour [i 1 5] [tape :i]'), '12345');
      expect(await out('repetepour [i 10 0 -5] [tape :i tape "| |]'), '10 5 0 ');
      expect(await out('donne "n 3 repetepour [i 1 :n * 2 2] [tape :i]'), '135');
    });

    test('tantque et jusqua', () async {
      expect(await out('donne "i 0 tantque [:i < 3] [donne "i :i + 1 tape :i]'), '123');
      expect(await out('donne "i 0 jusqua [:i = 3] [donne "i :i + 1 tape :i]'), '123');
    });

    test('si, (si … sinon) et sisinon', () async {
      expect(await out('si 1 < 2 [ecris "oui]'), 'oui\n');
      expect(await out('(si 1 > 2 [ecris "oui] [ecris "non])'), 'non\n');
      expect(await out('ecris sisinon 1 > 2 ["oui] ["non]'), 'non\n');
    });

    test('exec et invoque', () async {
      expect(await out('exec [ecris 1 + 1]'), '2\n');
      expect(await out('ecris exec [3 * 3]'), '9\n');
      expect(await out('ecris (invoque "somme 1 2 3)'), '6\n');
      expect(await out('ecris applique "produit [2 5]'), '10\n');
    });

    test('et, ou, non', () async {
      expect(await out('ecris et "vrai "faux'), 'faux\n');
      expect(await out('ecris (ou "faux "faux "vrai)'), 'vrai\n');
      expect(await out('ecris non 1 = 2'), 'vrai\n');
    });

    test('lis et lismot', () async {
      final (host, _) = await run('montre lis ecris lismot', inputs: ['a b c', 'bonjour']);
      expect(host.output.toString(), '[a b c]\nbonjour\n');
    });

    test('récursion profonde non terminale', () async {
      const src = '''
pour somme_jusqua :n
  si :n = 0 [retourne 0]
  retourne :n + somme_jusqua :n - 1
fin
ecris somme_jusqua 50000
''';
      expect(await out(src), '1250025000\n');
    });

    test('appel terminal : boucle infinie par récursivité', () async {
      final host = RecordingHost();
      final ip = Interpreter(host);
      final f = ip.run('pour tourne\n  av 1 td 1\n  tourne\nfin\ntourne');
      Timer(const Duration(milliseconds: 300), ip.halt);
      await expectLater(f, throwsA(isA<LogoHalt>()));
      expect(host.events.length, greaterThan(100000 ~/ 50));
    });

    test('appel terminal via retourne', () async {
      const src = '''
pour compte_a :n :acc
  si :n = 0 [retourne :acc]
  retourne compte_a :n - 1 :acc + 1
fin
ecris compte_a 200000 0
''';
      expect(await out(src), '200000\n');
    });

    test('appel terminal dont la valeur n\'est pas utilisée', () async {
      expect(await error('pour g\nretourne 5\nfin\npour f\ng\nfin\nf'), contains('Je ne sais que faire de « 5 »'));
    });

    test('arrêt depuis l\'extérieur', () async {
      final host = RecordingHost();
      final ip = Interpreter(host);
      final f = ip.run('tantque ["vrai] [av 1 td 1]');
      Timer(const Duration(milliseconds: 50), ip.halt);
      await expectLater(f, throwsA(isA<LogoHalt>()));
      expect(host.events, isNotEmpty);
    });

    test('pause et reprise', () async {
      final host = RecordingHost();
      final ip = Interpreter(host);
      final f = ip.run('repete 200000 [donne "x 1]');
      ip.pause();
      await Future<void>.delayed(const Duration(milliseconds: 30));
      expect(ip.isPaused, isTrue);
      ip.resume();
      await f;
    });
  });

  group('tortue', () {
    test('déplacements', () async {
      final (_, ip) = await run('av 100 td 90 av 50');
      expect(ip.turtle.x, 50);
      expect(ip.turtle.y, 100);
      expect(ip.turtle.heading, 90);
    });

    test('un carré revient au point de départ', () async {
      final (host, ip) = await run('repete 4 [av 100 td 90]');
      expect(ip.turtle.x, 0);
      expect(ip.turtle.y, 0);
      expect(ip.turtle.heading, 0);
      expect(host.drawnSegments, 4);
    });

    test('pos, cap, vers, distance', () async {
      expect(await out('fixepos [30 40] montre pos ecris distance [0 0]'), '[30 40]\n50\n');
      expect(await out('ecris vers [10 0]'), '90\n');
      expect(await out('tg 90 ecris cap'), '270\n');
    });

    test('levecrayon ne trace pas', () async {
      final (host, _) = await run('lc av 10 bc av 10');
      expect(host.drawnSegments, 1);
    });

    test('couleurs', () async {
      expect(await out('fcc 4 ecris cc'), '4\n');
      expect(await out('fcc "rouge ecris cc'), '1\n');
      expect(await out('fcc [1 2 3] montre cc'), '[1 2 3]\n');
    });

    test('videecran efface et recentre', () async {
      final (host, ip) = await run('av 50 ve av 10');
      expect(host.drawnSegments, 1);
      expect(ip.turtle.y, 10);
    });
  });

  group('erreurs', () {
    test('procédure inconnue', () async {
      expect(await error('toto 3'), 'Je ne sais pas faire « toto » — ligne 1');
    });

    test('arguments manquants', () async {
      expect(await error('av'), contains('Pas assez d\'arguments pour « av »'));
    });

    test('valeur inutilisée', () async {
      expect(await error('ecris 1\n3 + 4'), 'Je ne sais que faire de « 7 » — ligne 2');
    });

    test('variable sans valeur', () async {
      expect(await error('ecris :x'), contains('« x » n\'a pas de valeur'));
    });

    test('mauvais type', () async {
      expect(await error('av "abc'), contains('« av » n\'aime pas « abc »'));
    });

    test('erreur dans une procédure', () async {
      final msg = await error('pour f\n  av "x\nfin\nf');
      expect(msg, contains('(dans « f »)'));
      expect(msg, contains('ligne 2'));
    });

    test('fin manquante', () async {
      expect(await error('pour f\nav 10'), contains('Il manque « fin »'));
    });

    test('crochets', () async {
      expect(await error('repete 4 [av 10'), contains('« ] » manquant'));
      expect(await error('av 10]'), contains('« ] » inattendu'));
    });

    test('impossible de redéfinir une primitive', () async {
      expect(await error('pour av :x\nfin'), contains('est une primitive'));
    });

    test('récursion infinie non terminale', () async {
      expect(await error('pour f\nf\nav 1\nfin\nf'), contains('récursion infinie'));
    });
  });

  group('exemples', () {
    final dir = Directory('../../examples');
    for (final f in dir.existsSync() ? (dir.listSync().whereType<File>().toList()..sort((a, b) => a.path.compareTo(b.path))) : <File>[]) {
      test(f.uri.pathSegments.last, () async {
        final (host, _) = await run(f.readAsStringSync());
        expect(host.toSvg(), startsWith('<svg'));
      });
    }

    test('n°1 du rapport : 36 × 36 × 2 segments', () async {
      final (host, _) = await run(File('../../examples/01-cercles-decales.logo').readAsStringSync());
      expect(host.drawnSegments, 2592);
    });
  });
}
