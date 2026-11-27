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
Comandi GM in chat: `/level 99`, `/item id quantità potenziamento rarità`, `/spawn tipo n [raggio]`, `/tp x z`, `/destriero 20`, `/sigillo 15`, `/risorsa`, `/punti`, `/suprema`, `/abilita id livello`, `/aiuto`.

## Struttura
- `server/` — Node.js (HTTP + WebSocket), logica autoritativa (`world.js`; moduli installati su World: `mappe.js`, `missioni.js`, `bottino.js`, `altolivello.js`, `prove.js`), database JSON (`db.js`).
- `shared/` — dati (`data.js`: classi, abilità, oggetti, mostri, dungeon; `missioni.js`, `mappe.js`) e geografia (`world.js`: terreno, villaggi, strade).
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
- **Corpi base originali (fatti)**: `base_uomo` / `base_donna` non sono più i manichini di Mixamo. `tools/blender/corpo_base.py`
  li genera dalla mesh e dalle forme di **MakeHuman** (CC0) secondo i parametri in `modelli/corpi/*.json` (sesso, muscoli,
  peso, etnia, forme di dettaglio: istruzioni in `modelli/corpi/LEGGIMI.md`), riporta giunti e pesi di MakeHuman sulle ossa
  di Mixamo, porta gli arti nella posa a T dello scheletro (`modelli/scheletri/manichino_*.fbx`, solo come scheletro) e
  salva `modelli/mixamo/base_*.blend`, che `importa_mixamo.py` tratta come un personaggio (capi e armature come prima).
  Aggiunge la seconda UV `Viso` (pelle: x labbra, y sopracciglia; occhi: coordinate sul bulbo → `occhio.gdshader`),
  la chioma `capo_capelli` dal cuoio capelluto e le misure del cranio (`indice.json` → `testa`), usate da `metti_testa`.
  Nel container: `pip install bpy` (Blender come modulo Python) e i dati di MakeHuman con `git clone --sparse`; dopo aver
  cambiato un `.glb` serve `godot --headless --path godot --import` (senza, Godot usa la copia importata vecchia).
  Visti a schermo nel client Godot: uomo e donna, viso, chioma, vesti, spada e bastone in mano, posa da fermi.
  **Gusto dell'autore** (dopo aver visto la prima versione, orientale e snella: non gli è piaciuta): niente lineamenti
  orientali marcati (al più qualche tratto), fisici forti e muscolosi «da eroe», uomo e donna belli. I parametri attuali
  vanno in quella direzione (etnia 0,8 caucasica / 0,2 asiatica, muscoli al massimo, torso a V, spalle larghe, mascella
  forte; donna atletica a clessidra con `seno` e `tonicita`).
  Schiena e collo vanno allineati allo scheletro (`FIGLIO` in `corpo_base.py`, testa esclusa): con la postura rilassata
  di MakeHuman i personaggi stavano ingobbiti (l'autore l'ha notato subito). Proporzioni «da eroe»: gambe più lunghe,
  testa più piccola. L'autore cita i personaggi di Metin 2 come riferimento di stile (portamento e fisico), non da copiare.
  L'autore ha poi mandato due schermate del guerriero di Metin 2 chiedendo «simile a questo» (la versione realistica
  non gli piaceva per niente): **non si copia quel personaggio**, se ne prende il genere. Fatto: voce `stile` nei
  parametri (`corpo_base.py`: spalle, torace, vita, collo, testa, braccia, avambracci, mani, cosce, polpacci, piedi —
  scalature con i pesi delle ossa), ombre fra i muscoli nel colore dei vertici (`Col`, usato da `pelle.gdshader`), pelle
  abbronzata, `veste` senza maniche, `pantaloni` larghi raccolti sotto il ginocchio, capi nuovi `bracciali` e `gambali`
  (`crea_capi`, con orli lisciati), chioma a ciuffi.
  Da migliorare: attaccatura dei capelli seghettata, pelle uniforme (nessuna texture, muscoli poco leggibili sotto le
  vesti aderenti), scollo della veste seghettato, stili di capelli diversi. Il client nel browser non è stato riprovato
  con i corpi nuovi.
- **Corpi base attuali: modelli di terzi CC0** (decisione dell'autore dopo aver bocciato tutte le versioni generate da
  codice: «trovane di buoni online e usiamo quelli come base»). `modelli/eroi/` contiene i corpi «Superhero» uomo e donna,
  le capigliature e la Universal Animation Library di **Quaternius** (CC0, nota in `modelli/eroi/LEGGIMI.md`; presi da una
  copia su GitHub perché il sito dell'autore non è raggiungibile dal container). `tools/blender/importa_eroi.py` rinomina
  le ossa (stile Unreal → nomi del gioco), sceglie le animazioni (tabella `ANIMAZIONI`: fermo, guardia, camminata, corsa,
  spada_1..3, pugni, calcio, arco, magia, colpito, morte, sella…) in `eroe_anim.glb`, lega le capigliature alla testa
  (`capo_capelli_corti|crocchia|lunghi|rasati__N`, `capo_barba`) e ricostruisce capi e armature con le funzioni di
  `importa_mixamo.py`. In `indice.json`: `"dipinto": true` (il corpo tiene le sue texture; niente `pelle.gdshader` né
  `PiediDritti`), `"anim": "eroe_anim.glb"` (`_libreria_umani` legge il file dall'indice; con l'osso `root` il movimento
  del bacino resta intero). `metti_testa` accende la capigliatura dello stile e la tinge insieme alle sopracciglia.
  I corpi generati con MakeHuman (`corpo_base.py`, `modelli/corpi/`) restano come strumento ma non sono più usati.
  Visti a schermo: uomo e donna da fermi, viso, profilo, schiena. Non visti: corsa e attacchi con le animazioni nuove
  (l'arco usa un'animazione di tiro con la pistola, la sella una seduta), armature ed elmi sul corpo nuovo, PNG, cavallo.
  Le vesti di prima (gusci ricavati dal corpo) restano nel `.glb` solo per il client nel browser.
- **Completi per classe e grado (fatto, client Godot)** — richiesta dell'autore: «rifacciamo le armature, mantieni gli
  effetti, sempre più epiche col livello, una particolarità per classe». `tools/blender/completi.py` (chiamato da
  `importa_eroi.py`, ~40 s per tutto) costruisce su entrambi i corpi `capo_<classe>_base__<parte>` (vesti di sotto, sempre
  indossate) e `capo_<classe>_<g>__<parte>` con g = 0 (senza armatura) … 4 (grado `tier` del pezzo `body`).
  Strumenti (classe `Sarto`): `guscio` (pelle ritagliata su una linea esatta campo = 0 → orli puliti, gonfiata, lisciata,
  ridotta al 40%), `busto`/`arto` (anelli campionati con raggi dall'interno, rientri riempiti, file di lamelle a gradino),
  `falde` (pannelli appesi in vita, pesi bacino → coscia), `spallaccio`, `striscia` (cinghie, stole, colletti), `tubo`,
  `sfera`, `gemma`, `borchia`, `lama`, `aureola`, `mantello`. Pesi: punto del corpo più vicino; pezzi duri pesi rigidi.
  Parti: `stoffa` (robe), `stoffa2` (pants), `fascia` (trim), `regno` (colore del regno), `cuoio`, `piastre`, `lamelle`
  (giunture disegnate da `metallo.gdshader`, parametro `lamelle`), `bordo`, `grani`, `gemma` (`gemma.gdshader`, luce
  bassa che pulsa), `carta`. Le UV non arrivano nel glTF (nessuna texture): gli shader usano le coordinate del modello.
  Identità: **Lama** veste incrociata senza maniche → cuoio → lamelle laccate rosse → acciaio con specchio sul petto e
  gorgiera → nero e oro con ali sugli spallacci, gemme e mantello del regno; **Ombra** aderente scuro, sciarpa rossa,
  gilet di cuoio, un solo spallaccio (sinistro), cinghie a croce con lame da lancio, poi lame sugli avambracci, code della
  sciarpa, borse; al 4 mezza maschera e ventaglio di lame sulla schiena; **Monaco** busto nudo (la donna ha una fascia al
  petto, `donna=True`), pantaloni larghi con fasce, grani grossi, tracolla, cordone con nappe, bracciali e cavigliere
  d'oro, spallaccio d'oro e giada, al 4 anelli fluttuanti dietro la schiena; **Mistico** veste lunga a 8 falde con spacchi,
  maniche a campana, colletto alto, stola con talismani, mantellina del regno, spallacci di giada, al 4 aureola dietro la
  testa, talismani sospesi e seconda falda.
  Client: `Entita.completo(classe, grado, colori)` sceglie i capi; `_giocatore` (colori del `look` + regno), PNG
  (abitanti `lama_0`, guardie `lama_2`, araldo `lama_3`, maestri/guide/erboriste veste del Mistico) e mostri umani
  (banditi `ombra_0/1`, generale e custode `lama_4`, terracotta `lama_2` d'argilla) li usano se il modello li ha
  (`Entita.ha_completi`), altrimenti i capi di prima. Effetti `Equip.aura_armatura`/`cerchio_rune` invariati.
  Prove: `godot --path godot res://scene/vetrina.tscn -- --classe=lama --sesso=m --posa=fermo|corsa|attacco
  [--gradi=0,1,2,3,4] [--yaw=3.14] --foto=x.png` (vetrina senza server, con `--fixed-fps 30`); copione: comando `togli body`,
  `usa` prende la copia più potenziata. Nota: nel copione `/level` fa ripartire il copione (si rientra in gioco).
  Corretto: `Hair_SimpleParted` portava una sfera d'aiuto di 2 m (`capo_capelli_corti__2`), ora scartata.
  Dimensioni: `base_uomo.glb` ~10 MB, `base_donna.glb` ~11 MB (i capi vecchi per il browser ne pesano ~1).
  Visti a schermo (vetrina Godot e anteprime Blender): tutte le classi, gradi 0-4, uomo e donna, davanti e dietro; corsa e
  attacco col grado 4. Nel gioco vero (server, copione) visto solo la Lama. **Non verificati**: le altre animazioni
  (morte, sella, arco), elmi e calzari sopra i completi, PNG e mostri con i completi, resa con Forward+.
  Difetti noti: le chiome lunghe dell'uomo (Mistico) sono quelle del pacchetto (calvizie in cima).
- **Completi più ricchi (fatto)** — richiesta dell'autore: «più alta qualità e molti più dettagli, ognuno per classe»
  (le sagome gli piacevano: arricchite, non cambiate). Tre strumenti nuovi in `completi.py`, letti dagli shader:
  - seconda UV `Orlo` (TEXCOORD_1 → `UV2` in Godot): x = metri lungo l'orlo, y = metri dall'orlo. **Il glTF capovolge
    la v e Godot no**: negli shader `d = 1.0 - UV2.y` (vale anche per `UV`, vedi `carta.gdshader`). `griglia(orli=…)`:
    `'bordi'`, `'nastro'` (cinghie, stole), `'file0'`/`'file1'` (file di piastre: ogni fila ha il suo orlo, x della fila
    presa dall'orlo così le giunture vengono dritte), `None`; `guscio` la calcola dagli orli ritagliati (`_uv_orlo`);
  - occlusione dipinta nel colore dei vertici `Occl` (COLOR_0; `_occlusione`: 9 raggi entro 8 cm contro corpo, vesti di
    sotto e capo stesso): incavi e parti sotto le piastre più scuri. Il materiale la usa (nodo Color Attribute) sennò
    l'esportatore non la scrive;
  - spessore solo come bordino lungo gli orli (`_solido`, niente seconda pelle): metà dei triangoli di prima.
  Shader: `ornati.gdshaderinc` (motivo per classe lungo gli orli: Lama onde e nuvole, Ombra denti di sega, Monaco grani,
  Mistico rombi ricamati; `Personaggio.MOTIVI`), `metallo` (orlo consumato, doppio filetto, ribattini a cupola ogni
  4,5 cm, fascia incisa, martellatura, patina negli incavi; lamelle laccate con giunture, smusso, tinta per piastrina e
  allacciature nel colore del regno; `oro` per il riflesso caldo, `grani` per i solchi dei grani), `stoffa` (fascia
  ricamata lungo gli orli nel colore delle finiture, d'oro sulle finiture e sul regno; cuciture sul cuoio; `ritorto`
  per i cordoni, `frange` per le nappe, `piume`), `carta` (talismani con segni d'inchiostro inventati e sigillo rosso).
  Parti nuove in `personaggio.gd`: `cordone` e `nappa` (seta nel colore del regno), `piume`, `carta`.
  Pezzi nuovi (pochi triangoli): `fila_borchie`, `cordone`, `nodo` (nodo ornamentale a quattro asole), `fibbia`, `placca`
  (giada intagliata), `fodero`, `borsa`, `spirale` (fasce avvolte), `sonaglio`, `anellino`, `emblema_nuvola`, `denti`,
  `piume`, `sottoveste` (stoffa che spunta sotto le scarselle). Per classe: **Lama** teste di chiodo su cintura e
  cinturone, cordone annodato (0), file di chiodi e cinghie con fibbie sul petto (1), emblema della nuvola e cordoni a V
  con nodo e nappa (2), corona di chiodi attorno allo specchio, nuvole d'oro, cordoni (3), catenella d'oro e nappe al
  cinturone (4), sottoveste dal 2; **Ombra** fibbia, cinghie sulla coscia con pugnale nel fodero (0; due dal 2), fibbie
  sulle bandoliere, tasca (1), tasche, denti di sega sullo spallaccio (2), penne scure sulla spalla (3-4); **Monaco**
  fasce a spirale, cordone ritorto con anelli d'oro e sonagli, cavigliere coi sonagli e giro di grani al polso (2),
  anelli appesi allo spallaccio (3) e all'aureola (4); **Mistico** cordone e nodo con nappa in vita, nodi sulla stola,
  placche di giada sopra i talismani (2), pendente di giada (2), placche e nappe alla fascia (3-4).
  Triangoli per completo indossato (base + grado, uomo): Lama 3,9k / 6,4k / 8,9k / 10,5k / 11,8k (gradi 0-4), Ombra
  4,7k / 7,0k / 9,6k / 10,6k / 12,4k, Monaco 4,1k / 4,7k / 6,6k / 8,1k / 9,8k, Mistico 5,6k / 6,4k / 8,6k / 9,8k /
  12,0k (prima, con meno dettagli: grado 4 fra 12,9k e 15,3k). `base_uomo.glb` 11,0 MB, `base_donna.glb` 11,8 MB.
  Corretti: righe verticali sui pantaloni (erano le pieghe a seno dello shader; da vicino resta qualche filo scuro
  appena visibile lungo le vecchie cuciture della pelle), top dipinto ai lati della fascia della Monaca
  (fascia più larga e più alta), falde rigide (`falde`: pesi a curva morbida, i pannelli davanti e dietro divisi fra le
  due cosce secondo il lato; Mistico `coscia` 0,55). Vetrina: `--zoom=3 --mira=1.4 --fuoco=2` per i primi piani.
  Non verificati: gioco col server, Forward+, animazioni diverse da fermo/corsa, PNG e mostri con i completi nuovi.
- **Copricapi per classe** (l'autore: «gli elmi più piccoli e più a tema con la classe»): `copricapo()` e `Testa` in
  `tools/blender/completi.py` → `capo_<classe>_e<g>` (g = `tier` 1-4 del pezzo `head`), misurati sul cranio con i capelli
  corti. Lama: fascia con placca → frontale di ferro → frontale con mezzaluna e guanciali → corona da guerra nera e oro;
  Ombra: bandana → maschera di stoffa → placca dentata → diadema scuro con una lama di lato e penne; Monaco: corda
  annodata → giro di grani → cerchio d'oro con disco di giada → cerchio doppio con fiamma e sonagli; Mistico: nastro con
  talismano → fermacapelli con spillone → diadema di giada con pendenti → coroncina con stella. `entita.gd` li sceglie
  dalla classe e dal grado (i vecchi elmi restano per PNG, mostri e browser). Vetrina: `--elmo=1` (o `vecchio`),
  `--passo=0.72`. Visti in vetrina: tutte le classi, uomo e donna, davanti e dietro. Non visti: in gioco, con le
  capigliature lunghe (sotto il copricapo si mettono i capelli corti), in corsa.
- **PNG donne, chioma lunga e busto** (l'autore: «fammi i personaggi PNG donne più provocanti», poi «la fronte è troppo
  alta e il taglio di capelli fa cagare, falla con i capelli lunghi e con seno più pronunciato», poi «il caschetto comunque
  mi piaceva»). Prima c'era una sola donna (Nonna Lin). Ora sono donne: **Dama Lin** (speziale, ruolo `erbe`), **Scrivana
  Mei** (`scrivano`), **Cassiera Zhou** (`magazziniere`), la **Viandante Lu** (`guida`) e una guardia su due (id pari); i
  testi che li nominano sono stati volti al femminile. Abiti solo sul corpo femminile, `dama(S, g)` in
  `tools/blender/completi.py` → `capo_dama_0|1|2`: 0 abito a spacco (tubino senza spalline, schiena nuda, apertura a goccia
  sul ventre, due teli lunghi davanti e dietro con le gambe scoperte ai lati, fusciacca del regno), 1 danzatrice (fascia
  al petto, ventre nudo, cinta d'oro bassa con due veli, cavigliere, sonagli), 2 guerriera (corpetto di lamelle laccate,
  ventre nudo, uno spallaccio, gonnellino corto di lamelle, schinieri). Il corpo ha dipinti una fascia grigia al petto e
  uno slip: gli abiti li coprono (`z_seno`, `z_slip`). Scelta in `entita.gd` (tipo «n»). Vetrina: `--classe=dama
  --gradi=0,1,2 --sesso=f [--capelli=chioma|long]`.
  **Capigliature**: `"long"` = il caschetto del pacchetto (**all'autore piace: va tenuto**), `"chioma"` = chioma lunga
  fino a metà schiena con frangia che abbassa l'attaccatura, costruita da `chioma(S, T)` (`capo_capelli_chioma__ciocche`:
  calotta, due strati di ciocche sulla schiena, due ciocche davanti fino alla clavicola, frangia; pesi dal corpo, niente
  fisica). Le PNG donne alternano le due. Il ciuffo corto (`short`) sulle donne non gli piace.
  **Busto**: `gonfia_seno` in `importa_eroi.py` accentua il seno di `base_donna` (vale per TUTTE le donne, giocatrici
  comprese); le normali importate si ricalcolano. Per non far bucare le vesti dal corpo, `guscio` dopo la riduzione
  riporta fuori le facce finite sotto la pelle (dal lato della veste e dal lato dei vertici del corpo): la correzione
  tocca anche le vesti maschili (stessa forma, `base_uomo.glb` rigenerato). `base_donna.glb` 14,4 MB.
  Visti in vetrina: i tre abiti davanti e dietro con chioma e con caschetto, Lama donna gradi 0/2/4; in gioco gli abiti
  su Scrivana e Cassiera da lontano. **Non visti**: da vicino in gioco, la chioma in corsa e con i copricapi (sotto i
  copricapi si mettono i capelli corti), Mistica e Monaca col busto nuovo, le vesti maschili dopo la correzione.
- Da fare: capelli e volti, nascondere il corpo sotto i capi. Dopo: l'autore vuole lavorare sul sistema di combattimento.
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
- Fase 3 (superata dalla fase 4): **kit «2 accumuli + 4 scarichi»** per ogni Via (campo `ruolo` in `SKILLS`: `accumulo`, `medio`, `potente`).
  Di base: 2 accumuli (livello 1, gratuiti, generano risorsa/punti) e lo scarico medio singolo (livello 3). Dalla Via: scarico
  medio ad area (5), supporto (7), scarico potente singolo (9), scarico potente ad area (12), supporto (15), Suprema (15).
  Costi: medio 30-35, potente 45-60 (Mana 4-5% e 10-12%); per Ombra, Monaco e Mistico i potenti consumano anche tutti i punti.
  Energia 5,5/s e Chi 7/s: senza accumuli non si regge il ritmo. `DATA_VERSION = 4` azzera abilità e barra rapida.
  Mistico: accumuli con tempo di lancio, scarichi istantanei; la Benedizione ha cure al posto dei danni (`spendBonus`).
  Motore: i `dot` valgono anche per le tecniche ad area, `waves` anche fuori dalle Supreme, passivo `chainHeal` (Loto).
  Client: ruolo nel tooltip e nella finestra Abilità, tacca colorata sotto i tasti della barra (verde/oro/rosso).
- **Fase 4 — kit a pochi tasti (richiesta dell'autore, sostituisce i kit della fase 3)**: vuole 4-5 tasti per classe, colpi
  base «sempre spalmabili», finali epici, **niente sequenze di tasti** ma passive in stile maestria; farming alla Metin,
  dungeon alla WoW con interruzioni e stordimenti, PvP misto; la Benedizione resta guaritore.
  Ogni Via: 2 colpi base (`ruolo: 'accumulo'`: uno singolo con `pts: 1`, uno ad area con `risonanza: true`), 1 colpo
  finale (`finale: true`, `ruolo: 'potente'`), 1 interruzione (`interrupt: true`, fuori dal tempo globale) e, tranne la
  Lama, 1 mossa di Via; più la Suprema. Prima della Via c'è un finale di base (`finoVia: true`) che quello della Via
  sostituisce anche nella barra rapida. `DATA_VERSION = 5` azzera abilità e barra dei personaggi esistenti.
  Regole in `COMBAT` (`shared/data.js`) e `resolveSkill` (`server/world.js`):
  - **Concentrazione** (i punti di tutte le classi: Impeto, Punti combo, Sfere, Cariche): il finale li consuma, +9% a punto;
  - **Risonanza** (effetto `risonanza`): il colpo base ad area che prende ≥3 nemici la accende; il finale la consuma e
    colpisce (o cura) tutti attorno al bersaglio al 60% a testa; l'effetto parte con `ris: 1`;
  - **Maestrie** (`VIE[via].maestria`): slancio (Fulmine), baluardo (Montagna), veleno (Pugnali), distanza (Arco),
    ritmo (Ferro), cura (Loto), critPts (Tempesta), grazia (Benedizione: i danni dei colpi base curano il più ferito);
  - **Lanci dei mostri** (`MOBS[..].cast`: arciere bandito, spirito della lanterna, generale, lanterna e custode della
    cripta): effetti `mcast` / `mcastend`; stordimento, Squilibrio e interruzione li spezzano (`interrompi`);
  - **PvP**: stordimenti ripetuti entro 15 s durano la metà, poi un quarto, poi immunità (`stun`).
  Simulazione aggiornata (`rotazione` in `tools/sim/simula.mjs`). Misura dopo la taratura (40 s, velocità 4, una prova
  per scenario): Vie da danno entro ±8% fra loro al livello 30 su 1 bersaglio (1087-1264 DPS), su 5 bersagli (2670-3071)
  e al livello 15 (473-533); Montagna al 58-64%, Benedizione al 57% su un bersaglio e al 39% su cinque (il suo finale cura,
  non fa danni); barra Suprema ~53 s. Non misurato a velocità reale né con più ripetizioni; cure e tenuta del difensore
  non sono misurate. Visto a schermo nel client Godot (Lama): Risonanza, finale ad area, lancio di una Lanterna Insonne
  con la barra, interruzione con la Carica e stordimento.
- **Ritmo raddoppiato, scatti e potenziamenti di classe** (richiesta dell'autore: «dimezza il gcd», «ombra deve
  teletrasportarsi dietro il bersaglio e il lama charga davanti a lui», «una spell di buff per ogni classe»):
  `GCD_MS` 500 (minimo 375); per non raddoppiare i danni `COMBAT.scalaTecniche` = 0,62 moltiplica i danni di ogni tecnica
  (non gli attacchi base né le cure), i lanci del Mistico sono dimezzati (Dardo 0,5 s, Sfera 0,6 s) e la barra Suprema
  si riempie più piano (`perRes` 0,052, `perManaPct` 0,36). Misura (30 s, velocità 4, una prova): Vie da danno fra
  1234 e 1496 danni al secondo (−11% … +8%), Montagna 63%, Benedizione 58%, barra Suprema 46-58 s (Tempesta 33 s prima
  dell'ultimo ritocco a `perManaPct`, non rimisurata). Cure e farming non rimisurati con il ritmo nuovo.
  Scatti (`resolveSkill`): la carica si ferma davanti al bersaglio sulla linea d'arrivo; con `behindDash` si riappare alle
  spalle rispetto a dove il bersaglio guarda (`target.r`) e l'effetto porta `tp: 1` (il client lo mostra come teletrasporto).
  Potenziamenti (livello 8, fuori dal tempo globale, in `baseSkills`): Lama `grido_guerra` (12 s, danni + e danni subiti −,
  anche ai compagni entro 15 m, +25 Ira), Ombra `velo_ombra` (10 s, critico e velocità, +30 Energia), Monaco
  `respiro_drago` (12 s, rapidità e furto di vita, +2 Sfere), Mistico `benedizione_astri` (15 s, attacco e rigenerazione,
  anche ai compagni entro 20 m, +12% Mana). Campi nuovi: `gruppo` (raggio), `manaPct`; statistiche dei buff `lifesteal`,
  `spdPct`. Provato con un bot: i 4 potenziamenti si attivano, l'Ombra arriva dietro, la Lama sulla linea di carica.
- **Fase 5 — flow** (richiesta dell'autore: «rendilo fluido, con un flow divertente e rapido, parola chiave FLOW»).
  Diagnosi: nel farming il bot camminava il 70-77% del tempo (branchi distanti, Slancio e Ira che calavano fra un branco e
  l'altro); Monaco, Mistico e Ombra con l'arco non avevano modo di avvicinarsi o riposizionarsi; i lanci del Mistico si
  annullavano muovendosi; dopo uno scatto il client spegneva l'attacco automatico (`_su_pos` azzerava `intento`) e i tasti
  WASD lo spegnevano sempre; le uccisioni rendevano solo 10 punti di risorsa; l'interruzione riuscita rendeva solo risorsa;
  l'Arco aveva due potenziamenti quasi uguali (Occhio del Falco e Velo d'Ombra); la Montagna (difensore) non aveva
  provocazione né difesa attiva. Cambiato (server, dati, client Godot; `DATA_VERSION` resta 5):
  - **Serie di uccisioni** (`SERIE` in `shared/data.js`, `uccisione` in `server/world.js`, chiamata da `mobDie` per chi ha
    combattuto il mostro entro 40 m): ogni uccisione entro 7 s dalla precedente allunga la serie; in serie si corre più
    veloci (+4% a uccisione, max +24%: in `recalc`), Slancio e Ira non calano, ogni uccisione toglie 2 s alle ricariche
    degli scatti (`scatto: true`) e 1 s a quella del potenziamento (`potenziamento: true`; messaggio `cd` con `rid` e `tot`),
    ogni 5 uccisioni un'Occasione. Al client arriva in `me`/`r` (`se`, `sems`): scritta «Serie ×N +X%» accanto allo Slancio.
  - **Occasione** (effetto `occasione`, `finaleGratis`): il prossimo finale non costa risorsa e vale come Concentrazione piena
    (5 punti). Viene da un colpo base a segno (`COMBAT.occasionePct` = 6%), da ogni interruzione riuscita (`interrompi`) e
    dalla serie. Il tasto del finale lampeggia come per la Risonanza.
  - **Scatti per tutti**: Carica (Lama, ora +20 Ira), Passo d'Ombra (Pugnali), **Ala di Vento** (Arco, sostituisce il tasto
    Occhio del Falco: `dashDist` 9, porta a 9 m dal bersaglio avanti o indietro, raffica di penne che rallenta, 2 Punti
    combo e l'effetto Occhio del Falco per 6 s), **Calcio Volante** (Monaco, base, livello 4: balzo fino a 12 m, +1 Sfera),
    **Passo di Luce** (Mistico, base, livello 4: tipo `blink`, 10 m nella direzione `r` mandata dal client con `skill`).
  - **Radici della Montagna** (Montagna, livello 7, mossa di Via): provoca tutti i nemici entro 8 m (`provoca`, stessa logica
    della vecchia `taunt`) e dà Pelle di Pietra per 10 s.
  - **Lanci in movimento**: Dardo e Sfera hanno `mobile: true` (il server non li annulla in `onMove`, il client non manda `cancel`).
  - Client: attacco automatico che continua camminando con WASD sul bersaglio già ingaggiato (`_attacco_in_movimento`), lo
    scatto non spegne l'attacco, ruoli «Scatto» (viola) e «Potenziamento» (arancio) sotto i tasti (`Hud.ruolo_di`), icone
    disegnate per le tecniche nuove, i 4 potenziamenti e l'Occasione (`icone.gd`), aiuto in gioco aggiornato.
  - Tecniche tolte (Occhio del Falco come tasto): `pulisciTecniche` in `migrate` restituisce i punti spesi e toglie il tasto.
  - Simulazione: i bot di `npm run sim` ora usano anche i potenziamenti di classe e le mosse nuove (prima no: i numeri
    vecchi erano un po' più bassi del gioco vero); `npm run farming` usa gli scatti per avvicinarsi (`scatti` nella tabella
    `ROTAZIONI`) e stampa scatti al minuto e serie massima. Prova funzionale delle meccaniche nuove: 18 verifiche con un bot.
  Taratura dopo le aggiunte: Occhio del Falco rapidità 15% (era 25%, ora 6 s legato all'Ala di Vento), Freccia
  Perforante 2,8 (era 2,9), Raffica 3,9 (era 3,75). Misura (60 s, velocità 2, 2 in parallelo, una prova; la macchina era
  molto carica: contano i rapporti; «prima» = codice precedente con lo stesso bot che usa anche i potenziamenti):


  | scenario | prima (min … max delle Vie da danno) | dopo | Montagna | Benedizione |
  |---|---|---|---|---|
  | liv. 30, 1 bersaglio | 1313 … 1567 (−9% / +9%) | 1396 … 1629 (−8% / +7%) | 64% → 62% | 56% → 54% |
  | liv. 30, 5 bersagli | 3274 … 4068 (−9% / +13%) | 3354 … 4016 (−9% / +9%) | 65% → 64% | 39% → 37% |
  | liv. 15, 1 bersaglio | 574 … 663 (−7% / +7%) | 612 … 690 (−4% / +8%) | 64% → 65% | 58% → 59% |

  Barra Suprema invariata (45-54 s su un bersaglio; Tempesta 36 s su 5 bersagli come prima). Farming (`npm run farming
  -- --minuti 3 --vie fulmine,arco,ferro,tempesta`, velocità 3; prima → dopo): uccisioni al minuto bassa 64-69 → 85-93,
  media 51-57 → 65-73; esperienza al minuto +23…+35%; tempo a camminare da 53-78% a 53-67% (Fulmine 76 → 67%, Arco 71 → 57-65%); 7-14 scatti al minuto; la
  serie in pratica non si spezza mai (massimo 56-128 uccisioni). **Da sapere**: l'esperienza all'ora sale di circa un terzo
  (e il bottino all'ora con lei); se è troppo, abbassare `SERIE.velMax` o `scattoS` prima dei mostri.
  Non verificati: la resa a vista degli scatti nuovi (gli effetti li disegna `effetti.gd`, `fx: 'dash'`/`'quake'`), il
  Passo di Luce con mouse e tastiera veri, cure e tenuta del difensore con le Radici in un dungeon vero.
- **Tempo globale riportato a 1 secondo** (l'autore, dopo aver provato il mezzo secondo: «troppo spammoso»): `GCD_MS` 1000
  (minimo 750), `COMBAT.scalaTecniche` 1, lanci del Mistico 1,0 s (Dardo) e 1,2 s (Sfera), `SUPREMA.perRes` 0,082 e
  `perManaPct` 0,58 come prima. **Non riproporre il tempo globale dimezzato.** Restano scatti, potenziamenti, Serie e
  Occasione. Freccia Perforante 2,55 (con il tempo lungo l'Arco era a +14%). Misura (30 s, velocità 4, una prova): Vie da
  danno 1216-1422 (−7% … +9%), Montagna 63%, Benedizione 52%, barra Suprema 50-63 s (Benedizione ~94 s: da riguardare).
- **Auree di classe al posto dei potenziamenti a tempo** (l'autore: «cambia l'idea di spell passive con buff, pensa alle
  auree»): le quattro tecniche del livello 8 (stessi id) sono ora `type: 'aura'`, `aura: true`: un tasto le accende e
  restano finché non si ripreme, si cade o si cambia Via (`mettiAura` in `server/world.js`; `p.aura`, effetto in
  `p.buffs` con `aura: true` senza scadenza). **Aura di Guerra** (Lama: danni +, danni subiti −; gruppo entro 15 m),
  **Aura d'Ombra** (critico e velocità), **Aura del Drago** (Monaco: rapidità e furto di vita), **Aura degli Astri**
  (Mistico: attacco e rigenerazione; gruppo entro 20 m). Valori circa il 40% dei vecchi potenziamenti a tempo, niente
  risorsa regalata all'accensione. `tickAure`: i compagni di gruppo nel raggio la ricevono come effetto breve rinnovato
  ogni secondo. Agli altri: `au` nelle info del giocatore ed effetto `{ k: 'aura', s, a }`. Client Godot:
  `Equip.aura_classe(id)` / `Personaggio.metti_aura` (cerchio di rune a terra + motivo per classe: lingue rosso-oro, fumo
  scuro, fiamme del chi, stelle in orbita e corona), ruolo «Aura» sotto il tasto, icona senza conto alla rovescia.
  I bot di `sim` e `farming` la accendono una volta. Misura (30 s, velocità 4): Vie da danno −5% … +5%.
  Viste a schermo in gioco le quattro auree accese. Non visti: spegnimento, aura vista da un altro giocatore, gruppo.
  Il client nel browser non le mostra. `SERIE.potS` non serve più (nessuna tecnica `potenziamento`).
- **Tecnica Suprema nella rotazione** (l'autore: «non voglio che si carichi ma che faccia parte della rotazione, con del
  cd»): niente più barra che si riempie spendendo risorsa. `SUPREMA = { cd: 30, finaleS: 2 }`: ricarica di 30 s che ogni
  colpo finale accorcia di 2 s (`p.supAt` in `server/world.js`; `supPct` → `su` 0-100 e `sums` millisecondi nei messaggi
  `me`/`r`, così bot e client restano compatibili). Torna pronta ogni 14-15 s (Mistico 18-22 s, fa meno finali). Danni
  ridotti del 15% (Lama 2,2, Ombra 0,94, Monaco 3,05; Mistico invariato) e **Mille Ombre** ora colpisce anche attorno al
  bersaglio (`splash: 5`: su un gruppo l'Ombra restava indietro). Client: la barra sotto la risorsa si riempie col tempo,
  mostra i secondi e lampeggia «PRONTA» (`Hud._aggiorna_suprema`). GM `/suprema` la rende pronta.
  Misura (40 s, velocità 4, una prova, macchina carica): 1 bersaglio Vie da danno −4% … +5%, Montagna 67%, Benedizione
  60%, Suprema al 10-19% dei danni; 5 bersagli −12% … +11%, Suprema 8-31%. **Non visto a schermo** (macchina satura).
- **Ombra: assassino a Marchi** (terza versione). Storia: il kit «generatore e scarichi a Punti combo con Flusso» è stato
  **bocciato dall'autore** («non mi piace il gameplay, rifallo»: colpi senza impatto, non sembrava un assassino); ha scelto
  «assassino a Marchi». **Non riproporre Flusso, Taglio Gemello, scarichi a Punti.** Le altre tre classi hanno ancora il kit
  della fase 4: prima di portarle a uno schema nuovo chiedere all'autore.
  - **Marchi** (`CLASSES.ombra.marchi = { max: 5, dur: 14 }`; `marchiDi`, `mettiMarchi`, `togliMarchi` in `server/world.js`;
    stanno sul nemico in `e.marchi[idGiocatore]`): li incidono le tecniche con `marca: N` (anche a ogni ondata). Effetto
    `marchi` a tutti i vicini (`d`, `s`, `n`, `ms`; `boom: N` quando esplodono). Con la Via dei Pugnali ogni Marchio avvelena.
  - Tecniche: **Colpo Rapido** (12 Energia, 1 Marchio; 2 alle spalle o in Agguato: `behind.marchi`), **Esecuzione** (id
    `taglio_netto`; con la Via **Morso della Vipera** `taglio_finale` / **Freccia Perforante**; `finale: true`, 25 Energia,
    `esplode: { pct: 60, raggio: 6, catena: 60, energia: 25 }`: +60% per Marchio, i nemici marchiati entro 6 m saltano a
    catena, se il bersaglio cade rende Energia e azzera le ricariche degli scatti), **Passo d'Ombra** (ora di base, livello
    3, ricarica 8 s: alle spalle + effetto `agguato` per 5 s), **Ventaglio** (30 Energia, 1 Marchio a tutti), **Danza delle
    Lame / Pioggia di Frecce** (livello 10, 4 ondate, un Marchio a ondata su tutta la zona, ricarica 16 s), Colpo alla Gola,
    Ala di Vento (marca), Mille Ombre (`marca: 2`). Risveglio **Eclissi**: Colpo Rapido gratuito e un Marchio in più.
    L'Occasione rende gratuita l'Esecuzione e vale come prima per il finale. I Punti combo non si usano più per l'Ombra.
  - Client: schegge cremisi che girano attorno al nemico (`Afflizioni.marchi`, `Entita.marchi`), contatore «✦✦✦··» sotto
    l'Energia per il bersaglio (`gioco.marchi_miei`), tasto dell'Esecuzione che lampeggia a 5 Marchi, esplosione
    (`Effetti.esplosione_marchi`: i tagli si chiudono uno dopo l'altro, poi lo scoppio; scritta «ESECUZIONE ✦×N» e
    fermo-immagine proporzionale). Restano gli effetti per tecnica e per arma (`_ombra_lame`, `_ombra_arco`, `dardo()`),
    **senza segni a terra**, e gli **effetti addosso ai nemici** (`afflizioni.gd`: effetto `aff` per danni nel tempo, marchi
    e rallentamenti; veleno, sangue, stelle dello stordimento, brina; valgono per tutte le classi).
  - Bot (`ombra()` in `simula.mjs` e `farming.mjs`): Colpo Rapido fino a 5 Marchi poi Esecuzione; sui gruppi danza,
    Ventaglio, Esecuzione a 3 Marchi. Misura (60 s, velocità 4, una prova): liv. 30 su 1 bersaglio Pugnali e Arco ±0%; su 5
    bersagli +12% / +4%; liv. 15 +4% / −2%. Esecuzione a 5 Marchi ~2050 contro ~290 del Colpo Rapido (livello 40).
    Farming zona media 60 uccisioni/min, nessuna morte.
  - Prove a schermo: con `--fixed-fps` i Marchi (14 s d'orologio) scadevano fra un comando e l'altro: avviare il server
    con l'orologio rallentato, `SIM_VELOCITA=0.06 node --import ./tools/sim/orologio.mjs server/index.js`.
  - Visto in gioco (pugnali): Marchi sul nemico e nel riquadro, Agguato, Esecuzione a 5 Marchi, Danza e catena su 4
    fantocci. **Non visti**: con l'arco, l'uccisione che rende il Passo d'Ombra, PvP, Marchi di due Ombre sullo stesso nemico.
- **Risvegli: i cooldown offensivi** (l'autore: «cooldown offensivi per tutte le classi: abilità che potenziano le abilità
  base e le cambiano, cambiano colori ed effetti»). Una tecnica per classe, livello 12, in `baseSkills`: `type: 'buff'`,
  `risveglio: true`, fuori dal tempo globale, ricarica 60 s, effetto di 12 s (stesso id per tecnica ed effetto).
  `BUFFS[id].risveglio` dice come cambiano i colpi base (ruolo `accumulo` o `base: true`): `eco` (secondo colpo al N%),
  `scoppio` (il colpo singolo esplode attorno al bersaglio), `genPct`, `gratis`, `ptsExtra`, `istantanei`; più `stats`
  (`dmgPct`) per tutta la durata. In `resolveSkill`: `risv`, `scalaColpo`, e `pot: 1` nell'effetto `sk` del colpo base.
  **Risveglio del Drago** (Lama: Squarcio e Fendente colpiscono due volte, +50% Ira; rosso e oro), **Eclissi** (Ombra:
  Colpo Rapido gratuito e 3 Punti, un taglio in più anche sul Taglio Gemello; bianco lunare e cremisi), **Cuore del Sole**
  (Monaco: il Pugno esplode attorno al bersaglio e dà una Sfera in più, il Calcio colpisce due volte; bianco e oro),
  **Congiunzione** (Mistico: Dardo e Sfera istantanei e a coppie; oro). Client: `Effetti.PALETTE_RISVEGLIO`, `_potenziato`
  (l'effetto in più per classe), `_risveglio_accendi`, `risveglio()` (il corpo arde finché dura: effetto `risveglio` con
  `a`, `ms`, a tutti i vicini); ruolo «Risveglio» (tacca d'oro), i tasti dei colpi base hanno la cornice d'oro finché
  dura, icone nuove. I bot di `sim` e `farming` lo usano appena pronto. Misura (60 s, velocità 4, una prova): Vie da
  danno −5% … +3%, Montagna 65%, Benedizione 59%; i danni salgono di circa il 5% per tutti.
- **Contatore dei danni** (`godot/script/contatore.gd`, tasto **N** rimappabile, visibile di base, scelta salvata):
  si alimenta dagli effetti `hit` (nessun messaggio nuovo): danni al secondo, totale e quota di ogni giocatore in vista
  (barre nel colore della classe), e le quattro tecniche proprie più pesanti. Vista «Scontro» (si chiude dopo 6 s senza
  colpi) o «Totale» (clic per cambiare, clic destro per azzerare). Non conta le cure.
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

## Farming nel mondo aperto: branchi (fatto)
L'autore vuole il farming «alla Metin»: branchi da falciare con i colpi ad area (la Risonanza si accende con 3+ nemici).
- **Branchi** (`initSpawns`, `addBranco`, `programmaRinascita`, `tickBranchi`, `chiamaBranco` in `server/world.js`): gruppi di
  4-7 mostri della stessa famiglia entro ~3,4 m dal centro (`RAGGIO_DISPERSIONE`), vagano di soli 2,5 m (`m.vaga`), branchi
  ad almeno 22 m l'uno dall'altro (`SEP_BRANCHI`), mai a meno di 58 m dai villaggi. Intorno ai villaggi: lupi, cinghiali,
  lupi del branco; più lontano: banditi con arcieri, predoni, scimmie; Altopiano: soldati di terracotta (+ spiriti a 3-4).
  **Solitari élite** (vita ≥ 1000, hanno la Postura): Lupo Anziano (nuovo, vicino al villaggio), Orso Nero, Terracotta,
  Tigre Spettrale; il Lupo Alfa resta un solitario normale (serve alle ondate dell'obelisco).
- **Aggro di branco**: il primo colpo (o la prima volta che uno ti nota) chiama i compagni vivi entro `RAGGIO_BRANCO` = 10 m
  da quel mostro; gli altri branchi non si muovono. **Rinascita**: quando TUTTO il branco è a terra rinasce insieme dopo
  `respawn` (il massimo dei suoi membri, 24-50 s); un superstite non blocca i morti, che tornano dopo 3 volte il tempo.
- `MOBS[..].bott` = moltiplicatore del bottino (tabella + `extraDrops`), 0,8-0,9 sui mostri di branco: più uccisioni
  all'ora, stesso equipaggiamento all'ora. Vita, esperienza e tael dei mostri di branco sono scalati (vita -20%, esperienza
  -17/-21%): lupo, cinghiale, lupo_branco, bandito, scimmia, arciere_bandito, predone, soldato_terracotta.
  Attenzione: lupo_alfa, terracotta e spirito_lanterna sono usati anche dalle ondate degli obelischi e dal Generale, perciò
  NON sono stati toccati; bandito sì (ondate dell'obelisco minore: ora un po' più facili).
- La radura di `npm run sim` (-228,-228) è tenuta libera da `initSpawns` (nessuno spawner a meno di 50 m).
- **Misura**: `npm run farming` (`tools/sim/farming.mjs`, istruzioni in testa al file): un bot di livello adatto cammina
  nella zona, combatte con i kit nuovi e riporta uccisioni/min, esperienza/min, danni subiti, vita minima, morti, ginseng
  bevuti, oggetti caduti. Zone `bassa` (liv. 5), `media` (12), `alta` (19); `--bonus-livello 5` prova chi è sopra la zona.
  Il bot ha latenza zero e rotazione perfetta: i numeri assoluti sono ottimistici, contano i rapporti prima/dopo.
  Dopo ogni ritocco ai mostri del mondo: `npm run farming -- --ripeti 2` e confronto con i numeri qui sotto (5 min, velocità 3,
  Fulmine / Arco; prima → dopo; esperienza al minuto): bassa 1733 → 2066 / 2023 → 2227, media 4731 → 5644 / 5360 → 6161,
  alta 10406 → 10714 / 9950 → 11608 (da +3% a +19%); uccisioni al minuto bassa 46/54 → 65/68, media 48/53 → 47/53,
  alta 40/39 → 44/49. Con +5 livelli sopra la zona l'esperienza cresce solo del 2-19% e sale di 1 livello in 5 min.
- Da sapere: il bot cammina il 25-75% del tempo (i branchi sono distanziati: è il limite del ritmo, non la vita dei
  mostri); contro un branco il Fulmine al livello 5 beve ~9 ginseng in 5 min (prima 1) ma non muore; il bottino misurato è
  molto rumoroso (decine di oggetti in 5 min), la taratura vera è nei valori attesi per uccisione.

## Crescita: missioni e bottino (fatto)
Richiesta dell'autore: «leveling experience e miglioramento degli oggetti» (le icone e l'aspetto degli oggetti a terra
li fa un altro lavoro: `icone.gd` e la figura del bottino non sono stati toccati qui).
- **Curva dei livelli** (`expToNext` e `CURVA_LIVELLI` in `shared/data.js`): la forma di prima per un fattore che cresce col
  livello (3,0 al livello 1 → 4,6 al 20 → 8,5 al 40). Stima con i numeri di `npm run farming` (giocatore vero = 45% del bot,
  missioni della catena comprese, ~1,5 min di cammino per missione; calcolo ripetibile: esperienza al minuto del bot per
  zona × curva): prima livello 10 in ~25 min, 20 in ~55 min, 30 in ~1,6 h, 40 in ~2,4 h; ora 10 in ~45 min, 20 in ~2,2 h,
  30 in ~5 h, 40 in ~9-10 h. Bot (esperienza al minuto, Fulmine): liv. 2 piana 1826, 5 piana ~2300, 8 piana 2012,
  12 confine ~6300, 16 gole 4818, 19 altopiano ~12000, 25 cuore dell'Altopiano 11429, 33 Selva 20483.
  Premi delle missioni, ricompense della Prova (5%) e perdita alla morte (3%) sono in frazioni del livello: scalano da soli.
- **Buchi riempiti**: `razziatore_gola` (liv. 15, branchi nelle gole lontane dai villaggi, 142-182 m) e `lanciere_bronzo`
  (liv. 24, cuore dell'Altopiano 36-60 m attorno al Generale; i soldati ora 52-92 m). Etichette della mappa grande: confine
  8-18, Altopiano 17-28.
- **Missioni** (`shared/missioni.js` dati, `server/missioni.js` logica installata su World come `server/mappe.js`):
  catena di 34 missioni dal livello 1 al 40 (piana → Via al 5 → obelisco → puledro al 10 → confine → gole → fabbro →
  Altopiano → Prova del Sigillo al 20 → Generale al 25 → Selva dal 28 → Distesa al 38-40) e 22 incarichi giornalieri
  (3 al giorno, 4 dal 20, scelti per livello con un seme personaggio+giorno; dalla **Scrivana Mei**, PNG
  `scrivano` nei villaggi vicino all'arrivo, o dalla Viandante Lu nelle mappe lontane; si consegnano a entrambi).
  Obiettivi: `uccidi`, `raccogli` (oggetti del bottino raccolti dopo l'accettazione; con la missione aperta i mostri giusti
  lasciano l'oggetto più spesso), `parla`, `prova`, `obelisco`, `luogo`, `livello`, `via`, `destriero`, `arena`.
  Premi: esperienza in frazione del livello della missione, tael, oggetti, **equipaggiamento della classe** scelto
  all'accettazione (per l'arma il tipo impugnato: l'Ombra con l'arco riceve archi), destriero.
  Agganci in `world.js`: `missioniEntra` (addPlayer), `missioniMorte` (mobDie: contano tutti quelli che hanno colpito e i
  loro compagni entro 80 m), `missioniRaccolta` (onPickup), `missioniPng` (onNpc: il dialogo delle missioni si apre
  accanto alla finestra del PNG; per maestro e guardie sostituisce le solite frasi), `missioniEvento` (Prova completata,
  uccisione nell'arena in `server/mappe.js`), `missioniLivello` (gainExp e `/level`), `tickMissioni`, messaggio `mis`.
  Salvataggio: `ch.mis = { cat, att, gg }`; i personaggi di prima ricevono `mis` al primo ingresso e la catena riparte
  dalla missione del loro livello (nessun azzeramento, `DATA_VERSION` invariato).
  Messaggi: `mis` (stato completo: aperte con avanzamento, premio e `dove` {x, z, n}; `png` ruolo → «!»/«?»; `pross`;
  `gg`), `mis_png` (dialogo: offerte e consegne), `mis_ev` (nuova/avanza/pronta/fatta/via), `sblocchi` (passaggio di
  livello: tecniche, Via, cavalcatura, Prove, mappe, pezzi nuovi). Client → server: `{ t: 'mis', a: accetta|consegna|abbandona, id, npc }`.
  GM: `/missione c07` (porta lì la catena e la accetta), `/missione fatta` (obiettivi aperti completati), `/missione giorno`.
- **Oggetti**: 48 pezzi intermedi (livelli 5, 15, 25, 35, 40, 45 per ogni arma e per armatura, copricapo, calzari; id
  `spada_15`, `corazza_25`, `elmo_5`…) con `tier` del grado vicino per l'aspetto; copricapi e calzari hanno `aspetto` (id del
  modello dei quattro gradi, usato da `entita.gd`). Il client nel browser non li conosce come modelli: mostra il corpo senza elmo.
- **Bottino** (`server/bottino.js`, `extraDrops` spostato lì): pezzi del livello della zona (livello richiesto in
  (L-10, L+1], di solito il gradino più alto), 75% della classe di chi ha fatto più danni (armi del tipo impugnato al 70%);
  élite (vita ≥ 1000) 30% di un pezzo con rarità `RARITY_WEIGHTS.elite`, gemme 8%; tolti dai mostri del mondo i pezzi
  fissi di qualsiasi classe; minerale di ferro un po' più frequente da orso e terracotta. Premi della Prova del Sigillo:
  pezzi della classe (livello 30, 35 dal sigillo +4, 40 dal +8). Misura (`npm run farming`, nuova colonna «utili/h»:
  pezzi della propria classe indossabili e non più vecchi di un grado; 5 min per prova, molto rumorosa):

  | zona/via | equip/h prima → dopo | utili/h prima → dopo | di cui Pregiati o meglio |
  |---|---|---|---|
  | bassa (5) Fulmine / Arco | 144-192 / 288-336 → 48 / 72 | 60 / 228 → 48 / 60 | 0 / 24 → 36 / 36 |
  | media (12) Fulmine / Arco | 96-180 / 300 → 48 / 60 | 24 → 24 / 48 | 24 → 24 / 12 |
  | alta (19) Fulmine / Arco | 96-144 / 108-156 → 156 / 168 | 0 / 0 → 84 / 60 | 0 → 60 / 36 |

  Prima nella piana gli «utili» erano quasi tutti pezzi del livello 1 (tunica, sandali, cappello); ora i pezzi a terra sono
  meno, del livello giusto e della classe. `farming.mjs` ha anche le zone `gole`, `cuore`, `selva`, `distesa` e `--porte`
  (`simula.mjs`: `--porta`). La Distesa al livello 43 non parte (il bot non ha Tomi per le abilità oltre il 10).
- **Client Godot** (`godot/script/missioni.gd`): diario (tasto **L**, nell'aiuto H), elenco a destra sotto la minimappa
  («◆» catena, «◇» incarichi, «✓ Torna da…»), dialogo con Accetta/Consegna, «!» e «?» disegnati sopra i PNG (controllo
  `segni`, sotto le finestre), rombo dorato sulla minimappa (freccia sul bordo se lontano) e sulla mappa grande
  (`MappaGrande.punto_mappa`, anche nei dischi delle mappe lontane), riquadro del passaggio di livello, riga
  d'avanzamento. Tooltip delle caselle con i valori effettivi (potenziamento e rarità) e il confronto con il pezzo
  indossato («▲ +12 attacco» verde, «▼ -3 difesa» rosso, «✕ Serve il livello…»; `Casella._make_custom_tooltip`).
  Copione: `diario`, `missione accetta|consegna id|*` (aspetta il dialogo), `png ruolo` ora sceglie il PNG più vicino.
  Nota: nel container il client è lentissimo quando girano altri Godot (risposte del server mostrate dopo 1-2 minuti):
  nelle prove a schermo servono attese lunghe.
- Prove: `node tools/prove/missioni.mjs [porta]` (31 verifiche: prima missione automatica, segni, consegne, uccisioni,
  raccolta, premi della classe anche per l'Ombra con l'arco, Via, livello, incarichi e nuovo giorno, rientro e database,
  abbandono, personaggio vecchio senza `mis`, bottino per classe e livello).
- **Non verificati**: tempi della curva con giocatori veri (sono stime dal bot), Distesa col bot, missioni di gruppo e
  dell'arena giocate davvero, tooltip del confronto a schermo, client nel browser con i pezzi nuovi.

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
- **Versione per il browser** (l'autore: far giocare un amico «senza l'exe e senza fargli scaricare tutta sta roba»):
  preimpostazione «Web» in `export_presets.cfg` (senza thread: non servono intestazioni speciali) → cartella `web/`
  (ignorata da git: `index.pck` 62 MB, `index.wasm` 44 MB). `godot --headless --path godot --export-release "Web"
  ../web/index.html`, poi `npm run web:comprimi` (`tools/web/comprimi.mjs`: copie `.gz`, 67 MB da scaricare la prima
  volta). `server/index.js` la serve da `/gioca/` (`servWeb`: a flusso, ETag, gzip se c'è la copia). Nel browser
  `principale.gd` nasconde il campo del server e usa l'indirizzo della pagina (`Rete.ospite_web`, `wss://` se la pagina è
  in https: funziona dietro un tunnel). Il modello d'esportazione `web_nothreads_release.zip` non è nel container di
  base: lo si estrae dall'archivio ufficiale dei modelli 4.4.1 (1,2 GB) con richieste a intervalli, senza scaricarlo tutto
  (script `prendi.py`, tenuto nello scratchpad). Provato con Chromium senza scheda video (Playwright): accesso, elenco dei
  personaggi, ingresso nel mondo con terreno, piante, personaggio e interfaccia. **Non provati**: un browser vero con GPU
  (fluidità), suoni, tastiera e mouse in gioco, telefono, tunnel https.
- **Pacchetto «gioca da solo»** (l'autore: l'amico deve poter giocare «da solo sul suo pc senza che io apra nulla»):
  `npm run pacchetto` (`tools/pacchetto/solo.mjs`, dopo l'esportazione «Windows») → `esporta/solo/RegniDiGiada/` e
  `esporta/RegniDiGiada-solo-windows.zip` (117 MB): l'eseguibile più la cartella `server_locale/` (`server/`, `shared/`,
  `node_modules/ws` e il `node.exe` ufficiale 22.12 scaricato da nodejs.org con controllo dell'impronta, tenuto in
  `esporta/cache/`). Opzioni: `--piattaforma linux` (copia il Node in uso), `--node file`, `--gm` (l'account interno ha
  i comandi GM), `--niente-zip`. Client: `godot/script/solo.gd` (`Solo`): se accanto all'eseguibile c'è
  `server_locale/server/index.js` la schermata iniziale mostra «Gioca» (e «Gioca in rete con gli amici…» per i soliti
  campi); `Solo.avvia()` lancia Node senza finestra con `SOLO=1`, `PORT=31717` (se la porta è presa prova 31718 e 31719)
  e `DB_FILE` nella cartella dei dati dell'utente (`…/app_userdata/Regni di Giada/salvataggi/solitaria.json`: i
  personaggi restano quando si sostituisce la cartella del gioco), poi `principale.gd` riprova il collegamento finché
  il server risponde (fino a 45 s) ed entra con l'account interno `giocatore` (creato alla prima partita). Server
  (`SOLO` in `server/index.js`): ascolta solo su 127.0.0.1 (niente avviso del firewall), scrive in `server.log` accanto
  ai salvataggi, si spegne salvando dopo 10 s senza nessuno collegato (120 s all'avvio); il gioco non lo uccide mai.
  Prova automatica: `./RegniDiGiada.x86_64 -- --solo=Nome [--foto_inizio=1] --foto=cartella "--comandi=…"` (crea il
  personaggio se manca ed entra). Provato col pacchetto Linux sotto `xvfb-run`: prima partita da zero, seconda col
  personaggio già salvato, porta occupata da un altro programma, spegnimento del server alla chiusura.
  **Non provato su Windows** (nel container non c'è né Windows né Wine): avvio di `node.exe` senza finestra, percorsi
  con spazi o accenti, antivirus e SmartScreen sono da verificare sul PC dell'amico.
- **Difetto delle esportazioni corretto**: `terreno.png`, `variazione.png` e il font venivano letti come file, ma
  l'esportazione tiene solo le risorse importate: negli eseguibili (e nel browser) il terreno restava senza texture e il
  font era quello predefinito. Ora `Mondo.leggi_immagine` e `Impostazioni._metti_font` ripiegano sulla risorsa importata.
  Verificato con l'eseguibile Linux esportato (terreno e font giusti). Gli eseguibili Windows mandati fra il lavoro sul
  terreno dipinto e questa correzione avevano con ogni probabilità quel difetto.
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
  Giudizio dei Tuoni, edifici e personaggio con le texture nuove; poi pugnali +9, arco +12 e bastone +7 in mano, Mille Ombre,
  Collera del Cielo, Drago Celeste (rifatto: era un disco bianco) e il cerchio di rune dell'armatura +15 Leggendaria.
  Non visti: le scintille dell'aura dell'armatura (dal +9), l'arco nel momento del tiro. Il ricamo a fasce della stoffa è
  stato tolto (sui capi aderenti faceva anelli): ora sono punti radi.
- **Aspetto delle tecniche per livello dell'abilità** (richiesto dall'autore): il server manda il livello nell'effetto
  (`fx` `sk` con campo `l`); `Effetti.grado()` lo traduce in 5 gradi — Appresa (1), Affinata (5), Esperta (10), Maestra (15),
  Perfetta (20) — e `_arricchisci` aggiunge strati (rune, eco del colpo, più saette/proiettili, crepe e onda, sigillo
  d'oro e tinta dorata al 20); le forme principali crescono dell'8% a grado. Il grado compare nella finestra Abilità e nel
  tooltip. Comando GM `/abilita id livello` per provarli. Visto a schermo: Lama del Tuono ai livelli 1, 10 e 20.
- **Temi visivi per classe e Via** (richiesta dell'autore: «il tema delle abilità è molto tutto fulmini, diversifichiamolo per
  classe»): `Effetti.tema_di(sk)` ricava il tema dalla Via (`sk.via`), altrimenti dalla classe (`sk.cls`); `PALETTE` dà i tre
  colori del tema (il colore della tecnica non conta più, salvo la virata all'oro del grado Perfetta). Temi: **acciaio** (Lama
  base: fendenti netti, scintille di metallo), **fulmine** (Via del Fulmine: le uniche saette), **roccia** (Montagna: `lastre`
  che spuntano, `schegge`, crepe, polvere), **ombra** (Ombra base e Pugnali: `fumo` e `nube` viola, `taglio_ombra` scuro col
  bordo acido, `gocce`, `sagoma` = copie d'ombra), **vento** (Arco: scie d'aria, `petali` usati come penne, mirino dorato),
  **fiamma** (Monaco base e Ferro: impronte di palmo, onde calde, `fiamme`), **loto** (petali e fiori che sbocciano, onde
  verde giada), **astrale** (Mistico base e Tempesta: costellazioni, `stelle`, `raggio_luce`, vento stellato), **giada**
  (Benedizione: colonne verde-oro, sigilli, `cupola`). Ogni tema ha la sua funzione (`_acciaio`, `_roccia`, `_ombra`, `_vento`,
  `_fiamma`, `_loto`, `_astrale`, `_giada`) che sceglie per `fx`; le cavalcature (tema `neutro`) e ogni `fx` non previsto
  ricadono su `_generico` e, per le aure, su `_aura` (un `fx` sconosciuto non dà errori). `_arricchisci` (gradi), `_risonanza` e
  `_firma` (segno a terra di annuncio/Affinata) seguono il tema; le 4 Supreme (`_suprema`) hanno una regia per classe nel
  loro tema. Nuovi shader: `fx_forma` (mirino, loto, costellazione, sigillo di giada, palmo, vento, stella: `forma(pos, F_*, ...)`),
  `fx_ombra` (taglio scuro, fusione normale), `fx_cupola`; `fx_fendente` ha il parametro `bianco`. Texture di particelle
  (stella, petalo/penna) generate da codice. Leggerezza: particelle poche, `proiettile`/`fulmine` hanno `luce := false` quando
  ce ne sono molti (niente luci dinamiche in serie).
  **Scatti** (`fx: 'dash'`): `_carica` (Lama: scia a terra, polvere lungo il percorso, saette se Via del Fulmine, lastre se
  Montagna, impatto frontale) e `_teletrasporto` (Ombra: sbuffo di fumo alla partenza e un altro alle spalle del bersaglio,
  nessuna scia). Partenza da `fx`/`fz` del messaggio; l'arrivo da `tx`/`tz` se il server li manda, altrimenti si ricava dal
  bersaglio (davanti, o alle spalle per l'Ombra) perché chi scatta può non essere ancora stato spostato nel client.
  **Buff di classe** (`fx: 'buff_lama'`, `'buff_ombra'`, `'buff_monaco'`, `'buff_mistico'`: Grido di Guerra, Velo d'Ombra,
  Respiro del Drago, Benedizione degli Astri; `_buff_classe`): con `ally: 1` (effetto mandato agli alleati) la versione è ridotta.
  Prova senza server: `godot --path godot res://scene/prova_fx.tscn --fixed-fps 30 -- --classe=lama --lista=squarcio,carica@fulmine
  --cartella=/percorso --t=0.15,0.5 [--l=20] [--ris=1] [--dist=10]` (`id@via` forza la Via; `#polvere`, `#nube`, `#fumo`, `#forma`
  provano i mattoni; `base` fotografa la scena vuota); la scena di prova non è nel repository.
  Visti a schermo (scena di prova, Compatibilità): tutte le tecniche di base e di Via delle 4 classi, le 4 Supreme, i 2 scatti,
  i 4 buff, gradi 10/15/20 e Risonanza su alcune. **Non visti**: in gioco col server (solo la scena di prova), il rendering
  Forward+, i buff sugli alleati, `tx`/`tz` dello scatto, prestazioni con molti giocatori che lanciano insieme.
- **Kit a pochi tasti nel client Godot**: finale con Risonanza mostrato ad area (`Effetti._risonanza`), barra di lancio
  del bersaglio e barretta sulle targhette (`gioco.lanci_nemici`), cerchio a terra per i lanci ad area, scritta
  «INTERROTTO», il tasto dell'Interruzione lampeggia quando il bersaglio lancia e quello del finale quando c'è la
  Risonanza; ruoli rinominati (Colpo base, Colpo finale, Interruzione). Il client nel browser non è stato aggiornato ai
  nuovi kit: funziona ancora ma mostra testi e tacche dei ruoli vecchi.
- **Mappa grande, icone e font** (richiesti dall'autore dopo la sua prova): `mappa_grande.gd` (tasto M: mondo dipinto dai
  dati del terreno, zone con livelli, villaggi, strade, Sentieri Lontani, posizione propria; fasce 1-8 / 8-16 / 16-25
  ricavate dai livelli dei mostri); `icone.gd` (`Icone.disegna(ci, id, rett, spento)`: icone delle tecniche e degli effetti
  disegnate da codice al posto dei kanji; gli oggetti tranne le pozioni hanno ancora il glifo); font in `godot/font/`
  (Tahoma libero di Wine, LGPL: l'autore voleva «il font di Metin 2», cioè Tahoma di Microsoft, non distribuibile),
  caricato come file da `impostazioni.gd` `_metti_font` (il tema non attraversa CanvasLayer/Node3D: viene dato al primo
  Control di ogni ramo). Una classe nuova (`class_name`) dà errori al primo avvio senza editor finché la cache delle
  classi non è rigenerata: rilanciare una volta. Visti a schermo: mappa nel mondo aperto, font, icone in barra e finestra
  Abilità. Non visti: mappa da dentro le mappe lontane, icone degli effetti attivi, trascinamento.
- **Icone degli oggetti e oggetti a terra riconoscibili** (richiesta dell'autore: «quando droppano gli oggetti che si capisca cosa
  sono, in piccolo»). `icone_oggetti.gd` (`IconeOggetti`): icone di TUTTI gli oggetti disegnate da codice (stesso `Icone.Pennello` delle
  tecniche, niente kanji). `IconeOggetti.disegna(ci, id, rett, spento, rarita, potenziamento)` dentro un `_draw()`; `IconeOggetti.Vista`
  è il controllo pronto (id, rarità, `up`, `n`), `IconeOggetti.tooltip` la descrizione con l'icona grande, `IconeOggetti.texture` l'icona come
  texture (righe di chat). Il disegno si ricava dal TIPO, non da un elenco di id, quindi vale anche per gli oggetti nuovi: `weapon` → sagoma
  per `wt` (spada, pugnali incrociati, arco incoccato, guanto, bastone) e per `tier` 1-4 come in `forme_armi.gd` (ferro largo / sciabola con
  guardia a mezzaluna / giada con guardia cornuta e uncini / «Cento Gru» con ali; zanna / dentato / serpentino / eclissi; bambù / corno /
  airone / autunno con penne; bende / artigli / guanti della Tigre / guanti del Sole; salice / mezzaluna / anello / nubi); `body`, `head`,
  `feet` → corazza, elmo, calzari del `tier` (tunica / lamellare / giada / nubi, ecc.); `potion` (fiala del colore o tazza di tè), `scroll`,
  `book`, `seal`, `key`, `mod` (cote, rotolo con frecce, sigillo con freccia in su, scalpello), `gem` (sagoma per `gem`: rubino brillante,
  zaffiro esagonale, giada a disco forato, ambra ovale, onice ottagonale, perla; `grade` 0 = tre schegge, 1 = gemma, 2 = grande con alone e
  scintille, nel `color` dell'oggetto) e `material` (sagoma dalle parole dell'id/nome: zanna, pelle, benda, coccio, minerale, cristallo,
  essenza, osso, erba, lingotto, polvere; altrimenti sacchetto nel `color`). Id sconosciuti: runa generica. Fondo e cornice seguono la
  **rarità** (`IconeOggetti.rarita(id, voce)`: `r` dell'esemplare per l'equipaggiamento; per gli altri il `tier` o un valore dedotto dal prezzo),
  il «+N» del potenziamento sta in alto a sinistra. Usate in inventario, equipaggiamento, negozio (il fabbro usa l'inventario), barra rapida,
  trascinamento, tooltip (`Casella._make_custom_tooltip`), righe di chat del bottino e delle ricompense delle Prove (`hud.riga_chat_oggetto`;
  il server manda solo il nome dell'oggetto, l'id si ricava con `IconeOggetti.id_da_nome`). Gli effetti attivi e le tecniche restano in `icone.gd`.
  `oggetto_terra.gd` (`OggettoTerra`): l'entità di tipo «d» è ora un modellino da codice (0,3-0,8 m) che gira piano — le armi sono le stesse
  forme in mano (`Forme.spada/pugnale/arco/pugni/bastone`) infilzate o appoggiate, poi corazza, elmo, calzari, fiala, rotolo, tomo, sigillo,
  chiave, gemme (coni a doppia punta, anello di giada, perla), materiali per forma, pila di monete per `tael` — con alone sul terreno e una
  sottile colonna di luce (`shader/oggetto_colonna.gdshader`) nel colore della rarità, più alta dal Raro in su; dall'Epico qualche scintilla,
  dal Raro un lampo della colonna alla caduta (e un piccolo suono in `gioco._su_v`). L'etichetta col nome (colore della rarità, «+N», «×n»)
  la disegna `Hud._etichetta_oggetto` solo da vicino (12 m, un po' di più per le rarità alte), col bersaglio o col puntatore sopra. Nessuna
  luce dinamica e nessun campo nuovo dal server (il messaggio `v` dei «drop» portava già `it`, `n`, `up`, `r`).
  Prove: nel copione `butta id...` (getta una copia a terra, aspetta che sia nell'inventario), `raccogli`, `ricompense` (simula la riga delle
  ricompense di una Prova), `chiudi`, `reale N` (secondi veri), `aspetta_oggetto id`, `finche_oggetti N raggio`, `finche_vuoto raggio` e
  l'argomento `--attesa_comandi=N` (fotogrammi di attesa dopo ogni comando di chat, predefinito 3). Con la macchina sotto carico un fotogramma
  costa secondi e il server risponde dopo 2-3 fotogrammi, mentre gli oggetti buttati a terra durano solo 60 s: conviene aspettare le
  condizioni (`finche_*`) invece di contare i fotogrammi, e scattare subito. Corretto un errore che c'era già: `Entita.da_info` faceva
  `String(i.n)` con `n` intero (la quantità degli oggetti a terra) e l'entità non nasceva; ora `str()`.
  Visti a schermo: griglia di tutte le icone a 44 e 88 px e varianti di rarità, inventario, personaggio, negozio, oggetti a terra da vicino e
  da lontano. Non verificati: etichette degli oggetti con molti oggetti vicini, prestazioni con decine di oggetti, il tael a terra nel gioco
  (il server oggi non lo getta: è il bottino che va direttamente alla borsa), suoni all'ascolto.
- **Armi rifatte «cattive» e sempre più epiche col grado** (`forme_armi.gd`, geometria da codice nel sistema della presa;
  `equip.gd` le monta; `posa_arma.gd` è un `SkeletonModifier3D`): lame a sezione esagonale con filo chiaro, sagome estruse,
  tubi curvi. Spada: ferro largo → sciabola con guardia a mezzaluna → giada a due mani con guardia cornuta e uncini sul
  dorso → «Cento Gru» (1,5 m, ali di gru, uncini, incisioni luminose). Pugnali: zanna d'osso → acciaio dentato → lama
  serpentina con testa di serpe → eclissi scura con filo luminoso. Arco: bambù → corno → airone/autunno con ali di penne e
  punte a lama; corda in due tratti (`Equip.Corda`) e freccia incoccata. Pugni (ora costruiti, prima il Monaco non aveva
  nulla in mano): bende → artigli di ferro → guanti della Tigre → guanti del Sole con disco. Bastone: salice → mezzaluna →
  anello → corona di nubi con gemma sospesa che ruota; fino a 2,95 m.
  **Presa**: la lama sta ruotata di 90° (filo verso le dita, facce piatte all'esterno); `Equip.INCLINA` (spada 48°, bastone −12°,
  arco −60°), `Equip.RZ.staff` = −52° e `Equip.POSE` (chiusura delle dita, rotazione del polso, gomito) applicati da `PosaArma`
  dopo l'animazione. **Arco**: `Personaggio.tira_arco()` porta `tiro` a 1: cinematica inversa a due ossa (braccio sinistro
  teso con il telaio verticale, destro alla guancia, corda e freccia seguono la mano). Pugnali: attacchi `pugnali`, `pugni`,
  `pugni_2` (affondi). Gli effetti per potenziamento accendono solo le parti con metadato `accendi` (alone più tenue sulle
  armi corte). Visto a schermo (scena di prova + gioco): tutti i tipi e gradi, uomo e donna, da fermi, corsa, camminata,
  spada_1..3, pugni, calcio, magia, tiro con l'arco, +15 Leggendaria; il bastone anche in gioco col server.
  **Non verificato**: pugni a metà colpo (visti solo carica e calcio), la sella con le armi nuove, vecchi corpi Mixamo
  (la posa dita/polso è tarata sugli eroi), arco in gioco col bersaglio, prestazioni con molti giocatori (mesh da codice non
  condivise), scia dei colpi sulle forme nuove, aura dell'armatura. Difetti: lame con facce piatte senza texture, penne
  dell'arco un po' fitte, artigli dei pugni sottili, a riposo il bastone sfiora la gamba.
- **Effetti per classe e potenziamento** (richiesta dell'autore: «aumentiamo gli effetti e cambiamo colori e tipologia in
  base alla classe e al potenziamento»): `Equip.tema(tipo_arma, up)` → stile dalla classe (`STILE_DI`: spada = `fulmine`,
  pugnali/arco = `ombra`, pugni = `fiamma`, bastone = `astrale`) e colori dal passo (+7, +9, +12, +15: tabella `TEMI`).
  `effetti_arma(…, tipo)`: saette lungo la lama (`Equip.Saette`, nastri rifatti più volte al secondo), fumo scuro non
  additivo e gocce (`mat_fumo`), fiamme che salgono con anello di chi dal +12, stelle in orbita attorno alla cima.
  `aura_armatura(…, tipo)`: stesso tema attorno al corpo (archi, fumo ai piedi, fiamme dal suolo, stelle in orbita), ora
  dal +7; cerchio di rune dal +12. Prova: vetrina con `--gradi=4,4,4,4 --up=7,9,12,15`. Storia: l'autore aveva chiesto di
  «correggere» gli effetti e li avevo abbassati (abbagliavano), poi li ha voluti più ricchi: tenere le forme leggibili.
  **Bastone**: `Equip.Piombo` lo tiene quasi a piombo (85%) anche se la mano si inclina, presa a 1,14 m dalla base, braccio
  lungo il fianco (`POSE.staff`): prima il braccio era piegato sulla pancia e il bastone attraversava manica e veste.
  Ritocchi successivi («ritocca il ritoccabile»): saette più sottili con anima chiara e alone nel colore del tema; aura
  del Mistico con due corone di luci (a terra e sopra la testa) e più stelle in orbita; senza calzari si indossano i
  `sandali` (prima piedi nudi); sull'uomo crocchia e chioma lunga del pacchetto diventano `capelli_corti`.
  Visto a schermo in vetrina: le 4 classi ai 4 passi da fermi; Lama in corsa e in attacco, Mistico in attacco (video).
  Non visto: nel gioco col server.
- **Mondo più leggero e terreno con texture dipinte** (l'autore: «la mappa principale è molto pesante… più bello con
  texture migliori ma non più pesanti»). Misura con il comando `stat nome` del copione (disegni, triangoli, ms): nel
  container da ~3600-4000 disegni e ~4,2 milioni di triangoli a fotogramma a ~1200-2200 disegni e ~0,7-0,9 milioni; tempo
  del fotogramma (resa software, senza GPU: vale solo come rapporto) da ~1,3-1,6 s a ~0,76-1,0 s. Cosa è cambiato:
  `terreno.gdshader` campiona 8 materiali dipinti (`godot/texture/terreno.png`, atlante 4×2 da 512 px con altezza in
  alfa, generato da `python3 tools/godot/texture_terreno.py`; caricato come file in una `Texture2DArray` da
  `Mondo.strati_terreno`) al posto del rumore calcolato a ogni punto, con incastro per altezza ai confini e
  `texture/variazione.png` contro la ripetizione; piante divise in zolle di 64 m con distanza di vista (`_semina`);
  edifici dei villaggi fusi per materiale (`Edifici.fondi`); ombre del sole a 2 fasce fino a 95 m, atlante 2048, MSAA 2x
  in Alta e FXAA in Media; luci di lanterne e fucina che si spengono oltre 45-60 m; `Personaggio.sfoltisci` toglie i
  capi non indossati (erano un centinaio di mesh nascoste per personaggio); visuale fino a 620 m, nebbia un po' più fitta.
  Visti a schermo: villaggio, strada, campagna, altopiano. Non visti: altri due villaggi, neve e sabbia da vicino, mappe
  lontane (usano ancora `terreno_mappa` con il rumore). Restano ~1200 disegni nel villaggio: personaggi, PNG e obelischi.
- **Figure dei mostri** (richiesta dell'autore: ogni famiglia riconoscibile dalla sagoma, élite e capi col loro segno):
  `godot/script/mostri.gd` (`Mostri.crea(ty, voce)`, chiamato da `Entita._costruisci` prima dei ripieghi di prima) ha una
  ricetta per ogni tipo di `MOBS` (tabelle `BESTIE`, `LANTERNE`, `OMBRE`, `UMANI`, `STATUE`; ripiego per `model`).
  - Bestie: `tools/blender/mostri.py` → `client/assets/modelli/mostri.glb` (`python3 tools/blender/mostri.py --
    client/assets/modelli/mostri.glb`, poi `npm run godot:dati` e `--import`): stesso scheletro e stesse azioni di
    `animali.py` (`animali.glb` resta a cavallo e browser), 3400 triangoli a specie (suddivisione e poi Decimate; i pezzi a
    punta — orecchie, artigli, zanne, cresta — restano fuori dalla suddivisione, `netto=True`). Specie: `lupo` (con
    criniera corta), `lupo_capo` (alfa e anziano: petto e criniera grandi), `sciacallo` (snello, orecchie enormi),
    `cinghiale` (zanne ricurve, cresta irta), `cinghiale_ferro` (zanne di ferro e piastra borchiata), `orso`, `tigre`
    (basette), `scimmia` e `scimmia_urlatrice` (spalle alte, braccia lunghe sulle nocche, faccia nuda, coda arricciata;
    l'urlatrice con mantello di pelo e barba; attacco: si alza e schiaccia a due braccia). Orso e tigre attaccano di zampata,
    il cinghiale di zanne. Nel glTF: UV.x = casella della parte, UV.y = curvatura, UV2.y = occlusione dipinta.
    `Personaggio.quadrupede(file, specie, materiale, scala)` (prima era dentro `animale`; la libreria delle azioni ora
    tiene solo le sei azioni della specie esatta). Shader `bestia.gdshader` (+ `bestia.gdshaderinc`): colore per parte
    (pelo, ventre, criniera, occhi accesi, zanne, faccia, metallo, artigli), dorso scuro, ciuffi, strisce, sella scura,
    mezzaluna sul petto dell'orso, ventre luminoso; `bestia_spettro.gdshader` per la Tigre Spettrale (traslucida, strisce
    e contorno di luce). Un materiale per tipo di mostro, condiviso dal branco.
  - Lanterne (`Mostri.Lanterna`): carta a tornio con costole, volto arrabbiato ritagliato e luce da dentro
    (`lanterna_spirito.gdshader`: `crepe` per instabili e della cripta, `canne` per gli spiriti del canneto, `tremolio`),
    fiammella dello spirito sopra (`fiammella.gdshader`, quadrato rivolto alla visuale), nastri o catene che ondeggiano
    (`nastro.gdshader`). Ombre (`Mostri.Ombra`): veste e cappuccio traslucidi che si sfrangiano in fumo (`spettro.gdshader`),
    occhi accesi, maniche con artigli. Entrambe si animano da codice (`Mostri.Fluttuante`: fluttuare, inclinarsi in corsa,
    affondo, scossa da colpo, morte: la lanterna si spegne e cade, l'ombra si scioglie nel suolo).
  - Banditi: completi delle classi nei loro colori più accessori agganciati alla testa o al petto (`_accessorio`:
    `fazzoletto`, `velo`, `turbante`, `fascia_fronte`, `pittura`, `pelliccia`, `foglie`, `pennacchio`, `stendardi`) e capi
    del modello (cappello di paglia, elmo cornuto). Armi nuove sulla presa del bastone (`_arma_speciale`: `lancia`,
    `falcione`, `cerbottana`; il bastone resta di grado 1, quelli più alti hanno parti animate che si romperebbero).
  - Statue (`STATUE`): corpo e vesti con `statua.gdshader` (`materia` 0 argilla con resti di pittura, 1 bronzo con patina,
    2 arenaria a strati, 3 pietra scura; crepe che possono brillare, foglia d'oro), occhi accesi per le élite; il Custode
    Insonne ha l'aureola di rune. Generale: corazza nera e oro, falcione, pennacchio e due stendardi sulla schiena.
  - Élite (vita ≥ 1000, come il server) e capi: figura più grande dell'8-12% e anello a terra (`alone_mostro.gdshader`,
    additivo, doppio con punte per i capi). Nessuna luce dinamica, mesh e materiali condivisi (`Mostri._cil`, `_sfera`).
  - **Bestiario** senza server: `godot --path godot res://scene/bestiario.tscn --fixed-fps 30 -- --gruppo=lupi|bestie|
    spiriti|banditi|statue|capi [--lista=id,id] [--posa=fermo|passo|corsa|attacco|morte] [--yaw=3.6] --foto=x.png`.
  L'anello si spegne alla morte (`Personaggio._segno_elite`). Visti a schermo: tutte le figure nel bestiario (davanti e
  dietro per capi e banditi; bestie in corsa, attacco e morte; lanterne e ombre in attacco e morte); in gioco col server
  un branco di lupi, branchi di cinghiali, banditi e lanterne che combattono. Non visti: in gioco scimmie, statue, tigri,
  ombre e capi (i `/spawn` in fila del copione ne fanno nascere solo i primi); camminata delle figure fluttuanti;
  prestazioni con molti branchi in vista; resa Forward+. Gli obelischi restano quelli di `obelischi.gd`.
  Difetti noti: niente stivali sui corpi (i capi `stivali_*` del modello sono solo piastre: piedi nudi anche per
  generale e statue), criniere dei lupi a ciocche un po' regolari, la morte delle bestie è quella di `animali.py`.
- Da fare: corpi base originali con volto (il manichino resta il limite più evidente), edifici veri fatti in Blender, resa con Forward+ da guardare su PC con GPU, suoni veri al posto di quelli sintetici.
- **Mappe lontane con texture dipinte e villaggi con più carattere** (seguito della voce sopra: «migliora tutto il
  migliorabile»). Mappe: `terra_lontana.gd` usa ora `terreno.gdshader` (nuovo parametro `centro`) con 8 strati scelti fra
  due atlanti (`TerraLontana.STRATI`, `Mondo.strati_da(["m0", "t4", …])`); secondo atlante `godot/texture/terreno_mappe.png`
  (`fai_mappe()` in `tools/godot/texture_terreno.py`: muschio, foglie di bambù, terra umida, roccia muschiosa, sabbia
  rossa, arenaria, argilla crepata, ghiaia del deserto). I pesi (1 px = 2 m) si calcolano una volta per mappa in
  `_pesi` da pendenza, quota, rumori `FastNoiseLite` in blocco, sentieri arrivo → centro → obelischi, lettiera sotto i
  bambù, erba secca attorno ai cespugli, lastricato attorno all'arena e viali dalle porte (0,3-0,7 s nel container
  carico). Piante a zolle con `Mondo.semina` (statica, condivisa); i fusti dei bambù (1372 triangoli l'uno, 4017 nella
  Selva) senza ombra e visibili fino a 120 m. Arrivo, rovine e arena passano da `Edifici.fondi`. `terreno_mappa.gdshader`
  tolto. Villaggi (`edifici.gd`, `Mondo._dettagli_villaggio`): tetti con code ricurve al colmo, punte e campanelle agli
  angoli (`tetto(..., ornati)`), griglia dei tetti in proporzione (le mura passano da 1568 a ~190 triangoli a tratto);
  case con tendina sulla porta, insegna dorata (motivo astratto) e lanterne di carta alla gronda; porte con basi di
  bronzo, mensole, targa e secondo tetto; mura più alte con coronamento; torri ottagonali sugli ostacoli dei tratti ai lati
  di ogni porta e lungo il giro, con stendardi del regno; fili di lanterne fra le gronde (sopra la testa); bancarelle con
  merci (armi: lame, scudi, lance; erbe: ceste, vasi, mazzi appesi); piazza lastricata con cordolo e, al posto del pozzo
  (stesso ostacolo), un elemento per regno: braciere della Fenice (con luce), stele della Tigre, fontana del Drago;
  casse, botti e pini in vaso dentro la fascia d'ostacolo delle mura. Niente di nuovo sta dove il server lascia passare.
  `Edifici.fondi` ora fonde anche le mesh con figli (prima tetti e stendardi restavano fuori: un disegno ciascuno).
  Copione: `vicino x z` aspetta che il personaggio arrivi dopo un `/tp` (con la macchina carica la risposta tarda minuti).
  Misura (`stat`, vecchio e nuovo in parallelo con due server; ms molto rumorosi, contano disegni e triangoli):
  Selva 841 → 887 disegni, 7,03 → 2,19 milioni di triangoli; Distesa 958 → 959, 514k → 391k; Arena 1326 → 836, 438k →
  472k. Villaggi (dalla porta / in piazza): Fenice 1386 → 1341 e 727k → 665k / 1226 → 1249 e 659k → 681k; Tigre
  1427 → 1389 e 669k → 605k / 1186 → 1236 e 593k → 662k; Drago 1355 → 1306 e 643k → 581k / 1162 → 1209 e 483k → 536k.
  In piazza i triangoli salgono del 3-12% (i tetti fusi non si scartano più a pezzi fuori vista; i PNG che si muovono
  danno ±7% fra una prova e l'altra), dalla porta scendono dell'8-10%; ms invariati entro il rumore.
  Visti a schermo: le tre mappe (arrivo, dall'alto), i tre villaggi (porta e piazza). Non visti: Forward+, l'interno delle
  mappe lontano dall'arrivo, i villaggi di notte; le lanterne di carta non fanno luce vera (solo emissione).
- **Destrieri per classe** (richiesta dell'autore: «cavalli veri e in base alla classe, tematizzati; a livello massimo
  effetti sempre tematizzati molto importanti»; niente cerchi o linee a terra: «proprio effetti»).
  `tools/blender/destrieri.py` → `client/assets/modelli/destrieri.glb` (`python3 tools/blender/destrieri.py --
  client/assets/modelli/destrieri.glb [--solo lama] [--anteprima cartella] [--niente-glb]`, ~15 s; poi `npm run godot:dati`
  e `--import`). Il corpo nasce da sezioni anatomiche (tronco, collo, testa, zampe con ginocchia, garretti e nodelli,
  masse di spalla e groppa) fuse in una pelle sola col Remesh a voxel, lisciata (molto sul tronco, poco su zampe e muso)
  e ridotta a ~2700 triangoli con le normali della pelle fitta; pesi col calore delle ossa di Blender. Parametri per
  classe (`CLASSI`: tronco, fondo, zampe, collo, collo_alto, testa, muscoli, crini): **Lama** destriero da guerra massiccio,
  baio scuro con lista e balzane; **Ombra** corsiero nero asciutto, criniera rasata a cresta, occhi accesi; **Monaco** sauro
  compatto dai crini biondi, quattro balzane; **Mistico** bianco pomellato slanciato, collo alto, crini lunghissimi.
  Scheletro proprio (30 ossa: `hips, spine, chest, neck1, neck2, head, spalla/avambraccio/stinco_a/piede_a_L/R,
  coscia/gamba/stinco_p/piede_p_L/R, tail1-3, ear_L/R`, più `crini` = vento della criniera, `sella` = seggio, `muso`).
  **Godot rinomina le ossa degli scheletri dopo il primo dello stesso file (`hips_2`, `hips_3`…)**: usare
  `Destrieri.osso(sk, nome)` / `Destrieri.suffisso(sk)`, mai `find_bone` col nome nudo.
  Azioni `<classe>:fermo|passo|corsa|impennata` (classe `Andatura`: il corpo si muove come deciso e le zampe seguono
  il nodello con la cinematica inversa, zoccoli fermi in appoggio; corsa = galoppo a tre tempi con sospensione, 14
  fotogrammi: a 12-16 m/s la falcata è di 6-7 m come un cavallo vero).
  Finimenti in oggetti `<classe>_tAB` (visibili dal passo A al passo B; passi = livelli 1-5, 6-12, 13-19, 20:
  `Destrieri.PASSI`), costruiti con `p_avvolgi` (gusci attorno a un asse, anche a file di lamelle), `p_drappo` (stoffa che
  pende a piombo), `p_cinghia`, `p_tubo3d`, `p_arcione`, `p_nappa`, `p_anello`, `p_placca`. Lama: sella laccata → pettorale
  con lo specchio → pettiera e groppiera a lamelle, gualdrappa del regno, frontale di ferro → gorgiera a lamelle, corna
  d'oro, pennacchio, stendardi. Ombra: cuoio borchiato e bisacce → maschera d'acciaio, collare a punte, sciarpa del
  regno → mantello rosso lacero, lame sulla cresta, pugnali. Monaco: cavezza e corde, grani e nappe → collana di grani,
  sonagli, stuoia → anelli d'oro alle zampe, disco del sole. Mistico: gualdrappa ricamata → pendenti di giada, disco di
  giada, talismani → drappo del regno sulla groppa, diadema, mezzaluna, nastri.
  Dati per lo shader (niente texture): UV.x = casella della parte (`SLOT`), UV.y = curvatura o metri dal bordo × 2,
  UV2 = (metri lungo il pezzo / 4, occlusione), colore dei vertici = posizione a riposo (macchie, balzane, lista e
  pomelli restano fermi sul mantello) e in alfa quanto il crine è libero. `destriero.gdshaderinc` + `destriero.gdshader`
  (corpo) e `destriero_finimenti.gdshader` (due facce); orli ricamati col motivo della classe.
  Client: `destrieri.gd` (`Destrieri.crea(classe, livello, regno)` → `Destrieri.Destriero`, un `Personaggio` con `muovi`,
  `impenna()`, `posto()`; tabella `CLASSI` con mantelli, materiali e taglia; materiali condivisi per classe e regno).
  `Entita.in_sella(livello)` prende ora il **livello** del destriero (`sella` = livello): sceglie il destriero dalla classe
  (`info.cls`), impenna alla salita, e a ogni fotogramma siede il cavaliere sull'osso `sella` (`_siedi`: segue sobbalzi e
  impennata; i fianchi letti dalla posa vanno sul seggio). `posa_sella.gd` apre e abbassa le cosce sopra l'animazione
  «sella». Il server manda il livello agli altri in `ml` (accanto a `mt`, che resta per il browser).
  **Effetti del livello 20** (`Destrieri.EffettiDestriero`, shader `destriero_fx` con fiamma / stella / ciuffo di saette
  su quadrati rivolti alla visuale, `destriero_sagoma`): Lama saette agli zoccoli, sugli stinchi, lungo la criniera e
  attorno al corpo, scintille e scie elettriche al galoppo; Ombra fumo che cola da criniera e coda, lingue viola, occhi
  di brace, sbuffi agli zoccoli e tre sagome in ritardo al galoppo (copie della pelle sullo stesso scheletro); Monaco
  fiamme su zoccoli, criniera e coda, faville, veli caldi, strisce di fuoco; Mistico stelle in orbita con la scia, stelle
  su criniera e coda, corona di stelle sopra la testa, polvere di stelle. Criniera, coda e zoccoli hanno luce propria
  nello shader (`stile_luce`). Nessuna luce dinamica, nessun segno a terra; ~40-90 particelle e 10-25 quadrati a destriero.
  Triangoli (corpo con crini e zoccoli / con i finimenti ai passi 1-4): Lama 4,1k / 4,8k-5,9k; Ombra 3,5k / 4,1k-4,8k;
  Monaco 4,0k / 4,7k-6,3k; Mistico 4,1k / 4,7k-5,9k. `destrieri.glb` 1,6 MB.
  **Scuderia** senza server: `godot --path godot res://scene/scuderia.tscn --fixed-fps 30 -- [--classi=lama,ombra]
  [--livelli=1,6,13,20] [--cavaliere=1 --equip=1] [--posa=fermo|passo|galoppo|impennata] [--corre=1] [--fasi=7
  --azione=corsa] [--vecchio=1] [--spento=1] [--yaw=1.1 --zoom=1 --mira=1.3 --su=0.2 --cx=0] --foto=x.png [--film=4]`.
  `tools/blender/anteprima.py`: anteprima di una mesh con numpy, senza GPU (usata da `--anteprima`).
  Visti a schermo (scuderia): le 4 classi ai 4 passi, con e senza cavaliere, fermi, galoppo (anche in movimento con le
  scie), impennata, fasi del galoppo; in gioco col server Lama, Ombra e Mistico al livello 20 (salita con impennata,
  galoppo con sagome e fumo). **Non verificati**: destrieri degli altri giocatori in gioco (`ml`), il passo (solo le
  fasi), prestazioni con molti destrieri al 20, Forward+, tecniche a cavallo sopra il destriero nuovo, cavaliere donna
  su tutte le classi (vista solo la Mistica), client nel browser (usa ancora `animali.glb`).
  Difetti noti: barda e drappi sono rigidi (al galoppo le zampe li attraversano un poco), le mani non reggono le
  redini e l'arma resta in pugno, ciocche della criniera piatte viste da vicino, la criniera lunga del Mistico al
  galoppo si alza troppo compatta, le fiamme perse dagli zoccoli del Monaco sono globi tondi, Ombra ai passi 1-2 poco
  diversa (nero su nero).
- **Tecniche a cavallo per classe** (l'autore: «fammi anche le spell della cavalcatura dedicate per classe»): al posto
  delle quattro uguali per tutti, quattro per classe (`MOUNT_SKILLS[classe]`, `mountSkillsOf` in `shared/data.js`), ai
  livelli 1, 5, 10 e 15 del destriero (`hlvl`); il livello della tecnica è quello del destriero, non usano risorsa né
  tempo di lancio, ognuna ha la sua ricarica e si usano galoppando. **Lama** Falciata dalla Sella · Carica Travolgente
  (in linea, stordisce) · Impennata di Ferro · Galoppo del Tuono (carica lunga + tre scariche); **Ombra** Lame al Galoppo
  (un Marchio a ogni colpito) · Passaggio Tagliente (attraversa il bersaglio, due Marchi) · Agguato dal Buio (alle
  spalle, fa esplodere i Marchi e a catena quelli vicini) · Branco d'Ombre (quattro sagome che inseguono, un Marchio
  l'una); **Monaco** Onda Ardente (in linea oltre il bersaglio) · Zoccoli di Fiamma (scia di fuoco per 5 s) · Balzo della
  Gru Ardente · Ruota del Sole (tre giri che seguono il cavaliere, lasciano in fiamme); **Mistico** Dardi d'Astri · Velo
  di Stelle (difesa e passo, anche al gruppo entro 15 m) · Cometa · Pioggia di Stelle (sei scrosci che seguono).
  Campi nuovi del motore (`resolveSkill`, valgono per qualsiasi tecnica): `linea` (colpisce chi sta entro N metri dalla
  linea percorsa; `lineaOltre`), `oltre` (lo scatto finisce N metri dopo il bersaglio), `segue: 'se'|'bersaglio'` (le
  ondate seguono chi lancia o il bersaglio), `scia` (tratti a terra che bruciano chi li calpesta). Le tecniche
  dell'Ombra erano nate con le Ferite del kit bocciato: ora usano `marca` ed `esplode` come a piedi.
  Client: `tecniche_destriero.gd` (`TecnicheDestriero.tecnica`, chiamata da `Effetti.tecnica` quando la tecnica ha
  `mount`: effetti per tecnica nei colori del destriero, niente segni a terra), barra in sella, icone, scuderia.
  Prova: `node tools/prove/destriero.mjs [porta]` (134 verifiche; `--misura` dà i danni al secondo in sella).
  Viste a schermo in gioco le quattro tecniche di ogni classe sui fantocci. **Non verificati**: taratura dei danni in
  sella rispetto a quelli a piedi (non misurata dopo il passaggio ai Marchi), in movimento vero col galoppo, in gruppo,
  il client nel browser (mostra le tecniche ma con gli effetti vecchi).
- Da fare: corpi base originali con volto (il manichino resta il limite più evidente), edifici veri fatti in Blender,
  modelli per scimmie e banditi, resa con Forward+ da guardare su PC con GPU, suoni veri al posto di quelli sintetici.

## Mappe da esperienza e Arena PvP
- Definizioni in `shared/mappe.js` (nessun import: lo importano `data.js`, che aggiunge `MOBS_MAPPE` a `MOBS` e
  `NPC_MAPPE` a `NPC_ROLES`, e `world.js`, dove `heightAt`, `safeZoneAt` e `zoneAt` passano alle mappe per x > `MAPPE_X` = 5000).
  **Selva dei Mille Steli** (centro 6000, 0; raggio 160; livelli 30-40, minimo 28), **Distesa dei Venti Rossi** (7000, 0;
  raggio 170; 40-50, minimo 38), **Arena del Loto Cremisi** (8000, 0; pavimento di raggio 58, 4 porte con nicchie sicure).
  Terreno da `altezzaMappa` (stessa funzione per server ed esportazione), arrivo pianeggiante e sicuro, confine circolare.
- Server in `server/mappe.js` (metodi aggiunti a World con `installaMappe`): branchi e obelischi (`initMappe`), PNG `guida`
  (anche nei villaggi, `VILLAGE_LAYOUT.npcs`) e `araldo` (nicchie dell'arena), messaggio `viaggio` (`info`/`vai`/`torna`),
  PvP dell'arena (`pvpArena` in `canAttack`, `alleato` per cure e sostegno), uccisioni annunciate (`arena_k`) e classifica
  della sessione (`arena`), rinascita a una porta (da soli dopo 5 s), nessuna perdita alla morte nell'arena.
  Al login: chi era in una mappa da esperienza riparte dal suo arrivo (se ha il livello), dall'arena si torna al villaggio.
  Comandi GM: `/tp selva|distesa|arena`.
- Client Godot: `mappe.gd` (geografia e altezze da `dati/mappe.bin`), `terra_lontana.gd` (terreno, piante, arrivo, rovine,
  arena costruita da codice), `viaggi.gd` (finestra della guida, classifica, annunci); shader `terreno_mappa` e `arena`.
  Gli shader `pietra`, `intonaco` e `roccia` hanno il parametro `origine`: lontano dall'origine il rumore perde precisione,
  quindi nelle mappe i materiali si copiano con il centro della mappa (`TerraLontana._localizza`).
- Prova con bot: `node tools/prove/mappe.mjs [porta]` (27 verifiche: viaggi, mostri, obelisco, ritorno, confini, arena, gruppo, rientro).
  Viste a schermo nel client Godot: le tre mappe con i loro temi e gli obelischi dentro Selva e Distesa.
  Non viste: la finestra dei viaggi, la classifica dell'arena, i branchi del mondo aperto e l'uscita dai muri nella cripta.
- Revisione del server (controllore): corretti viaggio con mappa inesistente (faceva cadere il server; ora `Object.hasOwn`
  e try/catch attorno a `world.handle`), sostegno dalle nicchie dell'arena (`alleato`), finale della Via nella barra al
  login (`autoQuickbar` in `addPlayer`), veleni e ondate azzerati da `viaggia` e alla morte, `interrompi` con `canAttack`.
  Deciso: l'arena resta PvP anche con `cfg.pvp` spento (ci si entra apposta dall'Araldo; `cfg.pvp` vale per il mondo
  aperto). Corretto: un tentativo di stordimento respinto in PvP non rinnova più la finestra di 15 s (prima l'immunità
  con più storditori non finiva mai); la finestra riparte solo dagli stordimenti andati a segno.
- Nota per l'orchestrazione con agenti: mai `pkill -f "node server/index.js"` (uccide i server degli altri agenti):
  chiudere solo per porta, `kill $(lsof -ti tcp:PORTA)`.

## Livello alto: boss del mondo, Forgia, stagioni dell'Arena, imprese (fatto)
Richiesta: contenuto dal 30-40 in su e ragioni per rigiocare. Dati in `shared/altolivello.js` (nessun import: `data.js`
aggiunge `MOBS_ALTO` a `MOBS`, `OGGETTI_ALTO` a `ITEMS` ed esporta `PROVE = { cripta: DUNGEON, forgia: FORGIA }`), logica
in `server/altolivello.js` (installato su World come `mappe.js`/`missioni.js`), client in `godot/script/altolivello.gd`.
- **Meccaniche dei boss** (campo `mecc` del mostro, `bossMecc`): fasi a soglie di vita (annuncio, `rinforzi`, `furia`,
  `zoneOgni`), lanci interrompibili a rotazione (usano `m.cast` di `updateMob` con `def`: interrotti tolgono `post` di
  Postura), cerchi a terra sotto ogni giocatore con pozze ardenti (`warn` → colpo, `hazard`; `this.pozze`), anello attorno
  al boss (`lontano` = allontanarsi, `vicino` = stringersi, fx `warn` con `in: 1`), corazza (`scudo`: danni −85% finché i
  servitori sono in piedi, poi Squilibrio; `m.riduzione` in `mitigate`), **furia a tempo** (`furiaS`, `FURIA`: onda ogni
  2 s e cure ricevute −75%, `antiCura` in `heal`). Senza avversari per 6 s un boss con `mecc` torna al suo posto e si
  ricompone (niente vittorie rinascendo sul posto). Stato al client ogni 0,5 s (`boss`: fase, corazza, secondi alla furia).
- **Boss del mondo a tempo** (`BOSS_MONDO`): Colosso Ardente (liv. 32, Valle delle Braci a nord, 0/206; modello
  `terracotta` ×2,8 color brace), Madre delle Canne Cantanti (liv. 40, Selva; `tiger` ×2,6 verde giada), Re del Miraggio
  Rosso (liv. 50, Distesa; `general` ×2,5 rosso sabbia). Ogni 45-75 min, avvisi a tutti 5 e 1 minuto prima e alla
  comparsa, `boss_mondo` (elenco con posizione e conto alla rovescia: teschio sulla mappa grande e sulla minimappa). Se
  nessuno lo sfida se ne va dopo 20 min. Premi personali (`premiBoss`) a chi ha almeno 20 s di presenza in combattimento
  entro 45 m o il 3% dei danni: 2 pezzi della classe (Rari o meglio), 25% un **pezzo unico** del boss (garantito alla 4ª
  uccisione senza: `ch.pieta`) con due bonus fissi (`fissi`), trofeo, essenze, gemma, tael, 6% di livello. I pezzi unici
  (`boss` nella voce) sono esclusi dal bottino normale (`bottino.js`). Le arene dei boss restano libere dai branchi.
- **Forgia del Drago Addormentato** (`FORGIA`, dal livello 35, 18 min, stesso Sigillo della Cripta; la pianta è stata
  rifatta: vedi «Prove del Sigillo: piante a strade»): allora 9 stanze (muri
  ricavati con `muriDaStanze`), Fabbri di Cenere, Cani di Brace, Spiriti della Fornace (lancio), Martellatori (élite con
  lancio ad area), boss **Yan, il Cuore della Fornace** (`general` ×2,2 rosso scuro: Colata Ardente da interrompere, Martello
  del Drago a terra, Cani al 75%, Corazza di Brace al 50% con 3 Mantici Ardenti da spegnere, furia al 20%). Le Prove ora
  leggono la definizione da `inst.dg` (ex `DUNGEON` fisso); il Custode offre entrambe (`trial` con `prove`, `open` con `p`).
  Premi della Forgia dal livello 40, un'essenza e il 40% di tael in più; `ch.prove[id]` = migliore superata.
  Client: `Cripta.crea(ox, oz, id)` con `tema` (muri bruniti, lumi arancio, canali di lava, incudini, fornace).
- **Arena: stagione settimanale** (`db.data.arena`: `sett`, `cl`, `campioni`, `storico`): 10 punti a uccisione (+2 a
  uccisione in serie fino a +10, +5 se si spezza una serie ≥3, −2 alla caduta, 2 punti contro chi ha 10 livelli in meno,
  zero dalla 3ª uccisione della stessa vittima in 10 min). Gli stessi punti diventano **onore** (`ch.onore`), da spendere
  dall'Araldo (`NEGOZIO_ONORE`: titoli, essenze, gemme, Sigillo dell'Ascensione, tael). A fine settimana i primi tre
  ricevono onore e tael, il primo il titolo «Campione della Settimana» per la settimana dopo.
- **Imprese e titoli** (`IMPRESE`, `TITOLI`; `ch.imp`, `ch.impFatte`, `ch.titoli`, `ch.titolo`): boss abbattuti, Forgia,
  sigillo +8/+15 in tempo, 25/100 abbattuti nell'arena. Il titolo scelto va nelle info (`ti`) e compare sopra il nome.
  Tasto **J**: imprese, titoli e calendario dei boss. Comando `/titolo [id]`.
- GM: `/boss` (elenco), `/boss id` (compare ora), `/boss id qui|via|tra minuti|vita 0.6|furia`, `/boss vita 0.5` (boss
  con meccaniche più vicino, anche nella Forgia), `/onore n`, `/stagione [chiudi|punti n]`, `/impresa id`.
  Variabile d'ambiente `GM_EXTRA=a,b` (solo prove con più bot) in `server/index.js`.
- **Prove**: `node tools/prove/altolivello.mjs [porta]` (33 verifiche). **Taratura**: `node tools/sim/boss.mjs --boss id
  --vie fulmine,arco,tempesta [--livello N] [--goffi] --porte 3977-3978` (bot di `farming.mjs`, ora anche modulo: rinascono
  sul posto, interrompono, schivano). Misura (velocità 3, una prova, equipaggiamento comune +0 del livello del boss):

  | boss | 3 bot | 2 bot | 1 bot |
  |---|---|---|---|
  | Colosso (32) | 155-167 s (goffi 118 s, 4 morti) | 208 s, 1 morto | furia a 300 s, muore, boss si ricompone |
  | Madre (40) | 146 s | 216 s | furia, al 80% |
  | Re (50) | 178 s | 256 s, 2 morti | furia, al 77% |
  | Yan (38, fuori dalla Prova, 180000 vita = sigillo +2 per 4 giocatori) | 70 s | — | 208 s |

  Il bot è perfetto e a latenza zero: i giocatori veri ci metteranno di più. Da sapere: i bot «goffi» (che non schivano)
  battono il Colosso bevendo più ginseng (le pozioni non hanno ricarica: è il limite del sistema), la Forgia non è stata
  misurata in una Prova vera con la scala del sigillo.
- Client: `rete.gd` legge fino a 4 MB a fotogramma (prima 64 KB: a pochi fotogrammi al secondo, vicino a un boss, i
  messaggi arrivavano con minuti di ritardo); il riquadro della Prova mostra il nome del boss (`bossName` in `dg`).
  Copione: `imprese`, `esci_prova`, `spendi vit N`, `prova open forgia`. Foto: boss con fasi e lanci, zone, mappa, premi,
  imprese, finestra del Custode, Forgia (sale, Yan con corazza e mantici), Araldo.
- **Non verificati**: Forgia giocata da un gruppo vero e il suo tempo, aspetto dei boss (modelli esistenti riscalati e
  tinti: servono figure proprie), annunci e premi con molti giocatori, chiusura della stagione a cavallo della mezzanotte
  di lunedì col server acceso a lungo, client nel browser (non mostra nulla di tutto questo).
## Prove del Sigillo: piante a strade, varianti settimanali, architettura (fatto)
Richiesta dell'autore: «rifacciamo anche i dungeon, grafiche migliori e strade diverse». Le due Prove (Cripta delle
Mille Lanterne, Forgia del Drago Addormentato) non sono più una fila di stanze. Tempo, forze richieste (100%), sigillo,
affissi, boss e loro meccaniche sono quelli di prima.
- **Dati** in `shared/prove.js` (nessun import; `PIANTE.cripta|forgia`): `stanze` (id, nome, `tipo` ingresso/corridoio/
  bivio/sala/ponte/passerella/cancello/tesoro/boss, rettangolo, `ala`, `porta`), `ali` (nome, colore, nota), `porte`
  (`apre: 'branco'|'leva'`), `leve`, `vuoti` (abisso, lago di lava: non si calpestano ma lasciano passare vista e colpi a
  distanza), `ostacoli` [x, z, raggio, forma], `branchi` (con `ala`, `apre`, `tesoro`), `pericoli` (trappole a tempo),
  `ritorni` (Braciere del Ritorno), `tesoro`, `varianti`. `componiPianta(id, v, porteAperte)` dà la pianta giocabile
  (`rooms`, `walls` con tipo 0 muro / 1 parapetto / 2 roccia, `packs`, `frane`, `porte`, confini): `DUNGEON` e `FORGIA`
  tengono la pianta «tutta aperta» (per chi non conosce le varianti: il client nel browser), il server compone quella
  dell'istanza. Mostri nuovi `MOBS_PROVE`: Guardiano dei Sigilli, Avaro Sepolto, Scoria Vivente (élite).
  - **Cripta**: Soglia → Discesa → **Rotonda dei Tre Sentieri** → tre strade fino alla **Sala dei Sigilli** → Custode.
    Ovest *Catacombe dei Sussurri* (lunga, molte Ombre, forze 46%), centro *Via dei Guardiani* (corta: il Guardiano dei
    Sigilli tiene chiuso il cancello, 33%), est *Galleria delle Lanterne* (lanterne che tirano da oltre l'abisso e i Fuochi
    sul ponte, 44%); sale comuni 42%; dalla Sala dei Sigilli si scende alla **Camera delle Offerte** (Avaro Sepolto, 14%).
    Varianti: una delle tre strade è franata (il varco murato si vede dalla sala).
  - **Forgia**: Bocca → **Sala delle Incudini** affacciata sul **Lago del Crogiolo** → due archi attorno al lago fino
    alla **Terrazza del Drago** → Cuore della Forgia. Ovest *Fonderia* (lunga, sfiati di lava, 52%), est *Galleria dei
    Mantici* (due Martellatori e i magli, 46%), in mezzo il **Ponte del Crogiolo**, sommerso: lo fa emergere la leva sulla
    Terrazza (scorciatoia per chi rinasce e unica via per l'**Isola** con la Scoria Vivente e lo scrigno, 14%); sale comuni
    42%. Varianti: colata sul tratto di mezzo dell'arco ovest o est (le due metà restano vicoli ciechi), oppure ponte già emerso.
  - Variante = settimana (`varianteSettimana`, le due Prove sfasate); il Custode la annuncia nella finestra e in chat.
    Forze: le due ali aperte insieme superano sempre il 100%; un'ala sola + tesoro arriva al 100% con l'ala lunga.
- **Server** `server/prove.js` (installato su World): `inst.dg` è la pianta dell'istanza e si ricompone quando una porta
  si apre (`apriPortaProva`); `dg_start` porta `pianta` { v, stanze, porte, rit, tes }, `dg` ogni secondo `po`, `rit`,
  `tes` e `chi` (posizioni dei compagni). **I muri ora valgono anche per il server** (prima solo il client li
  rispettava): `passoLecitoProva` in `onMove` (margine 0,3 m; al più due varchi fra i due punti), `scattoProva`
  (ci si ferma al primo muro, vuoto od ostacolo: niente Passo di Luce oltre l'abisso), mostri che camminano per stanze
  (`prossimoPasso` sul grafo dei varchi, `fuoriDagliOstacoli`) e si accorgono/colpiscono solo con la vista libera
  (`vedeProva`); `/tp` e nascite vanno al punto libero più vicino. Branchi legati (`m.pk`: il primo che ti nota chiama i
  suoi), leve (un vivo entro 2,6 m), Braciere del Ritorno (chi cade rinasce lì), trappole (`tickProva`: preavviso `warn`,
  poi danno a chi è nel cerchio), scrigno (un pezzo, un'essenza e il 30% di tael in più a fine Prova).
  GM: `/pianta n` (forza la variante delle Prove che apri), `/invisibile` (i mostri non ti vedono: per foto e prove).
- **Client Godot** `cripta.gd` riscritto: `Cripta.crea(ox, oz, id, pianta)`, `passo` (scivola lungo muri e ostacoli),
  `visuale_libera`, `aggiorna_stato` (cancello che scende, ponte che emerge, braciere, scrigno), `Cripta.ambiente(id)`.
  Tema per Prova (`TEMI`). Cripta: conci con fregio a greca, pilastri, nicchie con statue, sarcofagi, urne, radici,
  stendardi, lanterne appese nel colore dell'ala, nebbia bassa, lame di luce, abisso con lanterne sospese, guardiano
  gigante con l'aureola nella sala del boss. Forgia: basalto fasciato di ferro con fessure incandescenti, lago e colate di
  lava, canali sotto le grate, incudini, crogioli, mantici che soffiano, catene, la fornace con gli occhi del drago; il
  «Mantice Ardente» di Yan è un mantice vero (`Cripta.mantice_ardente`). **Segni**: ogni varco di un'ala ha due grandi
  fiamme, stendardi e disco nel colore dell'ala, il boss il suo; ala chiusa = varco murato con assi in croce.
  Shader nuovi `prova_muro`, `prova_pavimento` (UV = metri dal centro, UV2 = mezze misure, COLOR = tipo e colore),
  `prova_fluido`, `prova_luce` (fiamme, aloni, fasci, nebbia: additivi in MultiMesh, colore per istanza),
  `prova_lanterna`, `prova_stendardo`. Leggerezza: ogni stanza fusa per materiale (`Edifici.fondi`, vista 92 m),
  lanterne e fili in un MultiMesh per stanza, luci vere solo entro 46 m.
  **Da sapere**: un valore costante passato per vertice (UV2) arriva al frammento sporco di un niente: dentro `h21` dava
  righe orizzontali su tutto il pavimento → arrotondarlo (`floor(UV2 * 2.0 + 0.5) * 0.5`).
  **Mappa della Prova**: la minimappa dentro una Prova è la pianta intera (ali colorate, porte chiuse, frane, boss,
  tesoro, braciere, compagni); tasto M: pianta grande con nomi, variante e forze di ogni strada (`Cripta.disegna_pianta`).
  Corretto: uscendo da una Prova o entrando in un'altra restavano a schermo i mostri di prima (`_svuota_entita`).
- **Anteprima senza server**: `godot --path godot res://scene/anteprima_prova.tscn --fixed-fps 30 -- --prova=cripta|forgia
  --var=0 [--porte=sigilli:1] [--rit=sigilli] [--tes=1] --cartella=DIR [--viste=nome:x,y,z:tx,ty,tz;…] [--alto=1]
  [--mappa=1] [--stat=1] [--conta=1]`.
- **Prove**: `node tools/prove/prove_sigillo.mjs [porta]` (95 verifiche, ~12 min: per ogni Prova e variante la pianta di
  `dg_start` coincide con server e `gioco.json`, forze per strada, muri/ali chiuse/cancello respingono, ogni strada porta
  al boss camminando con le regole del client senza un passo respinto, leva, braciere, scrigno, completamento; in testa
  scatti e vista senza server). Aggiornate `gruppo.mjs` e `altolivello.mjs` (seguono la pianta dell'istanza).
- Misura (`stat`, disegni / triangoli a fotogramma in gioco, prima → dopo; i mostri in vista cambiano da una prova
  all'altra): MISURE
- **Non verificati**: una Prova giocata da un gruppo vero e i suoi tempi (le strade allungano il cammino: 15 e 18 minuti
  non sono stati ritarati), danni delle trappole a sigillo alto, mostri contro i muri con molti giocatori, scatti di
  tutte le classi in gioco (provata la funzione), l'apertura di cancello e ponte vista a schermo in gioco (viste in
  anteprima), Forward+, client nel browser (disegna la pianta tutta aperta e il server lo respinge alle porte chiuse).
  Difetti noti: le statue sono sagome di poche forme, la fornace del boss è povera, i massi della frana si confondono col
  muro, i mostri attraversano gli angoli dei pilastri solo scivolando (niente vero aggiramento).

## Gioco in gruppo (prova con bot)
L'autore gioca con 2-3 amici: `node tools/prove/gruppo.mjs [porta]` (65 verifiche, ~6 min; `--solo gruppo,auree,cure,
difensore,serie,bottino,missioni,prova,arena,disconnessione`) con difensore Montagna, guaritrice Benedizione, Monaco del
Loto, un estraneo dello stesso regno e uno straniero, tutti di livello 40. Il server di prova dà il GM agli account in
`GM_ACCOUNTS` (variabile d'ambiente, non va in `config.json`); comando GM nuovo `/vita %` (0 = cadi).
- Difetti trovati e corretti: (1) la minaccia non contava: un mostro restava su chi l'aveva preso per primo finché non
  moriva o veniva provocato (la «minaccia ×4» della Montagna non serviva) → `updateMob` ogni 0,5 s passa a chi ha più del
  110% della minaccia del bersaglio; (2) la Serie toccava solo chi aveva colpito: il guaritore restava indietro senza la
  corsa in più → valgono anche i compagni di gruppo entro 40 m; (3) i pezzi della classe cadevano quasi sempre per chi fa
  più danni → in gruppo la classe va a turno fra i compagni vicini (`extraDrops(m, top, perChi)`), il bottino resta del
  gruppo; (4) l'oggetto delle missioni «raccogli» caduto per un compagno lo poteva raccogliere chiunque del gruppo (e
  contava per lui) → `spawnDrop(..., solo)` solo per chi ha la missione (per 60 s); (5) una disconnessione toglieva dal
  gruppo (sciogliendo quello di due) e dalla Prova, e se era il capo il sigillo scendeva → `removePlayer` lascia il posto
  per 5 minuti (`assenti`, `rientra` in `addPlayer`): si rientra nel gruppo e nella Prova non finita; il sigillo scende
  solo se la Prova si chiude incompiuta; nel riquadro del gruppo i disconnessi compaiono in grigio (`off` nel messaggio
  `party`); (6) stordimenti in PvP (vedi sopra); (7) la propria aura e la stessa aura ricevuta da un compagno si sommavano
  per 2,5 s (`mettiAura`); (8) l'icona dell'aura ricevuta da un compagno spariva dopo 2,5 s nel client (l'effetto si
  rinnova ogni secondo senza un nuovo `me`) → mandata senza scadenza come le auree; (9) client Godot: il riquadro del
  bersaglio offriva «Invita nel gruppo» anche sui compagni e a chi non è capogruppo → solo se si può invitare.
- Client Godot con due bot accanto (foto con il copione): riquadri dei compagni con vita e risorsa, aura degli Astri e del
  Drago dei compagni, tecniche del monaco sul fantoccio, riquadro e targhetta dell'alleato selezionato, cura ricevuta.
  Copione nuovo: `accetta` aspetta l'invito, `finche_gruppo N`, `finche_vita < 50`, `finche_cura`, `seleziona Nome`.
- Verificato e funzionante: inviti, capogruppo, uscita, espulsione; auree ai compagni nel raggio e non agli estranei,
  `au` per chi arriva, spegnimento e morte; cure sull'alleato scelto, sul più ferito, Grazia, Risonanza che cura il gruppo,
  Scudo di Giada, maestria del Loto (il `chainHeal` del Loto non esiste più dalla fase 4), niente cure a un altro regno;
  Radici della Montagna su élite e branco; Occasione di ciascuno; esperienza (40% a testa in tre) e tael divisi; missioni
  dei compagni entro 80 m; Prova del Sigillo in tre con una morte, un rientro e le ricompense a tutti; arena.
- Lasciati: le cure non generano minaccia (i mostri non si girano sul guaritore); chi viene espulso dal gruppo resta
  nella Prova; il compagno lontano più di 80 m non prende esperienza né missioni.
- Misura della tenuta (`--misura [--secondi 60] [--ripeti N] [--senza-guaritore] [--elite …] [--branco …] [--equip
  up,rarità]`): difensore e guaritrice di livello 40 con pezzi del 40 comuni +0, contro un Campione d'Arenaria (élite
  48) e branchi di 5 Guerrieri d'Arenaria (47) rimessi appena cadono, 60 s (2 prove): ~100 colpi ricevuti, danni in
  arrivo 26-32 al secondo (meno dell'1% della vita di 3445 al secondo), tutti assorbiti dallo Scudo di Giada; cure
  effettive 0-2 al secondo (non c'è niente da curare), vita minima 95-100%, nessuna morte; il difensore infligge 615-636
  danni al secondo e abbatte 8 branchi al minuto. Senza guaritore: 33 danni al secondo, vita minima 88%, la Pelle di Pietra
  basta. Con pezzi +9 Pregiati la difesa sale da 235 a 368 e i danni subiti scendono ancora. **Da sapere per la taratura**:
  con la formula `60 / (60 + difesa)` un difensore del 40 quasi non sente i mostri del 47-48 nel mondo aperto; il
  bisogno del guaritore va misurato nelle Prove a sigillo alto e contro i boss (non fatto).
## Comodità sociali: scambio, deposito, amici, tasti (fatto)
Richiesta dell'autore: le comodità di un gruppo di amici. Server in `server/sociale.js` (modulo installato su World come
`mappe.js`/`missioni.js`; dati in `shared/sociale.js`), client Godot in `godot/script/sociale.gd`, `tasti.gd`, `pannello_tasti.gd`.
Il client nel browser non ne sa nulla.
- **Scambio** (`{t:'scambio', a:...}`: `chiedi` id|n, `rispondi` ok, `offri` i n, `togli` k, `tael` n, `conferma` v, `annulla`; il
  server manda `richiesta`, `stato` con le due colonne e `fine`). Come evita i duplicati: l'oggetto offerto LASCIA la borsa e va nel
  «pegno» `ch.escrow = { o: [{ it, slot }], tael }` (tael compresi); torna indietro solo se lo scambio si annulla (casella d'origine,
  se non c'è posto cade a terra solo per lui). Lo scambio riuscito (`scambioEsegui`) è una funzione sincrona che controlla lo spazio
  di entrambi (`entrano`) e sposta i pegni: un oggetto sta sempre in un solo posto, quindi spostare/usare/buttare/vendere la casella
  offerta non fa nulla. La conferma vale per la versione `v` dell'offerta e ogni modifica la azzera per tutti e due. Si annulla da
  solo se uno muore, entra in una Prova o nell'Arena, si allontana oltre 16 m (richiesta entro 10 m) o esce; il pegno è salvato col
  personaggio e al login (`socialeEntra`) torna nella borsa. Borsa piena: non si conclude, resta aperto. Massimo 8 oggetti per parte.
- **Deposito**: PNG `magazziniere` (Cassiere Zhou, in ogni villaggio accanto allo Scrivano, `VILLAGE_LAYOUT.npcs`), `acc.deposito` =
  48 caselle per ACCOUNT (condiviso fra i personaggi). Messaggi `{t:'dep', a: metti|prendi|sposta|ordina, npc, i, s, n}` → `dep`/`stato`.
  Client: caselle `Finestre.Casella` (sottoclasse `Sociale.CasellaS`), trascinamento (anche tra le caselle del deposito; sopra una
  casella occupata si scambiano di posto), clic destro (deposita dall'inventario aperto, ritira dal deposito), quantità per le pile.
- **Amici**: `acc.amici` = nomi di personaggi (per account, massimo 50). `{t:'amico', a: aggiungi|rimuovi}` e `{t:'amici'}` → `amici`
  (in linea, livello, classe, zona; fuori linea: ultimo livello) aggiornata a ogni entrata/uscita e ogni 4 s a finestra aperta;
  `amico_on` + riga di sistema quando un amico entra. Sussurri: `/s nome testo`, `/r testo` (e `@nome` di prima); nomi cliccabili in
  chat (menu: Sussurra, Invita nel gruppo, Scambia, Amici), «Scambia» e «Amico» nel riquadro del bersaglio, tasto **F** (finestra Amici),
  anche `/amico nome`, `/amici`, `/scambia nome`.
- **Tasti personalizzabili** (l'autore: «anche personalizzazione dei tasti»; la prima versione aveva un tasto solo per
  azione, senza combinazioni né mouse): `Tasti` (`tasti.gd`). Ogni azione di `AZIONI` ha **due comandi** (principale e
  alternativo); un comando è un intero: codice fisico del tasto | `MAIUSC` | `CTRL` | `ALT`, oppure `TOPO` | indice del
  tasto del mouse (centrale 3, laterali 8 e 9). `codici(id)`, `azione_evento(ev)` (prima il comando esatto, poi lo stesso
  tasto senza modificatori: W cammina anche con Maiusc premuto), `comando_evento(ev)`, `premuto(id)`, `assegna(id, posto,
  comando)` (il comando viene tolto all'azione che lo aveva e ne restituisce l'id), `togli`, `senza_tasto()`,
  `nome_tasto` («Maiusc+1», «Mouse 4») e `nome_breve` («M-1», «C-Q», «Ms4»: barra rapida). Fissi solo Esc, tasto
  sinistro, destro e rotella; frecce, F1, F11 e Invio del tastierino sono alternativi predefiniti che si possono cambiare.
  Azioni aggiunte: `autocorsa` (X o tasto centrale: `gioco.autocorsa`, si ferma con avanti/indietro, Esc o un clic),
  `bersaglio_prec` (Maiusc+Tab), `attacca` (T), `imprese` (J, prima fisso), `schermo_intero` (F11), inventario anche su B.
  `gioco._azione(az)` esegue le azioni da tastiera e dal mouse. Salvataggio in `impostazioni.cfg`, sezione `tasti`:
  `id = [principale, alternativo]` (il vecchio formato con un intero si legge ancora; comandi doppi si tolgono al
  caricamento). Pagina «Personalizza i tasti» (`PannelloTasti`: due caselle per azione; clic, poi il comando; Esc annulla,
  Backspace o clic destro svuotano; avvisa delle azioni rimaste senza tasto), da Impostazioni e dal menu Esc. I testi
  hanno segnaposto `{azione}` e si registrano con `Tasti.registra(controllo, modello)`.
  Copione: `premi codice [maiusc] [ctrl] [alt]` e `mouse indice` mandano un evento vero (`Input.parse_input_event`),
  `sociale cattura azione [posto]`, `sociale ripristina_tasti`, `sociale tasto azione codice [posto]`.
  Visto a schermo con eventi simulati: cattura di Maiusc+1, Ctrl+G e Mouse 4, inventario aperto col tasto laterale, corsa
  automatica, «M-1» sulla barra. **Non verificato**: tastiera e mouse veri, layout non QWERTY, browser.
- **Extra**: «Ordina» nell'inventario (`{t:'ordina'}`: raggruppa le pile, ordina per tipo/livello/nome/rarità; anche il deposito),
  «Vendi comuni» nel negozio (`{t:'vendi_comuni', npc}`: equipaggiamento bianco senza potenziamenti né gemme e trofei «Si vende ai
  mercanti»; non tocca materiali del fabbro, pozioni, gemme), Maiusc+clic su un oggetto dell'inventario lo mostra in chat (`[[3]]` →
  `⟦json⟧` allegato dal server, nel client «[Nome]» colorato con la descrizione al passaggio del mouse).
- Prove: `node tools/prove/sociale.mjs [porta]` (71 verifiche: scambio riuscito/annullato/rifiutato, doppia offerta, spostare-usare-
  buttare con lo scambio aperto, tael, conferma vecchia, conferme azzerate, disconnessione a metà, troppo lontani, borsa piena, limite di
  8 oggetti, deposito fra due personaggi dello stesso account e da lontano, deposito pieno, amici, sussurri, `/r`, ordinamento, vendita,
  oggetti in chat, salvataggio e conservazione delle quantità nel database). Copione Godot: `sociale apri amici|tasti|deposito`,
  `sociale scambia nome`, `sociale offri i [n]`, `sociale tael n`, `sociale conferma`, `sociale aspetta_scambio`, `sociale deposita i`,
  `sociale tasto azione codice`… (vedi `Sociale.copione`).
- **Non verificato**: trascinamento col mouse vero (il copione non muove il puntatore), clic sui nomi in chat e passaggio del mouse sugli
  oggetti collegati, pagina «Tasti…» con la tastiera vera, tasti con layout non QWERTY, scambio tra due client Godot veri.

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
