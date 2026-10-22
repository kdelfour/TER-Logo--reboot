# Les primitives de TER Logo Reboot

_Fichier généré par `packages/logo_core/tool/gen_doc.dart`._

## Tortue

| Primitive | Synonymes | Description |
|---|---|---|
| `avance` | `av` | avance n — avance de n pas |
| `recule` | `re` | recule n — recule de n pas |
| `tournedroite` | `droite`, `td`, `dr` | td angle — tourne à droite (degrés) |
| `tournegauche` | `gauche`, `tg`, `ga` | tg angle — tourne à gauche (degrés) |
| `fixecap` | `fcap` | fixecap angle — oriente la tortue (0 = vers le haut) |
| `cap` |  | orientation actuelle |
| `fixepos` | `fpos` | fixepos [x y] — déplace la tortue |
| `fixexy` |  | fixexy x y |
| `fixex` |  | fixex x |
| `fixey` |  | fixey y |
| `position` | `pos` | position [x y] |
| `posx` |  | abscisse |
| `posy` |  | ordonnée |
| `vers` |  | vers [x y] — cap à prendre pour viser le point |
| `distance` |  | distance [x y] — distance au point |
| `origine` |  | ramène la tortue au centre, tournée vers le haut |
| `videecran` | `ve` | efface l'écran et ramène la tortue au centre |
| `nettoie` |  | efface les dessins sans bouger la tortue |
| `montretortue` | `mt` | montre la tortue |
| `cachetortue` | `ct` | cache la tortue |
| `visible?` |  | tortue visible ? |
| `cercle` |  | cercle r — cercle de rayon r centré sur la tortue |
| `arc` |  | arc angle r — arc centré sur la tortue, à partir de son cap |
| `point` |  | point [x y] — dessine un point |
| `etiquette` | `etiq` | etiquette "texte — écrit à la position de la tortue |
| `fixetaillepolice` |  | taille du texte des étiquettes |
| `vitesse` |  | vitesse n — de 1 (lent) à 500, 0 = instantané |

## Crayon et couleurs

| Primitive | Synonymes | Description |
|---|---|---|
| `levecrayon` | `lc` | la tortue se déplace sans tracer |
| `baissecrayon` | `bc` | la tortue trace en se déplaçant |
| `baissecrayon?` | `bc?` | crayon baissé ? |
| `gomme` |  | la tortue efface sur son passage |
| `dessine` |  | revient au tracé normal après « gomme » |
| `fixecouleurcrayon` | `fcc` | fcc n, fcc "rouge ou fcc [r v b] |
| `couleurcrayon` | `cc` | couleur du crayon |
| `fixecouleurfond` | `fcfg`, `fcf` | couleur du fond |
| `couleurfond` | `cf` | couleur du fond |
| `fixetaillecrayon` | `ftc`, `fixeepais`, `fepais` | épaisseur du trait |
| `taillecrayon` | `epais` | épaisseur du trait |
| `fixetrait` | `ftrait` | type de trait : 0 plein, 1 tirets, 2 pointillés, 3 tiret-point |
| `trait` |  | type de trait |

## Contrôle

| Primitive | Synonymes | Description |
|---|---|---|
| `repete` |  | repete n [instructions] — répète n fois les instructions |
| `compteur` |  | numéro du tour en cours dans le « repete » le plus proche |
| `repetepour` |  | repetepour [i début fin pas] [instructions] — boucle avec compteur |
| `tantque` |  | tantque [condition] [instructions] |
| `jusqua` |  | jusqua [condition] [instructions] — répète jusqu'à ce que la condition soit vraie |
| `si` |  | si condition [instructions]  ou  (si condition [alors] [sinon]) |
| `sisinon` |  | sisinon condition [si vrai] [si faux] |
| `exec` | `execute` | exec [instructions] — exécute une liste |
| `stop` |  | termine la procédure en cours |
| `retourne` | `rends` | retourne valeur — termine la procédure en renvoyant une valeur |
| `attends` |  | attends n — pause de n soixantièmes de seconde |
| `invoque` |  | (invoque "nom arg1 arg2 …) — appelle une procédure par son nom |
| `applique` |  | applique "nom [arguments] |
| `erreur` |  | erreur "message — déclenche une erreur |

## Variables

| Primitive | Synonymes | Description |
|---|---|---|
| `donne` |  | donne "nom valeur — affecte une variable |
| `locale` |  | locale "nom — déclare une variable locale |
| `donnelocale` |  | donnelocale "nom valeur |
| `chose` |  | chose "nom — valeur de la variable (comme :nom) |
| `nom?` |  | nom? "x — vrai si la variable x a une valeur |

## Procédures

| Primitive | Synonymes | Description |
|---|---|---|
| `detaille` |  | detaille "nom — affiche la définition d'une procédure |
| `procedures` |  | liste des procédures définies |
| `primitive?` |  | primitive? "nom |
| `procedure?` |  | procedure? "nom — vrai si définie avec « pour » |
| `defini?` |  | defini? "nom — primitive ou procédure |

## Calcul

| Primitive | Synonymes | Description |
|---|---|---|
| `somme` |  | somme a b  ou  (somme a b c …) |
| `difference` |  | difference a b — a − b |
| `produit` |  | produit a b  ou  (produit a b c …) |
| `quotient` |  | quotient a b — a ÷ b |
| `reste` |  | reste a b — reste de la division (signe de a) |
| `modulo` |  | modulo a b — reste du signe de b |
| `moins` |  | moins a — opposé de a |
| `abs` |  | abs a — valeur absolue |
| `signe` |  | signe a — −1, 0 ou 1 |
| `arrondi` |  | arrondi a — entier le plus proche |
| `tronque` | `ent` | tronque a — partie entière |
| `racine` |  | racine a — racine carrée |
| `puissance` |  | puissance a b — a à la puissance b |
| `exp` |  | exponentielle |
| `ln` | `log` | logarithme népérien |
| `log10` |  | logarithme décimal |
| `sin` |  | sinus (angle en degrés) |
| `cos` |  | cosinus (angle en degrés) |
| `tan` |  | tangente (angle en degrés) |
| `arcsin` |  | arc sinus, en degrés |
| `arccos` |  | arc cosinus, en degrés |
| `arctan` |  | arc tangente, en degrés |
| `pi` |  | 3.14159… |
| `hasard` |  | hasard n — entier au hasard entre 0 et n−1 |
| `max` |  | le plus grand |
| `min` |  | le plus petit |

## Logique

| Primitive | Synonymes | Description |
|---|---|---|
| `egal?` | `egale?` | egal? a b |
| `inegal?` |  | inegal? a b |
| `pluspetit?` | `plp?` | pluspetit? a b — a < b |
| `plusgrand?` | `plg?` | plusgrand? a b — a > b |
| `pluspetitou?` | `plpo?` | pluspetitou? a b — a ≤ b |
| `plusgrandou?` | `plgo?` | plusgrandou? a b — a ≥ b |
| `et` |  | et a b  ou  (et a b c …) |
| `ou` |  | ou a b  ou  (ou a b c …) |
| `non` |  | non a |

## Mots et listes

| Primitive | Synonymes | Description |
|---|---|---|
| `premier` | `prem` | premier élément d'un mot ou d'une liste |
| `dernier` | `der` | dernier élément |
| `saufpremier` | `sp` | tout sauf le premier élément |
| `saufdernier` | `sd` | tout sauf le dernier élément |
| `item` | `element` | item n liste — n-ième élément (à partir de 1) |
| `compte` |  | nombre d'éléments |
| `mot` |  | mot "a "b — colle des mots |
| `liste` |  | liste a b — liste formée des entrées |
| `phrase` | `ph` | phrase a b — met bout à bout (listes aplaties d'un niveau) |
| `metspremier` | `mp` | metspremier élément liste |
| `metsdernier` | `md` | metsdernier élément liste |
| `inverse` |  | inverse l'ordre des éléments |
| `majuscule` |  | mot en majuscules |
| `minuscule` |  | mot en minuscules |
| `choix` |  | élément pris au hasard |

## Prédicats

| Primitive | Synonymes | Description |
|---|---|---|
| `mot?` |  | vrai si mot |
| `liste?` |  | vrai si liste |
| `nombre?` |  | vrai si nombre |
| `vide?` |  | vrai si mot vide ou liste vide |
| `membre?` |  | membre? élément liste |
| `avant?` | `precede?` | avant? "a "b — ordre alphabétique |

## Entrées / sorties

| Primitive | Synonymes | Description |
|---|---|---|
| `ecris` | `ec` | ecris valeur — affiche dans la console |
| `montre` |  | montre valeur — affiche, listes entre crochets |
| `tape` |  | tape valeur — affiche sans aller à la ligne |
| `lis` | `lisliste` | lis — attend une ligne tapée et la renvoie comme liste |
| `lismot` |  | lismot — attend une ligne tapée et la renvoie comme mot |

