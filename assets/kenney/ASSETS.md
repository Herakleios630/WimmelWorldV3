# Kenney-Assets für den G4c-P-Pretest

Diese Assets werden **ausschließlich** von der visuellen Pretest-Ansicht
`tests/g4c_p/kenney_world_view.gd` und der Demo `tests/g4c_p/demo.tscn`
verwendet. Die Gate-Ansicht `src/view/world_view.gd`, die Simulation und alle
G1–G4b-Suiten bleiben unberührt.

## Herkunft und Lizenz

Alle drei Pakete sind von Kenney (https://kenney.nl) und stehen unter
**CC0 1.0 Universal (Public Domain Dedication)**. Die Lizenztexte liegen
jeweils im Asset-Ordner:

| Ordner | Quelle | Lizenz | Datei | Größe | SHA-256 |
|---|---|---|---|---|---|
| `roguelike-rpg-pack/` | https://kenney.nl/assets/roguelike-rpg-pack | CC0 1.0 (`License.txt`) | `roguelikeSheet_transparent.png` | 968×526, 16 px, 57×31 Tiles, 1 px Margin | `808C8D734480BC949B284F3BCC252E87E1EE53B24178791A6838CCE6A319C439` |
| `roguelike-characters/` | https://kenney.nl/assets/roguelike-characters | CC0 1.0 (`License.txt`) | `roguelikeChar_transparent.png` | 918×203, 16 px, 54×12 Tiles, 1 px Margin | `771D51CA84B2C5B412027BA80C6A6B8A98BB5A983B2C58AC4F0CCF08AE4D10F2` |
| `rpg-base/` | https://kenney.nl/assets/rpg-base | CC0 1.0 (`license.txt`) | `RPGpack_sheet.png` | 1280×832, 64 px, 20×13 Tiles (16-px-Design, 4×) | `2E97C179EEA9A2CBAE386BBF5C06A9F698DA8A4F57EBDC9ED5B74F14D064AA78` |

Bezugsstand: 2026-11-15 (lokale, bereits geprüfte Pakete; die Pakete enthalten
keine separate Versionsnummer). Die SHA-256-Werte identifizieren die
verwendeten Dateien exakt; vollständige Hashes stehen in der Testablage bzw.
lassen sich mit `Get-FileHash -Algorithm SHA256` reproduzieren.

Zusätzlich kopiert: `License.txt` (RPG Pack), `License.txt` (Characters),
`license.txt` (RPG Base) und die jeweiligen `spritesheetInfo.txt`.

**Nicht verwendet:** Tiny Farm, Tiny Town, Tiny Dungeon, Medieval RTS.

## Verwendete Kacheln / Mapping

RPG-Pack- und Character-Sheet: Tile `(col,row)` liegt bei
`x = col * 17`, `y = row * 17`, Größe 16×16. RPG Base: `(col,row)` bei
`x = col * 64`, `y = row * 64`, Größe 64×64; für die 16-px-Welt wird per
`Image.resize(16, 16, INTERPOLATE_NEAREST)` herunterskaliert.

### Gelände (RPG Pack)

| Zweck | Kachel(n) |
|---|---|
| Gras | `(5,1)`, `(5,0)`; 32×32-Tile-Muster mit seltenen Blumen `(0,9)`, `(1,9)` |
| Weg / Ackerboden | `(6,1)` (Dirt), Variante `(6,0)` |
| Sand / Ufer | `(8,1)` |
| Wasser | `(1,1)` |
| Kopfsteinpflaster (Dorfplatz) | `(9,0)` |
| Bäume | `(13,10)`, `(13,9)`, `(13,11)` |

### Gelände (RPG Base, 16-px-Downscale)

| Zweck | Kachel(n) |
|---|---|
| Gras | `(1,1)` |
| Weg / Ackerboden | `(6,1)` |
| Wasser | `(11,1)` |
| Sand / Ufer | `(6,0)` als robuste 16-px-Ersatztextur (kein eigener Sand im Pack) |
| Bäume | `(0,10)`, `(2,10)`, `(4,10)` (64 px → 24 px Anzeige) |

### Gebäude (aus RPG Base komponiert, 16-px-Downscale)

| Gebäude | Wand | Dach | Tür | Fenster | Details |
|---|---|---|---|---|---|
| Wohnhaus (3 Varianten) | `(3,3)`, `(4,3)`, `(13,3)` | `(1,7)`, `(6,7)`, `(10,7)` | `(10,12)` | `(12,12)` | Traufe/Firstlinien prozedural |
| Werkstatt | `(4,3)` | `(9,7)` | `(14,10)` | `(12,12)` | Schornstein `(13,4)` |
| Kornspeicher | `(3,3)` | `(1,7)` | `(14,10)` | `(12,12)` | Säcke `(9,12)` |
| Scheune | `(4,3)` | `(1,7)` | `(14,10)` | — | großes Tor |
| Brunnen | — | — | — | — | Stein `(13,4)`, Wasser `(11,1)`, Holzbalken prozedural |

Die RPG-Packs enthalten **keine vollständigen Häuser** und **keine
Acker-/Fruchtphasen-Kacheln**. Gebäude werden daher aus Wand-/Dach-/Tür-
Kacheln zu 8×8- bis 14×12-Tile-Sprites komponiert; Feldphasen nutzen den
Dirt-Boden plus prozedurale Furchen/Saat/Halme. Das ist im Pretest-Report als
Asset-Lücke für G4c vermerkt.

### Figuren (Roguelike Characters)

Zwölf vollständige 16×16-Figuren aus den Spalten 0/1, Zeilen 5–10:

`(0,5) (1,5) (0,6) (1,6) (0,7) (1,7) (0,8) (1,8) (0,9) (1,9) (0,10) (1,10)`

Die Auswahl ist deterministisch pro Agenten-ID. Kinder werden auf 0,78,
Alte auf 0,94 skaliert; Schatten, Bob, Auswahlring, Aktivitätsmarker und
Namen sind View-Elemente. Die Originaldateien wurden nicht verändert.
