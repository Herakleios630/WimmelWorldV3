# G4c-P2.1c1 — Rounded Transitions + Palette

Stand: 2026-11-15. View-only. Keine Sim-/Balance-/Save-/Layout-Änderung,
kein Git-Commit, kein G1–G4b-Lauf, kein 10k, kein Perf-/Baseline-Check.

## Geänderte Dateien

- `tests/g4c_p2/world_view_p2.gd` — weiche Übergänge, Rundungen, Palette.
- `tests/g4c_p2/screenshot_runner.gd` — fünf P2.1c1-Screenshots.
- `tests/g4c_p2/demo_main.gd` — HUD-Label `G4c-P2.1c1` (nur Text).
- `bench/results/g4c_p2c1_*.png` — neue Screenshots.
- `docs/g4c/v3-g4c-p2c1-report.md` — dieser Report.

`settlement_gen.gd`, `segments.json`, Layout, RNG-Konsum der Lauf-Agenten
und Save/Sim bleiben unberührt.

## Ansatz

- **Übergangsschicht (`_soften_shape`)**: pro Kachel 4-Bit-Nachbarschaft
  (N/E/S/W). Exponierte Kanten bekommen eine breite, transparente Grasnaht
  (5 px, Alpha 0.42); konvexe Ecken werden mit Gras-Kreisen gerundet
  (Wege 4.2 px, Platz 5.0 px, Sandufer 4.6 px). Keine Autotile-Bibliothek.
- **Platz**: Layout-Ellipse bleibt; die Tile-Treppe wird an der Kante
  weichgezeichnet und gerundet. Wegdurchlässe am Platzrand bleiben offen
  (`roads_block`), damit Kreuzstraßen nicht zugenäht werden.
- **Wege**: dunklerer/wärmerer Dirt-Ton (0.72/0.60/0.44), keine harten
  Randlinien mehr; pro Kachel leichte Rillen (horizontal/vertikal je nach
  Nachbarschaft) plus einzelne Kiesel.
- **Teich**: Wasser-Ton entsättigt (0.64/0.75/0.79); Wasser↔Sand mit breiter
  Sandnaht und gerundeten Ecken, Sand↔Gras mit Grasnaht, Schilf bleibt.
- **Felder/Höfe/Gärten**: Grasnaht an den Kanten, großzügig gerundete
  Parzellenecken (8 px), weicher Ackerrain statt harter Rechteckkontur.
  Hof- und Reihen-Schatten sind jetzt weiche Kreise unter den Gebäuden
  statt eines dunklen Rechtecks hinter der ganzen Row.
- **Palette**: Gras leicht entsättigt (Luma-Blend 0.14) mit feiner Körnung
  und Moosflecken; Dächer wärmer (Rot-/Gelbstich 1.07/0.99/0.90); Pflaster
  und Wege dunkler/wärmer, Wasser entsättigt. Häuser/Figuren bleiben lesbar.

## Screenshots

Lauf:

```
Godot_v4.7.2-stable_win64_console.exe --path V3 res://tests/g4c_p2/screenshots.tscn
```

- `bench/results/g4c_p2c1_overview.png` — Oval, Ringstraße, Platz, Teich,
  Felder; Kanten wirken weich, keine harten Slabs.
- `bench/results/g4c_p2c1_plaza.png` — Platz mit unregelmäßig gerundetem
  Cobble-Rand, weiche Wegmündungen, Wegkanten mit Rillen.
- `bench/results/g4c_p2c1_roads.png` — Weg/Hauszeile: gerundete Wegecken,
  weiche Feldränder mit Hecken, keine dunklen Rechteck-Schatten mehr.
- `bench/results/g4c_p2c1_pond.png` — Teich rund/irregulär mit Sand- und
  Grasufer; Wasser entsättigt.
- `bench/results/g4c_p2c1_fields.png` — Felder mit Grasnaht und runden
  Ecken; Hof mit weichem Rand und Gebäude-Schatten.

Alle fünf Shots: `err=0`, keine fehlenden Texturen. Layout-Zähler unverändert
(`houses=24 rows=8 farms=3 fields=6 roads=1904 trees=158 civic=2`),
100 Lauf-Agenten aktiv.

## Bewertung / offen

- Erreicht: Platz, Wege, Teich, Feld-/Hofränder sind sichtbar gerundet und
  weich; Palette flächiger weniger gesättigt, Dächer wärmer.
- Grenzen: Wasser↔Sand zeigt an wenigen Kacheln noch kleine Treppen/Notches;
  Wege sind auf Übersichts-Zoom weiterhin grob pixelig (Soft-Kanten wirken
  erst ab ~1.5× Zoom). Platznaht ist bewusst leicht „wolkig“.
- P2.1c2: organische Auflockerung (Büsche, Randsteine, Pfade), feinere
  Wasser-Kanten (Sand als zweite Übergangsebene), evtl. gebackene
  Kantenmaske pro Material.

## Timebox

- Ein Lauf der Screenshot-Szene ~10 s, jeder Befehl < 120 s.
- 30-Minuten-Timebox eingehalten; keine Suiten, kein 10k, kein Perf-Lauf.
