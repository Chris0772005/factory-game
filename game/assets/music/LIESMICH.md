# Musik

Dateien hier werden vom Spiel automatisch abgespielt (`scripts/core/music.gd`), als `.ogg` oder `.mp3`:

| Datei | spielt in |
|---|---|
| `menu` | Hauptmenü |
| `backyard` | Hinterhof |
| `garage` | Garage |
| `bell_foundry` | Glockengießerei |
| `iron_hall` | Eisenhalle |
| `theme` | überall, wo keine eigene Datei liegt |

Eine einzige Datei `theme.ogg` reicht für den Anfang. Die Stücke laufen in Schleife und blenden beim Hallenwechsel weich über.

Die aktuellen fünf Stücke erzeugt `tools/music_gen.py` (von einer KI komponiert, bei Steam als KI-Inhalt anzugeben). Wer sie ersetzt: Datei gleichen Namens hier ablegen und in `CREDITS.md` Titel, Urheber, Lizenz und Quelle eintragen.
