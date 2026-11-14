# V3-Risiko-Register

Status: G0-Artefakt, Entwurf  
Stand: 2026-11-13  
Bezug: `v3-plan.md`, `reviews/v3-review-2026-11-13.md`.

## 1. Legende

- **Wahrscheinlichkeit:** niedrig / mittel / hoch.
- **Wirkung:** niedrig / mittel / hoch / kritisch.
- **Status:** offen / beobachtet / mitigiert / geschlossen.

## 2. Risiken

| ID | Risiko | W | Wirkung | Auslöser | Gegenmaßnahme | Status |
|---|---|---|---|---|---|---|
| R1 | GDScript trägt Eventdichte nicht | mittel | kritisch | G0.5/G2: µs/Event über Budget | G0.5: 3,5–4,6 µs/Event, 100k-Sweep 41,5 ms; GDScript bleibt, Port-Trigger D-64 | beobachtet |
| R2 | 100k@50x unerreichbar | hoch | mittel | G5a-Stretch verfehlt | 100k@50x Stretch; 100k@10x Pflicht; B-Fallback | beobachtet |
| R3 | Event-Explosion | mittel | hoch | Events/Frame > Budget | G0.5: 9,52 Need-Wakes/Tag innerhalb 8–10; Batching/Event-Budget; reale Handler in G1a/G2 | beobachtet |
| R4 | Pfad-/Chunk-Kosten bei 100k | hoch | hoch | G3/G4 Pfad-p95/Speicher über Budget | G0.5: 0,53–0,97 ms p95 ohne Cache, 96,8 % Hit; Chunk/100k in G3/G4 | beobachtet |
| R5 | G1 zu groß | hoch | hoch | G1a/G1b nicht in Zeit | G1 abgeschlossen (G1a/G1a.1/G1b 1–3 bestanden); G1a reduziert, G1b gedrittelt | geschlossen |
| R6 | D-57-Scope frisst Skalierung | mittel | hoch | G2/G3 werden Feature-Gates | G2/G3 nur Stubs; echte Systeme G4/G5 | mitigiert |
| R7 | Save/Replay fehleranfällig | mittel | hoch | Save/Load-Differenz | versioniertes Binär-Save; stabile IDs; Restore-Tests | offen |
| R8 | Chronik wird Event-Rauschen | hoch | hoch | Alerts/Log unlesbar | Taxonomie, Importance, Dedup, Digest, Retention | offen |
| R9 | Fehlende Retention/Save-Größe | mittel | hoch | Save/Log explodiert | Retention-Politik; Budget in G0.5/G2; Summaries | offen |
| R10 | Plan-/Doku-Drift | hoch | hoch | widersprüchliche Entscheidungen | Master + G0-Artefakte; Status final/provisional; Review-Checkliste | offen |
| R11 | KI-Prozess/Monolithen | mittel | hoch | Datei > 1.000 Zeilen, Parallelwahrheit | PM-Review; kleine Aufträge; keine Subagenten-Designentscheidungen | offen |
| R12 | B wird stiller Qualitätsverlust | mittel | hoch | B ohne Vertrag/Freigabe | B-Vertrag; ADR; Paritätstests; Nutzerfreigabe | mitigiert |
| R13 | Kameraabhängigkeit schleicht sich ein | mittel | kritisch | Sim liest Kamera/Sichtbarkeit | Architekturregel; Tests; Review | mitigiert |
| R14 | Art/UI-Maßstab passt nicht | mittel | mittel | Figuren unlesbar, Welt leer | 3/4-Topdown; 1,5 m/16 px; frühe Screenshots | offen |
| R15 | Daten-/Content-Pipeline unklar | niedrig | mittel | neue Inhalte brauchen Code | JSON + prozedurale Regeln; Schema in G0 | mitigiert |
| R16 | Cursed-Beyond-Kopplung zu früh | niedrig | mittel | Netzwerk vor G5 | Engine-/Shell-Grenze; kein Netzwerk | mitigiert |
| R17 | Review-/Gate-Definition zu weich | mittel | hoch | „PARTIAL“/Kurzläufe | Benchmark-Matrix; 3 Läufe; Checkliste | mitigiert |
| R18 | Zeitbudget/Scope insgesamt zu groß | hoch | hoch | G5 nicht erreichbar | Gates; Stretch/Pflicht trennen; Systeme verschiebbar | offen |

## 3. Schweregrad-Reihenfolge

1. R1 GDScript/Eventdichte.
2. R4 Pfad-/Chunk-Kosten.
3. R10/R11 Prozess-/Doku-Drift.
4. R8 Chronik-Rauschen.
5. R7/R9 Save/Retention.
6. R18 Gesamt-Scope.

## 4. Review-Kadenz

- Vor G0: Widersprüche und Budgets prüfen.
- Nach G0.5: R1/R4 mit Messwerten neu bewerten.
- Nach jedem Gate: Register aktualisieren; neue Risiken aufnehmen.
- Keine Risiko-Schließung ohne Test oder Messung.
