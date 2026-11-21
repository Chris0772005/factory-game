# Steam: was du selbst tun musst

Das Konto kann nur der Inhaber anlegen, weil Steam Ausweis, Bank- und Steuerdaten prüft.

## Schritte

1. **Anmelden:** <https://partner.steamgames.com> öffnen und mit deinem normalen Steam-Konto einloggen. „Steamworks beitreten“ wählen.
2. **Angaben machen:** Name oder Firma, Adresse, Bankverbindung, Steuerformular. Die Namen müssen genau zu Ausweis und Konto passen.
3. **Gebühr zahlen:** 100 US-Dollar pro Spiel (dazu je nach Land Mehrwertsteuer). Sie wird verrechnet, sobald das Spiel 1.000 Dollar eingenommen hat. Steam-Guthaben geht dafür nicht.
4. **Warten:** Steam prüft die Angaben. Zwischen Zahlung und Veröffentlichung liegt außerdem eine Wartezeit (je nach Quelle 21 oder 30 Tage). Maßgeblich ist, was dein Konto anzeigt.
5. **Spiel anlegen:** In Steamworks „Neue App erstellen“, Name „Molten Mates“. Du bekommst eine **App-ID** (eine Zahl).
6. **App-ID schicken:** Diese Zahl gibst du mir. Sie ist nicht geheim.

## Was ich danach mache

- App-ID ins Spiel eintragen und die Steam-Erweiterung in den Build einbauen.
- Koop auf Steam-Einladungen umstellen (statt IP-Adresse).
- Dir die Liste der sieben Erfolge zum Anlegen geben (Kennungen stehen in `game/scripts/core/steam_service.gd`).
- Den automatischen Upload der Builds vorbereiten.

## Was du nie in den Chat schreibst

Steam-Passwort, Steam-Guard-Codes, Bankdaten. Für den Upload richten wir einen eigenen Build-Zugang ein, dessen Schlüssel du direkt bei GitHub hinterlegst.

## Später im Fragebogen zu Inhalten

Im Abschnitt „KI-generierte Inhalte“ gibst du an, was im Spiel von einer KI stammt und von Spielern gesehen oder gehört wird (vorab erzeugt, nicht während des Spielens):

- Die Musik ist von einer KI komponiert.
- Die Stadtbewohner (Passanten, Kunden am Verkaufstisch, Pfandleiher, Schrotthändler, Wirtin, Inhaber des Werkzeugladens, Bankangestellte, Polizei) und die Arbeiter der Spieler (so sehen die Mitspieler einen) sind KI-erzeugte 3D-Figuren (Higgsfield: GPT Image 2.6 und Meshy 7). Sie zeigen keine echten Personen.

Steam zeigt diese Angabe auf der Shopseite an. Kommt später weiteres KI-Material dazu, steht es in `CREDITS.md` und muss hier ergänzt werden.
