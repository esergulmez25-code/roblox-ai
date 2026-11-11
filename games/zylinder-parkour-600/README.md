# Zylinder-Parkour · 600 Level

Ein schweres Roblox-Obby mit **600 Leveln in 12 Welten**. Jede Welt ist ein
**eigener Zylinder** mit eigenen Wänden; die Strecke läuft als Spirale an der
Innenwand nach oben. Oben in jeder Welt steht ein **Portal**, das dich in die
nächste Welt bringt. Der ganze Parkour wird beim Start von **einem einzigen
Script** gebaut.

## Einbauen (2 Minuten)

1. Roblox Studio öffnen, neue leere Baseplate.
2. In **ServerScriptService** ein neues **Script** anlegen.
3. Den Inhalt von `ZylinderParkour.server.lua` hineinkopieren.
4. Auf **Spielen** drücken. Die Baseplate kann gelöscht werden.

Mit Rojo geht es auch: `rojo serve` in diesem Ordner.

## Was drin ist

- **12 Welten** à 50 Level, jede in ihrem eigenen Zylinder mit eigener Wand:

  | Welt | Wand |
  |---|---|
  | Grasland | grüne Hecke, Ziegel-Säule |
  | Wüste | Sandstein |
  | Ozean | Kiesel in Türkis/Sand |
  | Vulkan | Basalt, Säule aus Lava-Gestein |
  | Eiswelt | Eis |
  | Dschungel | Holz |
  | Süßigkeiten | Zuckerstange (rot/weiß gestreift) |
  | Neon-Stadt | dunkles Metall mit Neon-Streifen |
  | Weltall | dunkler Schiefer |
  | Giftsumpf | Schlamm |
  | Goldtempel | Marmor mit Gold-Streifen |
  | Regenbogen | Regenbogen-Wand, Neon-Säule |

- **Portal**: Wer das letzte Level einer Welt schafft, läuft oben durchs Portal
  und landet unten in der nächsten Welt. In Welt 12 wartet oben das 🏆 Ziel.
- **Schwer von Anfang an**: Schon Level 1 hat kleinere Plattformen und größere
  Lücken. Bis Level 600 schrumpfen die Plattformen auf 3 Studs, die Lücken
  wachsen auf über 6 Studs, und es gibt bis zu 8 Sprünge pro Level.
- **8 Hindernis-Arten**, die schnell freigeschaltet werden:

  | Ab Level | Hindernis | |
  |---:|---|---|
  | 1 | Sprung | normale Plattformen |
  | 3 | Lava | Weg mit tödlichem Lava-Streifen |
  | 8 | Verschwinden | Plattform löst sich auf, wenn man draufsteht |
  | 14 | Mini | kleine runde Pads |
  | 20 | Bewegt | Plattformen fahren nach innen/außen |
  | 30 | Förderband | schiebt dich zurück |
  | 40 | Spinner | drehender Lava-Balken (später ein Kreuz aus zwei Balken) |
  | 100 | Mix | alle Arten in einem Level gemischt |

  Das letzte Level jeder Welt ist ein **Endgegner-Level** (Mix).
- **Checkpoints** mit Levelnummer; nur der nächste zählt (kein Überspringen).
- Wer runterfällt, wird sofort zum letzten Checkpoint zurückgesetzt.
- **Bestenliste** (Level, Siege), Fortschrittsbalken oben im Bild.
- **Speichern** per DataStore (dafür in den Spieleinstellungen
  „Studio-Zugriff auf API-Dienste aktivieren“ einschalten).

## Chat-Befehle

- `/neustart` – zurück in die Lobby (Level 0)
- `/level 250` – zu Level 250 springen (nur in Studio oder für den Spielbesitzer, zum Testen)

## Anpassen

Oben im Script im Block `CONFIG`: Anzahl Level, Startschwierigkeit (`START_DIFF`), größte Lücke (`MAX_GAP`), Radius, Seed
(anderer Seed = andere Strecke) usw. Welten, Farben und Wand-Materialien stehen in `WORLDS`.
