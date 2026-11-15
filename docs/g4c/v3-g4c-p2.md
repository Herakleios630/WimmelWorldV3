# V3 G4c-P2 — Modularer Dorf-Designpass (100 Agenten)

Status: Designpass-Spezifikation, Umsetzung nach dem letzten G4a-Regressionslauf  
Stand: 2026-11-15  
Bezug: `docs/g4c/v3-g4c-pretest.md`, `docs/g4c/v3-g4c-plan.md`,
`docs/v3-architecture.md`, `docs/v3-data-model.md`.

## 1. Ziel

G4c-P2 ist ein **rein visueller Designpass** mit 100 Agenten. Kein 10k, keine
Wirtschafts-/Politik-/Chronik-Politur, keine großen Testläufe.

Ergebnis: ein organisches Dorf mit eigenen, auf dem Roguelike-Set basierenden
Häusern, kleinen Feldparzellen und einem modularen, seed-getriebenen
Siedlungsgenerator als Grundlage für G4c/G5.

## 2. Entschieden

- **Generator:** port-basierte Segmente; handgebaute 16×16-Prefabs mit
  Footprint, Road-Ports, Tags, Gewicht, Bedingungen.
- **Daten:** JSON-Metadaten + Tile-Prefabs; deterministischer RNG-Stream pro
  Siedlung; versionierte Module.
- **Dorf:** zentraler Platz/Brunnen, gewundene Wege, kompakte Häuser mit
  Gärten/Zäunen/Bäumen; Werkstatt/Scheune/Kornspeicher am Rand; Teich.
- **Häuser:** 6–10 eigene Roguelike-basierte Varianten aus RPG-Base/RPG-Pack;
  1-Tile-Türen, 2–3 Dachfarben, Fenster/Schornsteine; 6×6–8×8 Tiles.
- **Felder:** 6 kleine Parzellen (~10×8 Tiles), Zäune/Hecken, echte Boden-/
  Pflug-/Saat-/Wachs-/Reife-/Ernte-Kacheln, saisonale Farben.
- **Maßstab:** 1,5 m/Tile, 16 px/Tile; Figuren **1,2×** (~1,8 m); Türen
  1 Tile; Straßen 1–2 Tiles.
- **Palette:** Gras entsättigen, Dächer wärmer, Wege dunkler/wärmer, Wasser
  mit Ufer; Tag/Nacht/Season-Tint.
- **Stadtmauer:** jetzt planen (Wall/Gate/Tower-Segmente), später bauen;
  kein Krieg in V3.
- **Siedlungstypen:** gestaffelt Hof → Bauerschaft → Dorf → Kirchdorf →
  Kleinstadt → Mittelstadt → Großstadt (Mauer); Module erweiterbar.
- **Save:** Seed + Modulversionen + generiertes Layout + dynamische
  Änderungen; nicht nur Seed.
- **Tests:** keine großen G1–G4b-Suiten während der visuellen Iteration;
  kurze P2-Selbstchecks und Screenshots. Volle Regression erst vor dem
  G4c-10k-Gate/Tag.

## 3. P2.1-Modulsatz (erster Durchgang)

Segmente (jeweils 16×16 Tiles oder Vielfache, mit Ports):

- `square_well`: zentraler Platz, Brunnen, Bänke, Marktstände (Stub).
- `road_straight`, `road_corner`, `road_t`, `road_cross`: 1–2 Tiles breit.
- `house_row_a/b`: 3–4 Häuser mit Gärten/Zäunen entlang einer Straße.
- `house_single`: freistehendes Haus mit Garten.
- `farmstead`: Hof, Haus, Scheune, kleiner Garten.
- `workshop`: Werkstatt mit Hof/Lager.
- `granary`/`barn`/`well` als kleine Civic-/Farm-Segmente.
- `field_cluster`: 6 Parzellen ~10×8, Hecken/Zäune, Wege, Crop-Stufen.
- `pond`: Wasser mit Uferkante, Schilf.
- `orchard`/`garden`/`trees`: Bäume, Obstgarten, Deko.
- `props`: Zäune, Karren, Fässer, Holzstapel, Wäsche, Blumen.

## 4. Generator-Pipeline (P2.1)

1. Seed + Typ `village` + Biom `grass` + Zielbevölkerung 100.
2. Platz/Brunnen in die Mitte; Hauptstraßen mit Ports anlegen.
3. Segmente gewichtet auswählen/anbauen: Wohnen, Hof, Werkstatt, Civic.
4. Felder an Außenports; Teich/Obstgarten in Lücken; Props füllen.
5. Validierung: keine Überlappung, Straßenanschluss, 24 Häuser,
   6 Felder, 100 Agentenkapazität, Pfad-/Occupancy-Check.
6. Layout + Seed + Modulversionen speichern; dynamische Änderungen später
   als Delta.

## 5. Visuelle Iteration

- **P2.1a:** Modulsatz + Generator + Layout; Screenshots Übersicht/Nah.
- **P2.1b:** Häuser/Türen/Dächer/Gärten/Felder/Props verfeinern; Screenshots.
- **P2.1c:** Palette/Scale/Tag-Nacht/Season; finale P2-Screenshots.
- Nach jedem Schritt: kurze 100-Agenten-Preview + Screenshots, Feedback des
  Nutzers, dann gezielt nachbessern. Keine 35-Minuten-Suiten.

**Timebox (verbindlich):**

- Max. **25 Minuten** pro P2-Iteration.
- Kein G1–G4b-/G4a-/G3-Suite-Lauf, kein 10k, kein Baseline-/Perf-Vergleich.
- Kein einzelner Befehl über **120 Sekunden**; bei Überschreitung abbrechen
  und mit Screenshots/Blocker zurückmelden.
- Nur 100-Agenten-Demo + maximal 4 Screenshots + kurzer Report.
- Bei Timeout: unfertigen Stand + Screenshots liefern; keine stillen
  Langläufe.

## 6. Abnahme P2.1

- 100 Agenten, 24 Häuser, 6 Feldparzellen, organisches Dorf.
- Häuser als Wohnhäuser lesbar; 1-Tile-Türen; Figuren 1,2×.
- Felder zeigen Phasen und saisonale Farben; Zäune/Hecken.
- Straßen/Plätze organisch, keine Rasterwirkung.
- Keine fehlenden Texturen; Y-Sort/Tag-Nacht funktionieren.
- G1–G4b-Verhalten unverändert; keine Sim-/Balance-Änderung.
- Screenshots + kurzer P2-Report; kein Tag `g4c` vor G4c.

## 7. Nicht-Ziele

- Kein 10k, keine G4c-Abnahme, keine großen Testläufe.
- Keine Stadtmauer-Implementierung in P2.1 (nur Planung).
- Keine Wirtschaft/Politik/Chronik-Politur.
- Keine Tiny-Farm/Town/Dungeon-/Medieval-RTS-Assets.
- Keine Änderung an G0-Dokumenten/README/Master-Plan.
- Keine Git-Commits ohne Review; P2-Checkpoints separat.

## 8. P2.1c1 — Rounded Transitions, Palette, Wege

- Eigene Uebergangs-/Rundungsschicht aus den CC0-Tiles: Gras<->Dirt<->Weg<->Wasser<->Pflaster, 4-Bit-Kanten und abgerundete Ecken (2-4 px).
- Platz als unregelmaessige Ellipse/Polynom mit weichem Gras-/Dirt-Rand statt Rechteck.
- Wege 1-2 Tiles, runde Enden/Ecken, Grasraender, leichte Rillen.
- Teich mit runder/irregulaerer Form und Sand-/Grasufer.
- Palette: Gras leicht entsaettigen, Grassvariation/Bueschel, Daecher waermer, Wege dunkler.
- Kein Layout-Umbau (der kommt in P2.1c2); Timebox 30 min, keine Suiten.
