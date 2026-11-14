# V3 G1b — Schritt 1, Schritt 2 und Schritt 3

Status: **G1b Schritte 1–3 bestanden; G1 abgeschlossen (Review 2026-11-14);
Commit folgt**  
Bezug: `docs/v3-g1-spec.md`, `docs/v3-g1-workpackages.md`,
`docs/v3-architecture.md`, `docs/v3-data-model.md`,
`docs/g1a/v3-g1a-report.md`

## Inhalt

- `v3-g1b-step1-report.md` — Needs, Gesundheit, voller Feldzyklus.
- `v3-g1b-step2-report.md` — Lebenszyklus, Demografie, Haushaltsauflösung.
- `v3-g1b-step3-report.md` — kuratierte Chronik, Beobachtungs-UI, Replay,
  Save-Schema 4 und finale G1b-Abnahme.

## Umfang Schritt 1

- Needs **Hygiene**, **Spaß** und der langsame Zustand **Gesundheit**.
- Inspector/HUD zeigen sechs Werte: Hunger, Energie, Sozial, Hygiene, Spaß,
  Gesundheit.
- Voller Feldzyklus
  `FALLOW → PLOWING → PLOWED → SOWING → SOWN → GROWING → RIPE → HARVESTING → FALLOW`
  mit fortschrittsbasierter Arbeit, Aussaat, Wachstum, Ernte, Kornspeicher und
  Jahresbilanz bei 30-Tage-Jahr.
- Save-Schema **2**; Schema-1-Saves werden sichtbar abgelehnt.

## Umfang Schritt 2

- Alterung: Kind 0–12, Jugend 13–17, Erwachsen 18–59, Alt 60+; Geburtstage,
  Rollen- und Schedule-/Jobwechsel.
- Alters- und healthabhängige Sterblichkeit; Tod setzt `alive=0`, Cold-Record
  bleibt, stale Scheduler-Wakes werden ignoriert.
- Deterministische Partnerschaft unter lebenden Erwachsenen; bestehende
  Partner bleiben.
- Schwangerschaft, Geburt, Geburtsrisiko und neuer Agent mit Eltern/Haushalt.
- Haushaltsauflösung: Minderjährige zu verwandtem Haushalt, sonst Archiv und
  expliziter Nicht-Haushalt (0); keine Dangling-Referenzen.
- 1.000-Agenten-Demografie-Kohorte (100 Jahre, 5 Seeds) mit denselben
  Lifecycle-/Fertilitätsfunktionen wie die Hauptsimulation.
- Save-Schema **3**; Schema 1 und 2 werden sichtbar abgelehnt.
- Visueller 1-Jahres-Lauf mit **Featured Seed 34** (mindestens eine Geburt und
  ein Tod, ≥ 50 % lebend).

## Umfang Schritt 3

- Kuratierte Chronik statt rohem Event-Log: Event-Taxonomie, Importance,
  Dedup/Aggregation, Tagesdigest, Story of the Day, Kausalitätslinks.
- Ebenen Individuum, Familie und Siedlung; Nation erst G5.
- Deutsche Template-Texte, keine LLM-/Netzwerkabhängigkeit.
- Familienbaum (>= 3 Generationen, tote Agenten als historische Knoten),
  Follow-Modus, Alerts, Story of the Day, Chronik-Panel mit Filtern,
  Basis-Biografie im Inspector.
- Replay als Re-Simulation aus Seed + Konfiguration + Save-Snapshot;
  Log-Kürzung verändert den Verlauf nicht.
- Retention: 7 Sim-Tage notable+ im Ringpuffer, Tages-Summaries für 1 Sim-Jahr,
  historische Events budgetiert; Routine an der Quelle aggregiert.
- Save-Schema **4**; Schema 1–3 werden sichtbar abgelehnt.

## Nicht in Schritt 3 / G2

- Keine Siedlungs-/Nationen-Chronik, Lesezeichen, Sammlungen oder Zeitleiste.
- Kein A*/Pfad-Cache, keine Wirtschaft/Politik/Tiere/Fantasy.
- Keine Krankheit/Gewalt/Kriege.
- Kein Spielereingriff, kein Rewind/Scrubbing.

## Tests ausführen

```powershell
$godot = "C:\Users\ajsch\AppData\Local\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7.2-stable_win64_console.exe"

# 1) Import
& $godot --headless --path C:\coding\WimmelWorld\V3 --import

# 2) Visuellen G1a-Benchmark zuerst (T-UI-04/T-BENCH-02 lesen sein JSON)
& $godot --path C:\coding\WimmelWorld\V3 res://tests/g1a/bench_visual.tscn

# 3) Visuellen G1b-Jahreslauf (9 min; T-BENCH-03 liest sein JSON)
& $godot --path C:\coding\WimmelWorld\V3 res://tests/g1b/visual_year.tscn

# 4) G1a-Gate (29 Test-IDs)
& $godot --headless --path C:\coding\WimmelWorld\V3 res://tests/g1a/g1a_suite.tscn

# 5) G1b-Gate (Schritt 1 + 2 + 3; 28 Test-IDs)
& $godot --headless --path C:\coding\WimmelWorld\V3 res://tests/g1b/g1b_suite.tscn

# 6) Visueller Smoke-Screenshot (G1a-Demo)
& $godot --path C:\coding\WimmelWorld\V3 res://tests/g1a/capture_demo.tscn

# 7) Sichtbarer Chronik-/Familienbaum-/Follow-Smoke
& $godot --path C:\coding\WimmelWorld\V3 res://tests/g1b/capture_chronicle.tscn

# Optional: Seed-Suche (kein Gate)
& $godot --headless --path C:\coding\WimmelWorld\V3 res://tests/g1b/seed_search.tscn
```

## Erwartete Gates

```text
G1A_SUITE results=29 passed=29 failed=0 checks=260
G1A_SUITE_OK

G1B_SUITE results=28 passed=28 failed=0 checks=792
G1B_SUITE_OK
```

Zusätzlich bleibt der G0.5-Spike unverändert:

```powershell
& $godot --headless --path C:\coding\WimmelWorld\V3 res://tests/spike/unit_checks.tscn
# SPIKE_UNIT_OK
```

## Mess-Kurzfassung

### Schritt 1 (Seed 1337)

- 10 Agenten @50x visuell: **p95 5,07 ms**, **224,9 FPS**, 666 Draw Calls Ø.
- Ein Sim-Jahr (30 Tage): **4 Ernten**; Grain
  **60 + 880 − 769 = 171**; 260 Mahlzeiten-Skips in der Anfangsknappheit.
- Save Schema 2: **12.856 Bytes**.

### Schritt 2 (Seed 1337 / Featured Seed 34)

- Ein Sim-Jahr (Seed 1337): Startgrain **120**, 4 Ernten, Grain
  **120 + 880 − 828 = 172** (Endbestand 171 nach Jahresabschluss),
  **140** Mahlzeiten-Skips, A1-Gesundheit **92,4**, 1 Geburt, 0 Tode,
  11 Lebende.
- Demografie: 5 Seeds × 1.000 Agenten × 100 Jahre =
  **46.082 Geburten**, **4.990 Tode**, Median **49,0**,
  29,2 % vor 40, 16,2 % erreichen 70, 6,8 % erreichen 80.
- Featured Seed 34: **2 Geburten, 2 Tode, 8/10 Startagenten leben**,
  10 Lebende insgesamt; erste Geburt und erster Tod an Lifecycle-Tag 20
  (Anzeige Tag 21 00:00); Grain 182,
  ID 8 Gustav (Spec-A5) Gesundheit 80,1.
- Visueller Jahreslauf @50x: 30,0 Sim-Tage in 540,0 s,
  **p95 5,106 ms**, **224,2 FPS**, 665,3 Draw Calls Ø, max. 285,9 ms
  (Screenshot-Hitch; ohne Capture max. 10,6 ms im G1a-Bench).
- G1a-Bench @50x: **p95 5,086 ms**, **225,1 FPS**, 666,0 Draw Calls Ø,
  max. 10,641 ms.
- Save Schema 3: **13.506 Bytes**, Save **1,01 ms**, Load **7,77 ms**
  (Seed 1337, Tag 1 12:05).

### Schritt 3 (Featured Seed 34 / Seed 1337)

- Ein Sim-Jahr (Featured Seed 34): 30,0 Sim-Tage in 540,0 s,
  **2 Geburten, 2 Tode, 10 Lebende** (8/10 Startagenten), Grain 182.
- Visueller Jahreslauf @50x: **p95 5,319 ms**, **p99 7,208 ms**,
  **219,5 FPS**, 694,2 Draw Calls Ø, 5.850 Events, 117.414 Frames.
- Chronik: **88 Events**, **30 Summaries**, **1 Historic**,
  **72 Kausalitäts-Anker**, **Dedup-Ratio 99,1 %**;
  **Alerts max. 10/Tag**, **Story max. 7/Tag**.
- G1a-Bench @50x: **p95 5,107 ms**, **225,0 FPS**, 666 Draw Calls Ø,
  max. 10,429 ms.
- Save Schema 4: **16.835 Bytes**, Save **1,25 ms**, Load **7,66 ms**
  (Seed 1337, Tag 1 12:05).
- Sichtbare Screenshots: `bench/results/g1b_chronicle_ui.png`,
  `g1b_family_tree.png`, `g1b_year_birth.png`, `g1b_year_death.png`.
