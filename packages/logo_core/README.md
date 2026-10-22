# logo_core

Interpréteur Logo francophone en Dart pur, sans dépendance à Flutter.

- `Reader` lit le texte en lignes logiques (mots et listes) ;
- `Parser` construit l'arbre syntaxique en tenant compte du nombre d'entrées de chaque procédure ;
- `Interpreter` évalue de façon asynchrone et coopérative (stop, pause, animation), avec portée dynamique et optimisation des appels terminaux ;
- `RecordingHost` exécute sans interface et exporte les dessins en SVG.

```sh
dart run bin/logo.dart ../../examples/02-courbe-c.logo -o courbe.svg
dart test
```
