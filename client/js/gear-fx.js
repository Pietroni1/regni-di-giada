// Effetti dell'equipaggiamento: bagliore e particelle delle armi potenziate, scia dei colpi,
// aura dell'armatura (scintille che salgono, cerchio di rune per le Leggendarie).
import * as THREE from 'three';

export const GLOW_TEX = (() => {
  const cv = document.createElement('canvas'); cv.width = cv.height = 64;
  const g = cv.getContext('2d');
  const grd = g.createRadialGradient(32, 32, 0, 32, 32, 32);
  grd.addColorStop(0, 'rgba(255,255,255,1)'); grd.addColorStop(0.25, 'rgba(255,255,255,0.75)');
  grd.addColorStop(0.6, 'rgba(255,255,255,0.18)'); grd.addColorStop(1, 'rgba(255,255,255,0)');
  g.fillStyle = grd; g.fillRect(0, 0, 64, 64);
  return new THREE.CanvasTexture(cv);
})();

const RUNE_TEX = (() => {
  const cv = document.createElement('canvas'); cv.width = cv.height = 256;
  const g = cv.getContext('2d');
  g.translate(128, 128);
  g.strokeStyle = 'rgba(255,255,255,0.9)';
  for (const [r, w] of [[118, 4], [104, 2], [70, 3], [60, 1.5]]) { g.lineWidth = w; g.beginPath(); g.arc(0, 0, r, 0, Math.PI * 2); g.stroke(); }
  g.font = 'bold 20px serif'; g.fillStyle = 'rgba(255,255,255,0.95)'; g.textAlign = 'center'; g.textBaseline = 'middle';
  const glyphs = '天地風雷火水山澤龍虎鳳龜';
  for (let i = 0; i < 12; i++) { g.save(); g.rotate(i / 12 * Math.PI * 2); g.fillText(glyphs[i], 0, -88); g.restore(); }
  g.lineWidth = 2;
  for (let k = 0; k < 2; k++) {
    g.beginPath();
    for (let i = 0; i <= 3; i++) { const a = (i / 3) * Math.PI * 2 + k * Math.PI / 3 - Math.PI / 2; g.lineTo(Math.cos(a) * 60, Math.sin(a) * 60); }
    g.stroke();
  }
  return new THREE.CanvasTexture(cv);
})();

// livelli di potenziamento dell'arma
const TIERS = [
  { min: 15, kind: 'legend', c1: 0xffc040, c2: 0xff60e0, rate: 260, trail: 0xffc050 },
  { min: 12, kind: 'storm', c1: 0xb060ff, c2: 0x70b0ff, rate: 110, trail: 0xb070ff },
  { min: 9, kind: 'fire', c1: 0xffa020, c2: 0xff4010, rate: 90, trail: 0xffa040 },
  { min: 7, kind: 'frost', c1: 0x60c0ff, c2: 0xc0f0ff, rate: 60, trail: 0x80d0ff },
];
const RARITY = [null, 0x6ad86a, 0x5aa0ff, 0xc070ff, 0xff9a30];

// ------------------------------------------------------------------ particelle in coordinate di mondo
const PVERT = `attribute float size; attribute float alpha; attribute vec3 color; varying vec3 vC; varying float vA;
  void main() { vC = color; vA = alpha; vec4 mv = modelViewMatrix * vec4(position, 1.0); gl_PointSize = size * 420.0 / -mv.z; gl_Position = projectionMatrix * mv; }`;
const PFRAG = `uniform sampler2D map; varying vec3 vC; varying float vA;
  void main() { vec4 t = texture2D(map, gl_PointCoord); gl_FragColor = vec4(vC * t.a * vA, 1.0); }`;

class Particles {
  constructor(max) {
    this.max = max; this.n = 0;
    this.pos = new Float32Array(max * 3); this.vel = new Float32Array(max * 3);
    this.col = new Float32Array(max * 3); this.size = new Float32Array(max); this.alpha = new Float32Array(max);
    this.life = new Float32Array(max); this.age = new Float32Array(max); this.s0 = new Float32Array(max);
    const g = new THREE.BufferGeometry();
    g.setAttribute('position', new THREE.BufferAttribute(this.pos, 3));
    g.setAttribute('color', new THREE.BufferAttribute(this.col, 3));
    g.setAttribute('size', new THREE.BufferAttribute(this.size, 1));
    g.setAttribute('alpha', new THREE.BufferAttribute(this.alpha, 1));
    this.points = new THREE.Points(g, new THREE.ShaderMaterial({
      uniforms: { map: { value: GLOW_TEX } }, vertexShader: PVERT, fragmentShader: PFRAG,
      transparent: true, depthWrite: false, blending: THREE.AdditiveBlending,
    }));
    this.points.frustumCulled = false;
    this.geo = g;
  }
  emit(p, v, color, size, life) {
    if (this.n >= this.max) return;
    const i = this.n++;
    this.pos.set([p.x, p.y, p.z], i * 3); this.vel.set([v.x, v.y, v.z], i * 3);
    this.col.set([color.r, color.g, color.b], i * 3);
    this.s0[i] = size; this.life[i] = life; this.age[i] = 0;
  }
  update(dt, drag = 0.9, rise = 0) {
    for (let i = 0; i < this.n; i++) {
      this.age[i] += dt;
      if (this.age[i] >= this.life[i]) { this.kill(i); i--; continue; }
      const k = i * 3, f = Math.pow(drag, dt * 10);
      this.vel[k] *= f; this.vel[k + 1] = this.vel[k + 1] * f + rise * dt; this.vel[k + 2] *= f;
      this.pos[k] += this.vel[k] * dt; this.pos[k + 1] += this.vel[k + 1] * dt; this.pos[k + 2] += this.vel[k + 2] * dt;
      const p = this.age[i] / this.life[i];
      this.alpha[i] = p < 0.15 ? p / 0.15 : 1 - (p - 0.15) / 0.85;
      this.size[i] = this.s0[i] * (1 - p * 0.5);
    }
    this.geo.setDrawRange(0, this.n);
    for (const a of ['position', 'color', 'size', 'alpha']) this.geo.attributes[a].needsUpdate = true;
  }
  kill(i) {
    const j = --this.n;
    if (i === j) return;
    for (const [arr, w] of [[this.pos, 3], [this.vel, 3], [this.col, 3]]) arr.copyWithin(i * w, j * w, j * w + w);
    for (const arr of [this.size, this.alpha, this.life, this.age, this.s0]) arr[i] = arr[j];
  }
  dispose() { this.geo.dispose(); this.points.material.dispose(); }
}

// ------------------------------------------------------------------ scia della lama
class Trail {
  constructor(color, width = 1, life = 0.24, N = 18) {
    this.N = N; this.life = life; this.samples = []; this.color = new THREE.Color(color); this.width = width;
    const g = new THREE.BufferGeometry();
    this.pos = new Float32Array(this.N * 2 * 3); this.col = new Float32Array(this.N * 2 * 3);
    g.setAttribute('position', new THREE.BufferAttribute(this.pos, 3));
    g.setAttribute('color', new THREE.BufferAttribute(this.col, 3));
    const idx = [];
    for (let i = 0; i < this.N - 1; i++) { const a = i * 2; idx.push(a, a + 1, a + 2, a + 1, a + 3, a + 2); }
    g.setIndex(idx);
    this.mesh = new THREE.Mesh(g, new THREE.MeshBasicMaterial({ vertexColors: true, transparent: true, depthWrite: false, blending: THREE.AdditiveBlending, side: THREE.DoubleSide }));
    this.mesh.frustumCulled = false;
    this.geo = g;
  }
  update(dt, a, b, active) {
    for (const s of this.samples) s.age += dt;
    if (this.samples.length && this.samples[0].a.distanceTo(a) > 3) this.samples.length = 0; // teletrasporto o scatto: niente scia
    if (active) this.samples.unshift({ a: a.clone(), b: b.clone(), age: 0 });
    while (this.samples.length > this.N || (this.samples.length && this.samples[this.samples.length - 1].age > this.life)) this.samples.pop();
    const n = this.samples.length;
    this.mesh.visible = n > 1;
    for (let i = 0; i < this.N; i++) {
      const s = this.samples[Math.min(i, n - 1)];
      if (!s) break;
      const f = Math.max(0, 1 - s.age / this.life) * (1 - i / this.N) * 1.6;
      this.pos.set([s.a.x, s.a.y, s.a.z, s.b.x, s.b.y, s.b.z], i * 6);
      const c = this.color;
      this.col.set([c.r * f * 0.25, c.g * f * 0.25, c.b * f * 0.25, c.r * f, c.g * f, c.b * f], i * 6);
    }
    this.geo.attributes.position.needsUpdate = true; this.geo.attributes.color.needsUpdate = true;
    this.geo.setDrawRange(0, Math.max(0, n - 1) * 6);
  }
  dispose() { this.geo.dispose(); this.mesh.material.dispose(); }
}

// ------------------------------------------------------------------ effetti di un personaggio
const _a = new THREE.Vector3(), _b = new THREE.Vector3(), _p = new THREE.Vector3(), _v = new THREE.Vector3(), _c = new THREE.Color();
const _ax = new THREE.Vector3(), _n1 = new THREE.Vector3(), _n2 = new THREE.Vector3();

export class GearFx {
  constructor(rig, gear) {
    this.rig = rig; this.t = Math.random() * 10; this.acc = 0; this.accA = 0;
    this.tier = TIERS.find((t) => (gear.wu || 0) >= t.min) || null;
    this.weapons = [];
    for (const grip of [rig.armR.grip, rig.armL.grip]) for (const w of grip.children) if (w.userData.blade) this.weapons.push(w);
    const legend = !!this.tier && this.tier.kind === 'legend';
    this.parts = new Particles(legend ? 1200 : 500);
    const trailCol = this.tier ? this.tier.trail : 0xd8e4f0;
    this.trails = this.weapons.filter((w) => w.userData.trail).map((w) => ({ w, tr: legend ? new Trail(trailCol, 1, 0.5, 34) : new Trail(trailCol) }));
    // aura dell'armatura: dal +9 o da Epico in su; cerchio di rune per Leggendario o +15
    const bu = gear.bu || 0, br = gear.br || 0;
    this.auraCol = new THREE.Color(br >= 3 ? RARITY[br] : bu >= 12 ? 0xb070ff : 0xffc860);
    this.auraRate = (bu >= 9 || br >= 3) ? 18 + (bu >= 12 ? 16 : 0) + (br >= 4 ? 20 : 0) : 0;
    if (br >= 4 || bu >= 15) {
      this.ring = new THREE.Mesh(new THREE.PlaneGeometry(3.0, 3.0), new THREE.MeshBasicMaterial({
        map: RUNE_TEX, color: br >= 4 ? RARITY[4] : 0xffc860, transparent: true, depthWrite: false, blending: THREE.AdditiveBlending, polygonOffset: true, polygonOffsetFactor: -4 }));
      this.ring.rotation.x = -Math.PI / 2;
      this.ring.position.y = 0.14;
      rig.root.add(this.ring);
    }
    this.glowMats = [];
    for (const w of this.weapons) w.traverse((m) => { if (m.isMesh && m.material.emissive && m.material.emissive.getHex()) this.glowMats.push(m.material); });
    // +15: alone sulla lama, punta incandescente e cerchio di rune che gira attorno all'impugnatura
    this.extras = [];
    this.arcT = 0;
    if (legend) for (const w of this.weapons) {
      const [p0, p1] = w.userData.blade, len = p0.distanceTo(p1), dir = p1.clone().sub(p0).normalize();
      const glow = (color, opacity) => new THREE.SpriteMaterial({ map: GLOW_TEX, color, opacity, transparent: true, depthWrite: false, blending: THREE.AdditiveBlending });
      const halo = new THREE.Sprite(glow(0xffa828, 0.5));
      halo.position.copy(p0).lerp(p1, 0.55); halo.scale.setScalar(len * 1.6);
      const tip = new THREE.Sprite(glow(0xfff2c8, 0.9));
      tip.position.copy(p1); tip.scale.setScalar(Math.max(0.35, len * 0.5));
      const disc = new THREE.Mesh(new THREE.PlaneGeometry(1, 1), new THREE.MeshBasicMaterial({ map: RUNE_TEX, color: 0xffc860, transparent: true, depthWrite: false, blending: THREE.AdditiveBlending, side: THREE.DoubleSide }));
      disc.position.copy(p0).lerp(p1, 0.1); disc.quaternion.setFromUnitVectors(new THREE.Vector3(0, 0, 1), dir); disc.scale.setScalar(Math.max(0.5, len * 0.55));
      w.add(halo, tip, disc);
      this.extras.push({ halo, tip, disc, len });
    }
    this.added = false;
  }

  bladePoints(w, a, b) {
    const [p0, p1] = w.userData.blade;
    a.copy(p0); b.copy(p1);
    w.localToWorld(a); w.localToWorld(b);
  }

  update(dt, attacking) {
    const scene = this.rig.root.parent;
    if (!scene) return;
    if (!this.added) {
      scene.add(this.parts.points);
      for (const t of this.trails) scene.add(t.tr.mesh);
      this.added = true;
    }
    this.t += dt;
    const T = this.tier;
    // bagliore pulsante della lama
    for (const m of this.glowMats) m.emissiveIntensity = (T ? (T.kind === 'legend' ? 0.95 : 0.45) : 0.3) + Math.sin(this.t * 4) * 0.12;
    // scie dei colpi
    for (const { w, tr } of this.trails) {
      this.bladePoints(w, _a, _b);
      if (T && T.kind === 'legend') _b.sub(_a).multiplyScalar(1.3).add(_a);   // scia più larga della lama
      tr.update(dt, _a, _b, attacking);
    }
    for (const x of this.extras) {
      const pulse = 0.5 + 0.5 * Math.sin(this.t * 3.2);
      x.halo.material.opacity = 0.35 + pulse * 0.2 + (attacking ? 0.35 : 0);
      x.tip.scale.setScalar(Math.max(0.35, x.len * 0.5) * (0.85 + pulse * 0.3 + (attacking ? 0.5 : 0)));
      x.disc.rotateZ(dt * 1.8);
      x.disc.material.opacity = 0.55 + pulse * 0.35;
    }
    // +15: scariche che corrono lungo la lama
    if (T && T.kind === 'legend' && this.weapons.length) {
      this.arcT -= dt;
      if (this.arcT <= 0) {
        this.arcT = (attacking ? 0.04 : 0.1) + Math.random() * 0.22;
        const w = this.weapons[Math.floor(Math.random() * this.weapons.length)];
        this.bladePoints(w, _a, _b);
        _c.set(Math.random() < 0.7 ? 0xfff0b0 : 0xff80e0);
        for (let i = 0; i <= 10; i++) {
          const j = i === 0 || i === 10 ? 0 : 0.09;
          _p.copy(_a).lerp(_b, i / 10); _p.x += (Math.random() - 0.5) * j; _p.y += (Math.random() - 0.5) * j; _p.z += (Math.random() - 0.5) * j;
          this.parts.emit(_p, _v.set(0, 0, 0), _c, 0.12, 0.1);
        }
      }
    }
    // particelle dell'arma
    if (T) {
      this.acc += dt * T.rate * (attacking ? (T.kind === 'legend' ? 3.5 : 2.2) : 1);
      while (this.acc >= 1) {
        this.acc -= 1;
        const w = this.weapons[Math.floor(Math.random() * this.weapons.length)];
        if (!w) break;
        this.bladePoints(w, _a, _b);
        _p.copy(_a).lerp(_b, Math.random());
        const k = T.kind;
        _c.set(Math.random() < 0.5 ? T.c1 : T.c2);
        if (k === 'fire') _v.set((Math.random() - 0.5) * 0.4, 0.6 + Math.random() * 0.8, (Math.random() - 0.5) * 0.4);
        else if (k === 'storm') _v.set((Math.random() - 0.5) * 3, (Math.random() - 0.5) * 3, (Math.random() - 0.5) * 3);
        else if (k === 'legend') {
          // due spirali dorate attorno alla lama, con faville bianche e magenta che salgono verso la punta
          _ax.copy(_b).sub(_a).normalize();
          _n1.set(0, 1, 0).cross(_ax); if (_n1.lengthSq() < 0.01) _n1.set(1, 0, 0).cross(_ax); _n1.normalize();
          _n2.copy(_ax).cross(_n1);
          const u = Math.random(), ang = this.t * 9 + u * 11 + (Math.random() < 0.5 ? 0 : Math.PI), cs = Math.cos(ang), sn = Math.sin(ang);
          _p.copy(_a).lerp(_b, u).addScaledVector(_n1, cs * 0.13).addScaledVector(_n2, sn * 0.13);
          _v.copy(_n1).multiplyScalar(cs * 0.45).addScaledVector(_n2, sn * 0.45).addScaledVector(_ax, 1.1 + Math.random() * 0.8);
          _v.y += 0.25;
          const r = Math.random();
          _c.set(r < 0.6 ? 0xffb830 : r < 0.85 ? 0xfff4d0 : 0xff50c0);
        }
        else _v.set((Math.random() - 0.5) * 0.3, (Math.random() - 0.5) * 0.3 + 0.1, (Math.random() - 0.5) * 0.3);
        const size = k === 'storm' ? 0.09 : k === 'fire' ? 0.16 : k === 'legend' ? 0.12 + Math.random() * 0.09 : 0.1;
        const life = k === 'storm' ? 0.18 : k === 'fire' ? 0.75 : k === 'legend' ? 0.75 : 0.6;
        this.parts.emit(_p, _v, _c, size, life);
      }
    }
    // aura dell'armatura
    if (this.auraRate) {
      this.accA += dt * this.auraRate;
      const r = this.rig.root.position;
      while (this.accA >= 1) {
        this.accA -= 1;
        const a = Math.random() * 6.28, d = 0.35 + Math.random() * 0.35;
        _p.set(r.x + Math.cos(a) * d, r.y + 0.1 + Math.random() * 0.6, r.z + Math.sin(a) * d);
        _v.set(Math.cos(a) * 0.05, 0.7 + Math.random() * 0.6, Math.sin(a) * 0.05);
        this.parts.emit(_p, _v, this.auraCol, 0.11 + Math.random() * 0.06, 1.3);
      }
    }
    if (this.ring) {
      this.ring.rotation.z += dt * 0.6;
      this.ring.material.opacity = 0.8 + Math.sin(this.t * 2.5) * 0.2;
    }
    this.parts.update(dt, T && T.kind === 'storm' ? 0.6 : 0.9, T && T.kind === 'fire' ? 0.6 : 0);
  }

  dispose() {
    this.parts.points.removeFromParent(); this.parts.dispose();
    for (const t of this.trails) { t.tr.mesh.removeFromParent(); t.tr.dispose(); }
    if (this.ring) { this.ring.removeFromParent(); this.ring.geometry.dispose(); this.ring.material.dispose(); }
    for (const x of this.extras) { for (const o of [x.halo, x.tip, x.disc]) { o.removeFromParent(); o.material.dispose(); } x.disc.geometry.dispose(); }
  }
}

// ------------------------------------------------------------------ scintille dei colpi a segno
export class ImpactFx {
  constructor(scene) { this.parts = new Particles(400); scene.add(this.parts.points); }
  burst(pos, color, crit) {
    const n = crit ? 26 : 12;
    _c.set(color);
    for (let i = 0; i < n; i++) {
      const a = Math.random() * 6.28, e = (Math.random() - 0.3) * 1.6, s = (crit ? 5 : 3.2) * (0.5 + Math.random());
      _v.set(Math.cos(a) * Math.cos(e) * s, Math.sin(e) * s + 1, Math.sin(a) * Math.cos(e) * s);
      this.parts.emit(pos, _v, i % 3 ? _c : new THREE.Color(0xffffff), crit ? 0.2 : 0.14, 0.25 + Math.random() * 0.25);
    }
    this.parts.emit(pos, _v.set(0, 0, 0), _c, crit ? 1.6 : 0.9, 0.14);
  }
  update(dt) { this.parts.update(dt, 0.75, -6); }
}
