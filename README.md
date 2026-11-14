# WimmelWorld V3

Status: **G2 bestanden (2026-11-14); G3 bereit, Freigabe offen.**  
G0.5, G1 und G2 sind abgeschlossen.

## Was V3 ist

- Frischer Neustart ohne V1-/V2-Code.
- Beobachter-/Chronik-Sandbox: keine Eingriffe, keine Niederlage.
- Leben + Soziales + Wirtschaft + Handel + Politik.
- 3 menschliche Nationen, ~100k Einwohner, 30-Tage-Jahr.
- 1,5 m/Tile, 16 px/Tile, 3/4-Topdown.
- GDScript zuerst, SoA + eventgetrieben, strikt kameraunabhängig.
- Gates: G0 → G0.5 → G1a/G1b → G2 → G3 → G4a/G4b → G5a/G5b → G6.

## Dokumente

| Dokument | Inhalt |
|---|---|
| `docs/v3-plan.md` | Master-Plan, Entscheidungen D-01–D-64, Gates, Risiken |
| `docs/v3-g1-spec.md` | G1a/G1b: Welt, Agenten, Needs, Arbeit, Lifecycle, UI, Abnahme |
| `docs/v3-architecture.md` | Schichten, Ownership, Determinismus, Persistenz, View |
| `docs/v3-data-model.md` | Entitäten, IDs, Events, Save, Retention, JSON |
| `docs/v3-benchmark.md` | Zielhardware, 3-Lauf-Protokoll, Szenarien, Budgets |
| `docs/v3-chronicle.md` | Chronik-Taxonomie, Importance, Pacing, Retention |
| `docs/v3-fidelity.md` | A/B-Vertrag, preserved/approximated fields |
| `docs/v3-risk-register.md` | Risiken R1–R18, Auslöser, Gegenmaßnahmen |
| `docs/v3-g0.5-spike.md` | Technikspike vor G1 (abgeschlossen) |
| `docs/g0.5/v3-g0.5-results.md` | G0.5-Messwerte, C#-Vergleich, Portentscheid |
| `docs/v3-project-structure.md` | Repo-/Toolchain-/Test-/Benchmark-Plan |
| `docs/v3-g1-workpackages.md` | G1-Arbeitspakete und Test-IDs |
| `docs/g1a/v3-g1a-report.md` | G1a-Implementierung, Tests, Messwerte, Review |
| `docs/g1a/README.md` | G1a-Test- und Demoanleitung |
| `docs/g1b/v3-g1b-step1-report.md` | G1b Schritt 1: Needs, Health, Feldzyklus |
| `docs/g1b/v3-g1b-step2-report.md` | G1b Schritt 2: Lebenszyklus, Demografie, Haushalte |
| `docs/g1b/v3-g1b-step3-report.md` | G1b Schritt 3: Chronik, Beobachtungs-UI, Replay |
| `docs/g1b/README.md` | G1b-Testanleitung Schritt 1–3 |
| `docs/g2/v3-g2-spec.md` | G2: 100-Agenten-Bauerschaft, A*, Batching, 30 Tage |
| `docs/g2/v3-g2-report.md` | G2: Implementierung, Tests, Performance, Review |
| `docs/g2/README.md` | G2-Test-/Demoanleitung |
| `docs/v3-g0-review.md` | G0-Review-Checkliste und Freigabe |
| `docs/reviews/v3-review-2026-11-13.md` | Externes Review und Konsequenzen |
| `docs/reviews/v3-review-prompt.md` | Prompt für die erste externe Review |
| `docs/reviews/v3-review-prompt-round2.md` | Prompt für die zweite externe Review (G0-Verifikation) |

## Nächster Schritt

1. G0.5 und G1a sind bestanden.
2. G1b-Freigabe durch den Nutzer.
3. G1b gemäß `docs/v3-g1-spec.md` starten.
4. Danach G2 usw. gemäß Master-Plan.

G1a-Demo:
`& $godot --path C:\coding\WimmelWorld\V3 res://tests/g1a/demo.tscn`

## Regeln

- Kein V1-/V2-Code importieren.
- Keine kameraabhängige Simulation.
- Keine stillen Fidelity-Modi.
- Kein „PARTIAL“-Gate.
- Jede Budget-/Balanceänderung ist eine versionierte Entscheidung.
