# Personaggi e animazioni Mixamo

Metti qui i file `.fbx` scaricati da Mixamo, poi lancia (PowerShell, dalla cartella del progetto):

```
& "C:\Program Files\Blender Foundation\Blender 5.3\blender.exe" -b --factory-startup --python tools/blender/importa_mixamo.py -- modelli/mixamo client/assets/modelli
```

## Personaggi (8: 4 uomini, 4 donne)
- Scarica in **T-pose**, formato `FBX Binary`, **With Skin**.
- Nome del file libero, senza spazi: diventa il nome del modello (`samurai_uomo.fbx` → `samurai_uomo`).

## Animazioni (una volta sola, valgono per tutti)
- Scarica **Without Skin**, 30 fps; per camminata e corsa spunta **In Place**.
- Il nome del file decide l'animazione:

| File | Uso nel gioco |
|---|---|
| `fermo` | in piedi |
| `camminata`, `corsa` | movimento |
| `sella` | a cavallo |
| `spada_1`, `spada_2`, `spada_3` | colpi di spada |
| `pugnali` (oppure `pugnali_1`, `pugnali_2`) | colpi con i pugnali |
| `pugni`, `calcio` (oppure `pugni_1..3`) | colpi a mani nude |
| `arco` | tiro con l'arco |
| `magia` (e, se vuoi, `bastone`) | incantesimi e colpo di bastone |
| `colpito`, `morte` | reazioni |

Le animazioni che mancano vengono sostituite dalla più simile, quindi si può provare anche con poche.

## Risultato
- `client/assets/modelli/mixamo_anim.glb` — tutte le animazioni, condivise.
- `client/assets/modelli/NOME.glb` — un file per personaggio (alto 2,35, massimo 60.000 triangoli, texture fino a 2048, compressione Draco).
- `client/assets/modelli/indice.json` — i personaggi vengono aggiunti a `modelli`; per usarli scrivi a chi vanno:

```json
"classi": { "lama": "samurai_uomo", "ombra": "ninja_donna" },
"png": { "guardia": "guardia_uomo" }
```

Opzioni: `--altezza 2.35 --triangoli 60000 --texture 2048 --ruota 180 --draco 0`.

## Animazioni già scaricate
Le 14 animazioni sono già in questa cartella (scaricate da Mixamo con il personaggio predefinito) e convertite in
`client/assets/modelli/mixamo_anim.glb`. Per cambiarne una basta sostituire il file `.fbx` e rilanciare lo script.

| File | Animazione Mixamo |
|---|---|
| `fermo` | Orc Idle (Male Orc Standing Idle) |
| `camminata` | Standard Walk, In Place |
| `corsa` | Running (Male Weighted Run), In Place |
| `sella` | Sitting Idle (seduta su sedia: una posa a cavallo non l'ho cercata) |
| `spada_1` | Great Sword Slash (Downward Slash) |
| `spada_2` | Great Sword Slash (Low Slash) |
| `spada_3` | Great Sword Slash (Power Slash) |
| `pugnali` | Double Dagger Stab |
| `pugni` | Punching (Hook Punch With The Rear Hand) |
| `calcio` | Mma Kick (Roundhouse) |
| `arco` | Shooting Arrow |
| `magia` | Standing 2H Magic Area Attack 02 |
| `colpito` | Hit Reaction |
| `morte` | Two Handed Sword Death (Falling Back Death) |

## Corpi base e capi (aspetto dall'equipaggiamento)
I file che cominciano con `base_` (`base_uomo.fbx`, `base_donna.fbx`) sono corpi base: lo script ci costruisce sopra i capi
(pantaloni, veste, stivali) e le quattro armature per grado (`tools/blender/armature.py`), che il gioco accende in base
all'equipaggiamento.
Quelli presenti ora sono i manichini di Mixamo, provvisori: per sostituirli basta mettere qui due corpi originali con
gli stessi nomi e rilanciare lo script.
