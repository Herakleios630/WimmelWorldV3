# V3 B-Spike — 100k@150x Zeitraffer

Status: G3-Spike-Spezifikation, Entwurf  
Stand: 2026-11-14  
Bezug: `docs/v3-fidelity.md`, `docs/v3-plan.md` D-18/D-19, `docs/v3-benchmark.md`.

## 1. Ziel

Mess Spike für **B: deterministisches Tiering** als Standalone-150x-Zeitraffer:

- **100.000 persistente Agentenrecords**.
- Deterministisches **Detailtier** mit 1.000 und 5.000 Agenten.
- Hintergrund-Coarse pro Siedlung/Kohorte (täglich/wöchentlich).
- **150x** und **200x**; Ziel/Ist-Speed, Events/Frame, Batch-/Pfadkosten,
  Speicher, Save/Load, Determinismus innerhalb B.
- Keine Kameraabhängigkeit; keine A/B-Replay-Gleichheit.

Der Spike ist **kein** finales B, keine UI/A Kunst, keine Wirtschaft/Politik.
Er beantwortet nur: Ist 100k@150x mit B tragbar, und mit welchem Detailtier?

## 2. Modell

- 100k Records in SoA + kalten Records; Siedlungen/Kohorten synthetisch.
- Detailtier: 1k/5k Agenten; deterministisch gewählt über stabile Hash-
  Rotation, Siedlungs-/Ereignisnähe, Reisen, Alter/Beziehungen; **nicht**
  Kamera/Sichtbarkeit.
- Hintergrund: Needs/Lebenszyklus/Jobs pro Siedlung/Kohorte in Tages-/Wochen-
  batches; key events (Geburt, Tod, Ehe, Jobwechsel) individuell erzeugt.
- Promotion/Demotion mit deterministischem Catch-up; kein Teleport/Zeitsprung.
- 150x = 1 Sim-Tag in 6 s; 200x = 4,5 s.
- Kein A-Modus, kein 1x-Autoritativ-Test; B ist ein eigener Modus.

## 3. Messungen

| Messung | Details |
|---|---|
| Events/Frame | 100k, Detail 1k/5k, 150x/200x |
| Batch-Kosten | p50/p95/p99, max. Batch |
| Detailtier-Kosten | µs/Detailagent/Tag |
| Hintergrund-Kosten | µs/Siedlung/Batch, Cadence |
| Frame/Sim/Render | p50/p95/p99/max, FPS |
| Ziel/Ist-Speed | tatsächlich erreichte Sim-Tage/s |
| Speicher | 100k Records, Detailtier, Caches |
| Save/Load | Größe, ms; kein finales Format |
| Determinismus | 3 Läufe, State-/Event-Hash |
| Tier-Wechsel | Anzahl, Catch-up-Kosten, Key-Event-Erhalt |
| Kamera | Follow/Inspector ändert keine Tier-Auswahl |
| Telemetrie | Bevölkerung, Alter, Haushalte, Jobs, Grain, Krisen pro Jahr/Siedlung |
| A/B-Drift | Makro-Invarianten/Ereigniszahlen innerhalb Toleranz; Mikro-Identitäten dürfen abweichen; Anker-Agenten erhalten |

## 4. Abnahme

- 100k@150x mit Detailtier 1k **und** 5k messbar; p95 ≤ 16 ms oder
  dokumentierte tatsächliche Speed.
- 100k@200x als Stretch messen.
- Key-Lifecycle-Events bleiben erhalten; keine verlorenen Identitäten.
- A/B-Makro ähnlich innerhalb Toleranz; Mikro-Identitäten dürfen abweichen;
  Anker-Agenten bleiben erhalten.
- Determinismus innerhalb B (3 Läufe).
- Save/Load innerhalb B exakt; Tier-Wechsel reproduzierbar.
- Keine Kameraabhängigkeit.
- Kein Leak; keine G1/G2-Regression (G1/G2-Suiten bleiben grün).
- Ergebnisbericht mit Empfehlung: Detailtier-Größe, Cadence, 150x/200x,
  ob B für 100k@150x ausreicht.

## 5. Nicht-Ziele

- Kein finales B, keine UI, keine Kunst, keine Wirtschaft/Politik.
- Keine Änderung an A (1x) oder Cursed Beyond.
- Keine Änderung an G0-Dokumenten, README oder `docs/v3-plan.md`.
- Keine Git-Commits; Review/Commit durch den Hauptagenten.
- Kein Sprachwechsel; GDScript-Spike.

## 6. Dateien

- `src/lod/` (Tier-Auswahl, Hintergrund-Coarse, Records, Batch).
- `tests/g3/` (B-Spike-Suite, 100k-Szenarien, Determinismus).
- `docs/g3/v3-g3-b-spike-report.md`, `docs/g3/README.md`.
- Keine Änderung an G1/G2-Produktionsdateien außer optionalen Read-only-
  Helfern; G1/G2 müssen unverändert grün bleiben.

## 7. Vorgehen

1. 100k-Records + Siedlungen synthetisch, deterministisch.
2. Detailtier 1k/5k; Hintergrund-Coarse; Tier-Wechsel.
3. 150x/200x-Szenarien, Chunks 1/60/3600, 3 Läufe.
4. Key-Event-Erhalt, Save/Load, Speicher, Leaks.
5. G1a/G1b/G2-Suiten als Regression.
6. Bericht mit Messwerten und Empfehlung.
