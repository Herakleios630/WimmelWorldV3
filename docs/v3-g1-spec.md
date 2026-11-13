# V3 G1a/G1b — Spezifikation

Status: G0-Artefakt, Entwurf  
Stand: 2026-11-13  
Bezug: `v3-plan.md`, D-28, D-29, D-59.

## 1. Ziel

G1 beweist den Kern-Loop, die Chronik und die technische Disziplin mit
**10 Agenten**. G1 ist ausdrücklich **kein Skalierungsnachweis**. Skalierung
beginnt mit G2.

G1 besteht aus zwei formalen Gates:

- **G1a:** Kern-Loop mit Hunger/Energie/Sozial, Wohnen, Arbeit, Nahrung,
  Tag/Nacht, Inspector, Event-Log, Save/Load.
- **G1b:** Hygiene/Spaß/Gesundheit, Soziales/Lebenszyklus, Familienbaum,
  Follow, Alerts, Story of the Day, kuratierte Chronik.

G1 ist erst bestanden, wenn **G1a und G1b** bestanden sind.

## 2. Nicht-Ziele

- Keine 100+ Agenten, keine Skalierungsbehauptung.
- Keine Wirtschaft, Politik, Steuern, Karawanen.
- Keine Kriege, Tiere, Fantasy-Fraktionen.
- Keine D-57-Systeme (Wetter/Feste/Religion/Recht/Bildung) außer Tageslicht
  und Jahreszeit.
- Kein Rewind, keine Spielereingriffe.

## 3. Welt

- Lokale Karte: **128 × 128 Tiles** bei 1,5 m/Tile = **192 × 192 m**.
- 3 Wohnhäuser, 1 Feld, 1 Kornspeicher, 1 Brunnen, 1 Scheune/Werkstatt,
  Wege zwischen allen Gebäuden.
- Alle Wohnhäuser und Arbeitsplätze sind über Wege erreichbar.
- Keine Mauern, Tore, Fraktionen, Tempel oder Märkte.
- Tag/Nacht und vier Jahreszeiten sind sichtbar; Wetter bleibt in G1 aus.

### 3.1 Zeit und Optik

- 30-Tage-Jahr, 15 reale Minuten/Tag bei 1x, 1x/10x/50x.
- Clock-Einheit: 1 Sim-Sekunde; Events liegen auf logischen Terminen.
- 1 Sim-Minute ist das **Entscheidungsquantum/Planungshorizont**, kein
  Pflicht-Polling pro Minute/Sekunde.
- 1,5 m/Tile, 16 px/Tile, ~19–20 px Figuren, 3/4-Topdown.

## 4. Agenten

Genau **10 Agenten**, drei Haushalte:

| Haushalt | Agent | Alter | Rolle |
|---|---|---:|---|
| H1 | A1 | 38 | Landwirt, Haushaltsvorstand |
| H1 | A2 | 35 | Landwirtin, Partnerin von A1 |
| H1 | C1 | 12 | Kind von A1/A2 |
| H1 | C2 | 6 | Kind von A1/A2 |
| H2 | A3 | 30 | Landwirt, Haushaltsvorstand |
| H2 | A4 | 28 | Köchin/Hausfrau, Partnerin von A3 |
| H2 | C3 | 3 | Kind von A3/A4 |
| H3 | A5 | 70 | Altbauer, Witwer, Vater von A6 |
| H3 | A6 | 42 | Landwirt, Sohn von A5, Vater von A7 |
| H3 | A7 | 17 | Lehrling, Kind von A6, Enkel von A5 |

**Startbeziehungen:** A1–A2 Partner, C1/C2 Kinder; A3–A4 Partner, C3 Kind;
A5–A6 Vater/Sohn, A6–A7 Vater/Kind, A5–A7 Großvater/Enkel; erste Freundschaft
zwischen C1 und C3. A5 ist Witwer; H3 hat bewusst keine Partnerin.

## 5. Needs

Startwerte und Raten sind **Kalibrierungsparameter**; die folgenden Werte sind
Startpunkte für G1a/G1b, keine endgültige Balance.

| Need | Bereich | Start | Veränderung | Schwelle | Erfüllung |
|---|---:|---:|---|---:|---|
| Hunger | 0–100 | 80 | +100/Tag | 60 | Mahlzeit: −50 |
| Energie | 0–100 | 80 | −100/16 h wach | 20 | Schlaf: +80/8 h |
| Sozial | 0–100 | 70 | −50/Tag | 40 | Sozialisieren: +30 |
| Hygiene | 0–100 | 80 | −60/Tag | 50 | Waschen: +50 |
| Spaß | 0–100 | 70 | −40/Tag | 40 | Freizeit: +30 |
| Gesundheit | 0–100 | 100 | langsam | 30 | Erholung, gute Needs |

**Gesundheit** ist ein langsamer Zustand: Sie sinkt, wenn Hunger, Energie oder
Hygiene längere Zeit unter der Schwelle liegen, und altersbedingt. In G1 gibt
es keine Krankheiten und keine Gewalt.

## 6. Tagesablauf

- 06:00 Aufwachen, 07:00 Frühstück.
- 08:00–12:00 Feldarbeit.
- 12:00 Mittagessen.
- 13:00–17:00 Feldarbeit.
- 17:00–21:00 Sozialisieren/Freizeit/Hygiene.
- 21:00–06:00 Schlafen.

Needs unterbrechen die Routine. Nach kurzer Erfüllung kehrt der Agent zur
Routine zurück. Kein Dauer-Polling: Jeder Agent hat einen nächsten logischen
Termin.

**Rollen-Schedules:**

- **Kinder (0–12):** spielen, lernen, essen, schlafen; keine Feldarbeit.
- **Jugend (13–17):** leichte Arbeit/Lehre, Lernen, Haushalt.
- **Erwachsene (18–59):** Feldarbeit, Haushalt, Arbeit.
- **Alte (60+):** leichte Aufgaben, Ruhe, Soziales.

Der obige Tagesablauf gilt für Erwachsene; Kinder, Jugend und Alte weichen
altersgerecht ab.

## 7. Arbeit und Nahrung

**G1a — einfacher Nahrungsspeicher:**

- Startgrain im Speicher.
- Tägliche Arbeit erzeugt eine feste kleine Grain-Menge; kein voller
  Crop-Zyklus.
- Mahlzeiten verbrauchen Grain.
- Knappheit erhöht Hunger und senkt Gesundheit; keine stille Auffüllung.
- Bewegung: Waypoint/gerade Linie; keine A*-/Pfad-Cache-Abhängigkeit.

**G1b — voller Feldzyklus:**

- `FALLOW → PLOWING → PLOWED → SOWING → SOWN → GROWING → RIPE → HARVESTING → FALLOW`.
- Arbeit ist Fortschritt, kein Instant-Zustandswechsel.
- Ernte geht in den Kornspeicher; Mahlzeiten verbrauchen Grain.
- Jahresbilanz, Aussaat/Ernte, Knappheit und Kalibrierung.
- Lokaler A* und Pfad-Cache bleiben G2.

## 8. Lebenszyklus (G1b)

- Stufen: Kind (0–12), Jugend (13–17), Erwachsen (18–59), Alt (60+).
- Alterssterblichkeit mit Variation; Startwerte provisorisch:

| Alter | Todeswahrscheinlichkeit/Jahr |
|---|---:|
| 0–4 | 3 % |
| 5–14 | 0,5 % |
| 15–29 | 1 % |
| 30–49 | 2 % |
| 50–64 | 4 % |
| 65–79 | 8 % |
| 80+ | 15 % |

- **Zielverteilung (Kalibrierung, keine Einzelprognose):** Medianes Sterbealter
  ~48–52; 25–35 % sterben vor 40; 15–25 % erreichen 70; 5–10 % erreichen 80.
- Die Tabelle ist ein Startpunkt und wird in G1b gegen die Zielverteilung
  kalibriert; Änderungen sind versionierte Balance-Entscheidungen.
- G1b nutzt eine **separate synthetische Demografie-Kohorte** (1.000 Agenten,
  100 Sim-Jahre, 5 Seeds) für Sterbe-/Fertilitätskalibrierung. Der
  10-Agenten-Weiler bleibt der visuelle Slice (1 Sim-Jahr, Featured Seed). Ein
  einzelnes Sim-Jahr garantiert keine Geburt/Tod-Ereignisse.
- Partnerschaft, Geburt und Tod sind deterministisch und speicherbar.
- Keine Krankheiten/Gewalt in G1; Tode nur Alter und schwere
  Gesundheitsfolgen.
- Keine stille Bevölkerungsauffüllung.
- Haushaltsauflösung: Stirbt der letzte Erwachsene, werden minderjährige
  Mitglieder einem verwandten Haushalt zugeordnet; ohne Verwandten löst sich
  der Haushalt auf und wird als historischer Record archiviert.
- Fertilität: nur Partner im fruchtbaren Alter; deterministische
  Monatswahrscheinlichkeit; Schwangerschaftsdauer und Geburtsrisiko sind
  kalibrierbare Regeln, keine stillen Zufälle.

## 9. UI

**G1a:** Zeit/Speed, Inspector, Event-Log, Tag/Nacht, Auswahl/Fokus.

**G1b:** Familienbaum, Follow-Modus, Alerts, Story of the Day, Chronik-Panel.

Darstellung: 3/4-Topdown, 1,5 m/Tile, 16 px/Tile, ~19–20 px Figuren,
warme mittelalterliche Palette. Kamera/Zoom/Sichtbarkeit ändern keinen
Simulationszustand.

## 10. Persistenz und Replay

- Versioniertes Binär-Save: Agents, Needs, Beziehungen, Welt, Scheduler, RNG,
  Konfiguration und **Chronik-/Debug-Log getrennt**.
- **G1a:** Save/Load vor/nach Entscheidung und Arbeit ergibt exakt denselben
  weiteren Verlauf.
- **G1b:** Replay ist **Re-Simulation aus Seed + Konfiguration + Save-Snapshot**,
  nicht das Abspielen des Chronik-Logs. Keine Spielereingriffe.
- **Chronik-Log:** kuratiert/aggregiert, Retention-Politik ab G2.
- **Debug-Log:** optional vollständig, nur für kurze Testläufe; nicht
  autoritativ für Replay.
- Event-Log in G1 (10 Agenten) vollständig; ab G2 nur notable+ und Summaries.

## 11. Abnahme G1a

- Ein voller Sim-Tag bei 1x ist beobachtbar und verständlich.
- Gleicher Seed + gleiche Eingaben → identische Snapshots/Events (3 Läufe).
- Save/Load vor/nach Entscheidung und Arbeit ist exakt.
- Kamera/Zoom/Sichtbarkeit verändern keinen Zustand.
- Headless-Tests und Main-Smoke grün.
- 10 Agenten bei 50x stabil 60 FPS; Ereignis-/Tick-Kosten dokumentiert.
- Kein Replay, kein voller Feldzyklus, keine A*-/Pfad-Cache-Abhängigkeit;
  Waypoint-Bewegung und einfacher Nahrungsspeicher.
- Event-Log zeigt die Kernereignisse; keine kuratierte Chronik.
- Keine Datei über ~1.000 Zeilen; klare Modulgrenzen.

## 12. Abnahme G1b

- **Headless-Demografie:** 1.000-Agenten-Kohorte, 100 Sim-Jahre, 5 Seeds;
  mindestens 500 Geburten und 500 Tode insgesamt; Median-Sterbealter 48–52;
  Zielverteilung eingehalten.
- **Visuell:** 1 Sim-Jahr bei 50x (9 min) plus optionaler 5-Jahres-Zeitraffer;
  mindestens eine Geburt und ein Tod im sichtbaren Lauf (Featured Seed).
- **Chronik:** ≤ 20 Alerts/Tag, ≤ 7 Story-of-the-Day-Einträge/Tag,
  Dedup-Ratio > 80 %, mindestens 3 notable Ereignisse/Tag, keine Routine-Flut.
- Familienbaum, Follow, Alerts und Story of the Day funktionieren.
- **UI-DoD:** Inspector öffnet < 100 ms; Familienbaum mindestens 3
  Generationen; Follow 60 s stabil; keine fehlenden Pflichtfelder.
- **Render-DoD:** Nah/fern/Pan p95 ≤ 16 ms; kein Hänger > 250 ms; Draw Calls
  und GPU-ms dokumentiert.
- Voller Feldzyklus und Jahresbilanz funktionieren.
- Replay (Re-Simulation aus Seed + Konfiguration + Save-Snapshot) ergibt
  denselben Verlauf.
- Save/Load vor/nach Geburt, Tod und Beziehungswechsel ist exakt.
- Haushaltsauflösung, Fertilität und Gesundheitsregeln sind getestet.
- Determinismus und Kameraunabhängigkeit bleiben grün.
- Sechs Needs sind aktiv und getestet.
- G1a bleibt grün.

## 13. Tests

- Kernel-/Scheduler-/RNG-Determinismus.
- SoA-Store und ID-Lebenszyklus.
- Need-Schwellen und Unterbrechungen.
- Bewegung und Ankunft ohne Frame-Abhängigkeit.
- Feld-/Nahrungsbilanz.
- Lebenszyklus und Mortalität.
- Save/Load/Restore/Replay.
- Kamera-/Zoom-/Sichtbarkeitsvergleich.
- Chronik-Taxonomie und Importance.
- Visueller Smoke und Benchmark.

## 14. Offene Kalibrierung

Need-Raten, Arbeitsdauern, Ernteertrag, Mortalität, Geburtenrate,
Bewegungsgeschwindigkeit und Tageslänge werden in G1a/G1b kalibriert. Änderungen
sind versionierte Balance-Entscheidungen, keine stillen Anpassungen.
