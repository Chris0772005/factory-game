# MOLTEN MATES – Hinterhof-Umgebung (Set, Licht, Performance)

Stand: 05.10.2026 · Godot 4.7.2 · Umsetzung von `docs/ART_BIBLE.md` Abschnitte 4, 6, 7, 10 für Level 1.
Code: `game/scripts/environment/`, Shader: `game/shaders/env_*.gdshader` (+ `env_common.gdshaderinc`).

## 1. Aufbau

`backyard.gd` baut wie bisher Stationen und Entities. Danach ruft es `YardSet.build(self, stations)` auf; das Licht
kommt aus `_build_environment()` → `YardLighting.build()` (auch vom Asset-Kontaktbogen genutzt).

| Datei | Inhalt |
|---|---|
| `yard_layout.gd` | Grundriss: Zaunlinien, Haus, Schuppen, Arbeitsfläche. Liest die **echten Stationspositionen** → Sperrzonen (Laufwege), Abnutzung, Ruß am Ofen, Formsand an den Formkästen. Malt zwei Masken (4 px/m): **Zonen** (R Erde, G Kies, B Ruß, A Sand) und **Details** (R festgetretene Laufwege von jeder Station und vom Spawn zum nächsten Formkasten, vom Ofen zu jedem Formkasten, Trittring um jede Station; G feucht; B Pfütze – am Regenfass-Überlauf und am Abschreckeimer). |
| `yard_ground.gd` + `env_ground` | Ein Boden-Mesh (100 × 92 m, 0,6-m-Raster): flach wo gearbeitet wird, 0–8 cm Rasenwellen (nie unter y = 0), sanfte Hügel hinter dem Zaun. Shader: Rasen, Erde mit Krümeln, Staubkörnern und Kieseln, dunklere/glattere Laufwege, Kies, Sand, Ruß, feuchte Flecken, spiegelnde Pfützen (Himmelsreflex). Kollision: flache Box, Oberkante y = 0. |
| `grass_field.gd` + `env_grass` | Grasbüschel als MultiMesh in 8 × 8-m-Kacheln (Rasen, Wildgras am Zaun, Blühbüschel). Farbe = Rasenfarbe des Bodens darunter. Wind + Wegdrücken durch bis zu 4 Arbeiter. Kein Gras auf Laufwegen und in Pfützen. |
| `ground_scatter.gd` | Kiesel-MultiMesh an Weg- und Erdkanten, im Kiesstreifen. **Arbeitsspuren** (je ein MultiMesh, ohne Kollision, ≤ 3 cm hoch): Holzkohle- und Ziegelbrösel um den Ofen, Formsandklumpen und kalte Metalltropfen um die Formkästen, Hobelspäne unter der Werkbank, ein paar Splitter an Verkaufskiste und Brett. Folgt den Stationspositionen. |
| `plank_fence.gd` | Sichtschutz-Bretterzaun (1,55 m) links/rechts/hinten, niedriger gestrichener Lattenzaun vorn (Kamera schaut darüber), geschlossenes Tor rechts. Bretter als MultiMesh, Pfosten/Riegel zusammengeführt. Eine Box-Kollision pro Zaunlinie. |
| `yard_house.gd` | Wohnhaus (Putz mit abgeplatzten Stellen, Satteldach mit Ziegelreihen und Giebeln, Regenrinne + Fallrohr ins Regenfass, Schornstein, Eckquader, Fensterrahmen/Läden/Blumenkästen, Hintertür mit Stufen, Vordach und Wandlampe). Gleicher Baukasten in einfacher Form für 4 Nachbarhäuser. |
| `garden_shed.gd` | Bretterschuppen mit Wellblech-Pultdach, Fenster, offener Tür, Regalen und warmer Glühbirne innen. |
| `string_lights.gd` + `env_lights`/`env_bulb` | Lichterketten an 3 Masten und 2 Wandhaken: Kettenlinien-Kabel, Birnen als MultiMesh, Schwingen komplett im Shader. |
| `stylized_tree.gd` + `env_foliage` | Laubbaum (Reifenschaukel), Nadelbäume, Büsche, Hecken: klumpige Kugeln, Blattbüschel-Muster, Wind. |
| `prop_kit.gd` + `env_atlas` | KayKit-Props mit Pack-Maßstab, gemeinsamem Atlas-Material (Welt-Rauschen, Schmutz unten, raue Oberfläche, optional entsättigt/getönt) und Kollision aus den Modellgrenzen. |
| `yard_props.gd` | Prozedural: Amboss auf Hackklotz, Reifenstapel, rostige Bleche, Terrakottatöpfe, Hochbeet, Schamottstapel, Werkzeuge, Wäscheleine (flatternde Wäsche), Reifenschaukel. |
| `yard_dressing.gd` | Handplatzierung aller Props + Hintergrund: Nachbarhäuser, Bäume, Hecken, Strommast, Sträucher in den Nachbargärten, lockerer Baumring (29–38 m) und ein **geschlossenes Waldband** (40–44 m, ein Mesh), das das Bodenende aus jeder Spiel- und Menü-Kamerahöhe verdeckt. Warnt (`push_warning`), wenn ein festes Prop in die Sperrzone einer Station ragt. |
| `yard_ambience.gd` | Schornsteinrauch, Glühwürmchen (GPU-Partikel). |
| `yard_lighting.gd` + `env_sky` | Dämmerung: Sky-Shader (Verlauf, Abendrot, Erdschatten + „Venusgürtel“, Mond, Sterne, Wolken), AgX white 6 / contrast 1.3, Glow nur über HDR 1.2 (bloom 0), SSAO, SSIL (High), Tiefennebel mit Luftperspektive 0,65 (Fernes läuft in die Himmelsfarbe aus), Volumetrik (High), Sonne `#FFA36B` 1.2 tief von vorn-links, kühles Fill von hinten. |
| `yard_set.gd` | Ruft alles auf; Kamera-Durchlass (Abschnitt 2), eine Box-`ReflectionProbe` über dem Hof (einmalig gerendert, Art Bible 6.5), Profiling-Ausgabe `--env-stats` (Abschnitt 4). |
| `menu_camera.gd` | Hauptmenü-Kamera: leicht erhöhter Diorama-Blick (3,6 m) aus der vorderen rechten Hofecke, pendelt langsam (Spitze ≈ 0,02 rad/s, 45 s je Hin und Zurück) um den Ofen; Formkästen vorn, Haus mit Fenstern und Lichterkette dahinter, Dämmerhimmel mit Mond über den Dächern, ruhiger Rasen links unter der Menüspalte. Bewegt sich zwischen Vorgarten und dem Raum über dem niedrigen Lattenzaun, fährt nie durch Haus, Mast oder Baum, kein Lichterkettenmast im Nahbereich. Weiche Fern-Tiefenunschärfe ab 26 m. Vorschau: `-- --menu-cam-t=<s>`. |

Alle Zufallswerte haben feste Seeds → jeder Peer baut denselben Hof (gleiche Kollisionen).
Headless (Tests, Server) werden nur Kollisionen gebaut, keine Meshes/Gras (`EnvMesh.visual()`).

## 2. Freihaltezonen und Kamera
Sperrzonen um jede Station (Ofen r 2,0 m, sonst r 1,5–1,6 m), um den Spawn (r 2,4 m) und den Hammer-Spawn.
Feste Props stehen nur außerhalb; die Arbeitsfläche (Erde) enthält nur Amboss, Schamott, Säcke und Eimer an ihrem Rand.
Die Arbeitsspuren (Abschnitt 1, `ground_scatter.gd`) sind flach und ohne Kollision und dürfen auf Laufwege.

**Kamera-Durchlass (Art Bible 8.2):** Alle Set-Kollisionen außer Haus, Schuppen und Boden – also Zäune, Masten,
Laternenpfosten, Baumstämme, Wäscheleinenpfosten und jedes Deko-Prop – sind in der Gruppe `camera_passthrough`
(`YardSet.CAMERA_PASSTHROUGH`, gesammelt in `YardSet._collect_passthrough()`). Arbeiter und Gegenstände kollidieren
unverändert mit ihnen (Ebenen/Masken bleiben 1). Die Spielkamera (`camera_rig.gd`) ignoriert Treffer auf dieser Gruppe;
zusätzlich übergibt `YardSet` die Körper an jeden `SpringArm3D` in der Szene (`add_excluded_object`, auch für später
hinzugefügte). Geprüft headless: ein Arm durch den Lichterkettenmast fährt voll aus (5,00 / 5,00 m), ein Arm Richtung
Hauswand wird gestoppt (3,09 / 6,00 m).

## 3. Qualitätsstufen (`EnvQuality`)
Auswahl: `-- --quality=low|medium|high`, sonst LOW wenn `SteamDeck=1`, sonst HIGH.

| | HIGH | MEDIUM | LOW (Steam Deck) |
|---|---|---|---|
| Gras-Dichte / Sichtweite | 100 % / 48 m | 70 % / 34 m | 40 % / 24 m |
| Kiesel, Arbeitsspuren | 100 % | 70 % | 40 % |
| SSIL | an | aus | aus |
| Volumetrischer Nebel | an | aus | aus |
| Glow-Level 5 | an | an | aus |
| Sonnenschatten | 2 Splits, 40 m, weich (1,5°) | wie High | 2 Splits, 30 m, hart |
| Wandlampen-Spot-Schatten | aus | aus | aus |
| Fenster-/Laternen-/Schuppen-Omnis | an | an | aus |
| Lichterketten-Omnis | 5 | 5 | 2 |
| Rauch, Glühwürmchen | an | an | aus |
| Sky-Radiance | 256 | 256 | 128 |
| Reflection Probe (einmalig) | an | an | an |

Projekt-/Viewport-Einstellungen für das Deck (nicht Teil dieses Pakets, gehören in `graphics_settings.gd`, WP 10):
FSR 1.0 bei 0,8, MSAA aus + SMAA an, `soft_shadow_filter_quality` 1, SSAO halbe Größe.

Profiling-Schalter: `-- --env-off=vol,ssil,ssao,grass,shadows` schaltet einzelne Features ab.

**Lichthierarchie (Art Bible 6.1, Regel 2):** Emissions-Energien sind bewusst unter den Bibel-Startwerten, weil die
Messung im Wide-Shot Birnen und Fenster heller als die Schmelze zeigte: Lichterketten-Birnen 1,1 (statt 2,5),
Fenster 0,9 (statt 2,0), Türlampe 1,2, Schuppenbirne 1,4; Birnenglas und Türlampe haben eine dunkle Grundfarbe, damit nur die Emission leuchtet (sonst hellen die eigenen Omnis sie über die Schmelze hinaus auf). Siehe Messwerte in Abschnitt 4.

## 4. Budget und Messwerte

Messung: `-- --env-stats` (gibt nach 80 Frames Objekte, Draw Calls, Primitive, Lichter und Frame-Zeiten aus), Showcase-
bzw. Menü-Kamera, Software-Vulkan (lavapipe, 4 Kerne, parallel zu weiteren Renders) – Frame-Zeiten also nur relativ;
auf einer GTX-1060-Klasse-GPU ist nichts davon kritisch. Stand 05.10.2026, inkl. Stationen, Figuren und HUD.

| Ansicht (HIGH) | sichtbar: Objekte / Draws / Primitive | Schatten: Objekte / Draws / Primitive | Lichter in der Szene |
|---|---|---|---|
| Showcase `wide` | 416 / 384 / 637 k | 253 / 235 / 350 k | 22 (1 mit Schatten) |
| Showcase `pour` | 236 / 222 / 438 k | 216 / 203 / 334 k | 20 (1 mit Schatten) |
| Hauptmenü | 316 / 293 / 525 k | 198 / 181 / 295 k | 15 (1 mit Schatten) |
| Showcase `wide`, **LOW** | 406 / 374 / 472 k | 251 / 233 / 346 k | 13 (1 mit Schatten) |

Frame-Zeit lavapipe im Wide-Shot: LOW ≈ 1,6 s, HIGH ≈ 6–7 s je Frame (HIGH unter stärkerer Parallel-Last gemessen;
das Verhältnis zeigt, was SSIL, Volumetrik, Gras und Glow-Level 5 kosten). Draws hängen kaum am Preset – der LOW-Gewinn
kommt aus Gras (3 045 statt 7 920 Büschel), Bildschirmeffekten und Lichtern.

| Posten | Wert |
|---|---|
| Aufbauzeit `YardSet` | 1,1–2,5 s mit Grafik (gemessen unter Last mit 4–6 parallelen Renders; davon Gras ≈ 0,3 s), 0,3–0,5 s headless unter Last. `YardLayout` headless ≈ 60 ms (die Detailmaske wird nur mit Grafik gemalt). |
| Grasbüschel HIGH | ≈ 7 900 (2-Segment-Halme, ≈ 200 k Dreiecke, ab 48 m ausgeblendet), LOW ≈ 3 000 |
| Arbeitsspuren | 5 MultiMeshes (bis zu 90 Holzkohle, 16 Ziegel, 90 Sandklumpen, 14 Tropfen, 56 Späne/Splitter bei HIGH) = 5 Draw Calls, < 10 k Dreiecke |
| Hintergrund neu | Waldband 1 Mesh (≈ 170 Kugeln, ≈ 20 k Dreiecke, ohne Schatten), 12 Sträucher + 3 Bäume in den Nachbargärten (≈ 18 Draws) |
| Lichter | Umgebung: Sonne (Schatten) + Fill, 5 Lichterketten-Omnis, 2 Fenster-Omnis, Tür-Spot + Glimmlicht, Schuppenbirne, Tischlaterne, 2 Laternenpfosten – alle ohne Schatten; dazu Ofen, Schmelze, Werkbanklampe (Stationen). Mehr als das Art-Bible-Budget (≤ 8 sichtbare Omni/Spot), mit Forward+-Clustering aber unkritisch; sichtbar sind je Ansicht weniger. Kandidaten zum Kürzen: 2 der 5 Lichterketten-Omnis, Tischlaterne. |
| Reflection Probe | 1 Box, `UPDATE_ONCE` (6 Seiten einmal beim Start) |
| Lichthierarchie (Wide-Shot, Bildhelligkeit p99 nach AgX) | Lichterketten-Birnen 0,90 → 0,73 · Fenster 0,83 → 0,66 · Türlampe 0,94 → 0,70 (Umgebungs-Pass). Schmelze/Guss 0,70 → **0,92** nach dem Art-Director-Pass: flüssiges Metall leuchtet × (1 + `liquid_boost`) = × 2 (`metal.gdshader`), Gießstrahl Energie 2,2 und dicker, Ofen-Glut/Auskleidung heller, Helm matter. Damit ist die Schmelze klar das Hellste im Bild (Regel 2). |
| Showcase-Render 150 Frames | ≈ 8 min allein, 15–20 min wenn 4–6 Renders parallel laufen (Timeout entsprechend setzen). Jeder lavapipe-Render belegt ≈ 4 GB RAM: in der 16-GB-Sandbox höchstens 3 gleichzeitig, sonst greift der OOM-Killer. |

Optimierungen, die schon drin sind: Gras-Rasenfarbe pro Vertex statt pro Pixel, Voronoi im Boden-Shader nur auf
Erde/Kies (eine Voronoi-Abfrage liefert Kiesel und Krümel), Hintergrundbäume und Waldband ohne Schattenwurf,
Bretter/Pfosten/Ziegel als zusammengeführte Meshes bzw. MultiMesh, geteilte Materialien (KayKit-Atlas je Textur + Tönung),
Gras nur 3 m über den Zaun hinaus (Hecken verdecken den Rest), Detailmaske nur auf Erde ausgewertet.

## 5. Hinweise für andere Pakete
- **Kontur-Pass (`outline_post.gdshader`, WP 3):** Gras, Lichterketten-Kabel und Birnen laufen im transparenten Pass
  (`ALPHA = 1`), damit sie keine Tinten-Kontur bekommen; sie schreiben zusätzlich `ROUGHNESS = 0.99` als Marker
  (Art Bible 5.4). Sobald der Kontur-Shader Rauheit > 0,98 ignoriert, kann Gras zurück in den opaken Pass.
  Stand 05.10. (Art-Director-Pass): 1 px, Normal-Schwelle 0,6, Silhouetten-Fade 18 → 35 m, Tiefen-Schwelle 0,04
  (durchgehende Silhouetten statt gestrichelter Kanten), Falten-/Normalkanten schon ab 7 → 15 m ausgeblendet –
  so zeichnen Nägel, Ziegelreihen und Eckquader an Haus und Schuppen keine gepunkteten Linien mehr.
  Der Boden-Shader hat bewusst keine gebumpten Risse (die Kontur hätte jede Zelle nachgezeichnet).
- **Kamera (`camera_rig.gd`, WP 7):** siehe Abschnitt 2. Offen: Verdeckungs-Dither (Art Bible 8.2) für Zaun/Baum/Schuppen
  zwischen Kamera und Figur – bei flacher Neigung (−12°) verdeckt der 1,55-m-Zaun sonst die Beine der Figur.
- **Hauptmenü (`main_menu.gd`):** Im Attract-Modus hält das Menü den Ofen auf Hitze ≈ 0,9 (langsames Atmen), der Tiegel
  im Ofen ist mit glühender Schmelze gefüllt, zwei Arbeiter (nur Modelle) treten den Blasebalg bzw. zeichnen an der
  Werkbank. Der Hammer lehnt am zweiten Formkasten statt im Vordergrund zu stehen. Menü und Showcases laden/schreiben
  nie den Spielstand (`SaveGame.is_active()`).
- **Stationen:** `EnvMesh` (`piece`, `merge`, `box`, `cylinder`, `sphere`, `material`, `wood`, `surface`, `foliage`) wird
  inzwischen auch von `foundry/visuals/*` benutzt – Signaturen bitte stabil halten.
- Stationspositionen dürfen sich ändern: Sperrzonen, Abnutzung, Laufwege, Ruß, Formsand und Arbeitsspuren folgen den
  echten Knoten.
- **Figuren (Batch A, 06.10.):** Schrittgeräusche lesen den Boden über `YardSet.layout.zones_at()` (R Erde / A Formsand
  → `step_dirt_*`, sonst `step_grass_*`) – Kanal-Belegung der Zonenmaske bitte stabil halten. Die Ziel-Kontur
  (`scripts/player/target_highlight.gd`) setzt `material_overlay` auf die Meshes des anvisierten Objekts (Stencil-Maske +
  gewachsene Hülle, transparenter Pass, Priorität 7/8); Stationen und Props sollten `material_overlay` nicht selbst
  belegen, und Effekt-Meshes (Flammen, Rauch, Glühkarten) bleiben außen vor, solange ihr Shader `unshaded`/`blend_*`
  bzw. `depth_draw_never` nutzt.
