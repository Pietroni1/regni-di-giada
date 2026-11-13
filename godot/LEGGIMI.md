# Regni di Giada — client Godot

Client del gioco fatto con **Godot 4.4** al posto del client nel browser (`client/`). Il server è lo stesso
(`server/`, Node.js): questo progetto si collega via WebSocket e mostra quello che il server decide.

## Come si avvia (Windows)
1. Scarica **Godot 4.4** (versione standard, non .NET) da https://godotengine.org/download — è un solo `.exe`, non si installa.
2. Avvia il server del gioco dalla cartella del progetto: `npm.cmd start`.
3. Apri Godot → **Importa** → scegli `godot/project.godot`. La prima volta importa i modelli (qualche secondo).
4. Premi **F5** (o il tasto ▶ in alto a destra). Server: `localhost:3000`, poi account e password come nel browser.

## Far giocare gli amici
**Il programma.** Gli amici non hanno bisogno di Godot: gli dai un solo file.
In Godot: Progetto → Esporta → «Windows» → **Esporta progetto** (la prima volta l'editor chiede di scaricare i
«modelli di esportazione»: un clic). Esce `esporta/RegniDiGiada.exe`: mandalo agli amici, si avvia con un doppio clic.
Windows può avvisare che il programma non è firmato: «Ulteriori informazioni» → «Esegui comunque».
Le preimpostazioni sono già in `export_presets.cfg` (includono la cartella `dati/`).

**Il server.** Gira sul tuo PC (`npm.cmd start`) e deve restare acceso mentre si gioca.
- Stessa casa / stessa rete: gli amici scrivono come server `IL-TUO-IP:3000` (l'IP lo vedi con `ipconfig`).
- Case diverse, tre strade:
  1. aprire la porta **3000 TCP** sul router verso il tuo PC e dare agli amici il tuo IP pubblico;
  2. una rete privata virtuale gratuita (per esempio Tailscale o ZeroTier): ognuno la installa e usa l'IP che gli assegna;
  3. mettere il server su una macchina in rete sempre accesa (serve solo Node.js).
Il client ricorda l'ultimo server e l'ultimo account usati.

## Comandi
- **Movimento**: WASD o clic sul terreno · tasto destro trascinato o Q/E per girare la visuale · rotellina per lo zoom.
- **Combattimento**: clic o Tab per il bersaglio · 1-0 barra rapida · V Tecnica Suprema. Una tecnica premuta poco prima
  che sia pronta parte da sola.
- **Finestre**: I inventario · C personaggio · K abilità · O impostazioni · H aiuto · Esc chiude le finestre, poi apre il menu.
- **Barra rapida**: trascina tecniche (da K) e pozioni (da I) sui tasti; tasto destro su un tasto per svuotarlo.
- **Oggetti**: trascina per spostare e indossare; gemme e pergamene si trascinano su un'arma o un'armatura; clic destro usa,
  fonde tre gemme uguali o vende (col negozio aperto).
- **Altro**: Z raccoglie · R cavalcatura · Invio chat (comandi GM compresi) · F11 schermo intero.
- **Comandi GM utili per provare**: `/level 30`, `/via fulmine`, `/risorsa`, `/punti`, `/suprema`, `/spawn fantoccio 3`, `/tael 50000`.

## Quando cambiano i dati del gioco
Tecniche, mostri, oggetti e terreno arrivano da `shared/data.js` e `shared/world.js`. Dopo averli modificati
(o dopo aver rigenerato i modelli con Blender) lancia dalla cartella del progetto:
```
npm.cmd run godot:dati
```
Riscrive `godot/dati/` (tabelle e terreno) e `godot/modelli/` (copie dei `.glb` senza compressione Draco, che Godot non legge).

## Struttura
- `scene/principale.tscn` — scena d'avvio: qui si regolano **dall'editor** cielo, nebbia, sole e correzione colore.
- `script/dati.gd`, `script/rete.gd` — caricati sempre (autoload): tabelle + terreno, connessione al server.
- `script/principale.gd` — accesso, scelta e creazione del personaggio.
- `script/gioco.gd` — la partita: messaggi del server, movimento, visuale, bersagli, tecniche.
- `script/entita.gd`, `script/personaggio.gd` — creature del mondo e loro aspetto (capi indossati, armi, animazioni).
- `script/mondo.gd`, `script/edifici.gd` — terreno, acqua, vegetazione, villaggi (edifici costruiti da codice).
- `script/effetti.gd` + `shader/fx_*.gdshader` — effetti delle tecniche, composti da pochi mattoni riusabili.
- `script/hud.gd` — interfaccia di gioco; `script/finestre.gd` — inventario, personaggio, abilità, negozi, menu, impostazioni.
- `script/cripta.gd` — la cripta delle Prove del Sigillo.
- `script/impostazioni.gd`, `script/suoni.gd` — caricati sempre: impostazioni salvate e suoni (generati da codice, nessun file audio).
- `shader/` — terreno dipinto, chiome, cortecce, rocce, tetti a coppi, acqua.

## Resa grafica
Il progetto parte con il renderer **Compatibilità** (leggero, gira anche su schede vecchie). Con una scheda video
recente si può passare a **Forward+** dal menù in alto a destra dell'editor: aggiunge occlusione ambientale e
ombre migliori (le impostazioni sono già nella scena), ma la luce va ricontrollata a vista.

## Cosa manca rispetto al client nel browser
Niente di importante: restano da rifinire grafica e modelli (corpi base, edifici, mostri senza modello). I suoni sono generati da codice e sono essenziali: si possono sostituire con registrazioni vere. I mostri senza modello (scimmie, spiriti, statue) sono sagome provvisorie.
