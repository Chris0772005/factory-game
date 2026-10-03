# MOLTEN MATES – Game Design Document

> **Zeichne es. Gieß es. Zerschlag die Form.**
> Koop-Gieß-Partyspiel mit Aufstieg für 1–4 Spieler. Steam, Godot 4.7, Preis 7,99–9,99 € (Entscheidung vor Store-Page).

Stand: 03.10.2026. Grundlage: Recherche in `docs/research/` (zwei Ideenrunden, adversarial geprüft).

---

## 1. Kern-Versprechen (was jeder Clip zeigen muss)

1. **Deine schiefe Zeichnung wird zu glänzendem Metall.** Zeichnen → in Sand drücken → glühendes Metall gießen → Form zerschlagen → Enthüllung.
2. **Der Bronzefreund.** Wer in die Gießgrube fällt, wird in seiner Sturzpose zur Statue – und die verkauft ihr.
3. **Koop-Ritual mit Geschrei.** Tiegel zu zweit tragen, kippen, „STOPP!“ rufen, wenn der Steiger voll ist.

Positionierung: **Koop-Partyspiel mit Aufstieg**, kein reines Fabrikspiel. Vergleichs-Benchmarks: How to Fish, PEAK (Freundesabend), nicht Factorio.
Abgrenzung zu Roblox „The Forge“: Wir zeigen nur, was es dort nicht gibt – eigene Zeichnungen, Bronzefreund, Koop-Gieß-Chaos.

## 2. Loops

**Mikro-Loop (60–90 s, nichts passiv):**
1. Zeichnen (jeder Spieler an seiner Modellbank, gleichzeitig, 15–30 s)
2. Modell in den Formkasten drücken, **stampfen** (3-s-Rhythmus-Eingabe → Formqualität)
3. Schrott in den Ofen, **Blasebalg** treten (aktive Hitze) → Schmelze
4. Tiegel heben (zu zweit oder mit Schubkarre/Hebel solo), zum Formkasten tragen
5. **Gießen**: Kipp-Tempo bestimmt Fehler (zu langsam = Kaltlauf, zu schnell = Spritzer/Poren). Steiger voll → „STOPP!“
6. Kurz abkühlen (optional **abschrecken** im Wasser: schneller, aber Dampf + Rissrisiko)
7. **Form zerschlagen** mit dem Hammer → Enthüllung aller Kavitäten nacheinander, Note pro Teil
8. Verkaufen (in die Verkaufskiste werfen) oder in der Galerie ausstellen

**Booster-Effekt ohne Glücksspiel:** Ein Gießbaum hat 1–8 Kavitäten (pro Spieler eine + Upgrades). Ein Guss = mehrere Enthüllungen.
Überraschung kommt aus **Optik**, nicht aus Zufalls-Noten: versiegelte Schrottkisten mit unbekannter Mischung → Legierung zeigt sich erst beim Guss (Messing, Bronze, Rotgold, Grünspan). Seltene Einschlüsse (Omas Ehering → Goldanteil).
Die **Note** hängt transparent am Können (Stampfen, Gieß-Tempo, Temperatur). „Spiegelguss“ nur bei perfektem Guss.

**Makro-Loop:** Geld → Upgrades (ca. 20 Knoten, jeder sichtbar) → neue Halle alle 40–60 min.

## 3. Progression (MVP: 4 Bereiche, 4–5 h)

| Bereich | Zeit | Neues Verb / System | Produkte |
|---|---|---|---|
| **Hinterhof** | 0:00–0:40 | Zeichnen (Relief), Eimerofen, Blasebalg, Sandkasten, Gießen, Zerschlagen | Alu-Plaketten, Schilder, Gartenzwerge (Relief) |
| **Garage** | 0:40–1:40 | Gießbaum mit Mehrfach-Kavitäten, Schrottkisten & Legierungen, Abschrecken, erster Bronzefreund-Auftrag | Türklopfer, Pokale, Statuetten |
| **Glockengießerei** | 1:40–3:00 | Drehprofil-Modus (Glocken, Vasen, Pokale), Glockenton (Tonhöhe aus Profil), Kran-light (Flaschenzug) | Glocken, Vasen |
| **Eisenhalle** | 3:00–4:30 | Hallenkran, Gießpfanne für 2–4 Spieler, Formband-Automatik (Serienaufträge = passives Einkommen), Finale | Kanaldeckel-Serien, **Kaiserglocke (Finale)** |

Post-Launch-Updates: Stahlwerk, Figur-Modus (2 Silhouetten), Denkmal, Tagesaufträge, NG+.

Die Fabrik-Ebene (Wunsch: „klein anfangen, hochupgraden“) bleibt, aber als **Helfer-Module in festen Slots**:
Auto-Stampfer, Auto-Gießer, Ausleerrost, Verkaufsband, Formband. Genehmigte Designs laufen in Serie und finanzieren die Kunstgüsse.

## 4. Koop & Solo

- 1–4 Spieler, Host-autoritativ (Steam P2P via GodotSteam; Entwicklung über ENet).
- Jeder hat jederzeit ein Verb: parallele Modellbänke, Blasebalg, Stampfen, Tragen, Hämmern.
- **Solo vollwertig:** Schubkarre statt Stange, Gießhilfe als Hebel, „Lehrling“-Automat.
- Spielstand gehört dem Host; Gäste behalten Galerie, Kosmetik, Bronzefreunde im eigenen Profil.
- Zeichnungen/Posen werden als Daten synchronisiert, nie als Meshes.

## 5. Clip-Momente (Design-Pflicht)

- Enthüllung: Hammer → Sand fliegt → glühende Figur → kühlt zu Metallglanz ab → Note poppt auf.
- Bronzefreund in Sturzpose.
- „Ich wollte ein Pferd zeichnen“ – lustige Ergebnisse.
- Dampfexplosion beim Abschrecken, Funkenregen beim Gießen.
- Schief klingende Glocke.
- Scale-Reveal per Taste: vom Eimerofen bis zur Eisenhalle.

## 6. Streamer & Sicherheit

- Streamer-Modus: fremde Zeichnungen ausblenden, DMCA-freie Musik.
- Design-Codes als kurzer Text (keine Bild-Uploads, keine öffentliche Galerie im MVP).
- Kein Gore: Statue statt Leiche, Respawn sofort.

## 7. Look

Stilisiertes Low-Poly, Konturen, warme Gießerei-Palette. Budget auf Effekte mit großer Wirkung:
HDR-emissives Metall mit Schwarzkörper-Rampe, Glow, GPU-Funken, Dampf, Hitzeflimmern (nur Hoch).
Steam-Deck-Preset ab Woche 1: kein SDFGI/SSR, FSR.

## 8. Technik-Entscheidungen

- Zeichnung: Pinselstriche → `Geometry2D.offset_polyline` + `merge_polygons` → Extrusion (CSG-Union/Subtraktion, gebacken) → Kollision über konvexe Zerlegung.
- Gießen: kein Fluid; Füllstand als Schnittebene im Shader + Fehlerkarte.
- Zerschlagen: vorab zerteilte Sandblock-Stücke + Partikel.
- Lose Physikobjekte ≤ 64, Bänder als Daten (MultiMesh), siehe `game/scripts/factory/`.
- Godot-Version fest auf 4.7.x.

## 9. Validierung (harte Kriterien)

- Woche 2: Prototyp Hinterhof (zeichnen → gießen → zerschlagen) spielbar, 5–10 Testclips auf TikTok/Shorts.
- Steam-Seite früh online. **Abbruch/Umbau**, wenn nach 6 Wochen < 5.000 Wishlists oder Testgruppen die Enthüllung nicht laut kommentieren.
- Steam Next Fest mit Demo (Hinterhof + Garage).

## 10. Offene Entscheidungen

- Preis (7,99 vs. 9,99 €) – per Umfrage/Ad-Test.
- Name final prüfen (Marke/Store-Suche) vor Ankündigung.
