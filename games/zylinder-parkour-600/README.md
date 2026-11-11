# Zylinder-Parkour · 600 Level

Ein Roblox-Obby mit **600 Leveln** in einem riesigen Glas-Zylinder. Die Strecke
läuft als Spirale an der Innenwand nach oben (ca. 130 Runden, rund 3.300 Studs hoch).
Der ganze Parkour wird beim Start von **einem einzigen Script** gebaut.

## Einbauen (2 Minuten)

1. Roblox Studio öffnen, neue leere Baseplate.
2. In **ServerScriptService** ein neues **Script** anlegen.
3. Den Inhalt von `ZylinderParkour.server.lua` hineinkopieren.
4. Auf **Play** drücken. Die Baseplate kann gelöscht werden.

Mit Rojo geht es auch: `rojo serve` in diesem Ordner.

## Was drin ist

- **12 Welten** à 50 Level: Grasland, Wüste, Ozean, Vulkan, Eiswelt, Dschungel,
  Süßigkeiten, Neon-Stadt, Weltall, Giftsumpf, Goldtempel, Regenbogen.
  Die Mittelsäule hat pro Welt eine eigene Farbe.
- **7 Hindernis-Arten**, die nach und nach freigeschaltet werden:

  | Ab Level | Hindernis | |
  |---:|---|---|
  | 1 | Sprung | normale Plattformen |
  | 8 | Lava | Weg mit tödlichem Lava-Streifen |
  | 20 | Verschwinden | Plattform löst sich auf, wenn man draufsteht |
  | 35 | Mini | kleine runde Pads |
  | 50 | Bewegt | Plattformen fahren nach innen/außen |
  | 80 | Förderband | schiebt dich zurück |
  | 120 | Spinner | drehender Lava-Balken zum Drüberspringen |

- **Schwierigkeit steigt**: Plattformen werden kleiner (6 → 3,5 Studs), Lücken
  größer (2 → 6 Studs), mehr Sprünge pro Level. Jedes 50. Level ist eine Pause.
- **Checkpoints** mit Levelnummer; nur der nächste zählt (kein Überspringen).
- Wer runterfällt, wird sofort zum letzten Checkpoint zurückgesetzt.
- **Bestenliste** (Level, Siege), Fortschrittsbalken oben im Bild.
- **Speichern** per DataStore (dafür in den Spiel-Einstellungen
  „Studio-Zugriff auf API-Dienste“ aktivieren).

## Chat-Befehle

- `/neustart` – zurück in die Lobby (Level 0)
- `/level 250` – zu Level 250 springen (nur in Studio oder für den Spielbesitzer, zum Testen)

## Anpassen

Oben im Script im Block `CONFIG`: Anzahl Level, Radius, Steigung, Seed
(anderer Seed = andere Strecke) usw. Welten und Farben stehen in `WORLDS`.
