// Prepara i dati per il client Godot (cartella godot/): `npm run godot:dati`.
// - godot/dati/gioco.json   tabelle del gioco (shared/data.js) e geografia (shared/world.js)
// - godot/dati/terreno.bin  altezze e pesi dei materiali del terreno, calcolati con le stesse funzioni del server
// - godot/modelli/*.glb     copie dei modelli di client/assets senza compressione Draco (Godot non la legge)
// Va rilanciato ogni volta che cambiano shared/data.js, shared/world.js o i modelli.
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import * as D from '../../shared/data.js';
import * as W from '../../shared/world.js';
import { POSTURA } from '../../shared/postura.js';
import { togliDraco } from './togli_draco.mjs';

const radice = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../..');
const uscita = path.join(radice, 'godot');
fs.mkdirSync(path.join(uscita, 'dati'), { recursive: true });
fs.mkdirSync(path.join(uscita, 'modelli'), { recursive: true });

// ------------------------------------------------------------------ tabelle
const r2 = (v) => Math.round(v * 100) / 100;
const villaggi = {};
for (const kid of W.KINGDOM_IDS) {
  const f = W.villageFrame(kid);
  villaggi[kid] = { x: f.x, z: f.z, a: f.a, cos: f.cos, sin: f.sin };
}

// Vegetazione: stesso algoritmo (e stesso seme) di makeVegetation in client/js/world3d.js.
function vegetazione() {
  const rnd = W.mulberry32(4242);
  const liste = { pino: [], ciliegio: [], bambu: [], acero: [], roccia: [], cespuglio: [] };
  for (let x = -292; x < 292; x += 5.5) for (let z = -292; z < 292; z += 5.5) {
    const px = x + (rnd() - 0.5) * 5, pz = z + (rnd() - 0.5) * 5;
    const r = rnd(), rr = rnd();
    const h = W.heightAt(px, pz);
    if (h < 0.9) continue;
    let salta = false;
    for (const kid of W.KINGDOM_IDS) { const v = W.KINGDOMS[kid].village; if (Math.hypot(px - v.x, pz - v.z) < 52) salta = true; }
    if (salta || Math.hypot(px - W.CENTER.x, pz - W.CENTER.z) < 40 || W.roadDistance(px, pz) < 5) continue;
    const dens = W.fbm(px * 0.018, pz * 0.018, 3, 31);
    const s = 0.8 + rnd() * 0.5, rot = rnd() * Math.PI * 2;
    const el = [r2(px), r2(h - 0.2), r2(pz), r2(s), r2(rot)];
    if (dens > 0.53 && r < (dens - 0.5) * 2.6) {
      const ovest = px < -60 && pz > -60, sud = pz < -90, est = px > 60 && pz > -60;
      if (h > 16) liste.pino.push(el);
      else if (ovest && rr < 0.45) liste.bambu.push(el);
      else if (sud && rr < 0.35) liste.ciliegio.push(el);
      else if (est && rr < 0.3) liste.acero.push(el);
      else if (rr < 0.12) liste.ciliegio.push(el);
      else liste.pino.push(el);
    } else if (r < 0.018) liste.roccia.push(el);
    else if (r < 0.04 && h < 20) liste.cespuglio.push(el);
    else if (r < 0.047 && h < 14) (rnd() < 0.5 ? liste.ciliegio : liste.acero).push(el);
  }
  for (const kid of W.KINGDOM_IDS) {
    const f = W.villageFrame(kid);
    for (const [lx, lz] of W.VILLAGE_LAYOUT.trees) {
      const p = W.toWorld(f, lx, lz);
      liste.ciliegio.push([r2(p.x), W.VILLAGE_HEIGHT - 0.1, r2(p.z), 1.1, r2(rnd() * 6)]);
    }
  }
  return liste;
}

const gioco = {
  versione: D.DATA_VERSION,
  costanti: {
    PTS_MAX: D.PTS_MAX, QB_SIZE: D.QB_SIZE, INV_SIZE: D.INV_SIZE, GCD_MS: D.GCD_MS, VIA_LEVEL: D.VIA_LEVEL,
    WORLD_HALF: W.WORLD_HALF, PLAY_LIMIT: W.PLAY_LIMIT, SAFE_RADIUS: W.SAFE_RADIUS, WALL_RADIUS: W.WALL_RADIUS,
    VILLAGE_HEIGHT: W.VILLAGE_HEIGHT, CENTER: W.CENTER, DUNGEON_X: W.DUNGEON_X,
  },
  SLANCIO: D.SLANCIO, SUPREMA: D.SUPREMA, POSTURA,
  WEAPON_TYPES: D.WEAPON_TYPES, RESOURCES: D.RESOURCES, CLASSES: D.CLASSES, VIE: D.VIE, BUFFS: D.BUFFS,
  SKILLS: D.SKILLS, ITEMS: D.ITEMS, RARITIES: D.RARITIES, MOBS: D.MOBS, NPC_ROLES: D.NPC_ROLES,
  EQUIP_NAMES: D.EQUIP_NAMES, STAT_NAMES: D.STAT_NAMES, STAT_DESC: D.STAT_DESC, BONUS_STATS: D.BONUS_STATS, SHOPS: D.SHOPS, UPGRADE: D.UPGRADE,
  DUNGEON: D.DUNGEON, AFFIXES: D.AFFIXES, MOUNT_SKILLS: D.MOUNT_SKILLS,
  HORSE: { minLevel: D.HORSE.minLevel, price: D.HORSE.price, maxLevel: D.HORSE.maxLevel, names: D.HORSE.names, trainPct: D.HORSE.trainPct,
    need: Array.from({ length: D.HORSE.maxLevel + 1 }, (_, l) => D.HORSE.need(l)), trainCost: Array.from({ length: D.HORSE.maxLevel + 1 }, (_, l) => D.HORSE.trainCost(l)) },
  EQUIP_SLOTS: D.EQUIP_SLOTS, SKILL_MAX: D.SKILL_MAX, SKILL_MAX_POINTS: D.SKILL_MAX_POINTS,
  KINGDOMS: W.KINGDOMS, VILLAGE_LAYOUT: W.VILLAGE_LAYOUT, villaggi,
  mura: W.wallAngles().map(r2 => Math.round(r2 * 1000) / 1000),
  strade: W.ROADS.map(s => s.map(r2)),
  ostacoli: W.buildColliders(),
  vegetazione: vegetazione(),
};
fs.writeFileSync(path.join(uscita, 'dati', 'gioco.json'), JSON.stringify(gioco));

// ------------------------------------------------------------------ terreno
// Intestazione: 'RDGT', lato della griglia delle altezze, passo (m), lato della griglia dei pesi, passo (m) — 5 × uint32/float32.
// Poi le altezze (float32, riga per riga lungo z) e i pesi (2 × RGBA8 per punto: erba secca/bosco/sabbia/terra e roccia/neve/lastricato/—;
// quello che manca a 255 è erba).
const META = W.WORLD_HALF;
const PASSO_H = 2, LATO_H = (2 * META) / PASSO_H + 1;
const PASSO_P = 1, LATO_P = (2 * META) / PASSO_P + 1;
const altezze = new Float32Array(LATO_H * LATO_H);
for (let j = 0; j < LATO_H; j++) for (let i = 0; i < LATO_H; i++) altezze[j * LATO_H + i] = W.heightAt(-META + i * PASSO_H, -META + j * PASSO_H);

// Pesi dei materiali: come weights() in client/js/terrain.js.
function pesi(x, z) {
  const h = W.heightAt(x, z);
  const w = { grass: 1, dirt: 0, rock: 0, sand: 0, plaza: 0, snow: 0, dry: 0, forest: 0 };
  const verso = (k, f) => { if (f <= 0) return; f = Math.min(1, f); for (const n in w) w[n] *= 1 - f; w[k] += f; };
  const n2 = W.fbm(x * 0.008 + 50, z * 0.008, 2, 77);
  if (n2 > 0.55) verso('dry', (n2 - 0.55) * 3);
  const bosco = W.fbm(x * 0.018, z * 0.018, 3, 31);
  if (bosco > 0.55) verso('forest', Math.min(0.85, (bosco - 0.55) * 3.2));
  if (h < 1.3) verso('sand', W.smoothstep(1.3, 0.2, h));
  if (h < -0.5) verso('dirt', W.smoothstep(-0.5, -3, h));
  const pend = Math.hypot(W.heightAt(x + 1, z) - W.heightAt(x - 1, z), W.heightAt(x, z + 1) - W.heightAt(x, z - 1)) / 2;
  if (pend > 0.5) verso('rock', W.smoothstep(0.5, 1.0, pend));
  if (h > 24) verso('rock', W.smoothstep(24, 32, h));
  if (h > 44) verso('snow', W.smoothstep(44, 52, h));
  const rd = W.roadDistance(x, z);
  if (rd < 4.8) verso('dirt', W.smoothstep(4.8, 2.4, rd) * 0.95);
  const dc = Math.hypot(x - W.CENTER.x, z - W.CENTER.z);
  if (dc < 34) verso('plaza', W.smoothstep(34, 26, dc) * 0.9);
  for (const kid of W.KINGDOM_IDS) {
    const v = W.KINGDOMS[kid].village;
    const d = Math.hypot(x - v.x, z - v.z);
    if (d < W.WALL_RADIUS + 1) verso('plaza', W.smoothstep(W.WALL_RADIUS + 1, W.WALL_RADIUS - 5, d) * 0.95);
  }
  return w;
}
const pa = new Uint8Array(LATO_P * LATO_P * 4), pb = new Uint8Array(LATO_P * LATO_P * 4);
const b8 = (v) => Math.max(0, Math.min(255, Math.round(v * 255)));
for (let j = 0; j < LATO_P; j++) for (let i = 0; i < LATO_P; i++) {
  const w = pesi(-META + i * PASSO_P, -META + j * PASSO_P), o = (j * LATO_P + i) * 4;
  pa[o] = b8(w.dry); pa[o + 1] = b8(w.forest); pa[o + 2] = b8(w.sand); pa[o + 3] = b8(w.dirt);
  pb[o] = b8(w.rock); pb[o + 1] = b8(w.snow); pb[o + 2] = b8(w.plaza); pb[o + 3] = 255;
}
const testa = Buffer.alloc(20);
testa.write('RDGT', 0, 'ascii');
testa.writeUInt32LE(LATO_H, 4); testa.writeFloatLE(PASSO_H, 8); testa.writeUInt32LE(LATO_P, 12); testa.writeFloatLE(PASSO_P, 16);
fs.writeFileSync(path.join(uscita, 'dati', 'terreno.bin'), Buffer.concat([testa, Buffer.from(altezze.buffer), Buffer.from(pa.buffer), Buffer.from(pb.buffer)]));

// ------------------------------------------------------------------ modelli
const origine = path.join(radice, 'client', 'assets');
const modelli = ['natura.glb', 'animali.glb', 'personaggio.glb', ...fs.readdirSync(path.join(origine, 'modelli')).filter(f => f.endsWith('.glb')).map(f => 'modelli/' + f)];
for (const f of modelli) {
  const dati = await togliDraco(fs.readFileSync(path.join(origine, f)));
  fs.writeFileSync(path.join(uscita, 'modelli', path.basename(f)), dati);
}
fs.copyFileSync(path.join(origine, 'modelli', 'indice.json'), path.join(uscita, 'dati', 'indice.json'));

const n = Object.values(gioco.vegetazione).reduce((a, l) => a + l.length, 0);
console.log(`Dati per Godot scritti in godot/: ${Object.keys(gioco.SKILLS).length} tecniche, ${n} piante e rocce, terreno ${LATO_H}×${LATO_H}, ${modelli.length} modelli.`);
