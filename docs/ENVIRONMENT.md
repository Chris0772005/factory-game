# MOLTEN MATES – Hinterhof-Umgebung (Set, Licht, Performance)

Stand: 03.10.2026 · Godot 4.7.2 · Umsetzung von `docs/ART_BIBLE.md` Abschnitte 4, 6, 7, 10 für Level 1.
Code: `game/scripts/environment/`, Shader: `game/shaders/env_*.gdshader` (+ `env_common.gdshaderinc`).

## 1. Aufbau

`backyard.gd` baut wie bisher Stationen und Entities. Danach ruft es `YardSet.build(self, stations)` auf; das Licht
kommt aus `_build_environment()` → `YardLighting.build()` (auch vom Asset-Kontaktbogen genutzt).

| Datei | Inhalt |
|---|---|
| `yard_layout.gd` | Grundriss: Zaunlinien, Haus, Schuppen, Arbeitsfläche. Liest die **echten Stationspositionen** → Sperrzonen (Laufwege), Abnutzung, Ruß am Ofen, Formsand an den Formkästen. Malt die Boden-Zonenmaske (R Erde, G Kies, B Ruß, A Sand, 4 px/m). |
| `yard_ground.gd` + `env_ground` | Ein Boden-Mesh (76 × 64 m, 0,5-m-Raster): flach wo gearbeitet wird, 0–8 cm Rasenwellen (nie unter y = 0), sanfte Hügel hinter dem Zaun. Kollision: flache Box, Oberkante y = 0. |
| `grass_field.gd` + `env_grass` | Grasbüschel als MultiMesh in 8 × 8-m-Kacheln (Rasen, Wildgras am Zaun, Blühbüschel). Farbe = Rasenfarbe des Bodens darunter. Wind + Wegdrücken durch bis zu 4 Arbeiter. |
| `ground_scatter.gd` | Kiesel-MultiMesh an Weg- und Erdkanten, im Kiesstreifen. |
| `plank_fence.gd` | Sichtschutz-Bretterzaun (1,55 m) links/rechts/hinten, niedriger gestrichener Lattenzaun vorn (Kamera schaut darüber), geschlossenes Tor rechts. Bretter als MultiMesh, Pfosten/Riegel zusammengeführt. Eine Box-Kollision pro Zaunlinie. |
| `yard_house.gd` | Wohnhaus (Putz mit abgeplatzten Stellen, Satteldach mit Ziegelreihen und Giebeln, Regenrinne + Fallrohr ins Regenfass, Schornstein, Eckquader, Fensterrahmen/Läden/Blumenkästen, Hintertür mit Stufen, Vordach und Wandlampe). Gleicher Baukasten in einfacher Form für 4 Nachbarhäuser. |
| `garden_shed.gd` | Bretterschuppen mit Wellblech-Pultdach, Fenster, offener Tür, Regalen und warmer Glühbirne innen. |
| `string_lights.gd` + `env_lights`/`env_bulb` | Lichterketten an 3 Masten und 2 Wandhaken: Kettenlinien-Kabel, Birnen als MultiMesh, Schwingen komplett im Shader. |
| `stylized_tree.gd` + `env_foliage` | Laubbaum (Reifenschaukel), Nadelbäume, Büsche, Hecken: klumpige Kugeln, Blattbüschel-Muster, Wind. |
| `prop_kit.gd` + `env_atlas` | KayKit-Props mit Pack-Maßstab, gemeinsamem Atlas-Material (Welt-Rauschen, Schmutz unten, raue Oberfläche, optional entsättigt/getönt) und Kollision aus den Modellgrenzen. |
| `yard_props.gd` | Prozedural: Amboss auf Hackklotz, Reifenstapel, rostige Bleche, Terrakottatöpfe, Hochbeet, Schamottstapel, Werkzeuge, Wäscheleine (flatternde Wäsche), Reifenschaukel. |
| `yard_dressing.gd` | Handplatzierung aller Props + Hintergrund (Nachbarhäuser, Bäume, Hecken, Strommast). Warnt (`push_warning`), wenn ein festes Prop in die Sperrzone einer Station ragt. |
| `yard_ambience.gd` | Schornsteinrauch, Glühwürmchen (GPU-Partikel). |
| `yard_lighting.gd` + `env_sky` | Dämmerung: Sky-Shader (Verlauf, Abendrot, Erdschatten + „Venusgürtel“, Mond, Sterne, Wolken), AgX white 6 / contrast 1.3, Glow nur über HDR 1.2 (bloom 0), SSAO, SSIL (High), Tiefennebel mit Luftperspektive, Volumetrik (High), Sonne `#FFA36B` 1.2 tief von vorn-links, kühles Fill von hinten. |
| `menu_camera.gd` | Hauptmenü-Kamera: langsamer Schwenk über die offene Vorderseite (nie durchs Haus), Hof rechts der Menüspalte, weiche Fern-Tiefenunschärfe. |

Alle Zufallswerte haben feste Seeds → jeder Peer baut denselben Hof (gleiche Kollisionen).
Headless (Tests, Server) werden nur Kollisionen gebaut, keine Meshes/Gras (`EnvMesh.visual()`).

## 2. Freihaltezonen
Sperrzonen um jede Station (Ofen r 2,0 m, sonst r 1,5–1,6 m), um den Spawn (r 2,4 m) und den Hammer-Spawn.
Feste Props stehen nur außerhalb; die Arbeitsfläche (Erde) enthält nur Amboss, Schamott, Säcke und Eimer an ihrem Rand.
Kamera-Hinweis: Mast- und Baumkollisionen sind dünne Zylinder auf Ebene 1; der SpringArm der Spielkamera kollidiert
mit ihnen. Wenn das stört, diese Körper per `SpringArm3D.add_excluded_object()` ausnehmen (Kamera-Paket).

## 3. Qualitätsstufen (`EnvQuality`)
Auswahl: `-- --quality=low|medium|high`, sonst LOW wenn `SteamDeck=1`, sonst HIGH.

| | HIGH | MEDIUM | LOW (Steam Deck) |
|---|---|---|---|
| Gras-Dichte / Sichtweite | 100 % / 48 m | 70 % / 34 m | 40 % / 24 m |
| Kiesel | 100 % | 70 % | 40 % |
| SSIL | an | aus | aus |
| Volumetrischer Nebel | an | aus | aus |
| Glow-Level 5 | an | an | aus |
| Sonnenschatten | 2 Splits, 40 m, weich (1,5°) | wie High | 2 Splits, 30 m, hart |
| Wandlampen-Spot-Schatten | aus | aus | aus |
| Fenster-/Laternen-/Schuppen-Omnis | an | an | aus |
| Lichterketten-Omnis | 5 | 5 | 2 |
| Rauch, Glühwürmchen | an | an | aus |
| Sky-Radiance | 256 | 256 | 128 |

Projekt-/Viewport-Einstellungen für das Deck (nicht Teil dieses Pakets, gehören in `graphics_settings.gd`, WP 10):
FSR 1.0 bei 0,8, MSAA aus + SMAA an, `soft_shadow_filter_quality` 1, SSAO halbe Größe.

Profiling-Schalter: `-- --env-off=vol,ssil,ssao,grass,shadows` schaltet einzelne Features ab.

## 4. Budget und Messwerte

Messung: `game/`-Projekt, Showcase-Wide-Kamera, HIGH, Software-Vulkan (lavapipe, 4 Kerne) – also nur relative Werte;
auf einer GTX-1060-Klasse-GPU ist nichts davon kritisch.

| Posten | Wert |
|---|---|
| Aufbauzeit `YardSet` | ≈ 0,85 s mit Grafik (davon Gras ≈ 0,3 s), ≈ 70 ms headless (nur Kollisionen) |
| Grasbüschel HIGH | ≈ 8 000 (2-Segment-Halme, ≈ 200 k Dreiecke, ab 48 m ausgeblendet), LOW ≈ 3 200 |
| Gesamtszene im Wide-Shot (inkl. Stationen/Figuren) | HIGH: 572 Objekte, 526 Draw Calls, 0,89 M Primitive (alle Pässe inkl. Schatten), 18 Lichter (1 mit Schatten) · LOW: 547 Objekte, 501 Draw Calls, 0,71 M Primitive, 9 Lichter |
| Lichter | Sonne (Schatten) + Fill, 5 Lichterketten-Omnis, 2 Fenster-Omnis, Tür-Spot + Glimmlicht, Schuppenbirne, Tischlaterne, 2 Laternenpfosten – alle ohne Schatten |
| Kosten je Frame (lavapipe) | Gras ≈ 0,7 s, SSIL ≈ 0,4 s, Volumetrik ≈ 0,3 s (vor den Shader-Optimierungen gemessen) |
| Showcase-Render 150 Frames | ≈ 300–370 s bei normaler Last, bis ≈ 530 s wenn mehrere Renders parallel laufen (vorher 110 s) – unter dem 600-s-Timeout |

Optimierungen, die schon drin sind: Gras-Rasenfarbe pro Vertex statt pro Pixel, Voronoi im Boden-Shader nur auf
Erde/Kies, Hintergrundbäume ohne Schattenwurf, Bretter/Pfosten/Ziegel als zusammengeführte Meshes bzw. MultiMesh,
geteilte Materialien (KayKit-Atlas je Textur + Tönung), Gras nur 3 m über den Zaun hinaus (Hecken verdecken den Rest).

## 5. Hinweise für andere Pakete
- **Kontur-Pass (`outline_post.gdshader`, WP 3):** Gras, Lichterketten-Kabel und Birnen laufen im transparenten Pass
  (`ALPHA = 1`), damit sie keine Tinten-Kontur bekommen; sie schreiben zusätzlich `ROUGHNESS = 0.99` als Marker
  (Art Bible 5.4). Sobald der Kontur-Shader Rauheit > 0,98 ignoriert, kann Gras zurück in den opaken Pass.
  Die gepunkteten Konturen an Fasen, Brettfugen und Eckquadern in 15–25 m Entfernung verschwinden weitgehend mit den
  Art-Bible-Werten (Normal-Schwelle 0,6, 1 px Dicke, Distanz-Fade 18 → 35 m) – im Vorschau-Test geprüft.
- **Kamera (`camera_rig.gd`, WP 7):** dünne Kollisionen (Masten, Pfosten, Baumstamm, Wäscheleine) sind in der Gruppe
  `camera_passthrough` (`YardSet.CAMERA_PASSTHROUGH`) → `SpringArm3D.add_excluded_object(body.get_rid())`.
- **Stationen:** `EnvMesh` (`piece`, `merge`, `box`, `cylinder`, `sphere`, `material`, `wood`, `surface`, `foliage`) wird
  inzwischen auch von `foundry/visuals/*` benutzt – Signaturen bitte stabil halten.
- Stationspositionen dürfen sich ändern: Sperrzonen, Abnutzung, Ruß und Formsand folgen den echten Knoten.
