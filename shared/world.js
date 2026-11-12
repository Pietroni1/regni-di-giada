// Geografia del mondo, condivisa da server e client.
// Tutto è deterministico: server e client calcolano esattamente lo stesso terreno.

export const WORLD_HALF = 300;
export const PLAY_LIMIT = 280;
export const SAFE_RADIUS = 44;
export const WALL_RADIUS = 40;
export const VILLAGE_HEIGHT = 3;
export const CENTER = { x: 0, z: 10 };

export const KINGDOMS = {
  fenice: {
    name: 'Regno della Fenice Vermiglia', short: 'Fenice', color: '#d0452f', hex: 0xd0452f, roof: 0x6e2a22,
    village: { x: 0, z: -195 }, villageName: 'Borgo delle Braci',
    desc: 'Popolo fiero delle pianure del sud. Onora il fuoco, il coraggio e la parola data.',
  },
  tigre: {
    name: 'Regno della Tigre Bianca', short: 'Tigre', color: '#d8dce4', hex: 0xd8dce4, roof: 0x45484e,
    village: { x: -172, z: 110 }, villageName: 'Rocca dei Bambù',
    desc: "Clan delle foreste d'occidente. Cacciatori pazienti, maestri della strategia.",
  },
  drago: {
    name: 'Regno del Drago di Giada', short: 'Drago', color: '#2fae7e', hex: 0x2fae7e, roof: 0x1f4a3c,
    village: { x: 172, z: 110 }, villageName: 'Approdo delle Nebbie',
    desc: "Genti dei fiumi d'oriente. Disciplinate, colte, custodi delle arti antiche.",
  },
};
export const KINGDOM_IDS = Object.keys(KINGDOMS);

// ---------------------------------------------------------------- rumore
function hash2(ix, iz, seed) {
  let h = (Math.imul(ix, 374761393) + Math.imul(iz, 668265263) + Math.imul(seed, 982451653)) | 0;
  h = Math.imul(h ^ (h >>> 13), 1274126177);
  h ^= h >>> 16;
  return (h >>> 0) / 4294967296;
}
export const lerp = (a, b, t) => a + (b - a) * t;
export function smoothstep(e0, e1, x) {
  const t = Math.min(1, Math.max(0, (x - e0) / (e1 - e0)));
  return t * t * (3 - 2 * t);
}
export function noise2(x, z, seed = 0) {
  const ix = Math.floor(x), iz = Math.floor(z);
  const fx = x - ix, fz = z - iz;
  const a = hash2(ix, iz, seed), b = hash2(ix + 1, iz, seed);
  const c = hash2(ix, iz + 1, seed), d = hash2(ix + 1, iz + 1, seed);
  const u = fx * fx * (3 - 2 * fx), v = fz * fz * (3 - 2 * fz);
  return a + (b - a) * u + (c - a) * v + (a - b - c + d) * u * v;
}
export function fbm(x, z, oct = 4, seed = 0) {
  let s = 0, amp = 1, f = 1, norm = 0;
  for (let i = 0; i < oct; i++) {
    s += noise2(x * f, z * f, seed + i * 17) * amp;
    norm += amp; amp *= 0.5; f *= 2;
  }
  return s / norm;
}
export function mulberry32(seed) {
  return function () {
    seed |= 0; seed = (seed + 0x6D2B79F5) | 0;
    let t = Math.imul(seed ^ (seed >>> 15), 1 | seed);
    t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}
function angDiff(a, b) {
  let d = a - b;
  while (d > Math.PI) d -= 2 * Math.PI;
  while (d < -Math.PI) d += 2 * Math.PI;
  return d;
}

// ---------------------------------------------------------------- villaggi
// Ogni villaggio ha un sistema di coordinate locale: +z punta verso il centro della mappa.
export function villageFrame(kid) {
  const v = KINGDOMS[kid].village;
  const a = Math.atan2(CENTER.x - v.x, CENTER.z - v.z);
  return { x: v.x, z: v.z, a, cos: Math.cos(a), sin: Math.sin(a) };
}
export function toWorld(f, lx, lz) {
  return { x: f.x + lx * f.cos + lz * f.sin, z: f.z - lx * f.sin + lz * f.cos };
}

export const VILLAGE_LAYOUT = {
  spawn: { x: 0, z: 12 },
  gates: [0, Math.PI / 2, -Math.PI / 2],
  gateHalf: 0.15,
  buildings: [
    { kind: 'pagoda', x: 0, z: -25, w: 10, d: 10, face: 0 },
    { kind: 'hall', x: -16, z: -25, w: 9, d: 6, face: 0 },
    { kind: 'forge', x: 16, z: -25, w: 8, d: 6, face: 0 },
    { kind: 'house', x: -22, z: -11, w: 7, d: 10, face: Math.PI / 2 },
    { kind: 'house', x: 22, z: -11, w: 7, d: 10, face: -Math.PI / 2 },
    { kind: 'house', x: -22, z: 14, w: 7, d: 10, face: Math.PI / 2 },
    { kind: 'house', x: 22, z: 14, w: 7, d: 10, face: -Math.PI / 2 },
  ],
  stalls: [
    { x: -9, z: 2, role: 'armi' },
    { x: 9, z: 2, role: 'erbe' },
  ],
  npcs: [
    { role: 'armi', x: -9, z: 0.3, face: 0 },
    { role: 'erbe', x: 9, z: 0.3, face: 0 },
    { role: 'fabbro', x: 16, z: -20.6, face: 0 },
    { role: 'maestro', x: 0, z: -18.6, face: 0 },
    { role: 'guardia', x: -5, z: 36.5, face: 0 },
    { role: 'guardia', x: 5, z: 36.5, face: 0 },
  ],
  lanterns: [[-4, 18], [4, 18], [-4, 28], [4, 28], [-14, -8], [14, -8], [-14, 8], [14, 8]],
  trees: [[-28, -25], [28, -25], [-12, 25], [12, 25], [-30, 28], [30, 28]],
  dummies: [[-15, 21], [15, 21]],
  well: { x: 0, z: -7 },
};

export function wallAngles() {
  const out = [];
  const n = 64;
  for (let i = 0; i < n; i++) {
    const a = -Math.PI + (i + 0.5) * (2 * Math.PI / n);
    let gate = false;
    for (const g of VILLAGE_LAYOUT.gates) if (Math.abs(angDiff(a, g)) < VILLAGE_LAYOUT.gateHalf + 0.03) gate = true;
    if (!gate) out.push(a);
  }
  return out;
}

export function villageSpawn(kid, jitter = 3) {
  const f = villageFrame(kid);
  const s = VILLAGE_LAYOUT.spawn;
  return toWorld(f, s.x + (Math.random() - 0.5) * jitter, s.z + (Math.random() - 0.5) * jitter);
}

// ---------------------------------------------------------------- strade
const ROAD_SEGS = [];
(function buildRoads() {
  const sides = { fenice: 1, tigre: -1, drago: 1 };
  for (const kid of KINGDOM_IDS) {
    const f = villageFrame(kid);
    const a = toWorld(f, 0, 0);
    const g = toWorld(f, 0, WALL_RADIUS + 2);
    ROAD_SEGS.push([a.x, a.z, g.x, g.z]);
    // curva verso il centro (bezier quadratica)
    const ctrlL = toWorld(f, 28 * sides[kid], (WALL_RADIUS + 205) / 2);
    const end = { x: CENTER.x - (CENTER.x - g.x) * 0.16, z: CENTER.z - (CENTER.z - g.z) * 0.16 };
    let prev = g;
    for (let i = 1; i <= 10; i++) {
      const t = i / 10;
      const p = {
        x: (1 - t) * (1 - t) * g.x + 2 * (1 - t) * t * ctrlL.x + t * t * end.x,
        z: (1 - t) * (1 - t) * g.z + 2 * (1 - t) * t * ctrlL.z + t * t * end.z,
      };
      ROAD_SEGS.push([prev.x, prev.z, p.x, p.z]);
      prev = p;
    }
    // sentieri dalle porte laterali
    for (const s of [-1, 1]) {
      const p0 = toWorld(f, s * (WALL_RADIUS - 6), 0);
      const p1 = toWorld(f, s * (WALL_RADIUS + 40), 8);
      ROAD_SEGS.push([p0.x, p0.z, p1.x, p1.z]);
    }
  }
})();
export const ROADS = ROAD_SEGS;

export function roadDistance(x, z) {
  let best = 1e9;
  for (const s of ROAD_SEGS) {
    const dx = s[2] - s[0], dz = s[3] - s[1];
    const l2 = dx * dx + dz * dz;
    let t = l2 > 0 ? ((x - s[0]) * dx + (z - s[1]) * dz) / l2 : 0;
    t = Math.max(0, Math.min(1, t));
    const px = s[0] + dx * t - x, pz = s[1] + dz * t - z;
    const d = px * px + pz * pz;
    if (d < best) best = d;
  }
  return Math.sqrt(best);
}

// ---------------------------------------------------------------- altezza
export function heightAt(x, z) {
  let h = (fbm(x * 0.011, z * 0.011, 4, 11) - 0.43) * 30;
  h += (fbm(x * 0.045 + 100, z * 0.045 - 50, 2, 5) - 0.5) * 3;
  const edge = Math.max(Math.abs(x), Math.abs(z));
  if (edge > 222) {
    const t = (edge - 222) / 78;
    h = Math.max(h, 2) + t * t * 70 + fbm(x * 0.05, z * 0.05, 3, 5) * t * 18;
  }
  const dc = Math.hypot(x - CENTER.x, z - CENTER.z);
  if (dc < 75) h = lerp(4, h, smoothstep(34, 75, dc));
  const rd = roadDistance(x, z);
  if (rd < 10) h = lerp(Math.max(h * 0.75 + 0.6, 1.0), h, smoothstep(3, 10, rd));
  for (const kid of KINGDOM_IDS) {
    const v = KINGDOMS[kid].village;
    const d = Math.hypot(x - v.x, z - v.z);
    if (d < 82) h = lerp(VILLAGE_HEIGHT, h, smoothstep(47, 82, d));
  }
  return h;
}

// ---------------------------------------------------------------- zone
const RING_NAMES = { fenice: 'Piana dei Ciliegi Rossi', tigre: 'Boschi del Sussurro', drago: 'Riva delle Gru' };

export function safeZoneAt(x, z) {
  for (const kid of KINGDOM_IDS) {
    const v = KINGDOMS[kid].village;
    if (Math.hypot(x - v.x, z - v.z) < SAFE_RADIUS) return kid;
  }
  return null;
}

export function zoneAt(x, z) {
  const safe = safeZoneAt(x, z);
  if (safe) return { name: KINGDOMS[safe].villageName, safe };
  if (Math.max(Math.abs(x), Math.abs(z)) > 236) return { name: 'Monti Nebbiosi' };
  if (Math.hypot(x - CENTER.x, z - CENTER.z) < 95) return { name: 'Altopiano delle Spade Spezzate' };
  for (const kid of KINGDOM_IDS) {
    const v = KINGDOMS[kid].village;
    if (Math.hypot(x - v.x, z - v.z) < 125) return { name: RING_NAMES[kid] };
  }
  return { name: 'Terre di Confine' };
}

// ---------------------------------------------------------------- collisioni
export function buildColliders() {
  const list = [];
  for (const kid of KINGDOM_IDS) {
    const f = villageFrame(kid);
    for (const b of VILLAGE_LAYOUT.buildings) {
      const c = toWorld(f, b.x, b.z);
      list.push({ t: 'box', x: c.x, z: c.z, hw: b.w / 2, hd: b.d / 2, cos: f.cos, sin: f.sin });
    }
    for (const s of VILLAGE_LAYOUT.stalls) {
      const c = toWorld(f, s.x, s.z);
      list.push({ t: 'box', x: c.x, z: c.z, hw: 2.1, hd: 0.8, cos: f.cos, sin: f.sin });
    }
    const w = toWorld(f, VILLAGE_LAYOUT.well.x, VILLAGE_LAYOUT.well.z);
    list.push({ t: 'circle', x: w.x, z: w.z, r: 1.3 });
    for (const a of wallAngles()) {
      const c = toWorld(f, Math.sin(a) * WALL_RADIUS, Math.cos(a) * WALL_RADIUS);
      list.push({ t: 'circle', x: c.x, z: c.z, r: 2.3 });
    }
  }
  return list;
}

export function resolveCollisions(x, z, rad, colliders) {
  for (const c of colliders) {
    const dx = x - c.x, dz = z - c.z;
    if (dx * dx + dz * dz > 400) continue;
    if (c.t === 'circle') {
      const d = Math.hypot(dx, dz), m = c.r + rad;
      if (d < m && d > 1e-6) { x = c.x + dx / d * m; z = c.z + dz / d * m; }
      continue;
    }
    let lx = dx * c.cos - dz * c.sin, lz = dx * c.sin + dz * c.cos;
    const px = Math.max(-c.hw, Math.min(c.hw, lx)), pz = Math.max(-c.hd, Math.min(c.hd, lz));
    const ex = lx - px, ez = lz - pz, d = Math.hypot(ex, ez);
    if (d >= rad) continue;
    if (d > 1e-6) { lx = px + ex / d * rad; lz = pz + ez / d * rad; }
    else {
      const ox = c.hw - Math.abs(lx), oz = c.hd - Math.abs(lz);
      if (ox < oz) lx = Math.sign(lx || 1) * (c.hw + rad); else lz = Math.sign(lz || 1) * (c.hd + rad);
    }
    x = c.x + lx * c.cos + lz * c.sin;
    z = c.z - lx * c.sin + lz * c.cos;
  }
  return [x, z];
}
