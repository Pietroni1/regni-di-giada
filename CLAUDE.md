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
  Da migliorare: attaccatura dei capelli seghettata, pelle uniforme (nessuna texture, muscoli poco leggibili sotto le
  vesti aderenti), scollo della veste seghettato, stili di capelli diversi. Il client nel browser non è stato riprovato
  con i corpi nuovi.
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
  Giudizio dei Tuoni, edifici e personaggio con le texture nuove; poi pugnali +9, arco +12 e bastone +7 in mano, Mille Ombre,
  Collera del Cielo, Drago Celeste (rifatto: era un disco bianco) e il cerchio di rune dell'armatura +15 Leggendaria.
  Non visti: le scintille dell'aura dell'armatura (dal +9), l'arco nel momento del tiro. Il ricamo a fasce della stoffa è
  stato tolto (sui capi aderenti faceva anelli): ora sono punti radi.
- **Aspetto delle tecniche per livello dell'abilità** (richiesto dall'autore): il server manda il livello nell'effetto
  (`fx` `sk` con campo `l`); `Effetti.grado()` lo traduce in 5 gradi — Appresa (1), Affinata (5), Esperta (10), Maestra (15),
  Perfetta (20) — e `_arricchisci` aggiunge strati (rune, eco del colpo, più saette/proiettili, crepe e onda, sigillo
  d'oro e tinta dorata al 20); le forme principali crescono dell'8% a grado. Il grado compare nella finestra Abilità e nel
  tooltip. Comando GM `/abilita id livello` per provarli. Visto a schermo: Lama del Tuono ai livelli 1, 10 e 20.
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
  Lasciati così, da decidere: l'arena resta PvP anche con `cfg.pvp` spento; in PvP un tentativo di stordimento respinto
  rinnova la finestra di 15 s (immunità continua).
- Nota per l'orchestrazione con agenti: mai `pkill -f "node server/index.js"` (uccide i server degli altri agenti):
  chiudere solo per porta, `kill $(lsof -ti tcp:PORTA)`.

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
