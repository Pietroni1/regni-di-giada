// Pacchetto «gioca da solo»: una cartella (e uno zip) con il gioco e, accanto, il server e un Node già pronto.
// Chi lo riceve estrae lo zip e apre RegniDiGiada.exe: il gioco avvia da sé il server interno (godot/script/solo.gd),
// senza installare niente e senza che nessun altro tenga acceso qualcosa.
//
//   1. esportare il gioco:   godot --headless --path godot --export-release "Windows" ../esporta/RegniDiGiada.exe
//   2. npm run pacchetto     (oppure: node tools/pacchetto/solo.mjs [--piattaforma windows|linux] [--node file] [--gm] [--niente-zip])
//
// Risultato: esporta/solo/RegniDiGiada/ e esporta/RegniDiGiada-solo-windows.zip.
// Node per Windows viene scaricato una volta da nodejs.org (con `curl`, controllando l'impronta SHA-256) e tenuto in
// esporta/cache/. Per Linux si copia il Node con cui gira questo script. `--node file` usa un eseguibile già scaricato.
import fs from 'fs';
import path from 'path';
import crypto from 'crypto';
import { execFileSync } from 'child_process';
import { fileURLToPath } from 'url';

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..', '..');
const arg = (nome, pred = null) => {
  const i = process.argv.indexOf('--' + nome);
  return i < 0 ? pred : (process.argv[i + 1] && !process.argv[i + 1].startsWith('--') ? process.argv[i + 1] : true);
};
const piattaforma = arg('piattaforma', 'windows');
const NODE_VERSIONE = 'v22.12.0';
const ESPORTA = path.join(ROOT, 'esporta');
const DEST = path.join(ESPORTA, 'solo', 'RegniDiGiada');
const eseguibile = piattaforma === 'windows' ? 'RegniDiGiada.exe' : 'RegniDiGiada.x86_64';

function copia(da, a) { fs.mkdirSync(path.dirname(a), { recursive: true }); fs.copyFileSync(da, a); }
function copiaCartella(da, a, filtro = () => true) {
  for (const v of fs.readdirSync(da, { withFileTypes: true })) {
    const s = path.join(da, v.name), d = path.join(a, v.name);
    if (v.isDirectory()) copiaCartella(s, d, filtro);
    else if (filtro(v.name)) copia(s, d);
  }
}

// ---------------------------------------------------------------- Node da mettere nel pacchetto
function nodeWindows() {
  const cache = path.join(ESPORTA, 'cache', `node-${NODE_VERSIONE}-win-x64.exe`);
  const base = `https://nodejs.org/dist/${NODE_VERSIONE}`;
  if (!fs.existsSync(cache)) {
    fs.mkdirSync(path.dirname(cache), { recursive: true });
    console.log(`Scarico Node ${NODE_VERSIONE} per Windows...`);
    execFileSync('curl', ['-fL', '--retry', '3', '-o', cache + '.tmp', `${base}/win-x64/node.exe`], { stdio: 'inherit' });
    const somme = execFileSync('curl', ['-fsL', '--retry', '3', `${base}/SHASUMS256.txt`], { encoding: 'utf8' });
    const attesa = (somme.split('\n').find(r => r.trim().endsWith('win-x64/node.exe')) || '').split(/\s+/)[0];
    const trovata = crypto.createHash('sha256').update(fs.readFileSync(cache + '.tmp')).digest('hex');
    if (!attesa || attesa !== trovata) {
      fs.rmSync(cache + '.tmp');
      throw new Error(`Impronta di node.exe diversa da quella pubblicata (${trovata} invece di ${attesa || '?'})`);
    }
    fs.renameSync(cache + '.tmp', cache);
  }
  return cache;
}

// ---------------------------------------------------------------- assemblaggio
const gioco = path.join(ESPORTA, eseguibile);
if (!fs.existsSync(gioco)) {
  console.error(`Manca ${path.relative(ROOT, gioco)}: prima si esporta il gioco da Godot (vedi in testa a questo file).`);
  process.exit(1);
}
fs.rmSync(DEST, { recursive: true, force: true });
copia(gioco, path.join(DEST, eseguibile));
// se l'esportazione tiene i dati in un file a parte (.pck), va accanto all'eseguibile
const pck = gioco.replace(/\.(exe|x86_64)$/, '.pck');
if (fs.existsSync(pck)) copia(pck, path.join(DEST, path.basename(pck)));
if (piattaforma !== 'windows') fs.chmodSync(path.join(DEST, eseguibile), 0o755);

const SRV = path.join(DEST, 'server_locale');
copiaCartella(path.join(ROOT, 'server'), path.join(SRV, 'server'), n => n.endsWith('.js'));
copiaCartella(path.join(ROOT, 'shared'), path.join(SRV, 'shared'), n => n.endsWith('.js'));
copiaCartella(path.join(ROOT, 'node_modules', 'ws'), path.join(SRV, 'node_modules', 'ws'), n => !n.endsWith('.md'));
fs.writeFileSync(path.join(SRV, 'package.json'), JSON.stringify({ name: 'regni-di-giada-solo', private: true, type: 'module' }, null, 2) + '\n');
// chi gioca da solo è un giocatore normale; con --gm il suo account interno ha i comandi del Game Master
fs.writeFileSync(path.join(SRV, 'server', 'config.json'), JSON.stringify({
  port: 31717, rates: { exp: 1, drop: 1, tael: 1 }, gmAccounts: arg('gm') ? ['giocatore'] : [],
  pvp: true, pvpMinLevel: 10, maxCharsPerAccount: 4, saveIntervalSec: 30,
}, null, 2) + '\n');

const node = typeof arg('node') === 'string' ? path.resolve(arg('node')) : (piattaforma === 'windows' ? nodeWindows() : process.execPath);
const nomeNode = piattaforma === 'windows' ? 'node.exe' : 'node';
copia(node, path.join(SRV, nomeNode));
if (piattaforma !== 'windows') fs.chmodSync(path.join(SRV, nomeNode), 0o755);
// la licenza di Node va con l'eseguibile
fs.writeFileSync(path.join(SRV, 'NODE-LICENZA.txt'),
  `Questa cartella contiene Node.js ${piattaforma === 'windows' ? NODE_VERSIONE : process.version} (https://nodejs.org), distribuito con licenza MIT:\nhttps://github.com/nodejs/node/blob/main/LICENSE\n`);

fs.writeFileSync(path.join(DEST, 'LEGGIMI.txt'), [
  'REGNI DI GIADA — partita in solitaria',
  '',
  `1. Estrai TUTTA la cartella dallo zip (non aprire il gioco da dentro lo zip).`,
  `2. Apri ${eseguibile} e premi «Gioca».`,
  '',
  'Non serve installare nulla e non serve Internet: il mondo gira sul tuo computer.',
  'La prima volta Windows può mostrare «PC protetto da Windows»: «Ulteriori informazioni» → «Esegui comunque».',
  '',
  'La cartella «server_locale» deve restare accanto al gioco: è il mondo.',
  'I personaggi si salvano nella cartella dei dati dell\'utente',
  '(Windows: %APPDATA%\\Godot\\app_userdata\\Regni di Giada\\salvataggi), quindi restano anche se sostituisci',
  'questa cartella con una versione nuova.',
  '',
  'In gioco il tasto H apre l\'aiuto.',
  'Per giocare con gli amici: «Gioca in rete con gli amici…» e l\'indirizzo di chi ospita.',
  '',
].join('\r\n'));

let peso = 0;
(function somma(d) { for (const v of fs.readdirSync(d, { withFileTypes: true })) v.isDirectory() ? somma(path.join(d, v.name)) : (peso += fs.statSync(path.join(d, v.name)).size); })(DEST);
console.log(`Pacchetto: ${path.relative(ROOT, DEST)}  (${(peso / 1048576).toFixed(0)} MB)`);

if (!arg('niente-zip')) {
  const zip = path.join(ESPORTA, `RegniDiGiada-solo-${piattaforma}.zip`);
  fs.rmSync(zip, { force: true });
  try {
    if (process.platform === 'win32') {
      execFileSync('powershell', ['-NoProfile', '-Command', `Compress-Archive -Path '${DEST}' -DestinationPath '${zip}'`], { stdio: 'inherit' });
    } else {
      execFileSync('zip', ['-qr', '-9', zip, 'RegniDiGiada'], { cwd: path.dirname(DEST), stdio: 'inherit' });
    }
    console.log(`Zip: ${path.relative(ROOT, zip)}  (${(fs.statSync(zip).size / 1048576).toFixed(0)} MB)`);
  } catch (e) {
    console.error('Zip non creato (manca il programma «zip»?): la cartella è comunque pronta.', e.message);
  }
}
