// Riscrive un .glb togliendo la compressione Draco (KHR_draco_mesh_compression), che Godot non legge.
// Usa il decodificatore già presente in node_modules/three: nessuna dipendenza in più.
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { createRequire } from 'node:module';

const qui = path.dirname(fileURLToPath(import.meta.url));
let modulo = null;
async function draco() {
  if (modulo) return modulo;
  const src = fs.readFileSync(path.join(qui, '../../node_modules/three/examples/jsm/libs/draco/gltf/draco_decoder.js'), 'utf8');
  // il file è uno script classico (non un modulo): lo si valuta e si prende la funzione che crea il decodificatore
  const crea = new Function('__filename', '__dirname', 'require', src + '\nreturn DracoDecoderModule;')(path.join(qui, 'draco_decoder.js'), qui, createRequire(import.meta.url));
  modulo = await crea();
  return modulo;
}

const TIPI = { 5120: Int8Array, 5121: Uint8Array, 5122: Int16Array, 5123: Uint16Array, 5125: Uint32Array, 5126: Float32Array };
const COMP = { SCALAR: 1, VEC2: 2, VEC3: 3, VEC4: 4, MAT4: 16 };

function leggi(glb) {
  if (glb.readUInt32LE(0) !== 0x46546c67) throw new Error('non è un file .glb');
  let p = 12, json = null, bin = Buffer.alloc(0);
  while (p < glb.length) {
    const len = glb.readUInt32LE(p), tipo = glb.readUInt32LE(p + 4), dati = glb.subarray(p + 8, p + 8 + len);
    if (tipo === 0x4e4f534a) json = JSON.parse(dati.toString('utf8')); else if (tipo === 0x004e4942) bin = dati;
    p += 8 + len;
  }
  return { json, bin };
}

function scrivi(json, bin) {
  let j = Buffer.from(JSON.stringify(json), 'utf8');
  if (j.length % 4) j = Buffer.concat([j, Buffer.alloc(4 - j.length % 4, 0x20)]);
  if (bin.length % 4) bin = Buffer.concat([bin, Buffer.alloc(4 - bin.length % 4)]);
  const testa = Buffer.alloc(12);
  testa.writeUInt32LE(0x46546c67, 0); testa.writeUInt32LE(2, 4); testa.writeUInt32LE(12 + 8 + j.length + 8 + bin.length, 8);
  const tj = Buffer.alloc(8); tj.writeUInt32LE(j.length, 0); tj.writeUInt32LE(0x4e4f534a, 4);
  const tb = Buffer.alloc(8); tb.writeUInt32LE(bin.length, 0); tb.writeUInt32LE(0x004e4942, 4);
  return Buffer.concat([testa, tj, j, tb, bin]);
}

export async function togliDraco(glb) {
  const { json, bin } = leggi(glb);
  if (!(json.extensionsUsed || []).includes('KHR_draco_mesh_compression')) return glb;
  const M = await draco();
  const pezzi = [], viste = [];
  let lungo = 0;
  const aggiungi = (buf, target) => {
    const pad = (4 - lungo % 4) % 4;
    if (pad) { pezzi.push(Buffer.alloc(pad)); lungo += pad; }
    const v = { buffer: 0, byteOffset: lungo, byteLength: buf.length };
    if (target) v.target = target;
    pezzi.push(buf); lungo += buf.length;
    viste.push(v);
    return viste.length - 1;
  };
  // viste compresse: non si copiano
  const compresse = new Set();
  for (const m of json.meshes || []) for (const pr of m.primitives) {
    const d = pr.extensions && pr.extensions.KHR_draco_mesh_compression;
    if (d) compresse.add(d.bufferView);
  }
  const mappa = new Map();
  (json.bufferViews || []).forEach((v, i) => {
    if (compresse.has(i)) return;
    const n = aggiungi(bin.subarray(v.byteOffset || 0, (v.byteOffset || 0) + v.byteLength), v.target);
    if (v.byteStride) viste[n].byteStride = v.byteStride;
    mappa.set(i, n);
  });
  for (const a of json.accessors || []) if (a.bufferView !== undefined && mappa.has(a.bufferView)) a.bufferView = mappa.get(a.bufferView);
  for (const im of json.images || []) if (im.bufferView !== undefined) im.bufferView = mappa.get(im.bufferView);

  const dec = new M.Decoder();
  for (const m of json.meshes || []) for (const pr of m.primitives) {
    const d = pr.extensions && pr.extensions.KHR_draco_mesh_compression;
    if (!d) continue;
    const v = json.bufferViews[d.bufferView];
    const dati = bin.subarray(v.byteOffset || 0, (v.byteOffset || 0) + v.byteLength);
    const db = new M.DecoderBuffer();
    db.Init(new Int8Array(dati.buffer, dati.byteOffset, dati.length), dati.length);
    const mesh = new M.Mesh();
    const st = dec.DecodeBufferToMesh(db, mesh);
    if (!st.ok() || !mesh.ptr) throw new Error('Draco: decodifica fallita (' + st.error_msg() + ')');
    // indici
    const nf = mesh.num_faces(), nb = nf * 3 * 4, pi = M._malloc(nb);
    dec.GetTrianglesUInt32Array(mesh, nb, pi);
    const indici = Buffer.from(new Uint8Array(M.HEAPU8.buffer, pi, nb));
    M._free(pi);
    const ai = json.accessors[pr.indices];
    ai.bufferView = aggiungi(Buffer.from(indici), 34963); ai.byteOffset = 0; ai.componentType = 5125; ai.count = nf * 3;
    // attributi
    const np = mesh.num_points();
    for (const [nome, id] of Object.entries(d.attributes)) {
      const acc = json.accessors[pr.attributes[nome]];
      const Tipo = TIPI[acc.componentType], nc = COMP[acc.type];
      const att = dec.GetAttributeByUniqueId(mesh, id);
      const bytes = np * nc * Tipo.BYTES_PER_ELEMENT, pt = M._malloc(bytes);
      const dt = { 5120: M.DT_INT8, 5121: M.DT_UINT8, 5122: M.DT_INT16, 5123: M.DT_UINT16, 5125: M.DT_UINT32, 5126: M.DT_FLOAT32 }[acc.componentType];
      dec.GetAttributeDataArrayForAllPoints(mesh, att, dt, bytes, pt);
      const copia = Buffer.from(new Uint8Array(M.HEAPU8.buffer, pt, bytes));
      M._free(pt);
      acc.bufferView = aggiungi(Buffer.from(copia), 34962); acc.byteOffset = 0; acc.count = np;
    }
    M.destroy(mesh); M.destroy(db);
    delete pr.extensions.KHR_draco_mesh_compression;
    if (!Object.keys(pr.extensions).length) delete pr.extensions;
  }
  M.destroy(dec);
  json.bufferViews = viste;
  json.buffers = [{ byteLength: lungo }];
  json.extensionsUsed = (json.extensionsUsed || []).filter(e => e !== 'KHR_draco_mesh_compression');
  json.extensionsRequired = (json.extensionsRequired || []).filter(e => e !== 'KHR_draco_mesh_compression');
  if (!json.extensionsUsed.length) delete json.extensionsUsed;
  if (!json.extensionsRequired.length) delete json.extensionsRequired;
  return scrivi(json, Buffer.concat(pezzi));
}
