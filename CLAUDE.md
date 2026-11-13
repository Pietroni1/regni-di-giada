# Regni di Giada — note per Claude Code

MMORPG originale in stile orientale (giapponese/coreano), giocabile nel browser, per l'autore e i suoi amici.
Gameplay alla WoW, grind coreano, dungeon a tempo (Prove del Sigillo), cavalcature, obelischi.
**Tutto deve restare originale**: niente nomi, asset, mappe o grafica di giochi esistenti (Metin2, WoW, ecc.).

## Lingua e preferenze dell'autore
- Si scrive in **italiano** (risposte, testi del gioco, commenti nel codice, messaggi di commit).
- L'autore dà comandi brevi ("procedi", "vai") e vuole **immagini e video** dei risultati.
- Obiettivo grafico: qualità simile a un modello "orco" stilizzato e dipinto a mano (alta definizione, non low poly).
- Non vuole i fili d'erba 3D sul terreno.
- Usa Windows: in PowerShell `npm.cmd install` / `npm.cmd start` se gli script sono bloccati.

## Avvio
```
npm install
npm start          # http://localhost:3000 — account GM: "admin" (server/config.json)
```
Comandi GM in chat: `/level 99`, `/item id quantità potenziamento rarità`, `/spawn tipo n`, `/tp x z`, `/destriero 20`, `/sigillo 15`, `/aiuto`.

## Struttura
- `server/` — Node.js (HTTP + WebSocket), logica autoritativa (`world.js`), database JSON (`db.js`).
- `shared/` — dati (`data.js`: classi, abilità, oggetti, mostri, dungeon) e geografia (`world.js`: terreno, villaggi, strade).
- `client/js/`
  - `main.js` avvio e caricamento asset; `game.js` gioco ed eventi di rete; `ui.js` interfaccia.
  - `world3d.js` mondo (cielo, luci, edifici con motivi dipinti, dissolvenza davanti alla camera).
  - `terrain.js` terreno dipinto (texture procedurali miscelate nello shader).
  - `nature.js` alberi/rocce da `natura.glb`; `animals.js` animali da `animali.glb`.
  - `skinned.js` personaggi con scheletro da `personaggio.glb` + modelli esterni (`assets/modelli/indice.json`).
  - `models.js` costruzione dei modelli per giocatori, PNG, mostri, armi, cavalli.
  - `vfx.js` effetti delle abilità; `gear-fx.js` effetti di armi/armature; `post.js` bloom e qualità.
- `tools/blender/` — script Python per Blender che generano i `.glb` in `client/assets/`.

## Pipeline Blender
```
blender -b --factory-startup --python tools/blender/personaggio.py -- client/assets/personaggio.glb
blender -b --factory-startup --python tools/blender/animali.py -- client/assets/animali.glb
blender -b --factory-startup --python tools/blender/natura.py -- client/assets/natura.glb
blender -b --factory-startup --python tools/blender/importa_modello.py -- modelli/X.glb client/assets/modelli/X.glb --altezza 2.35
```
- `forme.py` strumenti comuni; `umanoide_anim.py` le 17 animazioni dell'umanoide (riusabili su altre armature).
- Convenzioni: Blender Z in alto, personaggio rivolto verso -Y; ossa umanoide `hips, spine, chest, neck, head,
  shoulder/upper_arm/forearm/hand_L/R, thigh/shin/foot_L/R`; animali con 19 ossa e azioni `specie:azione`.
- Il glTF capovolge la v delle UV: per dati nelle UV si scrive `1 - v`.
- La seconda UV (`Part`) indica la parte del modello (maschera di visibilità), la terza (`Ombra`) l'ombreggiatura dipinta.
- Nel container cloud la cottura (bake) di Cycles non funzionava (build di Ubuntu): con Blender ufficiale e GPU dovrebbe.

## Modelli ad alta definizione (in corso)
Piano concordato: l'autore genera 8 personaggi (4 uomini, 4 donne) con un servizio da immagine a 3D, li rigga su
**Mixamo** e li carica in `modelli/mixamo/` (personaggi `With Skin` in T-pose; animazioni una volta sola `Without Skin`,
30 fps, `In Place` per camminata/corsa) con nomi: fermo, camminata, corsa, spada_1..3, pugnali, pugni, calcio, arco,
magia, colpito, morte, sella.
Da fare: script di importazione Mixamo (FBX → glb compresso, ossa `mixamorig:*`, armi su `RightHand/LeftHand`,
animazioni mappate sugli stati del gioco, parte alta = Spine..Hands per attacchi in corsa), compressione (meshopt/KTX2),
livelli di dettaglio, assegnazione in `client/assets/modelli/indice.json`, varianti (colori, proporzioni, accessori).

## Altri passi grafici in sospeso
- Luce da HDRI, occlusione ambientale (GTAO), ombre più morbide, correzione colore, normal map.
- Edifici più dettagliati (modelli importati o Blender), texture del mondo dipinte da strumenti AI.

## Verifiche
- Il gioco si prova nel browser; per immagini automatiche si usava Playwright (Chromium) contro un server su un'altra porta
  (`PORT=3999 DB_FILE=... node server/index.js`). Su un PC con GPU il rendering è molto più veloce che nel cloud.
- Prima di consegnare: nessun errore in console, prova con un personaggio in gioco, commit e push su `main`.
