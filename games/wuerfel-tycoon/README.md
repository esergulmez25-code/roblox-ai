# Würfel-Tycoon

Ein kleines Roblox-Tycoon-Spiel in einem einzigen Server-Script: [WuerfelTycoon.server.luau](WuerfelTycoon.server.luau).

Eine Maschine (Dropper) spuckt ständig kleine Würfel auf ein Förderband. Das Band bringt sie zum Ende, dort fallen sie in einen Geld-Kasten und werden zu Geld. Mit dem Geld kaufst du Upgrades.

## Einbau in Roblox Studio

1. Roblox Studio öffnen und ein neues Projekt mit der Vorlage **Baseplate** anlegen.
2. Im Explorer mit der rechten Maustaste auf **ServerScriptService** klicken, dann **Insert Object → Script**.
3. Den kompletten Inhalt von `WuerfelTycoon.server.luau` in das Script kopieren.
4. Auf **Play** drücken.
5. Zu einem der 4 Tycoons laufen (links und rechts vom Spawn) und auf das grüne Feld **Tycoon frei!** treten.

Das Script baut alles selbst: Boden, Dropper, Förderband, Geld-Kasten, Kauf-Buttons und die Geld-Anzeige oben rechts in der Rangliste.

## Upgrades

| Button | Startpreis | Stufen | Wirkung |
| :--- | ---: | ---: | :--- |
| Dropper 2 | $25 | 1 | Zweite Maschine |
| Dropper 3 | $150 | 1 | Dritte Maschine (nach Dropper 2) |
| Schneller droppen | $40 | 5 | Würfel kommen 25 % schneller pro Stufe |
| Wertvollere Würfel | $75 | 5 | Würfelwert verdoppelt sich pro Stufe ($1 bis $32), neue Farbe |
| Förderband schneller | $60 | 3 | Band läuft schneller |

Grüne Buttons kannst du dir leisten, rote noch nicht. Der Preis steigt mit jeder Stufe.

## Anpassen

Oben im Script stehen `CONFIG`, `UPGRADES` und `WUERFEL_FARBEN`. Dort kannst du Startgeld, Tempo, Preise und Farben ändern, ohne den Rest anzufassen.

Wenn ein Spieler das Spiel verlässt, wird sein Tycoon zurückgesetzt und ist wieder frei. Geld wird noch nicht gespeichert; dafür bräuchte man einen DataStore.
