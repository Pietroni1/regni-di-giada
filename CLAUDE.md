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
Fatto: `tools/blender/importa_mixamo.py` converte la cartella intera (istruzioni in `modelli/mixamo/LEGGIMI.md`):
- le ossa `mixamorig:*` prendono i nomi del gioco (`hips`, `spine`, `spine_1`, `chest`, `hand_R`, dita `hand_L_index1`...),
  così armi, cappelli e divisione parte alta/bassa funzionano senza casi speciali nel client;
- animazioni in un solo `mixamo_anim.glb` (tracce NLA), personaggi senza animazioni in `NOME.glb` (Draco, WebP);
- `skinned.js` (`retarget`, `withAliases`) applica le animazioni condivise: solo rotazioni + bacino riscalato, camminata e
  corsa sul posto, nomi mancanti sostituiti, attacchi accelerati a ~0,8 s (`quickAttacks`).
Le 14 animazioni sono già scaricate in `modelli/mixamo/*.fbx` e convertite in `client/assets/modelli/mixamo_anim.glb`.
Provato in gioco con il personaggio predefinito di Mixamo (fermo, corsa, spada: bene; non lasciato nel progetto).
Da verificare con gli 8 personaggi veri: pose a riposo diverse, posa `sella` sul cavallo (è una seduta su sedia),
orientamento della spada da fermo, `morte` che arretra di un paio di metri.
Nel browser integrato i download restano `.tmp` in Download: sono FBX completi, basta rinominarli.
Da fare: assegnazione in `client/assets/modelli/indice.json` (manca la scelta uomo/donna per classe), KTX2,
livelli di dettaglio, varianti (colori, proporzioni, accessori).

## Aspetto dall'equipaggiamento (prototipo)
Obiettivo dell'autore: aspetto alla WoW, cioè corpo base + capi separati che cambiano con l'equipaggiamento.
- I personaggi `base_*.fbx` in `modelli/mixamo/` sono corpi base: `importa_mixamo.py` (`crea_capi`) ricava dal corpo dei
  gusci già pesati sulle ossa (`capo_pantaloni`, `capo_veste`, `capo_stivali`, `capo_bracciali`, `capo_armatura`).
- `tools/blender/armature.py` costruisce le armature per grado (tabella `GRADI`: tunica, lamellare, giada, nubi) in stile
  lamellare orientale: corazza a file di piastre, spallacci a pannello con calotta, scarselle, bracciali, schinieri,
  fascia, collare, medaglione, aureola. Tre oggetti per grado: `capo_<grado>__piastre|bordo|stoffa`.
  Per rifare un solo corpo senza le animazioni: `--solo base_uomo`.
  Nello stesso file: `ELMI` (cappello di paglia, elmo di bronzo, cornuto, del drago: calotta, paranuca a lamelle,
  visiera, corna, cresta) e `CALZARI` (sandali, stivali di cuoio, del vento, di nuvola: gambale, anello, alette).
  Elmi e calzari si chiamano come l'id dell'oggetto (`capo_elmo_drago__piastre`), così `wear[info.h] = true` basta.
- `skinned.js` accende le mesh `capo_<capo>[__<parte>]` presenti in `o.wear` (valore: colore, `true` o `{ parte: colore }`);
  `buildPlayerModel` (`models.js`) decide `wear`: veste e pantaloni dai colori della classe, armatura dal grado del pezzo
  `body` (fascia nel colore del regno), stivali dal pezzo `feet` (il server ora manda anche `f` nelle info del giocatore).
- In `indice.json` una classe può avere un elenco di modelli (`["base_uomo", "base_donna"]`): per ora sceglie in base
  al nome del personaggio. **Da fare**: scelta uomo/donna alla creazione, salvata dal server.
- `base_uomo` / `base_donna` sono i manichini Y Bot / X Bot di Mixamo: **provvisori**, non originali e non nello stile
  del gioco; vanno sostituiti con due corpi base originali (stesso nome di file, stesso scheletro).
- Da fare: capelli e volti, vesti delle classi con forma propria (hakama, maniche larghe) al posto dei gusci aderenti,
  nascondere il corpo sotto i capi, PNG. Dopo: l'autore vuole lavorare sul sistema di combattimento.
- Proporzioni: `"spalle": 1.22` nella voce del modello in `indice.json` allontana le braccia dal busto (`skinned.js`).
- In corsa `SkinAnim.straightFeet` raddrizza i piedi (la corsa scelta li ruota verso l'esterno).
- L'autore vuole animazioni ed effetti "epici/possenti": armi +15 con alone, cerchio di rune, spirali e scariche
  (`gear-fx.js`, livello `legend`).
- Per tornare ai personaggi di prima: svuotare `"classi"` in `client/assets/modelli/indice.json`.
- Server di prova per il browser integrato: `.claude/launch.json` (porta 3999, database in `%TEMP%`).

## Sistema di combattimento (in corso)
Linea voluta dall'autore: generare risorsa in modo dinamico e scaricarla in tecniche epiche, quasi incantesimi; gioco
dinamico e divertente, difficoltà delle classi progressiva. **Niente schivata per ora** (l'ha esclusa lui).
- Fase 1 fatta: **Slancio** (`SLANCIO` in `shared/data.js`; `gainSlancio`/`giveRes` in `server/world.js`): ogni colpo a
  segno dà una tacca (max 5) che aumenta risorsa generata, rapidità e rigenerazione; cala se smetti di colpire.
  `BONUS_RISORSA`: risorsa extra per più bersagli colpiti, critici e uccisioni. Vale per tutte le classi.
  Client: tacche sotto la barra della risorsa (`ui.js`, `me.sl`), fermo-immagine e scossa sui colpi pesanti (`game.js`, `hitStop`).
- Fase 2 scritta: **Tecnica Suprema** (`SUPREMA`, `supremaOf` e le 4 tecniche `sup: true` in `shared/data.js`): barra
  `p.sup` che si riempie spendendo risorsa e punti, dal livello 15; tasto V o clic sulla barra; ondate (`waves`,
  `waveGap`) gestite in `tickPlayer`; effetti in `vfx.js`, rallentatore e lampo in `game.js`.
  Verificata dai numeri del server solo sulla Lama (4 ondate, barra azzerata, secondo lancio rifiutato).
  **Da verificare**: effetti a vista di tutte e 4, e Ombra/Monaco/Mistico in gioco (personaggi di prova Ombrina,
  Monachino, Mistichino già creati sull'account `admin` del database di prova).
- **Richiesta dell'autore ancora da fare**: ogni classe con 2 tecniche che accumulano risorsa e 4 che la spendono, di
  natura diversa (bersaglio singolo e ad area), 2 di media potenza e 2 potenti, col costo che cresce con la potenza.
- Da fare dopo: **Postura** di élite e boss, taratura per classe e curva di sblocco per livello.

## Altri passi grafici in sospeso
- Luce da HDRI, occlusione ambientale (GTAO), ombre più morbide, correzione colore, normal map.
- Edifici più dettagliati (modelli importati o Blender), texture del mondo dipinte da strumenti AI.

## Verifiche
- Il gioco si prova nel browser; per immagini automatiche si usava Playwright (Chromium) contro un server su un'altra porta
  (`PORT=3999 DB_FILE=... node server/index.js`). Su un PC con GPU il rendering è molto più veloce che nel cloud.
- Prima di consegnare: nessun errore in console, prova con un personaggio in gioco, commit e push su `main`.
