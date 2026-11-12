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

**Controlli:** WASD per muoversi, clic sinistro per muoversi, attaccare, parlare o raccogliere. Tasto destro trascinato o Q/E per ruotare la visuale, rotella per lo zoom. Spazio attacca, Tab cambia bersaglio, 1-9 e 0 usano la barra rapida, R sale o scende da cavallo, Z raccoglie, I/C/K/P/H aprono inventario, personaggio, abilità, misuratore dei danni e guida, Invio apre la chat.

**Chat:** `!testo` grida a tutto il regno, `#testo` scrive al gruppo, `@nome testo` sussurra, `/online` mostra chi è in linea, `/pos` mostra la posizione.

**GM:**

| Comando | Effetto |
|---|---|
| `/item id [quantità] [+livello] [rarità 0-4]` | Crea un oggetto (`/items` per la lista degli id) |
| `/level n` · `/exp n` · `/tael n` | Imposta livello, aggiunge esperienza o tael |
| `/tp x z` · `/tp nome` · `/tp fenice\|tigre\|drago` | Teletrasporto |
| `/spawn mostro [n]` | Evoca mostri (`/mobs` per la lista) |
| `/heal` · `/risorsa` | Cura completa · risorsa al massimo |
| `/via nome` | Cambia la Via del personaggio (per provare le specializzazioni) |
| `/destriero livello` | Dà un destriero del livello indicato |
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

## Grind dell'equipaggiamento

Ogni arma o armatura che cade ha una **rarità**: Comune, Pregiato, Raro, Epico o Leggendario. Più è alta, più l'oggetto ha statistiche di base, **bonus casuali** (fino a 4) e **incavi** per le gemme (fino a 3).

- **Bonus casuali** (18 tipi): vita, difesa, attacco, attacco magico, critico, danni critici, rapidità, danni ai mostri, danni a boss e obelischi, danni ad area, vita rubata, riduzione dei danni dai mostri, velocità, evasione, rigenerazione della risorsa, esperienza, tael e probabilità di bottino. Il suggerimento valuta ogni valore da ★ a ★★★★★: i valori alti sono più rari.
- **Modificatori** (si trascinano sull'oggetto): Pietra dell'Affinamento (rilancia i valori), Pergamena del Mutamento (rimescola i bonus), Sigillo dell'Ascensione (35%: rarità +1), Scalpello del Gioielliere (estrae le gemme).
- **Gemme**: Rubino, Zaffiro, Giada, Ambra, Onice e Perla, ognuna su 3 gradi. Clic destro su 3 gemme uguali per fonderle nel grado successivo.
- **Fabbro**: potenziamento fino a **+15**. Da +10 serve l'Essenza Celeste. Ogni fallimento aggiunge il 2% di "perseveranza" a quell'oggetto, fino al 20%. Con il Sigillo del Fabbro un fallimento non distrugge l'oggetto: da +9 in su lo fa scendere di un livello. Il pulsante **Smonta** trasforma un oggetto in materiali e restituisce le gemme.
- **Bottino**: ogni mostro può lasciare equipaggiamento del suo livello; obelischi e boss lasciano oggetti più rari, gemme, modificatori ed essenze. Tieni premuto **Alt** per vedere i nomi di tutti gli oggetti a terra.

## Gruppi

Fino a 5 giocatori dello stesso regno. Seleziona un alleato e premi **Invita nel gruppo**, oppure scrivi `/invita nome`. Per uscire usa `/lascia`; il capogruppo può espellere qualcuno dal riquadro del compagno o con `/espelli nome`.

- **Esperienza:** il danno del gruppo vale come un'unica quota, divisa tra i membri entro 80 metri con un bonus del 10% per ogni compagno. Chi è più di 15 livelli sotto il membro più alto ne riceve solo il 20%.
- **Tael e bottino:** i tael vengono divisi tra i membri vicini. Il bottino appartiene a tutto il gruppo per i primi 20 secondi.
- **Riquadri dei compagni:** vita e risorsa sono sempre visibili, anche da lontano; un clic seleziona il compagno, per esempio per curarlo.
- **Chat e mappa:** `#testo` scrive al gruppo. I compagni appaiono in verde sulla minimappa e sopra la testa.

## Cavalcature

Dal livello 10 lo **Stalliere** (Mastro Bo, vicino alla porta laterale di ogni villaggio) vende un Puledro per 5.000 tael. Premi **R** per salire in sella: servono 1,5 secondi da fermo, e muoversi annulla il richiamo. Premi di nuovo **R** per scendere.

- **In sella** corri più veloce: da +50% a +97,5% a seconda del livello del destriero. Le prime quattro caselle della barra rapida diventano le **tecniche a cavallo**, ad area e senza costo di risorsa:

  | Tecnica | Livello del destriero |
  |---|---|
  | Carica del Destriero | 1 |
  | Fendente in Corsa | 1 |
  | Zoccoli di Tuono | 8 |
  | Turbine al Galoppo | 15 |

  Le tecniche della classe si usano solo a piedi.
- **Il destriero cresce combattendo in sella**: riceve il 30% dell'esperienza base dei mostri. Puoi anche addestrarlo a pagamento dallo Stalliere (+25% del livello per volta). Al livello 10 diventa Destriero, al 20 Destriero da Guerra, e ogni grado ha un aspetto diverso.
- **Accampamenti**: raduni fitti di mostri deboli che ricompaiono in fretta, ideali per il grind ad area:
  - Lupi del Branco vicino ai villaggi;
  - Predoni delle Colline nelle terre di confine;
  - Soldati di Terracotta intorno all'altopiano.

## Sistemi presenti

- **Regni:** Fenice Vermiglia (sud), Tigre Bianca (ovest) e Drago di Giada (est). Ognuno ha un villaggio fortificato che è zona sicura.
- **Classi:** Lama, Ombra, Monaco e Mistico. Al livello 5 si sceglie una delle due **Vie** della classe, in modo definitivo: danni, difensore o guaritore.
- **Abilità:** 7-8 per Via, livelli 1-10 con i punti abilità, 11-20 con i Tomi della Tecnica (50% di successo).
- **Statistiche:** Vitalità, Forza, Destrezza e Intelletto, con 3 punti per livello.
- **Mostri:** dai lupi del livello 2 ai guerrieri di terracotta, fino al **Generale Senza Volto** (boss, livello 25).
- **Obelischi corrotti:** quando vengono colpiti richiamano ondate di mostri all'80, 60, 40 e 20% della vita e rilasciano tomi e materiali.
- **Negozi:** armaiolo (armi, armature e modificatori) ed erborista. Clic destro su un oggetto dell'inventario per venderlo.
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
