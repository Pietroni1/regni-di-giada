// Piante delle Prove del Sigillo: stanze, ali a scelta, porte, leve, varianti settimanali, pericoli e tesoro.
// Solo dati e funzioni pure, nessun import: lo importano shared/data.js (DUNGEON), shared/altolivello.js (FORGIA),
// server/prove.js (logica) e tools/godot/esporta.mjs (dati per il client Godot).
//
// Coordinate locali rispetto all'origine dell'istanza: x = larghezza, z = profondità (si entra a sud, il boss è a nord).
//  stanze:    { id, nome, tipo, r: [x1, z1, x2, z2], ala?, porta? }. Le stanze si toccano con almeno 1 m di sovrapposizione.
//             tipo: ingresso | corridoio | bivio | sala | ponte | passerella | cancello | tesoro | boss (serve al client
//             per l'architettura). `porta`: la stanza è calpestabile solo quando quella porta è aperta.
//  ali:       { id: { nome, colore, segno, nota } }: le strade a scelta; il colore è quello delle fiaccole al bivio.
//  porte:     { id: { nome, apre: 'branco' (cade il branco con `apre: id`) | 'leva' (un giocatore la raggiunge), dice } }.
//  leve:      [{ id, porta, x, z }].
//  vuoti:     [x1, z1, x2, z2]: abisso o lago di lava. Non si calpesta, ma non blocca la vista (i mostri a distanza
//             tirano attraverso) e il client ci mette parapetti al posto dei muri.
//  ostacoli:  [x, z, raggio, forma]: pilastri, sarcofagi, incudini. Non si attraversano (la forma serve solo al client).
//  branchi:   { id, x, z, mobs, ala?, apre?: porta, tesoro?: true }.
//  pericoli:  { id, nome, x, z, r, ogni (ms), ms (preavviso), mult, sfasa (ms) }: trappole a tempo.
//  ritorni:   { id, nome, x, z, px, pz (dove si rinasce), zona: [x1, z1, x2, z2] }: quando un giocatore vivo entra nella zona si accende il
//             Braciere del Ritorno e chi cade rinasce lì invece che all'ingresso.
//  varianti:  { id, nome, nota, chiuse: [stanze tolte], allagate: [stanze diventate vuoto], aperte: [porte già aperte],
//             rotte: [porte che non si aprono mai] }: una per settimana (varianteSettimana).

// Muri dai bordi delle stanze, tolti i tratti che stanno dentro un'altra stanza. [x1, z1, x2, z2] orizzontali o verticali.
export function muriDaStanze(stanze) {
  const muri = [];
  const togli = (a, b, buchi) => {
    let pezzi = [[a, b]];
    for (const [h1, h2] of buchi) {
      const nuovi = [];
      for (const [p1, p2] of pezzi) {
        if (h2 <= p1 || h1 >= p2) { nuovi.push([p1, p2]); continue; }
        if (h1 > p1) nuovi.push([p1, h1]);
        if (h2 < p2) nuovi.push([h2, p2]);
      }
      pezzi = nuovi;
    }
    return pezzi.filter(([p1, p2]) => p2 - p1 > 0.2);
  };
  stanze.forEach((r, i) => {
    const [x1, z1, x2, z2] = r;
    const altre = stanze.filter((_, j) => j !== i);
    for (const z of [z1, z2]) {   // bordi orizzontali
      const buchi = altre.filter(o => o[1] < z && z < o[3]).map(o => [o[0], o[2]]);
      for (const [a, b] of togli(x1, x2, buchi)) muri.push([a, z, b, z]);
    }
    for (const x of [x1, x2]) {   // bordi verticali
      const buchi = altre.filter(o => o[0] < x && x < o[2]).map(o => [o[1], o[3]]);
      for (const [a, b] of togli(z1, z2, buchi)) muri.push([x, a, x, b]);
    }
  });
  return muri;
}

// ------------------------------------------------------------------ mostri nuovi (aggiunti a MOBS in data.js)
export const MOBS_PROVE = {
  // Cripta: il guardiano della navata centrale (abbatterlo apre il Cancello dei Sigilli) e l'avaro della Camera delle Offerte
  guardiano_cripta: { name: 'Guardiano dei Sigilli', cast: { name: 'Colpo del Sepolcro', ms: 2600, mult: 2.4, cd: 12000, raggio: 7 }, lvl: 27, hp: 7800, atk: 94, def: 46, exp: 1300, speed: 3.8, aggro: 12, range: 3.0, aspd: 2200, model: 'terracotta', color: 0x6a5a9a, scale: 1.6, respawn: 0, dungeon: true, tael: [180, 360], drops: [] },
  avaro_cripta: { name: 'Avaro Sepolto', cast: { name: "Maledizione dell'Oro", ms: 2400, mult: 3.0, cd: 9000 }, lvl: 27, hp: 8600, atk: 88, def: 40, exp: 1500, speed: 4.0, aggro: 11, range: 2.8, aspd: 2000, model: 'terracotta', color: 0xc8a030, scale: 1.5, respawn: 0, dungeon: true, tael: [600, 900], drops: [] },
  // Forgia: la scoria che custodisce l'Isola del Crogiolo
  scoria_vivente: { name: 'Scoria Vivente', cast: { name: 'Eruzione di Scorie', ms: 2600, mult: 2.4, cd: 11000, raggio: 7 }, lvl: 38, hp: 12500, atk: 168, def: 54, exp: 2100, speed: 3.6, aggro: 11, range: 3.0, aspd: 2200, model: 'terracotta', color: 0xe0501a, scale: 1.7, respawn: 0, dungeon: true, tael: [900, 1400], drops: [] },
};

// ------------------------------------------------------------------ Cripta delle Mille Lanterne
// Dalla Rotonda partono tre strade che si ritrovano nella Sala dei Sigilli, davanti al Custode:
//  ovest  Catacombe dei Sussurri: lunga, molte Ombre deboli, nessun pericolo;
//  centro Via dei Guardiani: corta e dritta, ma il Guardiano dei Sigilli (élite) tiene chiuso il cancello;
//  est    Galleria delle Lanterne: media, lanterne che lanciano e il Ponte sull'Abisso con i Fuochi.
// Dalla Sala dei Sigilli si scende alla Camera delle Offerte (tesoro facoltativo). Ogni settimana una strada è chiusa.
const CRIPTA = {
  spawn: [0, -5],
  boss: { type: 'custode_insonne', x: 0, z: 142 },
  forze: { sentinella_cripta: 5, ombra_cripta: 4, lanterna_cripta: 5, guardiano_cripta: 14, avaro_cripta: 14, eco_spirito: 1 },
  dannoPericoli: 100,
  ali: {
    ovest: { nome: 'Catacombe dei Sussurri', colore: '#48d8a0', segno: 'luna', nota: 'lunga, molte Ombre deboli' },
    centro: { nome: 'Via dei Guardiani', colore: '#b070ff', segno: 'sigillo', nota: 'corta: il Guardiano dei Sigilli tiene chiuso il cancello' },
    est: { nome: 'Galleria delle Lanterne', colore: '#ffb040', segno: 'fiamma', nota: "lanterne che lanciano e i Fuochi sul Ponte dell'Abisso" },
  },
  stanze: [
    { id: 'soglia', nome: 'Soglia delle Lanterne', tipo: 'ingresso', r: [-9, -10, 9, 8] },
    { id: 'discesa', nome: 'Discesa dei Morti', tipo: 'corridoio', r: [-3, 7, 3, 20] },
    { id: 'rotonda', nome: 'Rotonda dei Tre Sentieri', tipo: 'bivio', r: [-16, 19, 16, 45] },
    // ala ovest
    { id: 'o1', nome: 'Catacombe dei Sussurri', tipo: 'corridoio', ala: 'ovest', r: [-34, 29, -15, 35] },
    { id: 'ossario', nome: 'Ossario', tipo: 'sala', ala: 'ovest', r: [-60, 20, -33, 48] },
    { id: 'o3', nome: 'Catacombe dei Sussurri', tipo: 'corridoio', ala: 'ovest', r: [-51, 47, -45, 62] },
    { id: 'nicchie', nome: 'Galleria delle Nicchie', tipo: 'sala', ala: 'ovest', r: [-64, 61, -36, 86] },
    { id: 'o5a', nome: 'Catacombe dei Sussurri', tipo: 'corridoio', ala: 'ovest', r: [-46, 85, -40, 98] },
    { id: 'o5b', nome: 'Catacombe dei Sussurri', tipo: 'corridoio', ala: 'ovest', r: [-46, 92, -21, 98] },
    // via centrale
    { id: 'c1', nome: 'Via dei Guardiani', tipo: 'corridoio', ala: 'centro', r: [-4, 44, 4, 59] },
    { id: 'guardiani', nome: 'Sala dei Guardiani', tipo: 'sala', ala: 'centro', r: [-11, 58, 11, 80] },
    { id: 'cancello', nome: 'Cancello dei Sigilli', tipo: 'cancello', ala: 'centro', porta: 'sigilli', r: [-3, 79, 3, 87] },
    // ala est
    { id: 'e1', nome: 'Galleria delle Lanterne', tipo: 'corridoio', ala: 'est', r: [15, 29, 35, 35] },
    { id: 'lanterne', nome: 'Sala delle Mille Lanterne', tipo: 'sala', ala: 'est', r: [34, 18, 62, 46] },
    { id: 'ponte', nome: "Ponte sull'Abisso", tipo: 'ponte', ala: 'est', r: [45, 45, 51, 70] },
    { id: 'urne', nome: 'Sala delle Urne', tipo: 'sala', ala: 'est', r: [36, 69, 62, 94] },
    { id: 'e5', nome: 'Galleria delle Lanterne', tipo: 'corridoio', ala: 'est', r: [21, 87, 37, 93] },
    // dove le strade si ritrovano
    { id: 'sigilli', nome: 'Sala dei Sigilli', tipo: 'sala', r: [-22, 86, 22, 107] },
    { id: 't1', nome: 'Scala delle Offerte', tipo: 'corridoio', ala: 'tesoro', r: [-19, 69, -13, 87] },
    { id: 'offerte', nome: 'Camera delle Offerte', tipo: 'tesoro', ala: 'tesoro', r: [-31, 53, -14, 70] },
    { id: 'b1', nome: 'Soglia del Custode', tipo: 'corridoio', r: [-4, 106, 4, 119] },
    { id: 'custode', nome: 'Sala del Custode Insonne', tipo: 'boss', r: [-24, 118, 24, 162] },
  ],
  vuoti: [[36, 46, 62, 69]],
  ostacoli: [
    [-9, 26, 1.0, 'pilastro'], [9, 26, 1.0, 'pilastro'], [-9, 38, 1.0, 'pilastro'], [9, 38, 1.0, 'pilastro'],                 // pilastri della Rotonda
    [-6, 64, 0.9, 'pilastro'], [6, 64, 0.9, 'pilastro'], [-6, 75, 0.9, 'pilastro'], [6, 75, 0.9, 'pilastro'],                 // Sala dei Guardiani
    [-53, 27, 1.3, 'sarcofago'], [-40, 27, 1.3, 'sarcofago'], [-53, 41, 1.3, 'sarcofago'], [-40, 41, 1.3, 'sarcofago'],           // sarcofagi dell'Ossario
    [-57, 73.5, 1.3, 'sarcofago'], [-50, 73.5, 1.3, 'sarcofago'], [-43, 73.5, 1.3, 'sarcofago'],                     // sarcofagi della Galleria delle Nicchie
    [41, 25, 1.0, 'pilastro'], [55, 25, 1.0, 'pilastro'], [41, 39, 1.0, 'pilastro'], [55, 39, 1.0, 'pilastro'],               // pilastri della Sala delle Mille Lanterne
    [42, 76, 1.1, 'urna'], [56, 76, 1.1, 'urna'], [42, 88, 1.1, 'urna'], [56, 88, 1.1, 'urna'],               // grandi urne
    [-14, 101, 1.0, 'pilastro'], [14, 101, 1.0, 'pilastro'],                                          // Sala dei Sigilli
    [-22.5, 55.8, 1.3, 'scrigno'],                                                       // lo scrigno delle offerte
    [-16, 126, 1.2, 'colonna'], [16, 126, 1.2, 'colonna'], [-16, 140, 1.2, 'colonna'], [16, 140, 1.2, 'colonna'], [-16, 154, 1.2, 'colonna'], [16, 154, 1.2, 'colonna'],   // navata del Custode
  ],
  porte: {
    sigilli: { nome: 'Cancello dei Sigilli', apre: 'branco', dice: 'Il Guardiano dei Sigilli è caduto: il Cancello dei Sigilli si apre!' },
  },
  leve: [],
  branchi: [
    { id: 'discesa', x: 0, z: 14, mobs: ['sentinella_cripta', 'sentinella_cripta'] },
    { id: 'rotonda', x: 0, z: 33, mobs: ['sentinella_cripta', 'lanterna_cripta', 'lanterna_cripta'] },
    { id: 'ossario', x: -46, z: 34, ala: 'ovest', mobs: ['ombra_cripta', 'ombra_cripta', 'ombra_cripta', 'ombra_cripta'] },
    { id: 'nicchie', x: -50, z: 80, ala: 'ovest', mobs: ['ombra_cripta', 'ombra_cripta', 'ombra_cripta', 'lanterna_cripta'] },
    { id: 'sussurri', x: -32, z: 95, ala: 'ovest', mobs: ['ombra_cripta', 'ombra_cripta', 'lanterna_cripta'] },
    { id: 'via', x: 0, z: 52, ala: 'centro', mobs: ['lanterna_cripta', 'ombra_cripta'] },
    { id: 'guardiano', x: 0, z: 70, ala: 'centro', apre: 'sigilli', mobs: ['guardiano_cripta', 'sentinella_cripta', 'sentinella_cripta'] },
    { id: 'lanterne', x: 48, z: 32, ala: 'est', mobs: ['lanterna_cripta', 'lanterna_cripta', 'sentinella_cripta'] },
    { id: 'abisso', x: 48, z: 74, ala: 'est', mobs: ['lanterna_cripta', 'lanterna_cripta'] },
    { id: 'urne', x: 49, z: 84, ala: 'est', mobs: ['sentinella_cripta', 'sentinella_cripta', 'ombra_cripta', 'lanterna_cripta'] },
    { id: 'sigilli', x: 0, z: 98, mobs: ['ombra_cripta', 'ombra_cripta', 'ombra_cripta', 'lanterna_cripta'] },
    { id: 'offerte', x: -22.5, z: 62, ala: 'tesoro', tesoro: true, mobs: ['avaro_cripta'] },
  ],
  pericoli: [
    { id: 'fuoco1', nome: "Fuochi dell'Abisso", x: 48, z: 51.5, r: 2.6, ogni: 6000, ms: 1800, mult: 1.3, sfasa: 0 },
    { id: 'fuoco2', nome: "Fuochi dell'Abisso", x: 48, z: 57.5, r: 2.6, ogni: 6000, ms: 1800, mult: 1.3, sfasa: 2000 },
    { id: 'fuoco3', nome: "Fuochi dell'Abisso", x: 48, z: 63.5, r: 2.6, ogni: 6000, ms: 1800, mult: 1.3, sfasa: 4000 },
  ],
  ritorni: [{ id: 'sigilli', nome: 'Braciere del Ritorno', x: 9, z: 103.5, px: 6.5, pz: 102, zona: [-22, 99, 22, 119] }],
  tesoro: { nome: 'Scrigno delle Offerte', x: -22.5, z: 55.8, dice: "L'Avaro Sepolto è caduto: lo Scrigno delle Offerte si apre. Un premio in più alla fine della Prova!" },
  varianti: [
    { id: 'ovest', nome: 'Catacombe franate', nota: 'Le Catacombe dei Sussurri sono franate: restano la Via dei Guardiani e la Galleria delle Lanterne.', chiuse: ['o1', 'ossario', 'o3', 'nicchie', 'o5a', 'o5b'] },
    { id: 'centro', nome: 'Via murata', nota: 'La Via dei Guardiani è murata: restano le Catacombe dei Sussurri e la Galleria delle Lanterne.', chiuse: ['c1', 'guardiani', 'cancello'] },
    { id: 'est', nome: 'Ponte crollato', nota: "Il Ponte sull'Abisso è crollato: restano le Catacombe dei Sussurri e la Via dei Guardiani.", chiuse: ['e1', 'lanterne', 'ponte', 'urne', 'e5'] },
  ],
};

// ------------------------------------------------------------------ Forgia del Drago Addormentato
// Un anello attorno al Lago del Crogiolo: dalla Sala delle Incudini si gira a ovest (Fonderia: lunga, molti nemici
// deboli, sfiati di lava) o a est (Galleria dei Mantici: corta, due Martellatori e i magli) fino alla Terrazza del
// Drago. In mezzo al lago il Ponte del Crogiolo, sommerso: lo fa emergere la leva sulla Terrazza (scorciatoia per chi
// rinasce e unica via per l'Isola del Crogiolo, con il tesoro). Ogni settimana un tratto dell'anello è sommerso
// dalla colata, oppure il ponte è già emerso.
const FORGIA_PIANTA = {
  spawn: [0, -4],
  boss: { type: 'yan_fornace', x: 0, z: 158 },
  forze: { fabbro_cenere: 5, cane_brace: 3, spirito_fornace: 5, martellatore_bronzo: 10, scoria_vivente: 14, eco_spirito: 1 },
  dannoPericoli: 170,
  ali: {
    ovest: { nome: 'Fonderia', colore: '#ffd040', segno: 'crogiolo', nota: 'lunga: Cani di Brace e Fabbri, sfiati di lava sul Canale delle Scorie' },
    est: { nome: 'Galleria dei Mantici', colore: '#50c8ff', segno: 'maglio', nota: 'corta: due Martellatori di Bronzo e i magli sulla Passerella delle Catene' },
    ponte: { nome: 'Ponte del Crogiolo', colore: '#ff5a20', segno: 'ponte', nota: "sommerso nel lago: lo fa emergere la leva sulla Terrazza del Drago. Porta all'Isola del Crogiolo" },
  },
  stanze: [
    { id: 'bocca', nome: 'Bocca della Montagna', tipo: 'ingresso', r: [-8, -8, 8, 8] },
    { id: 'discesa', nome: 'Discesa della Cenere', tipo: 'corridoio', r: [-3, 7, 3, 22] },
    { id: 'incudini', nome: 'Sala delle Incudini', tipo: 'bivio', r: [-18, 21, 18, 45] },
    // arco ovest
    { id: 'w1', nome: 'Fonderia', tipo: 'corridoio', ala: 'ovest', r: [-23, 30, -17, 36] },
    { id: 'fonderia', nome: 'Fonderia', tipo: 'sala', ala: 'ovest', r: [-48, 26, -22, 58] },
    { id: 'scorie', nome: 'Canale delle Scorie', tipo: 'passerella', ala: 'ovest', r: [-34, 57, -22, 80] },
    { id: 'crogioli', nome: 'Sala dei Crogioli', tipo: 'sala', ala: 'ovest', r: [-48, 79, -22, 112] },
    { id: 'w5', nome: 'Sala dei Crogioli', tipo: 'corridoio', ala: 'ovest', r: [-23, 106, -15, 112] },
    // arco est
    { id: 'e1', nome: 'Galleria dei Mantici', tipo: 'corridoio', ala: 'est', r: [17, 30, 23, 36] },
    { id: 'mantici', nome: 'Galleria dei Mantici', tipo: 'sala', ala: 'est', r: [22, 24, 44, 62] },
    { id: 'catene', nome: 'Passerella delle Catene', tipo: 'passerella', ala: 'est', r: [22, 61, 32, 84] },
    { id: 'magli', nome: 'Officina dei Magli', tipo: 'sala', ala: 'est', r: [22, 83, 50, 112] },
    { id: 'e5', nome: 'Officina dei Magli', tipo: 'corridoio', ala: 'est', r: [15, 106, 23, 112] },
    // il ponte sul lago
    { id: 'ponte_s', nome: 'Ponte del Crogiolo', tipo: 'ponte', ala: 'ponte', porta: 'ponte', r: [-3, 44, 3, 71] },
    { id: 'isola', nome: 'Isola del Crogiolo', tipo: 'tesoro', ala: 'ponte', r: [-9, 70, 9, 84] },
    { id: 'ponte_n', nome: 'Ponte del Crogiolo', tipo: 'ponte', ala: 'ponte', porta: 'ponte', r: [-3, 83, 3, 105] },
    // dove l'anello si chiude
    { id: 'terrazza', nome: 'Terrazza del Drago', tipo: 'sala', r: [-16, 104, 16, 124] },
    { id: 'scala', nome: 'Scala del Drago', tipo: 'corridoio', r: [-4, 123, 4, 136] },
    { id: 'cuore', nome: 'Cuore della Forgia', tipo: 'boss', r: [-24, 135, 24, 176] },
  ],
  vuoti: [[-22, 45, 22, 104]],
  ostacoli: [
    [-10, 39, 1.7, 'incudine'], [10, 27, 1.7, 'incudine'],                                            // le grandi incudini
    [-35, 42, 2.2, 'crogiolo'],                                                           // il crogiolo della Fonderia
    [-41, 88, 1.6, 'crogiolo'], [-30, 97, 1.6, 'crogiolo'], [-41, 105, 1.6, 'crogiolo'],                          // Sala dei Crogioli
    [38, 31, 1.8, 'mantice'], [38, 54, 1.8, 'mantice'],                                             // i mantici della Galleria
    [30, 91, 1.6, 'incudine'], [42, 102, 1.6, 'incudine'],                                            // incudini dell'Officina
    [6.2, 80.5, 1.2, 'scrigno'],                                                         // lo scrigno dell'isola
    [-17, 143, 1.3, 'colonna'], [17, 143, 1.3, 'colonna'], [-17, 156, 1.3, 'colonna'], [17, 156, 1.3, 'colonna'], [-17, 169, 1.3, 'colonna'], [17, 169, 1.3, 'colonna'],   // colonne del Cuore
  ],
  porte: {
    ponte: { nome: 'Ponte del Crogiolo', apre: 'leva', dice: 'La leva scatta: il Ponte del Crogiolo emerge dal lago di lava!' },
  },
  leve: [{ id: 'leva_ponte', porta: 'ponte', x: 0, z: 107.5 }],
  branchi: [
    { id: 'incudini_o', x: -9, z: 30, mobs: ['fabbro_cenere', 'fabbro_cenere', 'cane_brace'] },
    { id: 'incudini_e', x: 9, z: 38, mobs: ['cane_brace', 'cane_brace', 'cane_brace', 'spirito_fornace'] },
    { id: 'fonderia_s', x: -41, z: 33, ala: 'ovest', mobs: ['cane_brace', 'cane_brace', 'cane_brace', 'cane_brace'] },
    { id: 'fonderia_n', x: -30, z: 51, ala: 'ovest', mobs: ['fabbro_cenere', 'fabbro_cenere', 'spirito_fornace'] },
    { id: 'scorie', x: -28, z: 69, ala: 'ovest', mobs: ['cane_brace', 'cane_brace', 'cane_brace'] },
    { id: 'crogioli', x: -34, z: 92, ala: 'ovest', mobs: ['fabbro_cenere', 'fabbro_cenere', 'cane_brace', 'cane_brace'] },
    { id: 'mantici', x: 31, z: 40, ala: 'est', mobs: ['martellatore_bronzo', 'cane_brace', 'cane_brace'] },
    { id: 'catene', x: 27, z: 72, ala: 'est', mobs: ['spirito_fornace', 'spirito_fornace'] },
    { id: 'magli', x: 36, z: 96, ala: 'est', mobs: ['martellatore_bronzo', 'fabbro_cenere', 'spirito_fornace'] },
    { id: 'terrazza', x: -7, z: 116, mobs: ['fabbro_cenere', 'fabbro_cenere', 'spirito_fornace'] },
    { id: 'isola', x: 0, z: 77, ala: 'ponte', tesoro: true, mobs: ['scoria_vivente'] },
  ],
  pericoli: [
    { id: 'sfiato1', nome: 'Sfiato di lava', x: -28, z: 63, r: 3.0, ogni: 7000, ms: 2000, mult: 1.3, sfasa: 0 },
    { id: 'sfiato2', nome: 'Sfiato di lava', x: -28, z: 75, r: 3.0, ogni: 7000, ms: 2000, mult: 1.3, sfasa: 3500 },
    { id: 'maglio1', nome: 'Maglio della Forgia', x: 27, z: 66, r: 2.8, ogni: 5000, ms: 1600, mult: 1.7, sfasa: 0 },
    { id: 'maglio2', nome: 'Maglio della Forgia', x: 27, z: 79, r: 2.8, ogni: 5000, ms: 1600, mult: 1.7, sfasa: 2500 },
  ],
  ritorni: [{ id: 'terrazza', nome: 'Braciere del Ritorno', x: 11, z: 120.5, px: 8.5, pz: 118.5, zona: [-16, 109, 16, 136] }],
  tesoro: { nome: 'Scrigno del Crogiolo', x: 6.2, z: 80.5, dice: 'La Scoria Vivente si spegne: lo Scrigno del Crogiolo si apre. Un premio in più alla fine della Prova!' },
  varianti: [
    { id: 'ovest', nome: 'Colata a ovest', nota: 'La colata ha sommerso il Canale delle Scorie: si passa dalla Galleria dei Mantici (o dal ponte, tirata la leva).', allagate: ['scorie'] },
    { id: 'est', nome: 'Colata a est', nota: 'La colata ha sommerso la Passerella delle Catene: si passa dalla Fonderia (o dal ponte, tirata la leva).', allagate: ['catene'] },
    { id: 'ponte', nome: 'Ponte emerso', nota: "Il Ponte del Crogiolo è già emerso dal lago: la via più corta passa dall'isola della Scoria Vivente, le forze vanno cercate nei due archi.", aperte: ['ponte'] },
  ],
};

export const PIANTE = { cripta: CRIPTA, forgia: FORGIA_PIANTA };

// ------------------------------------------------------------------ varianti
// Numero della settimana (da lunedì 1 gennaio 2024, come gli affissi in data.js).
function numeroSettimana(now) { return Math.floor((now - Date.UTC(2024, 0, 1)) / (7 * 86400000)); }

// Variante della settimana: cambia ogni lunedì, e le due Prove non hanno mai la stessa posizione nel giro.
export function varianteSettimana(id, now = Date.now()) {
  const P = PIANTE[id];
  if (!P) return 0;
  const n = P.varianti.length, sfasa = id === 'forgia' ? 1 : 0;
  return (((numeroSettimana(now) + sfasa) % n) + n) % n;
}

const dentro = (r, x, z, m = 0) => x >= r[0] + m && x <= r[2] - m && z >= r[1] + m && z <= r[3] - m;

// La pianta giocabile di una Prova: variante `v` (-1 = tutto aperto, serve ai client che non conoscono le varianti)
// e porte aperte { id: true }. Restituisce i campi che il motore legge da `inst.dg` (rooms, walls, packs, boss, spawn,
// forces, bounds) più quelli nuovi (stanze, vuoti, ostacoli, pericoli, leve, ritorni, porte, frane, var).
export function componiPianta(id, v = -1, aperte = {}) {
  const P = PIANTE[id];
  const V = v >= 0 ? P.varianti[v % P.varianti.length] : { id: 'tutto', nome: '', nota: '' };
  const chiuse = new Set(V.chiuse || []), allagate = new Set(V.allagate || []);
  const rotte = new Set(V.rotte || []);
  const porte = {};
  for (const pid of Object.keys(P.porte)) porte[pid] = rotte.has(pid) ? -1 : (v < 0 || aperte[pid] || (V.aperte || []).includes(pid)) ? 1 : 0;
  // stanze della variante (anche quelle dietro una porta chiusa: il client disegna il varco) e stanze calpestabili ora
  const stanzeVar = P.stanze.filter(s => !chiuse.has(s.id) && !allagate.has(s.id) && !(s.porta && porte[s.porta] < 0));
  const stanze = stanzeVar.filter(s => !s.porta || porte[s.porta] === 1);
  const rooms = stanze.map(s => s.r);
  const vuoti = [...P.vuoti, ...P.stanze.filter(s => allagate.has(s.id)).map(s => s.r)];
  const inStanza = (x, z) => rooms.some(r => dentro(r, x, z));
  const inVariante = (x, z) => stanzeVar.some(s => dentro(s.r, x, z));
  // muri: bordi delle stanze della variante (porte comprese: lì il client mette cancello o ponte), con il tipo:
  // 0 muro, 1 parapetto (dall'altra parte c'è un vuoto)
  const inVuoto = (x, z) => vuoti.some(r => dentro(r, x, z, -0.01)) && !inVariante(x, z);
  const walls = muriDaStanze(stanzeVar.map(s => s.r)).map(([x1, z1, x2, z2]) => {
    const mx = (x1 + x2) / 2, mz = (z1 + z2) / 2, oriz = z1 === z2;
    const fuori = oriz ? (inVariante(mx, mz + 0.6) ? [mx, mz - 0.6] : [mx, mz + 0.6]) : (inVariante(mx + 0.6, mz) ? [mx - 0.6, mz] : [mx + 0.6, mz]);
    return [x1, z1, x2, z2, inVuoto(fuori[0], fuori[1]) ? 1 : 0];
  });
  // pareti dei vuoti dove non c'è una stanza (tipo 2: la roccia che chiude l'abisso o il lago), a tratti di 1 m riuniti
  for (const [x1, z1, x2, z2] of vuoti) {
    const lati = [[x1, z1, x2, z1, 0, -1], [x1, z2, x2, z2, 0, 1], [x1, z1, x1, z2, -1, 0], [x2, z1, x2, z2, 1, 0]];
    for (const [ax, az, bx, bz, nx, nz] of lati) {
      const oriz = az === bz, da = oriz ? ax : az, fino = oriz ? bx : bz;
      let inizio = null;
      for (let q = da; q <= fino + 1e-6; q++) {
        const mx = oriz ? q + 0.5 : ax, mz = oriz ? az : q + 0.5;
        const serve = q < fino - 1e-6 && !inVariante(mx + nx * 0.6, mz + nz * 0.6) && !vuoti.some(r => dentro(r, mx + nx * 0.6, mz + nz * 0.6)) && !inVariante(mx - nx * 0.4, mz - nz * 0.4);
        if (serve && inizio === null) inizio = q;
        if (!serve && inizio !== null) { walls.push(oriz ? [inizio, az, q, az, 2] : [ax, inizio, ax, q, 2]); inizio = null; }
      }
    }
  }
  // frane: dove una stanza della variante toccava una stanza tolta (il varco murato, da disegnare)
  const frane = [];
  for (const c of P.stanze.filter(s => chiuse.has(s.id) || (s.porta && porte[s.porta] < 0))) {
    for (const s of stanzeVar) {
      const x1 = Math.max(c.r[0], s.r[0]), z1 = Math.max(c.r[1], s.r[1]), x2 = Math.min(c.r[2], s.r[2]), z2 = Math.min(c.r[3], s.r[3]);
      if (x2 - x1 <= 0 || z2 - z1 <= 0) continue;
      frane.push({ x: (x1 + x2) / 2, z: (z1 + z2) / 2, w: Math.max(x2 - x1, z2 - z1), oriz: (x2 - x1) > (z2 - z1) ? 1 : 0, ala: c.ala || '' });
    }
  }
  // bracieri del ritorno e leve sono piccoli ostacoli anche loro
  const ostacoli = [...P.ostacoli, ...P.ritorni.map(r => [r.x, r.z, 0.7, 'braciere']), ...P.leve.map(l => [l.x, l.z, 0.45, 'leva'])].filter(([x, z]) => inVariante(x, z));
  const packs = P.branchi.filter(b => inVariante(b.x, b.z));
  const xs = stanzeVar.flatMap(s => [s.r[0], s.r[2]]).concat(vuoti.flatMap(r => [r[0], r[2]]));
  const zs = stanzeVar.flatMap(s => [s.r[1], s.r[3]]).concat(vuoti.flatMap(r => [r[1], r[3]]));
  return {
    var: v, variante: { id: V.id, nome: V.nome, nota: V.nota },
    spawn: P.spawn, boss: P.boss, forces: P.forze, dannoPericoli: P.dannoPericoli,
    stanze: stanzeVar.map(s => s.id), rooms, walls, vuoti, ostacoli, frane, porte,
    packs, pericoli: P.pericoli.filter(t => inVariante(t.x, t.z)), leve: P.leve.filter(l => porte[l.porta] >= 0),
    ritorni: P.ritorni, tesoro: P.tesoro && inVariante(P.tesoro.x, P.tesoro.z) ? P.tesoro : null,
    boundsMin: [Math.min(...xs) - 1, Math.min(...zs) - 1], boundsMax: [Math.max(...xs) + 1, Math.max(...zs) + 1],
  };
}

// Il punto (coordinate locali) è calpestabile? margin = raggio del personaggio. `dg` ha rooms e, se ci sono, ostacoli.
export function calpestabile(lx, lz, margin, dg) {
  let ok = false;
  for (const [x1, z1, x2, z2] of dg.rooms) {
    if (lx >= x1 + margin && lx <= x2 - margin && lz >= z1 + margin && lz <= z2 - margin) { ok = true; break; }
  }
  if (!ok) return false;
  if (dg.ostacoli) for (const [ox, oz, r] of dg.ostacoli) {
    const dx = lx - ox, dz = lz - oz, lim = r + margin * 0.5;
    if (dx * dx + dz * dz < lim * lim) return false;
  }
  return true;
}

// Il punto lascia passare la vista (e i colpi a distanza)? Stanze e vuoti sì, muri e ostacoli grandi no.
export function trasparente(lx, lz, dg) {
  for (const [x1, z1, x2, z2] of dg.rooms) if (lx >= x1 && lx <= x2 && lz >= z1 && lz <= z2) return true;
  if (dg.vuoti) for (const [x1, z1, x2, z2] of dg.vuoti) if (lx >= x1 && lx <= x2 && lz >= z1 && lz <= z2) return true;
  return false;
}

// Vista libera fra due punti (campioni ogni 0,7 m).
export function vistaLibera(ax, az, bx, bz, dg) {
  const d = Math.hypot(bx - ax, bz - az), n = Math.max(1, Math.ceil(d / 0.7));
  for (let i = 1; i < n; i++) {
    const t = i / n;
    if (!trasparente(ax + (bx - ax) * t, az + (bz - az) * t, dg)) return false;
  }
  return true;
}

// Il punto calpestabile più vicino (per chi nasce o viene portato dentro un muro).
export function puntoLibero(lx, lz, margin, dg) {
  if (calpestabile(lx, lz, margin, dg)) return [lx, lz];
  let meglio = null, md = Infinity;
  for (const [x1, z1, x2, z2] of dg.rooms) {
    if (x2 - x1 < margin * 2 || z2 - z1 < margin * 2) continue;
    const qx = Math.min(Math.max(lx, x1 + margin), x2 - margin), qz = Math.min(Math.max(lz, z1 + margin), z2 - margin);
    const d = (qx - lx) ** 2 + (qz - lz) ** 2;
    if (d < md) { md = d; meglio = [qx, qz]; }
  }
  if (!meglio) return [lx, lz];
  // fuori da un ostacolo: spinta lungo il raggio
  if (dg.ostacoli) for (const [ox, oz, r] of dg.ostacoli) {
    const dx = meglio[0] - ox, dz = meglio[1] - oz, d = Math.hypot(dx, dz), lim = r + margin * 0.5 + 0.05;
    if (d < lim) { const k = d > 0.01 ? lim / d : 0; meglio = d > 0.01 ? [ox + dx * k, oz + dz * k] : [ox + lim, oz]; }
  }
  return meglio;
}

// Grafo delle stanze per il cammino dei mostri: stanze vicine e il centro del varco fra loro.
export function grafoStanze(dg, margin = 0.35) {
  const R = dg.rooms, n = R.length, vicini = R.map(() => []);
  for (let i = 0; i < n; i++) for (let j = i + 1; j < n; j++) {
    const x1 = Math.max(R[i][0], R[j][0]) + margin, z1 = Math.max(R[i][1], R[j][1]) + margin;
    const x2 = Math.min(R[i][2], R[j][2]) - margin, z2 = Math.min(R[i][3], R[j][3]) - margin;
    if (x2 - x1 < 0.05 || z2 - z1 < 0.05) continue;
    const varco = [(x1 + x2) / 2, (z1 + z2) / 2];
    vicini[i].push([j, varco]); vicini[j].push([i, varco]);
  }
  return vicini;
}

// Prossimo punto verso cui camminare per andare da (ax, az) a (bx, bz) restando nelle stanze: il bersaglio stesso
// se sta in una stanza in comune, altrimenti il varco verso la prossima stanza del cammino più corto (in stanze).
export function prossimoPasso(ax, az, bx, bz, dg, grafo) {
  const R = dg.rooms;
  const da = [], a = [];
  for (let i = 0; i < R.length; i++) {
    if (dentro(R[i], ax, az, -0.05)) da.push(i);
    if (dentro(R[i], bx, bz, -0.05)) a.push(i);
  }
  if (!da.length || !a.length) return [bx, bz];
  const arrivo = new Set(a);
  if (da.some(i => arrivo.has(i))) return [bx, bz];
  // ricerca in ampiezza dalle stanze d'arrivo: `verso[i]` = varco da prendere dalla stanza i
  const dist = new Array(R.length).fill(-1), verso = new Array(R.length).fill(null), coda = [...a];
  for (const i of a) dist[i] = 0;
  while (coda.length) {
    const i = coda.shift();
    for (const [j, varco] of grafo[i]) {
      if (dist[j] >= 0) continue;
      dist[j] = dist[i] + 1; verso[j] = varco; coda.push(j);
    }
  }
  let meglio = -1;
  for (const i of da) if (dist[i] >= 0 && (meglio < 0 || dist[i] < dist[meglio])) meglio = i;
  return meglio < 0 ? null : verso[meglio];
}

// Forze disponibili in una pianta composta: totale e per ala (per le prove e per la taratura).
export function forzePianta(dg) {
  const out = { totale: 0, tronco: 0 };
  for (const b of dg.packs) {
    const f = b.mobs.reduce((s, t) => s + (dg.forces[t] || 0), 0);
    out.totale += f;
    out[b.ala || 'tronco'] = (out[b.ala || 'tronco'] || 0) + f;
  }
  return out;
}

// Quante stanze separano due punti (0 = stessa stanza, Infinity = non collegati o fuori dalle stanze): il server lo usa
// per rifiutare i passi che scavalcano un muro.
export function saltiStanze(ax, az, bx, bz, dg, grafo) {
  const R = dg.rooms, da = [], arrivo = new Set();
  for (let i = 0; i < R.length; i++) {
    if (dentro(R[i], ax, az, -0.05)) da.push(i);
    if (dentro(R[i], bx, bz, -0.05)) arrivo.add(i);
  }
  if (!da.length || !arrivo.size) return Infinity;
  const dist = new Array(R.length).fill(-1), coda = [...da];
  for (const i of da) dist[i] = 0;
  while (coda.length) {
    const i = coda.shift();
    if (arrivo.has(i)) return dist[i];
    for (const [j] of grafo[i]) if (dist[j] < 0) { dist[j] = dist[i] + 1; coda.push(j); }
  }
  return Infinity;
}
