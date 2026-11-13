# Regni di Giada — client Godot

Client del gioco fatto con **Godot 4.4** al posto del client nel browser (`client/`). Il server è lo stesso
(`server/`, Node.js): questo progetto si collega via WebSocket e mostra quello che il server decide.

## Come si avvia (Windows)
1. Scarica **Godot 4.4** (versione standard, non .NET) da https://godotengine.org/download — è un solo `.exe`, non si installa.
2. Avvia il server del gioco dalla cartella del progetto: `npm.cmd start`.
3. Apri Godot → **Importa** → scegli `godot/project.godot`. La prima volta importa i modelli (qualche secondo).
4. Premi **F5** (o il tasto ▶ in alto a destra). Server: `localhost:3000`, poi account e password come nel browser.

Gli amici in rete locale mettono come server `IL-TUO-IP:3000`. Per dare loro un `.exe`: Progetto → Esporta
(nelle opzioni di esportazione, in «Risorse», aggiungi `dati/*` ai file non-risorsa da includere).

## Comandi
WASD o clic sul terreno per muoversi · tasto destro trascinato o Q/E per girare la visuale · rotellina per lo zoom ·
clic o Tab per il bersaglio · 1-0 per la barra rapida · V Tecnica Suprema · Invio chat (comandi GM compresi) ·
I inventario · C personaggio · K abilità · R cavalcatura · Z raccogli · Esc chiude le finestre o toglie il bersaglio.

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
- `script/hud.gd` — interfaccia di gioco.
- `shader/` — terreno dipinto, chiome, cortecce, rocce, tetti a coppi, acqua.

## Resa grafica
Il progetto parte con il renderer **Compatibilità** (leggero, gira anche su schede vecchie). Con una scheda video
recente si può passare a **Forward+** dal menù in alto a destra dell'editor: aggiunge occlusione ambientale e
ombre migliori (le impostazioni sono già nella scena), ma la luce va ricontrollata a vista.

## Cosa manca rispetto al client nel browser
Gemme e pergamene sugli oggetti, suoni. I mostri senza modello (scimmie, spiriti, statue) sono sagome provvisorie.
