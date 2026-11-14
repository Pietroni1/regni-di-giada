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
Comandi GM in chat: `/level 99`, `/item id quantità potenziamento rarità`, `/spawn tipo n [raggio]`, `/tp x z`, `/destriero 20`, `/sigillo 15`, `/risorsa`, `/punti`, `/suprema`, `/aiuto`.

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
- `tools/sim/` — simulazione del combattimento senza browser (`npm run sim`, vedi «Sistema di combattimento»).
- `godot/` — client Godot 4.4 (vedi «Client Godot»); `tools/godot/` — esportazione dei dati per Godot.

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
  al sesso scelto alla creazione (salvato dal server).
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
- Fase 3 fatta: **kit «2 accumuli + 4 scarichi»** per ogni Via (campo `ruolo` in `SKILLS`: `accumulo`, `medio`, `potente`).
  Di base: 2 accumuli (livello 1, gratuiti, generano risorsa/punti) e lo scarico medio singolo (livello 3). Dalla Via: scarico
  medio ad area (5), supporto (7), scarico potente singolo (9), scarico potente ad area (12), supporto (15), Suprema (15).
  Costi: medio 30-35, potente 45-60 (Mana 4-5% e 10-12%); per Ombra, Monaco e Mistico i potenti consumano anche tutti i punti.
  Energia 5,5/s e Chi 7/s: senza accumuli non si regge il ritmo. `DATA_VERSION = 4` azzera abilità e barra rapida.
  Mistico: accumuli con tempo di lancio, scarichi istantanei; la Benedizione ha cure al posto dei danni (`spendBonus`).
  Motore: i `dot` valgono anche per le tecniche ad area, `waves` anche fuori dalle Supreme, passivo `chainHeal` (Loto).
  Client: ruolo nel tooltip e nella finestra Abilità, tacca colorata sotto i tasti della barra (verde/oro/rosso).
- **Postura** di élite e boss: fatta (`shared/postura.js`, `colpisciPostura`/`tickPostura` nel server, barre nel client).
- **Simulazione senza browser**: `npm run sim` (`tools/sim/simula.mjs`). Avvia da sé un server di prova, crea un personaggio
  per Via (livello, arma, punti statistica e abilità), lo porta davanti ai fantocci e gioca una rotazione sensata (tabella
  `ROTAZIONI` nel file); stampa danni al secondo, quote per ruolo, danno per uso e per punto di risorsa degli scarichi,
  risorsa sprecata, tempo della barra Suprema, Squilibri e il confronto con gli obiettivi di taratura.
  Opzioni: `--livello 30 --secondi 60 --vie fulmine,arco --bersagli 1|5 --ripeti 2 --dettagli --json file`;
  `--velocita 4` accelera l'orologio del server (per tarare in fretta; i numeri definitivi a velocità 1).
  Dopo ogni ritocco ai numeri di `shared/data.js`: `npm run sim -- --velocita 4`, anche con `--bersagli 5` e `--livello 15`.
  `/spawn tipo n [raggio]` ha un raggio facoltativo (serve allo strumento per i gruppi stretti).
- **Taratura fatta con lo strumento** (solo numeri: moltiplicatori, costi, `RESOURCES`, `SUPREMA`, `BONUS_RISORSA`).
  Obiettivi: Vie da danno entro ±10% (±15% su 5 bersagli), difensore e guaritore al 60-75%, scarico potente più forte del
  medio per uso ma meno per punto di risorsa, accumuli al 20-35% dei danni, barra Suprema in 45-60 s, Suprema sotto il 20%.
  Risultato (danni al secondo, 60 s, media di 2 prove a velocità reale; fra parentesi i secondi della barra Suprema al 30):

  | Via | liv. 30, 1 bersaglio | liv. 30, 5 bersagli | liv. 15, 1 bersaglio | liv. 15, 5 bersagli |
  |---|---|---|---|---|
  | fulmine | 987 (54 s) | 2267 (46 s) | 454 | 997 |
  | montagna (difensore) | 684 (54 s) | 1599 (48 s) | 316 | 710 |
  | pugnali | 1103 (54 s) | 2211 (46 s) | 442 | 945 |
  | arco | 1039 (51 s) | 2304 (45 s) | 421 | 933 |
  | ferro | 1010 (50 s) | 2273 (45 s) | 459 | 1033 |
  | loto | 973 (53 s) | 2302 (47 s) | 446 | 1034 |
  | tempesta | 1034 (53 s) | 2122 (45 s) | 485 | 979 |
  | benedizione (guaritore) | 664 (57 s) | 1012 (57 s) | 292 | 460 |

  Prima della taratura, con lo stesso bot: da 789 (loto) a 1266 (pugnali) su un bersaglio, da 1557 a 3170 su cinque.
  Come gioca il bot: 2 punti statistica su 3 al valore primario (la Montagna 2 su 3 in vitalità, da difensore), di fronte
  al bersaglio, scarico potente a punti pieni, scarico medio con la risorsa che avanza; contro un gruppo il Monaco usa
  Calcio della Gru + scarico medio ad area (la sequenza rende meno); il guaritore fa danni tenendo su di sé Loto e Scudo.
  **Fuori obiettivo, da sapere**: accumuli dell'Arco al 17% (la Freccia Inchiodante, che pure dà punti, conta come supporto: con lei 25%) e
  dell'Ombra al 10% su 5 bersagli (i suoi accumuli colpiscono un nemico solo); Benedizione al 45% su 5 bersagli (non ha
  scarichi ad area che fanno danni); in prove lunghe (180 s) il Mistico cala del 5-10% perché il Mana si consuma.
  Gli attacchi base pesano molto (dal 13% del Mistico al 39% dei Pugnali): per questo gli scarichi dei Pugnali sono bassi.
- Due difetti del motore corretti durante la taratura: l'effetto «prossimo accumulo istantaneo» (Tempesta Imminente) veniva
  consumato dal lancio già in corso; le Cariche spese da Scudo di Giada e Pioggia di Petali non riempivano la barra Suprema.
- Da fare: prova a vista giocando (soprattutto cure e difensore: lo strumento misura solo i danni), effetti da ricontrollare
  su PC con GPU. La Postura (`shared/postura.js`) non è stata tarata: il Mistico squilibra il fantoccio 2-3 volte al minuto,
  le altre classi 5.

## Client Godot (in corso — direzione scelta dall'autore)
L'autore trova il client nel browser pesante e poco maneggevole: si passa a **Godot 4.4** (`godot/`). Il server Node,
`shared/` e la simulazione restano; il client nel browser resta com'è finché quello Godot non lo raggiunge.
- Avvio e struttura: `godot/LEGGIMI.md`. Dati per Godot: `npm run godot:dati` (`tools/godot/esporta.mjs`) scrive
  `godot/dati/gioco.json` (tabelle di `shared/data.js` + geografia, ostacoli, vegetazione), `godot/dati/terreno.bin`
  (altezze a 2 m e pesi dei materiali a 1 m, calcolati con `heightAt`) e copia i `.glb` in `godot/modelli/` togliendo
  Draco (`togli_draco.mjs`, usa il decodificatore di `node_modules/three`). Va rilanciato quando cambiano dati o modelli.
- Fatto: accesso e scelta/creazione del personaggio, terreno dipinto (shader procedurali), acqua, vegetazione da
  `natura.glb` (MultiMesh), villaggi costruiti da codice (`edifici.gd`: tetti concavi a coppi, pagoda, mura, porte),
  giocatori/PNG con corpo base + capi + armi + animazioni Mixamo, animali da `animali.glb`, movimento con gli stessi
  urti del server, visuale, bersagli, attacco automatico, barra rapida con ricariche, Slancio/punti/Suprema, chat con
  comandi GM, targhette e numeri di danno, effetti delle tecniche per tipo `fx` (`effetti.gd`); finestre (`finestre.gd`):
  Inventario (I), Personaggio (C) con punti statistica, Abilità (K) con scelta della Via e assegnazione alla barra, negozio,
  fabbro, dialoghi; minimappa; visuale che si accorcia davanti agli edifici; albero di animazione per gli umani
  (`_crea_albero` in `personaggio.gd`: il colpo prende solo la parte alta del corpo se ci si muove).
- Renderer predefinito: **Compatibilità** (è l'unico verificabile nel container, via `xvfb-run` + `--rendering-driver opengl3`;
  Forward+ richiede Vulkan). Con Forward+ la luce va riguardata a vista.
- Prove automatiche: `godot --path godot -- --server=localhost:3999 --auto=utente:password:Personaggio --foto=cartella
  "--comandi=/level 30;tecnica lama_tuono;attendi 0.1;foto nome"` (copione in `principale.gd`). Nel container il rendering
  è ~1 fps: usare `--fixed-fps 30` (il tempo di gioco avanza di 1/30 a fotogramma, così gli effetti si fotografano) e
  `--write-movie file.avi` per i video. Verificato a vista così: villaggio, Lama del Tuono e Tempesta di Lame sul fantoccio, lupi fuori dalle mura.
- Fatto anche: **Prove del Sigillo** (`cripta.gd` costruisce stanze e muri da `DUNGEON` all'origine data da `dg_start`;
  ambiente buio in `gioco.gd` `_ambiente`; finestra delle Prove e riquadro con tempo/forze/custode), **gruppo** (inviti,
  riquadri dei compagni, «Invita nel gruppo» sul bersaglio), **scuderia e cavalcature** (cavallo da `animali.glb`, posa
  `sella`, barra con le tecniche a cavallo), figure per lanterne, ombre, statue di terracotta, custode e obelischi.
  Il renderer Compatibilità regge poche luci: nella cripta restano accese solo le lanterne entro 42 m (`Cripta._process`).
- Provato a schermo con il copione automatico: Lama (Fulmine), Ombra (Pugnali), Monaco (Ferro), Mistico (Tempesta) con
  scarichi potenti e Suprema; finestre Prove e scuderia; sella; cripta e combattimento lì dentro; invito al gruppo da un
  secondo giocatore (bot) e riquadro del compagno; dialogo del maestro; fabbro. Comandi GM aggiunti per le prove:
  `/punti` (punti al massimo) e `/suprema` (barra piena).
  Provate poi anche le Vie Montagna, Arco, Loto e Benedizione (scarichi potenti e Suprema), la morte con le due rinascite e
  una Prova del Sigillo completata fino al boss (con `/uccidi`): riquadro, esito, sigillo +2 → +5 e ricompense in inventario.
  Non provati: vendita, cure su un alleato vero, trascinamento col mouse (il copione non muove il puntatore), suoni all'ascolto.
  Nota per gli script di prova: avviando il server con `( ... nohup node ... & )` dentro uno script la cui uscita va in una
  pipe, la pipe resta aperta e il comando non termina: aggiungere `> /dev/null 2>&1` alla sottoshell.
- Aggiunti: capelli per stile (`metti_testa` in `personaggio.gd`: crocchia, lunghi, cappuccio, corti), pelo degli animali
  (`pelo.gdshader`: dorso scuro, ventre chiaro, tigrato). Occhi e volti provati e tolti: sul manichino non rendono.
- **Basi di gioco** (richieste dall'autore prima della sua prova): icone degli effetti attivi su di sé (`me.buffs`) e di
  quelli messi sul bersaglio (messaggi `dot`, `stun`, `post` → `gioco.effetti_bersagli`), coda dei comandi (`gioco.coda`,
  mezzo secondo), bottino e tael in chat, colonna di luce sugli oggetti a terra, intenti `parla`/`raccogli` (si cammina fino
  al PNG o all'oggetto), rinascita sul posto o al villaggio, gemme e pergamene (`apply`, `combine`), trascinamento fra
  inventario, equipaggiamento e barra rapida, menu (Esc), impostazioni salvate (`impostazioni.gd`, autoload), aiuto (H),
  suoni generati da codice (`suoni.gd`, autoload: `Suoni.suona(nome, dB, intonazione)`), barra dell'esperienza.
- **Eseguibile**: `godot/export_presets.cfg` (Windows e Linux, `include_filter="dati/*"`). Nel container:
  `godot --headless --path godot --export-release "Windows" ../esporta/RegniDiGiada.exe` (modelli di esportazione in
  `~/.local/share/godot/export_templates/4.4.1.stable/`). L'eseguibile Linux esportato è stato provato ed entra in gioco;
  quello Windows non si può provare qui. `esporta/` è ignorata da git.
- Limiti delle prove nel container: i suoni non si possono ascoltare (nessuna uscita audio); con `--fixed-fps` il tempo
  reale corre ~30 volte più del tempo di gioco, quindi i timer basati sull'orologio (ricariche, icone degli effetti) scadono
  subito nelle foto; a 1 fps reale il movimento è limitato a 0,1 s per fotogramma (`gioco.gd`).
- **Grafica, dopo la prima prova dell'autore** (spada storta, effetti persi, texture povere, piedi storti):
  - `equip.gd`: armi rifatte e **presa calcolata sulla posa a riposo** (`Equip.impugna`: +y = lato del pollice, +z = dita;
    `inclina` in gradi: spada 28, pugnali 20, bastone −78 cioè lungo l'avambraccio); scia dei colpi (`Equip.Scia`).
  - **Effetti per potenziamento** (`Equip.LIVELLI`: +7 gelo, +9 fuoco, +12 tempesta, +15 leggenda): lama accesa,
    particelle, alone, luce, spirali; aura dell'armatura dal +9 o Epica, cerchio di rune al +15 o Leggendaria.
    Il proprio equipaggiamento arriva da `inv.eq` (`wu`, `wr`, `bu`, `br`), quello degli altri dalle info del server.
  - `piedi_dritti.gd` (`SkeletonModifier3D`): toglie ai piedi la rotazione verso l'esterno dopo l'animazione.
  - `effetti.gd` riscritto: mattoni `rune`, `crepe`, `spirale`, `bagliore`, `polvere`, `taglio`; colori resi saturi da
    `vivo()` (i colori pastello sommati diventavano bianchi: tenere basse le intensità additive); `_suprema` ha una regia
    per classe distesa su `waves × waveGap`.
  - Texture da codice in `shader/`: `comune.gdshaderinc` (rumore, celle, `rilievo` da derivate), `intonaco`, `legno`,
    `pietra`, `stoffa` (trama + orlo ricamato nel colore `trim` della classe), `metallo`, `pelle`; rilievo anche su tetti
    e terreno, fiorellini nell'erba.
  Visto a schermo: presa della spada da fermo e in corsa, spada +15 Leggendaria, scia, Lama del Tuono, Tempesta di Lame,
  Giudizio dei Tuoni, edifici e personaggio con le texture nuove. Non visti: le altre tre Supreme con la regia nuova,
  pugnali, arco e bastone in mano, i livelli +7/+9/+12, l'aura dell'armatura da vicino.
- Da fare: corpi base originali con volto (il manichino resta il limite più evidente), edifici veri fatti in Blender,
  modelli per scimmie e banditi, resa con Forward+ da guardare su PC con GPU, suoni veri al posto di quelli sintetici.

## Altri passi grafici in sospeso (client nel browser)
- Fatto: occlusione ambientale (GTAO, solo qualità Alta) e correzione colore finale (`GradeShader`) in `post.js`.
- Da fare: luce da HDRI vera; il bilanciamento `LUCE` va riguardato a vista insieme a GTAO e correzione colore.
- Fatto (`world3d.js`, `terrain.js`): ombra del sole agganciata alla visuale con scatto al texel e scostamenti in
  proporzione al texel (`OMBRA`); bilanciamento sole/cielo/rimbalzo del terreno (`LUCE`, suolo caldo nell'ambiente PMREM);
  rilievo da derivate sullo schermo (altezza nel canale alfa delle texture del terreno, pennellate e coppi degli edifici;
  spento in Bassa: `q.relief ?? q.composer`); nebbia atmosferica all'aperto = ramo `FogExp2` di three riscritto
  (quota + tinta verso il sole), la cripta resta con `Fog` lineare. Sole fisso: l'ambiente si calcola una volta sola.
- Scartati: ombre a cascata (CSM, troppi shader personalizzati da agganciare) e `PCFShadowMap` con raggio (penombra a gradini).
  Da verificare su PC con GPU e in gioco: tremolio del rilievo in movimento, resa a 1080p, cripta vera.
- Edifici più dettagliati (modelli importati o Blender), texture del mondo dipinte da strumenti AI.

## Verifiche
- Il gioco si prova nel browser; per immagini automatiche si usava Playwright (Chromium) contro un server su un'altra porta
  (`PORT=3999 DB_FILE=... node server/index.js`). Su un PC con GPU il rendering è molto più veloce che nel cloud.
- Prima di consegnare: nessun errore in console, prova con un personaggio in gioco, commit e push su `main`.
