# Personaggi base «da eroe» (modelli di terzi, pubblico dominio)

Corpi, capigliature e animazioni in questa cartella sono di **Quaternius** (https://quaternius.com), pubblicati con
licenza **CC0 1.0** (pubblico dominio: si possono usare, modificare e distribuire senza vincoli):

- `corpi/` — *Universal Base Characters*, modelli «Superhero» uomo e donna (glTF, texture dipinte a mano);
- `capelli/` — le capigliature dello stesso pacchetto, già legate all'osso della testa;
- `animazioni/` — *Universal Animation Library* 1 e 2 (versione Standard, senza spostamento della radice).

L'autore del gioco li ha scelti come base al posto dei corpi generati da codice. Non sono presi da altri giochi.
Se vuoi sostenere chi li ha fatti: https://www.patreon.com/quaternius

## Portarli nel gioco
```
blender -b --factory-startup --python tools/blender/importa_eroi.py -- modelli/eroi client/assets/modelli
npm run godot:dati
```
Lo strumento rinomina le ossa con i nomi del gioco, sceglie le animazioni (tabella `ANIMAZIONI` nel file), ricostruisce
vesti, armature, elmi e calzari attorno al corpo nuovo e scrive `base_uomo.glb`, `base_donna.glb` ed `eroe_anim.glb`.
