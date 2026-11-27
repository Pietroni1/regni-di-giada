// Comprime i file grossi della versione per il browser (cartella web/, esportata da Godot con la preimpostazione «Web»):
// accanto a index.wasm, index.pck e index.js scrive le copie .gz, che il server manda ai browser al posto degli originali.
//   npm run web:comprimi
import fs from 'node:fs';
import path from 'node:path';
import zlib from 'node:zlib';
import { fileURLToPath } from 'node:url';

const WEB = path.join(path.dirname(fileURLToPath(import.meta.url)), '..', '..', 'web');
if (!fs.existsSync(path.join(WEB, 'index.html'))) {
  console.error('Manca web/index.html: esporta prima il client con Godot (preimpostazione «Web»).');
  process.exit(1);
}
let prima = 0, dopo = 0;
for (const nome of fs.readdirSync(WEB)) {
  if (!/\.(wasm|pck|js)$/.test(nome)) continue;
  const dati = fs.readFileSync(path.join(WEB, nome));
  const gz = zlib.gzipSync(dati, { level: 9 });
  fs.writeFileSync(path.join(WEB, nome + '.gz'), gz);
  prima += dati.length; dopo += gz.length;
  console.log(`${nome}: ${(dati.length / 1e6).toFixed(1)} MB → ${(gz.length / 1e6).toFixed(1)} MB`);
}
console.log(`Totale da scaricare la prima volta: ${(dopo / 1e6).toFixed(1)} MB (senza compressione ${(prima / 1e6).toFixed(1)} MB).`);
