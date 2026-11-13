# V3-Benchmark und Abnahmematrix

Status: G0-Artefakt, Entwurf  
Stand: 2026-11-13  
Bezug: `v3-plan.md`, D-17, D-24, D-58, D-62.

## 1. Ziel

Jede Performance- und Determinismusbehauptung wird mit identischer Last,
Seed, Warm-up, Kamera, Dauer und Zielhardware belegt. Kurzläufe und
„PARTIAL“-Ergebnisse sind keine Abnahme.

## 2. Zielhardware und Umgebung

- CPU: Ryzen 5 5600.
- GPU: RTX 5060.
- OS: Windows, Godot 4.7.2 stable.
- Auflösung: 1920 × 1080, Fenstermodus; zusätzlich 2560 × 1440 als
  Render-Stichprobe.
- Simulation: headless für Determinismus und Eventkosten; grafisch für
  Render-/UI-Abnahme.
- Energieprofil und Hintergrundlast dokumentieren.

## 2.1 G0.5-Messwerte (2026-11-13)

Details: `docs/g0.5/v3-g0.5-results.md`.

| Messung | Ergebnis |
|---|---|
| Scheduler 10k/100k | 3,5–4,6 µs/Event; 218k–287k Events/s |
| SoA 10/1k/10k/100k | 0,41–0,48 µs/Agent/Tick; 100k-Sweep 41,5 ms |
| Needs | 9,52 Wakes/Agent/Tag (Plan: 8–10) |
| Pfad 128²/512² | 0,53–0,97 ms p95 ohne Cache; 96,8 % Hit mit Cache |
| Batch 100k | 0,52 µs/Event; p95 54 ms (nicht frame-fähig) |
| Save 100k | 5,8 MB; 45,8 ms Save / 86,8 ms Load |
| Render 100k Marker | 1 Draw Call; p95 < 0,61 ms; Build 29,2 ms |
| Determinismus | 3 Läufe identisch; C#-Parität bitgleich |
| GDScript vs. C# | 27–69× schneller in C# (Konsolen-Hotloop) |

Die Budgets in §5 bleiben provisional; G0.5 bestätigt große Reserven, ersetzt
aber keine echte G1a-/G2-Last mit Terrain, UI und realen Handlern.

## 3. Standardprotokoll

Pro Messpunkt:

1. Gleicher Seed und gleiche Konfiguration.
2. Warm-up: mindestens 10 % der Messdauer, nicht gewertet.
3. Messdauer: **Performance-Fenster** (Wandzeit, z. B. 5 Minuten) und
   **Funktions-Fenster** (Sim-Zeit, z. B. 30 Sim-Tage/1 Sim-Jahr) getrennt
   ausweisen. Ein 5-Minuten-Lauf bei 10x deckt nur ~3,3 Sim-Tage ab und ist
   kein Jahres-/Wirtschaftsnachweis.
4. Drei vollständige Läufe; alle drei müssen bestehen.
5. Kamerafahrt: fern → nah → Pan, definiert pro Gate.
6. Metriken: p50/p95/p99/max, FPS, Sim-/Render-/UI-Zeit, Events/Frame,
   Batch-Größen, Pfadaufrufe, Cache-Hit-Rate, Speicher, Save-Größe,
   Ladezeit.
7. Rohdaten als JSON/CSV plus Log; keine geschätzten Werte.
8. Bei Abweichung: gleiche Bedingungen erneut messen, nicht „wegoptimieren“.

## 4. Szenarien und Budgets

| Gate | Funktion (Sim-Zeit) | Last | Speed | Performance-Fenster | Harte Abnahme |
|---|---|---|---:|---:|---|
| G0.5 | Mikrobenchmarks | 10/1k/10k/100k Hot Loops | — | kurz | Events/s, µs/Event, Pfad-ms, Render-ms, Save-Durchsatz, Repeat-Hash |
| G1a | 1 Sim-Tag | 10 Agenten | 1x | 15 min | 60 FPS, Determinismus, Save/Load |
| G1b | 1.000-Agenten-Demografie (100 Jahre/5 Seeds) + 1 Sim-Jahr visuell | 10 Agenten visuell | 50x visuell | 9 min visuell | Demografie, Chronik, Replay, Determinismus |
| G2 | 30 Sim-Tage | 100 Agenten | 50x | 5 min | 60 FPS, 3 Läufe, Save/Load |
| G3 | 30 Sim-Tage | 1.000 Agenten | 50x | 5 min | 60 FPS, Pfad-Checkpoint, 3 Läufe |
| G4a | 30 Sim-Tage | 10.000 Agenten | 50x | 5 min | 60 FPS, 3 Läufe |
| G4b | 1 Sim-Jahr funktional + 30 Sim-Tage Performance | 10.000 Agenten + Wirtschaft/Politik | 50x | 9 min funktional / 5 min Performance | Systembilanz + Performance |
| G5a | 1 Sim-Jahr funktional | 100.000 Agenten | 10x | 45 min funktional / 5 min Performance | 100k@10x Pflicht; 100k@50x Stretch |
| G5b | 1 Sim-Jahr funktional + 30 Sim-Tage Performance | 100.000 Agenten + Systeme | 10x/50x | 45 min / 9 min | Systembilanz + Chronik |

## 5. Event-Budget pro Szenario

Annahme: ~8–10 Events pro Agent und Tag.

| Szenario | Events/Frame @60 FPS | µs/Event für 8 ms Sim |
|---|---:|---:|
| 10k @ 50x | 74–93 | ~86–108 µs |
| 100k @ 10x | 148–185 | ~43–54 µs |
| 100k @ 50x (Stretch) | 740–926 | ~8,6–10,8 µs |

**60 FPS/Gesamtframe sind ab G1a hart. Per-Event-/Pfad-/Save-Budgets werden in
G0.5/G2 kalibriert und ab G3 hart.**

- **Gesamtframe:** p95 ≤ 16,0 ms, p99 ≤ 20 ms, 60 FPS.
- **Split:** Sim p95 ≤ 6 ms, Render p95 ≤ 6 ms, UI/Godot/GC ≤ 4 ms.
- Kein Einzel-Event über 250 µs; Batch-p95 < 2 ms.
- **Pfad/Frame:** höchstens 2 Neuberechnungen und 50 Cache-Lookups pro Frame;
  Pfad-p95 ≤ 2 ms/Frame. Cache-Hit-Rate > 90 % für lokale Ziele.
- **Burst:** Morgen, Mahlzeiten, Arbeitsfenster und gleiche Sim-Zeit explizit
  messen; p95 der Frame-Summe, nicht nur Einzel-Event-p95.
- 100k nur mit Instancing/Markern; keine 100k-Einzel-Draw-Calls.
- Save-Größe/Ladezeit/Peak-Speicher pro Gate messen; Zielwerte in G0.5.
- Event-Log/Chronik: hartes Byte-/Event-Budget in G0.5/G2.

**Provisorische Obergrenzen pro Event-Typ (G0.5 kalibriert, harte Gates ab G3):**

| Event-Typ | Obergrenze |
|---|---:|
| Need-Wake | 50 µs |
| Arbeit Start/Ende | 50 µs |
| Ankunft inkl. Cache-Lookup | 100 µs |
| Sozial/Lifecycle | 100 µs |
| Economy-Batch | 2 ms |
| Lokaler Path-Call (Neuberechnung) | 5 ms p95, max. 2/Frame |

G1a zusätzlich: 1 Minute bei 50x für den 60-FPS-Check.

## 6. Determinismus-Abnahme

- Gleicher Seed + gleiche Konfiguration → identische Snapshots und
  Event-Reihenfolge (3 Läufe).
- Unterschiedliche Batch-Größen und Frame-Aufteilungen → gleicher
  Sim-Zustand bei gleicher Sim-Zeit.
- Kamera/Zoom/Sichtbarkeit → kein Zustandsunterschied.
- Save/Load vor/nach Entscheidung, Buchung, Geburt, Tod → exakter Verlauf.
- Replay = Re-Simulation aus Seed + Konfiguration + Save-Snapshot; der
  Chronik-Log ist **nicht** die Replay-Quelle.
- Zufällige Dictionary-/Heap-Reihenfolge ist ein Fehler, kein Messrauschen.

## 7. Render-/UI-/Chronik-Abnahme

- Nahzoom: sichtbare Agenten detailliert, keine Simulation beeinflusst.
- Fernzoom: Marker/Instanzen, keine Einzel-Draw-Calls.
- Pan/Zoom: p95 ≤ 16 ms, kein Hänger > 250 ms; Chunk-Budget.
- Render: Draw Calls und GPU-ms pro Szenario; 100k nur mit Instancing.
- UI: Inspector öffnet < 100 ms; Familienbaum mindestens 3 Generationen;
  Follow bleibt 60 s stabil; keine fehlenden Pflichtfelder.
- Alerts: ≤ 20/Tag, Story of the Day ≤ 7/Tag, Dedup-Ratio > 80 %,
  mindestens 3 notable Ereignisse/Tag.
- Chronik: keine Routine-Event-Flut; Kausalitätslinks vorhanden.
- Tag/Nacht und Jahreszeiten visuell geprüft.

## 8. Speicher-, Save- und Replay-Abnahme

- Peak-Speicher pro Gate messen.
- Save-Größe, Ladezeit, Kompressionsrate.
- Event-Log-Größe und Retention.
- Replay-Dauer und Reproduzierbarkeit.
- Keine stillen Speicherlecks über 5 Minuten.

## 9. Berichtsformat

```text
Gate:
Szenario:
Seed:
Warm-up:
Dauer:
Hardware/OS/Godot:
Kamera:
Läufe: 3
p50/p95/p99/max Sim:
p50/p95/p99/max Render:
Events/Frame:
Batches:
Pfadaufrufe/Cache-Hit:
Speicher:
Save-Größe/Ladezeit:
Determinismus: bestanden/fehlgeschlagen
Ergebnis: bestanden/fehlgeschlagen
```

## 10. Regeln

- Keine M2/M3-Abkürzung aus Kurzläufen.
- Keine Benchmark-Sonderregeln, die das Verhalten ändern.
- Keine Kamera-/Sichtbarkeitsfilterung der Simulation.
- Keine „PARTIAL“-Abnahme; ein Gate besteht nur vollständig.
- Jede Budgetänderung ist eine versionierte Entscheidung.
