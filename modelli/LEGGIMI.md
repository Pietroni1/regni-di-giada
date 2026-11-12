# Modelli ad alta definizione

Metti qui i modelli `.glb` creati con un generatore da immagine a 3D (o da un artista), poi lancia:

```bash
blender -b --factory-startup --python tools/blender/importa_modello.py -- modelli/NOME.glb client/assets/modelli/NOME.glb --altezza 2.35
```

Lo script li scala, li raddrizza, riduce i triangoli se sono troppi (`--triangoli 80000`), crea lo scheletro del gioco con i pesi
e aggiunge le 17 animazioni dei personaggi. Infine assegna il modello in `client/assets/modelli/indice.json`, per esempio:

```json
{
  "modelli": { "orco": { "file": "orco.glb", "arma": "spada_gru" } },
  "classi": { "lama": "orco" },
  "mostri": { "generale": "orco" },
  "png": { "guardia": "orco" }
}
```

Per un buon risultato il modello deve essere: in piedi, in posa a T (braccia aperte) o ad A, visto di fronte, a figura intera,
senza armi in mano (le armi del gioco si agganciano alle mani con i loro effetti).
