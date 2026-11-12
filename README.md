# Regni di Giada

MMORPG privato in stile orientale classico per giocare con gli amici. Si gioca dal browser, senza installare un client; il server gira in Node.js.

Tre regni in guerra, quattro classi con due Vie ciascuna, obelischi che richiamano ondate di mostri, potenziamento degli oggetti dal fabbro con rischio di distruzione, un boss sull'altopiano centrale e PvP tra regni fuori dalle mura.

## Avvio rapido

Serve [Node.js](https://nodejs.org) 18 o superiore.

```bash
npm install
```

```bash
npm start
```

Poi apri `http://localhost:3000` nel browser (Chrome, Edge o Firefox).

**La prima cosa da fare è registrare l'account `admin`.** È l'account Game Master predefinito: chi lo registra per primo ha i comandi GM. Puoi cambiarne il nome in `server/config.json`.

## Far entrare gli amici

All'avvio il server stampa gli indirizzi a cui collegarsi.

- **Stessa rete (LAN):** gli amici aprono `http://IP-DEL-TUO-PC:3000`, per esempio `http://192.168.1.20:3000`. Se non si collegano, consenti Node.js nel firewall di Windows.
- **Via Internet, il modo più semplice:** installate tutti [Tailscale](https://tailscale.com) (gratuito). Gli amici usano l'IP Tailscale del tuo PC, senza toccare il router.
- **Via Internet, port forwarding:** inoltra la porta TCP 3000 del router verso il tuo PC e dai agli amici il tuo IP pubblico.
- **Server sempre acceso:** su un VPS Linux da pochi euro al mese esegui gli stessi comandi. Per tenerlo attivo in background puoi usare `pm2`:

```bash
npx pm2 start server/index.js --name regni-di-giada
```

## Configurazione (`server/config.json`)

| Chiave | Significato |
|---|---|
| `port` | Porta del server (default 3000) |
| `rates.exp` / `rates.drop` / `rates.tael` | Moltiplicatori di esperienza, bottino e denaro |
| `gmAccounts` | Account con i comandi GM |
| `pvp` / `pvpMinLevel` | PvP tra regni attivo e livello minimo per attaccare o essere attaccati |
| `maxCharsPerAccount` | Personaggi per account |
| `saveIntervalSec` | Ogni quanti secondi si salva su disco |

I dati (account e personaggi) stanno in `data/db.json`. Le password sono salvate con hash scrypt. Per un backup basta copiare quel file a server spento.

## Comandi

**Controlli:** WASD per muoversi, clic sinistro per muoversi, attaccare, parlare o raccogliere. Tasto destro trascinato o Q/E per ruotare la visuale, rotella per lo zoom. Spazio attacca, Tab cambia bersaglio, 1-9 e 0 usano la barra rapida, Z raccoglie, I/C/K/P/H aprono inventario, personaggio, abilità, misuratore dei danni e guida, Invio apre la chat.

**Chat:** `!testo` grida a tutto il regno, `@nome testo` sussurra, `/online` mostra chi è in linea, `/pos` mostra la posizione.

**GM:**

| Comando | Effetto |
|---|---|
| `/item id [quantità] [+livello]` | Crea un oggetto (`/items` per la lista degli id) |
| `/level n` · `/exp n` · `/tael n` | Imposta livello, aggiunge esperienza o tael |
| `/tp x z` · `/tp nome` · `/tp fenice\|tigre\|drago` | Teletrasporto |
| `/spawn mostro [n]` | Evoca mostri (`/mobs` per la lista) |
| `/heal` · `/risorsa` | Cura completa · risorsa al massimo |
| `/via nome` | Cambia la Via del personaggio (per provare le specializzazioni) |
| `/rate exp\|drop\|tael valore` | Cambia i moltiplicatori al volo (vengono salvati) |
| `/annuncio testo` | Messaggio a tutto il server |
| `/save` | Salvataggio immediato |

## Combattimento a rotazione

Le abilità condividono un **tempo di ricarica globale** (GCD) di 1 secondo, ridotto dalla Rapidità; alcune sono "fuori dal GCD". Gli incantesimi con **tempo di lancio** si interrompono se ti muovi. Puoi premere il tasto successivo poco prima che finisca il GCD: l'abilità parte appena possibile (coda).

| Classe | Risorsa | Punti | Meccanica |
|---|---|---|---|
| Lama | Ira (sale colpendo e subendo colpi, cala fuori dal combattimento) | — | Fulmine: Squarcio critico → Scintilla (Lama del Tuono gratuita +30%); Ferita Aperta da tenere attiva; Colpo di Grazia sotto il 25%. Montagna: difensore con minaccia ×4 e Sfida |
| Ombra | Energia | Punti combo (5) | Generatori e tecniche finali; Pugnalata più forte alle spalle; veleno; Tiro Mirato reso istantaneo dal Colpo Rapido |
| Monaco | Chi | Sfere (5) | Sequenza Pugno → Calcio → Palmo (Loto: Palmo → Fiore → Palmo) = Forma Perfetta: +2 Sfere e prossima tecnica finale +40% |
| Mistico | Mana | Cariche celesti (5) | Tempesta: Marchio del Tuono può rendere istantaneo il Fulmine Celeste; Giudizio consuma le Cariche. Benedizione: guaritore con scudi e cure ad area |

I **DoT** rinnovati prima della scadenza conservano fino al 30% del tempo rimasto. Le abilità si sbloccano con il livello (Via dal 5, poi ai livelli 7, 9, 12 e 15) e si potenziano con i punti abilità e i Tomi della Tecnica.

Nei villaggi ci sono due **fantocci d'addestramento**: con il **misuratore dei danni** (tasto P) vedi DPS e contributo di ogni abilità, per ottimizzare la rotazione.

## Sistemi presenti

- **Regni:** Fenice Vermiglia (sud), Tigre Bianca (ovest) e Drago di Giada (est). Ognuno ha un villaggio fortificato che è zona sicura.
- **Classi:** Lama, Ombra, Monaco e Mistico. Al livello 5 si sceglie una delle due **Vie** della classe, in modo definitivo: danni, difensore o guaritore.
- **Abilità:** 7-8 per Via, livelli 1-10 con i punti abilità, 11-20 con i Tomi della Tecnica (50% di successo).
- **Statistiche:** Vitalità, Forza, Destrezza e Intelletto, con 3 punti per livello.
- **Mostri:** dai lupi del livello 2 ai guerrieri di terracotta, fino al **Generale Senza Volto** (boss, livello 25).
- **Obelischi corrotti:** quando vengono colpiti richiamano ondate di mostri all'80, 60, 40 e 20% della vita e rilasciano tomi e materiali.
- **Fabbro:** potenziamenti da +0 a +9. Fino a +3 un fallimento non distrugge l'oggetto; da +4 in su sì, a meno di usare il Sigillo del Fabbro. Dal +4 servono materiali. Le armi a +7 e oltre brillano.
- **Negozi:** armaiolo ed erborista. Clic destro su un oggetto dell'inventario per venderlo.
- **Bottino:** gli oggetti a terra appartengono per 20 secondi a chi ha fatto più danni. L'esperienza si divide in base al danno inflitto.
- **Morte:** si perde il 3% dell'esperienza del livello se si muore contro un mostro. Si può rinascere sul posto o al villaggio.
- **PvP:** fuori dalle mura, tra regni diversi, dal livello 10.

## Dove personalizzare

| File | Cosa contiene |
|---|---|
| `shared/data.js` | Classi, Vie, abilità, oggetti, mostri e drop, tabella del fabbro, negozi, PNG |
| `shared/world.js` | Regni, posizione dei villaggi, terreno, strade, zone |
| `server/world.js` | Generazione dei mostri sulla mappa, formule di danno ed esperienza, IA, comandi |
| `client/js/models.js` | Aspetto di personaggi, mostri e PNG |
| `client/js/world3d.js` | Grafica del mondo: edifici, alberi, cielo |
| `client/css/style.css` | Aspetto dell'interfaccia |

Dopo una modifica riavvia il server e ricarica la pagina.

## Struttura

```
server/   server Node.js (HTTP + WebSocket), logica autoritativa del gioco
shared/   dati e geografia usati sia dal server sia dal client
client/   gioco nel browser (Three.js, grafica tutta procedurale)
data/     salvataggi (creato al primo avvio)
```
