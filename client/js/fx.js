// Effetti visivi: numeri di danno, anelli, proiettili, fulmini, aure, particelle.
import * as THREE from 'three';
import { heightAt } from '/shared/world.js';

const add = (c, o = 0.9) => new THREE.MeshBasicMaterial({ color: c, transparent: true, opacity: o, depthWrite: false, blending: THREE.AdditiveBlending, side: THREE.DoubleSide });

export class Fx {
  constructor(scene, camera, floatLayer) {
    this.scene = scene; this.camera = camera; this.layer = floatLayer;
    this.list = [];
    this.v = new THREE.Vector3();
  }

  spawn(obj, dur, update, onEnd) {
    if (obj) this.scene.add(obj);
    this.list.push({ obj, t: 0, dur, update, onEnd });
  }

  update(dt) {
    for (let i = this.list.length - 1; i >= 0; i--) {
      const e = this.list[i];
      e.t += dt;
      const p = Math.min(1, e.t / e.dur);
      if (e.update) e.update(p, dt, e);
      if (p >= 1) {
        if (e.obj) { this.scene.remove(e.obj); e.obj.traverse(m => { if (m.isMesh || m.isLine) { m.geometry.dispose(); m.material.dispose(); } }); }
        if (e.onEnd) e.onEnd();
        this.list.splice(i, 1);
      }
    }
  }

  // numero fluttuante sullo schermo
  number(pos, text, cls) {
    this.v.copy(pos);
    this.v.project(this.camera);
    if (this.v.z > 1) return;
    const el = document.createElement('div');
    el.className = 'floater ' + (cls || '');
    el.textContent = text;
    const x = (this.v.x * 0.5 + 0.5) * innerWidth + (Math.random() - 0.5) * 30;
    const y = (-this.v.y * 0.5 + 0.5) * innerHeight;
    el.style.left = x + 'px'; el.style.top = y + 'px';
    this.layer.appendChild(el);
    setTimeout(() => el.remove(), 1300);
  }

  ring(pos, color, radius, dur = 0.5, y = 0.15) {
    const m = new THREE.Mesh(new THREE.RingGeometry(0.75, 1, 40), add(color));
    m.rotation.x = -Math.PI / 2;
    m.position.set(pos.x, heightAt(pos.x, pos.z) + y, pos.z);
    this.spawn(m, dur, p => { const s = 0.3 + p * radius; m.scale.set(s, s, s); m.material.opacity = 0.9 * (1 - p); });
  }

  disc(pos, color, radius, dur = 0.6) {
    const m = new THREE.Mesh(new THREE.CircleGeometry(1, 32), add(color, 0.5));
    m.rotation.x = -Math.PI / 2;
    m.position.set(pos.x, heightAt(pos.x, pos.z) + 0.12, pos.z);
    m.scale.setScalar(radius);
    this.spawn(m, dur, p => { m.material.opacity = 0.45 * (1 - p); });
  }

  spin(ent, color, radius) {
    const m = new THREE.Mesh(new THREE.TorusGeometry(radius * 0.7, 0.12, 4, 32, Math.PI * 1.4), add(color));
    m.rotation.x = Math.PI / 2;
    this.spawn(m, 0.4, (p) => {
      m.position.set(ent.x, ent.y + 1.1, ent.z);
      m.rotation.z = p * Math.PI * 3;
      m.material.opacity = 0.9 * (1 - p);
    });
  }

  slash(ent, color) {
    const m = new THREE.Mesh(new THREE.TorusGeometry(1.1, 0.06, 3, 16, Math.PI * 0.8), add(color));
    this.spawn(m, 0.22, (p) => {
      m.position.set(ent.x + Math.sin(ent.r) * 0.8, ent.y + 1.2, ent.z + Math.cos(ent.r) * 0.8);
      m.rotation.set(0.4, ent.r + Math.PI / 2, p * 1.5);
      m.material.opacity = 0.9 * (1 - p);
    });
  }

  bolt(from, to, color, size = 0.3, dur = 0.28, onHit) {
    const g = new THREE.Group();
    g.add(new THREE.Mesh(new THREE.SphereGeometry(size, 8, 6), add(color, 1)));
    g.add(new THREE.Mesh(new THREE.SphereGeometry(size * 2, 8, 6), add(color, 0.35)));
    const a = new THREE.Vector3(from.x, from.y + 1.5, from.z);
    this.spawn(g, dur, (p) => {
      const b = new THREE.Vector3(to.x, to.y + 1.2, to.z);
      g.position.lerpVectors(a, b, p);
    }, onHit);
  }

  arrow(from, to, color = 0xe8dcc0) {
    const g = new THREE.Group();
    const shaft = new THREE.Mesh(new THREE.CylinderGeometry(0.025, 0.025, 1.0, 4), new THREE.MeshBasicMaterial({ color }));
    shaft.rotation.x = Math.PI / 2;
    g.add(shaft);
    const a = new THREE.Vector3(from.x, from.y + 1.5, from.z);
    this.spawn(g, 0.22, (p) => {
      const b = new THREE.Vector3(to.x, to.y + 1.2, to.z);
      g.position.lerpVectors(a, b, p);
      g.lookAt(b);
    });
  }

  lightning(to, color) {
    const pts = [];
    const top = new THREE.Vector3(to.x + (Math.random() - 0.5) * 2, to.y + 14, to.z + (Math.random() - 0.5) * 2);
    const bot = new THREE.Vector3(to.x, to.y + 0.8, to.z);
    for (let i = 0; i <= 10; i++) {
      const p = top.clone().lerp(bot, i / 10);
      if (i > 0 && i < 10) { p.x += (Math.random() - 0.5) * 1.4; p.z += (Math.random() - 0.5) * 1.4; }
      pts.push(p);
    }
    const line = new THREE.Line(new THREE.BufferGeometry().setFromPoints(pts), new THREE.LineBasicMaterial({ color, transparent: true, blending: THREE.AdditiveBlending }));
    const g = new THREE.Group(); g.add(line);
    const flash = new THREE.PointLight(color, 30, 14, 1.5);
    flash.position.copy(bot); g.add(flash);
    this.spawn(g, 0.3, (p) => { line.material.opacity = p < 0.5 ? 1 : 1 - (p - 0.5) * 2; flash.intensity = 30 * (1 - p); });
    this.ring(to, color, 2.5, 0.35);
  }

  aura(ent, color) {
    const m = new THREE.Mesh(new THREE.CylinderGeometry(0.9, 1.1, 2.6, 16, 1, true), add(color, 0.5));
    this.spawn(m, 0.9, (p) => {
      m.position.set(ent.x, ent.y + 1.3 + p * 0.6, ent.z);
      m.scale.set(1 + p * 0.3, 1, 1 + p * 0.3);
      m.material.opacity = 0.5 * (1 - p);
    });
    this.ring(ent, color, 2.2, 0.6);
  }

  sparkles(ent, color, n = 14, dur = 1.0) {
    const g = new THREE.Group();
    const geo = new THREE.OctahedronGeometry(0.09, 0);
    const parts = [];
    for (let i = 0; i < n; i++) {
      const m = new THREE.Mesh(geo, add(color, 1));
      const a = Math.random() * Math.PI * 2, r = 0.3 + Math.random() * 0.7;
      m.userData = { x: Math.cos(a) * r, z: Math.sin(a) * r, y: Math.random() * 0.8, s: 1 + Math.random() * 1.5 };
      g.add(m); parts.push(m);
    }
    this.spawn(g, dur, (p) => {
      g.position.set(ent.x, ent.y, ent.z);
      for (const m of parts) { const u = m.userData; m.position.set(u.x, u.y + p * 2.2 * u.s, u.z); m.material.opacity = 1 - p; }
    });
  }

  column(ent, color) {
    const m = new THREE.Mesh(new THREE.CylinderGeometry(1.2, 1.2, 30, 16, 1, true), add(color, 0.55));
    this.spawn(m, 1.4, (p) => {
      m.position.set(ent.x, ent.y + 15, ent.z);
      const s = p < 0.2 ? p * 5 : 1 - (p - 0.2) * 0.8;
      m.scale.set(s, 1, s);
      m.material.opacity = 0.55 * (1 - p);
    });
    this.ring(ent, color, 5, 1.0);
    this.sparkles(ent, color, 24, 1.4);
  }

  rain(pos, color, radius) {
    for (let i = 0; i < 14; i++) {
      const a = Math.random() * Math.PI * 2, r = Math.random() * radius;
      const x = pos.x + Math.cos(a) * r, z = pos.z + Math.sin(a) * r;
      const y = heightAt(x, z);
      const shaft = new THREE.Mesh(new THREE.CylinderGeometry(0.03, 0.03, 1.1, 4), add(color, 1));
      const delay = Math.random() * 0.25;
      this.spawn(shaft, 0.45 + delay, (p, dt, e) => {
        const q = Math.max(0, (e.t - delay) / 0.45);
        shaft.position.set(x, y + 12 * (1 - q) + 0.5, z);
        shaft.visible = e.t > delay;
      });
    }
    this.disc(pos, color, radius, 0.7);
  }

  wind(ent, color, radius) {
    for (let k = 0; k < 3; k++) {
      const m = new THREE.Mesh(new THREE.TorusGeometry(radius * (0.4 + k * 0.25), 0.1, 3, 32, Math.PI * 1.2), add(color, 0.8));
      m.rotation.x = Math.PI / 2;
      this.spawn(m, 0.7, (p) => {
        m.position.set(ent.x, ent.y + 0.5 + k * 0.5, ent.z);
        m.rotation.z = -p * Math.PI * (2 + k);
        m.material.opacity = 0.8 * (1 - p);
      });
    }
  }

  quake(pos, color, radius) {
    this.ring(pos, color, radius, 0.5, 0.2);
    this.ring(pos, 0xffffff, radius * 0.7, 0.35, 0.25);
    this.disc(pos, color, radius, 0.5);
  }

  dash(from, to, color) {
    const a = new THREE.Vector3(from.x, from.y + 1.1, from.z), b = new THREE.Vector3(to.x, to.y + 1.1, to.z);
    const len = a.distanceTo(b);
    if (len < 0.5) return;
    const m = new THREE.Mesh(new THREE.CylinderGeometry(0.25, 0.05, len, 6, 1, true), add(color, 0.6));
    m.position.copy(a).lerp(b, 0.5);
    m.lookAt(b); m.rotateX(Math.PI / 2);
    this.spawn(m, 0.35, (p) => { m.material.opacity = 0.6 * (1 - p); });
  }
}
