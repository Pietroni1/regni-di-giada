// Avvio del server: HTTP per i file del client + WebSocket per il gioco.
import http from 'http';
import fs from 'fs';
import os from 'os';
import path from 'path';
import { fileURLToPath } from 'url';
import { WebSocketServer } from 'ws';
import { DB } from './db.js';
import { World, newCharacter } from './world.js';
import { CLASSES } from '../shared/data.js';
import { KINGDOMS } from '../shared/world.js';

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const CONFIG_FILE = path.join(ROOT, 'server', 'config.json');

const DEFAULT_CONFIG = {
  port: 3000,
  rates: { exp: 1, drop: 1, tael: 1 },
  gmAccounts: ['admin'],
  pvp: true,
  pvpMinLevel: 10,
  maxCharsPerAccount: 4,
  saveIntervalSec: 30,
};
const cfg = { ...DEFAULT_CONFIG, ...(fs.existsSync(CONFIG_FILE) ? JSON.parse(fs.readFileSync(CONFIG_FILE, 'utf8')) : {}) };
cfg.rates = { ...DEFAULT_CONFIG.rates, ...cfg.rates };
const PORT = process.env.PORT ? parseInt(process.env.PORT, 10) : cfg.port;
const saveConfig = () => fs.writeFileSync(CONFIG_FILE, JSON.stringify(cfg, null, 2) + '\n');
if (!fs.existsSync(CONFIG_FILE)) saveConfig();

const db = new DB(process.env.DB_FILE || path.join(ROOT, 'data', 'db.json'));
const world = new World(db, cfg, saveConfig);
world.start();

// ---------------------------------------------------------------- file statici
const MIME = {
  '.html': 'text/html; charset=utf-8', '.js': 'text/javascript; charset=utf-8', '.css': 'text/css; charset=utf-8',
  '.json': 'application/json', '.glb': 'model/gltf-binary', '.png': 'image/png', '.svg': 'image/svg+xml', '.ico': 'image/x-icon',
};
const MOUNTS = [
  ['/shared/', path.join(ROOT, 'shared')],
  ['/lib/three/', path.join(ROOT, 'node_modules', 'three', 'build')],
  ['/lib/three-addons/', path.join(ROOT, 'node_modules', 'three', 'examples', 'jsm')],
  ['/', path.join(ROOT, 'client')],
];

const server = http.createServer((req, res) => {
  let url = decodeURIComponent((req.url || '/').split('?')[0]);
  if (url === '/') url = '/index.html';
  for (const [prefix, dir] of MOUNTS) {
    if (!url.startsWith(prefix)) continue;
    const file = path.resolve(dir, '.' + url.slice(prefix.length - 1));
    if (!file.startsWith(dir + path.sep)) break;
    fs.readFile(file, (err, data) => {
      if (err) { res.writeHead(404); res.end('Non trovato'); return; }
      res.writeHead(200, { 'Content-Type': MIME[path.extname(file)] || 'application/octet-stream', 'Cache-Control': 'no-cache' });
      res.end(data);
    });
    return;
  }
  res.writeHead(404); res.end('Non trovato');
});

// ---------------------------------------------------------------- sessioni
const online = new Map(); // account -> sessione
const NAME_RE = /^[A-Za-zÀ-ÖØ-öø-ÿ][A-Za-zÀ-ÖØ-öø-ÿ0-9_]{2,15}$/;
const USER_RE = /^[A-Za-z0-9_]{3,20}$/;

function charSummary(c) { return { id: c.id, name: c.name, cls: c.cls, kd: c.kingdom, lvl: c.lvl }; }

const wss = new WebSocketServer({ server, path: '/ws', maxPayload: 8 * 1024 });

wss.on('connection', (ws) => {
  const sess = {
    ws, user: null, gm: false, player: null, tokens: 60, last: Date.now(),
    send(obj) { if (ws.readyState === 1) ws.send(JSON.stringify(obj)); },
  };

  const reply = (obj) => sess.send(obj);
  const sendChars = () => reply({ t: 'chars', list: db.charsOf(sess.user).map(charSummary), max: cfg.maxCharsPerAccount });

  ws.on('message', (raw) => {
    const t = Date.now();
    sess.tokens = Math.min(80, sess.tokens + (t - sess.last) * 0.05);
    sess.last = t;
    if (sess.tokens < 1) return;
    sess.tokens--;
    let msg;
    try { msg = JSON.parse(raw); } catch { return; }
    if (!msg || typeof msg.t !== 'string') return;

    if (sess.player) { world.handle(sess.player, msg); return; }

    if (!sess.user) {
      const user = String(msg.user || '').trim(), pass = String(msg.pass || '');
      if (msg.t === 'register') {
        if (!USER_RE.test(user)) return reply({ t: 'auth_err', m: 'Nome account: 3-20 caratteri, solo lettere, numeri e _' });
        if (pass.length < 4 || pass.length > 64) return reply({ t: 'auth_err', m: 'La password deve avere almeno 4 caratteri' });
        if (!db.createAccount(user, pass)) return reply({ t: 'auth_err', m: 'Questo account esiste già' });
      } else if (msg.t !== 'login') return;
      if (!db.verify(user, pass)) return reply({ t: 'auth_err', m: 'Account o password errati' });
      const acc = db.account(user);
      const key = acc.user.toLowerCase();
      const prev = online.get(key);
      if (prev && prev !== sess) { prev.send({ t: 'kicked', m: 'Il tuo account è stato aperto da un altro dispositivo.' }); prev.ws.close(); }
      online.set(key, sess);
      sess.user = acc.user;
      sess.gm = cfg.gmAccounts.map(s => s.toLowerCase()).includes(key);
      reply({ t: 'auth_ok', user: acc.user, gm: sess.gm ? 1 : 0 });
      return sendChars();
    }

    switch (msg.t) {
      case 'chars': return sendChars();
      case 'create': {
        const name = String(msg.name || '').trim();
        if (!NAME_RE.test(name)) return reply({ t: 'auth_err', m: 'Nome: 3-16 caratteri, deve iniziare con una lettera' });
        if (!CLASSES[msg.cls] || !KINGDOMS[msg.kd]) return reply({ t: 'auth_err', m: 'Classe o regno non validi' });
        if (db.charsOf(sess.user).length >= cfg.maxCharsPerAccount) return reply({ t: 'auth_err', m: 'Hai raggiunto il numero massimo di personaggi' });
        if (db.nameTaken(name)) return reply({ t: 'auth_err', m: 'Questo nome è già in uso' });
        db.createChar(sess.user, newCharacter(name, msg.cls, msg.kd));
        return sendChars();
      }
      case 'delete': {
        db.deleteChar(sess.user, msg.id | 0);
        return sendChars();
      }
      case 'play': {
        const ch = db.charsOf(sess.user).find(c => c.id === (msg.id | 0));
        if (!ch) return;
        sess.player = world.addPlayer(sess, ch);
        return;
      }
    }
  });

  ws.on('close', () => {
    if (sess.player) { world.removePlayer(sess.player); sess.player = null; db.save(); }
    if (sess.user && online.get(sess.user.toLowerCase()) === sess) online.delete(sess.user.toLowerCase());
  });
});

setInterval(() => { world.saveAll(); db.save(); }, cfg.saveIntervalSec * 1000);

function shutdown() {
  console.log('\nSalvataggio in corso...');
  world.saveAll(); db.save();
  process.exit(0);
}
process.on('SIGINT', shutdown);
process.on('SIGTERM', shutdown);

server.listen(PORT, () => {
  console.log('=====================================================');
  console.log('  Regni di Giada — server avviato');
  console.log('=====================================================');
  console.log(`  Su questo computer:   http://localhost:${PORT}`);
  for (const list of Object.values(os.networkInterfaces())) {
    for (const a of list || []) if (a.family === 'IPv4' && !a.internal) console.log(`  In rete locale:       http://${a.address}:${PORT}`);
  }
  console.log(`  Account GM: ${cfg.gmAccounts.join(', ')}  (modificabili in server/config.json)`);
  console.log(`  Moltiplicatori: exp x${cfg.rates.exp}, drop x${cfg.rates.drop}, tael x${cfg.rates.tael}`);
  console.log(`  Entità nel mondo: ${world.ents.size}`);
});
