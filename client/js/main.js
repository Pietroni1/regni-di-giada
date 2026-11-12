// Avvio del client: rendering, schermate di accesso e selezione personaggio.
import * as THREE from 'three';
import { buildWorld } from './world3d.js';
import { Post, QUALITIES } from './post.js';
import { Net } from './net.js';
import { Game } from './game.js';
import { loadCharacterAssets } from './skinned.js';
import { loadNatureAssets } from './nature.js';
import { CLASSES } from '/shared/data.js';
import { KINGDOMS, KINGDOM_IDS, heightAt } from '/shared/world.js';

const $ = (id) => document.getElementById(id);
const esc = (s) => String(s).replace(/[&<>"']/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
const show = (id) => { for (const s of ['loading', 'login-screen', 'select-screen']) $(s).classList.toggle('hidden', s !== id); };

const canvas = $('scene');
const renderer = new THREE.WebGLRenderer({ canvas, antialias: true });
renderer.setPixelRatio(Math.min(devicePixelRatio, 1.5));
renderer.setSize(innerWidth, innerHeight);
renderer.shadowMap.enabled = true;
renderer.shadowMap.type = THREE.PCFSoftShadowMap;
renderer.toneMapping = THREE.ACESFilmicToneMapping;
renderer.toneMappingExposure = 1.05;
const scene = new THREE.Scene();
const camera = new THREE.PerspectiveCamera(55, innerWidth / innerHeight, 0.3, 1500);
const post = new Post(renderer, scene, camera);
window.__post = post;
addEventListener('resize', () => {
  post.resize(innerWidth, innerHeight);
  camera.aspect = innerWidth / innerHeight;
  camera.updateProjectionMatrix();
});

let world, game, net;
let selKingdom = 'fenice', selClass = 'lama';
let menuKingdom = KINGDOM_IDS[Math.floor(Math.random() * 3)];

async function boot() {
  show('loading');
  await new Promise(r => setTimeout(r, 30));
  try { await loadNatureAssets(); } catch (e) { console.warn('Alberi da Blender non caricati, uso quelli procedurali:', e); }
  world = buildWorld(scene, post);
  try { await loadCharacterAssets(); } catch (e) { console.warn('Modello del personaggio non caricato, uso quello procedurale:', e); }
  net = new Net();
  try { await net.connect(); }
  catch { $('loading').querySelector('.loading-text').textContent = 'Impossibile collegarsi al server. Controlla che sia avviato e ricarica la pagina.'; return; }
  net.onclose = () => {
    if (game && game.active) {
      game.active = false;
      document.getElementById('game-ui').classList.add('hidden');
    }
    show('loading');
    $('loading').querySelector('.loading-text').innerHTML = (kickedMsg || 'Connessione al server persa.') + '<br><br><button class="btn primary" onclick="location.reload()">Ricollegati</button>';
  };
  game = new Game(renderer, scene, camera, world, net);
  game.post = post;
  setupGfxButtons();
  window.__game = game;
  setupMenus();
  show('login-screen');
  const saved = localStorage.getItem('rdg-user');
  if (saved) { $('login-user').value = saved; $('login-pass').focus(); } else $('login-user').focus();
  requestAnimationFrame(loop);
}

let kickedMsg = '';

function setupGfxButtons() {
  const el = $('gfx-buttons');
  const render = () => {
    el.innerHTML = Object.entries(QUALITIES).map(([k, q]) => `<button class="btn ${post.quality === k ? 'primary' : ''}" data-q="${k}" style="padding:2px 10px;font-size:14px">${q.name}</button>`).join(' ');
    el.querySelectorAll('[data-q]').forEach(b => { b.onclick = () => { post.set(b.dataset.q); render(); }; });
  };
  render();
}

function setupMenus() {
  const auth = (t) => {
    const user = $('login-user').value.trim(), pass = $('login-pass').value;
    if (!user || !pass) { $('login-msg').textContent = 'Inserisci account e password'; return; }
    $('login-msg').textContent = '';
    try { localStorage.setItem('rdg-user', user); } catch { /* ignora */ }
    net.send({ t, user, pass });
  };
  $('btn-login').onclick = () => auth('login');
  $('btn-register').onclick = () => auth('register');
  $('login-pass').addEventListener('keydown', (e) => { if (e.key === 'Enter') auth('login'); });
  $('login-user').addEventListener('keydown', (e) => { if (e.key === 'Enter') $('login-pass').focus(); });

  net.on('auth_err', (m) => { $('login-msg').textContent = m.m; $('select-msg').textContent = m.m; });
  net.on('auth_ok', () => show('select-screen'));
  net.on('kicked', (m) => { kickedMsg = m.m; });
  net.on('chars', (m) => renderChars(m.list, m.max));
  net.on('enter', (m) => {
    for (const s of ['loading', 'login-screen', 'select-screen']) $(s).classList.add('hidden');
    game.start(m);
  });

  $('btn-new-char').onclick = () => { $('create-panel').classList.remove('hidden'); renderPicks(); $('new-name').focus(); };
  $('btn-cancel-create').onclick = () => $('create-panel').classList.add('hidden');
  $('btn-logout').onclick = () => location.reload();
  $('btn-create').onclick = () => {
    $('select-msg').textContent = '';
    net.send({ t: 'create', name: $('new-name').value.trim(), cls: selClass, kd: selKingdom });
  };
  $('new-name').addEventListener('keydown', (e) => { if (e.key === 'Enter') $('btn-create').click(); });
}

function renderChars(list, max) {
  $('create-panel').classList.add('hidden');
  $('new-name').value = '';
  $('select-msg').textContent = '';
  const el = $('char-list');
  if (!list.length) el.innerHTML = '<div style="color:#cdbf9c">Nessun personaggio. Creane uno!</div>';
  else el.innerHTML = list.map(c => {
    const k = KINGDOMS[c.kd], cl = CLASSES[c.cls];
    return `<div class="char-card" data-id="${c.id}"><div class="cg" style="border-color:${k.color};color:${k.color}">${cl.glyph}</div>
      <div class="ci"><div class="cn">${esc(c.name)}</div><div class="cs">Liv. ${c.lvl} ${cl.name} — ${k.short}</div></div>
      <button class="del" title="Elimina" data-del="${c.id}">✕</button></div>`;
  }).join('');
  el.querySelectorAll('.char-card').forEach(card => {
    card.onclick = (e) => {
      if (e.target.dataset.del) {
        const c = list.find(x => x.id === +e.target.dataset.del);
        if (confirm(`Eliminare definitivamente ${c.name}?`)) net.send({ t: 'delete', id: c.id });
        return;
      }
      net.send({ t: 'play', id: +card.dataset.id });
    };
  });
  $('btn-new-char').disabled = list.length >= max;
  if (!list.length) { $('create-panel').classList.remove('hidden'); renderPicks(); }
}

function renderPicks() {
  $('kingdom-pick').innerHTML = KINGDOM_IDS.map(id => {
    const k = KINGDOMS[id];
    return `<div class="pick ${id === selKingdom ? 'sel' : ''}" data-k="${id}"><div class="pn" style="color:${k.color}">${k.name}</div><div class="pd">${k.desc}</div><div class="pd" style="margin-top:4px">Villaggio: ${k.villageName}</div></div>`;
  }).join('');
  $('class-pick').innerHTML = Object.entries(CLASSES).map(([id, c]) =>
    `<div class="pick ${id === selClass ? 'sel' : ''}" data-c="${id}"><div class="pg">${c.glyph}</div><div class="pn">${c.name}</div><div class="pd"><i>${c.title}</i><br>${c.desc}</div></div>`).join('');
  $('kingdom-pick').querySelectorAll('.pick').forEach(p => { p.onclick = () => { selKingdom = p.dataset.k; menuKingdom = selKingdom; renderPicks(); }; });
  $('class-pick').querySelectorAll('.pick').forEach(p => { p.onclick = () => { selClass = p.dataset.c; renderPicks(); }; });
}

let last = performance.now(), menuT = 0;
const focus = new THREE.Vector3();
function loop(now) {
  requestAnimationFrame(loop);
  const dt = Math.min(0.25, (now - last) / 1000);
  last = now;
  if (game && game.active) {
    game.update(dt);
    focus.copy(game.camTarget);
  } else {
    menuT += dt * 0.08;
    const v = KINGDOMS[menuKingdom].village;
    const r = 58;
    camera.position.set(v.x + Math.sin(menuT) * r, 22, v.z + Math.cos(menuT) * r);
    focus.set(v.x, 5, v.z);
    const gh = heightAt(camera.position.x, camera.position.z) + 6;
    if (camera.position.y < gh) camera.position.y = gh;
    camera.lookAt(focus);
  }
  world.update(dt, focus, game && game.active ? camera : null);
  if (!window.__freeze) post.render();
}

boot();
