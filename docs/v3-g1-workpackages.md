# V3 G1 — Arbeitspakete und Test-IDs

Status: G0-Artefakt, Entwurf  
Stand: 2026-11-13  
Bezug: `v3-plan.md`, `v3-g1-spec.md`, `v3-benchmark.md`, D-59.

## 1. Zweck

Dieses Dokument macht die G1-Arbeitspakete und ihre Akzeptanztests prüfbar.
Jedes Paket hat eine Gate-Zuordnung und mindestens eine Test-ID. Ein Gate ist
nur bestanden, wenn alle seine Test-IDs grün sind.

## 2. Arbeitspakete

| WP | Gate | Inhalt | Test-IDs |
|---|---|---|---|
| W1 | G1a | Kernel: Clock, Scheduler, RNG, Debug-/Chronik-Log, Snapshot | T-KERN-01..04 |
| W2 | G1a | SoA-Agentenstore, kalte Records, ID-Lebenszyklus | T-STORE-01..03 |
| W3a | G1a | Needs/Decisions: Hunger, Energie, Sozial | T-NEED-01..04 |
| W3b | G1b | Needs: Hygiene, Spaß, Gesundheit | T-NEED-05..07 |
| W4 | G1a | Welt: Weiler, Häuser, Feld, Speicher, Brunnen, Scheune, Wege | T-WORLD-01..03 |
| W5a | G1a | Bewegung: Waypoint, `position_at`, Ankunft | T-MOVE-01..03 |
| W5b | G2 | Lokaler A*, Pfad-Cache, Occupancy | T-PATH-01..04 |
| W6a | G1a | Arbeit/Nahrung: tägliche Arbeit, einfacher Speicher, Essen | T-FOOD-01..03 |
| W6b | G1b | Voller Feldzyklus, Aussaat/Ernte, Jahresbilanz | T-FARM-01..04 |
| W7 | G1b | Lebenszyklus/Soziales: Alterung, Tod, Partnerschaft, Geburt | T-LIFE-01..06 |
| W8a | G1a | Save/Load, Snapshot, Restore | T-SAVE-01..03 |
| W8b | G1b | Replay als Re-Simulation; Log-Trennung | T-REPLAY-01..03 |
| W9a | G1a | View/UI-Kern: Terrain, Kamera, Tag/Nacht, Inspector, Event-Log | T-UI-01..04 |
| W9b | G1b | Chronik-Tools: Familienbaum, Follow, Alerts, Story of the Day | T-UI-05..08, T-CHRON-01..05 |
| W10 | G1a/G1b | Benchmark/Abnahme, 3 Läufe, headless + visuell | T-BENCH-01..04 |
| W11 | G1b | Review/Doku, Risiko-Update, G1-Bericht | T-REVIEW-01 |

**Hinweis:** W5b (G2) und T-PATH-01..04 werden in der G2-Spezifikation
definiert; in G1 sind sie nur eine Abhängigkeit, kein G1-Abnahmepunkt.

## 3. Testmatrix

### G1a

| ID | Test | Bestehenskriterium |
|---|---|---|
| T-KERN-01 | Scheduler-Ordnung `(time, seq)` | 3 Läufe identisch; keine Dictionary-Reihenfolge |
| T-KERN-02 | RNG-Streams | Gleicher Seed → gleiche Zustände; Streams getrennt |
| T-KERN-03 | Event-Log-Trennung | Debug/Chronik getrennt; kein Replay aus Log |
| T-KERN-04 | Snapshot/Restore | Clock/Scheduler/RNG exakt wiederhergestellt |
| T-STORE-01 | SoA-Store | 10 Agenten, stabile IDs, keine Kopien |
| T-STORE-02 | ID-Lebenszyklus | Toter Agent bleibt referenzierbar |
| T-STORE-03 | Keine Per-Agent-Dicts im Hot-Loop | Codeprüfung/Profiling |
| T-NEED-01 | Hunger-Schwelle | Mahlzeit unterbricht Arbeit, Rückkehr zur Routine |
| T-NEED-02 | Energie/Schlaf | Schlaffenster und Erholung korrekt |
| T-NEED-03 | Sozial | Sozialisieren erfüllt Need, kein Dauerloop |
| T-NEED-04 | Determinismus | Need-Events 3 Läufe identisch |
| T-WORLD-01 | Erreichbarkeit | Alle Häuser/Arbeitsplätze über Wege erreichbar |
| T-WORLD-02 | Occupancy | Gebäude blockieren korrekt |
| T-WORLD-03 | Weltgrenzen | Kein Agent verlässt die Karte |
| T-MOVE-01 | `position_at` | Position zur Zeit exakt, keine Frame-Abhängigkeit |
| T-MOVE-02 | Ankunft | Ankunfts-Event exakt zum Termin |
| T-MOVE-03 | Waypoint | Kein A*-/Cache-Zwang in G1a |
| T-FOOD-01 | Tägliche Arbeit | Grain-Zuwachs pro Arbeitstag korrekt |
| T-FOOD-02 | Mahlzeit | Grain-Verbrauch und Hunger-Reset korrekt |
| T-FOOD-03 | Knappheit | Kein stilles Auffüllen; Hunger/Health reagieren |
| T-SAVE-01 | Save/Load vor Entscheidung | Exakter weiterer Verlauf |
| T-SAVE-02 | Save/Load nach Arbeit | Exakter weiterer Verlauf |
| T-SAVE-03 | Save-Version | Inkompatible Version sichtbar abgelehnt |
| T-UI-01 | Inspector | Agent, Needs, Home, Job sichtbar |
| T-UI-02 | Event-Log | Kernereignisse sichtbar, keine Sim-Mutation |
| T-UI-03 | Kamera/Zoom | Kein Sim-Zustandsunterschied |
| T-UI-04 | 60 FPS | 10 Agenten@50x, Gesamtframe p95 ≤ 16 ms |
| T-BENCH-01 | 3 Läufe | Alle drei G1a-Läufe bestehen |
| T-BENCH-02 | Headless/visuell | Beide Messungen dokumentiert |

### G1b

| ID | Test | Bestehenskriterium |
|---|---|---|
| T-NEED-05 | Hygiene | Waschen erfüllt Need; Health-Folge |
| T-NEED-06 | Spaß | Freizeit erfüllt Need; kein Dauerloop |
| T-NEED-07 | Gesundheit | Langsamer Zustand; keine Krankheit/Gewalt in G1 |
| T-FARM-01 | Feldzyklus | FALLOW→…→HARVEST vollständig, deterministisch |
| T-FARM-02 | Aussaat/Ernte | Jahresbilanz korrekt, keine stille Auffüllung |
| T-FARM-03 | Knappheit | Ernteausfall → Hunger/Health, Chronik |
| T-FARM-04 | 1 Sim-Jahr | Jahreszyklus im visuellen Lauf sichtbar |
| T-LIFE-01 | Alterung | Alterung korrekt, Kind/Jugend/Erwachsen/Alt |
| T-LIFE-02 | Mortalität | 1.000-Agenten-Kohorte, 100 Jahre/5 Seeds: Mindestgeburten/-tode, Zielverteilung |
| T-LIFE-03 | Partnerschaft | Nur gültige Partner, deterministisch |
| T-LIFE-04 | Geburt | Schwangerschaft/Geburt deterministisch, Save-fähig |
| T-LIFE-05 | Tod | Todeszeitpunkt/Record korrekt, Haushalt aktualisiert |
| T-LIFE-06 | Haushaltsauflösung | Minderjährige korrekt zugeordnet, kein Dangling |
| T-REPLAY-01 | Re-Simulation | Seed+Config+Snapshot → gleicher Verlauf |
| T-REPLAY-02 | Log-Unabhängigkeit | Chronik-Log-Kürzung ändert Replay nicht |
| T-REPLAY-03 | 3 Läufe | Identische Hashes/Events |
| T-UI-05 | Familienbaum | 3 Generationen, korrekte Kanten |
| T-UI-06 | Follow | 60 s stabil, keine Sim-Mutation |
| T-UI-07 | Alerts | ≤ 20/Tag, keine Routine-Flut |
| T-UI-08 | Story of the Day | ≤ 7/Tag, deterministisch bei festem Fokus |
| T-CHRON-01 | Event-Taxonomie | Alle Typen/Importance vorhanden |
| T-CHRON-02 | Dedup | Dedup-Ratio > 80 %, keine erfundene Ursache |
| T-CHRON-03 | Retention | Budget eingehalten; Summaries korrekt |
| T-CHRON-04 | Kausalität | „Warum?“-Links vorhanden |
| T-CHRON-05 | Fokusunabhängigkeit | Anderer Fokus ändert Chronik-Events nicht |
| T-BENCH-03 | G1b-Lauf | 1 Jahr visuell (10 Agenten) + 1.000-Agenten-Demografie (100 Jahre/5 Seeds) |
| T-BENCH-04 | Demografie | Zielverteilung eingehalten |
| T-REVIEW-01 | Review | Checkliste vollständig, keine offenen M-Punkte |

## 4. Reihenfolge

G0.5 → W1 → W2 → W3a → W4 → W5a → W6a → W8a → W9a → G1a-Abnahme →
W3b → W6b → W7 → W8b → W9b → G1b-Abnahme.

W5b (A*/Cache) folgt in G2.

## 5. Regeln

- Keine Test-ID ohne reproduzierbaren Seed/Setup.
- Keine „PARTIAL“-Abnahme; ein Gate besteht nur vollständig.
- Jede Test-ID wird im Gate-Bericht mit Ergebnis und Rohdaten referenziert.
- Änderungen an Akzeptanztests sind versionierte Entscheidungen.
