# Corpi base dei personaggi

I due corpi dei giocatori (`base_uomo`, `base_donna`) nascono da questi file `.json`: sono il «disegno» del personaggio.
La mesh e le forme vengono da **MakeHuman** (mesh base, forme e pesi sono CC0: si possono usare liberamente nel gioco);
lo scheletro è quello delle animazioni del gioco (`modelli/scheletri/`).

## Rifare un corpo dopo aver cambiato i parametri
Serve Blender 4.2 o successivo e, una volta sola, i dati di MakeHuman:

```
git clone --depth 1 --filter=blob:none --sparse https://github.com/makehumancommunity/makehuman
cd makehuman
git sparse-checkout set makehuman/data/targets makehuman/data/rigs makehuman/data/3dobjs
```

Poi, dalla cartella del progetto (PowerShell; cambia i percorsi di Blender e di MakeHuman):

```
$b = "C:\Program Files\Blender Foundation\Blender 5.3\blender.exe"
& $b -b --factory-startup --python tools/blender/corpo_base.py -- C:\makehuman\makehuman\data modelli/scheletri/manichino_uomo.fbx modelli/corpi/base_uomo.json modelli/mixamo/base_uomo.blend
& $b -b --factory-startup --python tools/blender/importa_mixamo.py -- modelli/mixamo client/assets/modelli --solo base_uomo
npm.cmd run godot:dati
```

Per la donna: `manichino_donna.fbx`, `base_donna.json`, `base_donna.blend`, `--solo base_donna`.
Dopo, apri una volta il progetto `godot/` nell'editor di Godot (reimporta i modelli).

## I parametri
| Voce | Valori | Cosa cambia |
|---|---|---|
| `sesso` | `uomo` / `donna` | corporatura di partenza |
| `muscoli`, `peso` | da 0 a 1 (0,5 = medio) | massa muscolare e grasso |
| `altezza`, `proporzioni` | da 0 a 1 | statura (il gioco riporta poi tutti alla stessa altezza) e proporzioni «ideali» |
| `seno`, `tonicita` | da 0 a 1 (solo donna) | misura e tonicità del seno |
| `etnia` | `asian`, `caucasian`, `african` (pesi, somma 1) | lineamenti di base |
| `forme` | nome della forma → peso (di solito da 0 a 1) | dettagli: naso, occhi, mento, bocca, spalle, mani... |

I nomi delle forme sono i file dentro `makehuman/data/targets/` senza `.target`, per esempio `nose/nose-hump-incr`,
`chin/chin-height-decr`, `torso/torso-vshape-incr`. Con `lr-` al posto di `l-` / `r-` la forma vale per i due lati
(`armslegs/lr-hand-scale-incr`). Chi preferisce i cursori può provare le forme nel programma MakeHuman (gratuito) e
riportare qui i valori che gli piacciono.

## Cosa viene creato da solo
- occhi, labbra e sopracciglia: dipinti dallo shader a partire da una seconda UV (`Viso`);
- chioma (`capo_capelli`): ricavata dal cuoio capelluto del modello, così segue la testa;
- vesti, armature, elmi e calzari: gli stessi di prima, ricostruiti attorno al corpo nuovo da `importa_mixamo.py`.
