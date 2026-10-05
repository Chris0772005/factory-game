# MOLTEN MATES – Art Bible

> **Cozy-Industrial Toy Diorama.** Klobige, liebevoll abgenutzte Spielzeug-Formen, weiche Farbverläufe,
> warmes Feierabendlicht – und flüssiges Metall als hellstes, lebendigstes Ding im Bild.

Stand: 03.10.2026 · Engine: Godot 4.7.2 (Forward+, Jolt) · Gilt für alle Szenen, Menüs und Marketing-Shots.
Alle Eigenschaftsnamen wurden gegen die Godot-4.7.2-Binary geprüft (`ClassDB`), nicht aus dem Gedächtnis übernommen.

Dieses Dokument ist **verbindlich**. Wer ein Asset, Material, Licht oder UI-Element baut, prüft es gegen die Regeln hier
und gegen die Screenshot-Checkliste (Abschnitt 14). Abweichungen nur mit Begründung im PR.

---

## 0. Die 15 Regeln (Kurzfassung)

1. **Keine Einfarb-Fläche.** Jede Oberfläche hat mindestens drei Variationsebenen: Höhenverlauf, Makro-Rauschen, Mikro-Körnung (plus Kantenabnutzung bei Props). Keine Fläche mit nur einer Farbe darf mehr als 5 % des Bilds einnehmen.
2. **Geschmolzenes Metall ist das Hellste im Bild.** Mindestens 2 Blenden heller als die hellste beleuchtete Umgebungsfläche. Gesättigtes Orange/Gelb-Leuchten ist exklusiv für Hitze reserviert.
3. **Formen in drei Ebenen.** Grundform → Sekundärform (Fasen, Bänder, Bretter, Füße) → Tertiärdetail (Nieten, Nägel, Griffe). Nichts ist ein nackter Quader, nichts ist perfekt gerade (±1–3° Jitter).
4. **Der Boden ist nie eine Platte.** Gras-Büschel (MultiMesh + Wind), Erdwege mit aufgebrochenen Kanten, Ruß- und Sandflecken, leichte Höhenwellen. Das Spielfeld endet nie an einer sichtbaren Kastenkante.
5. **Stylized PBR statt Toon-Bänder.** Godots PBR-Licht mit gemalten Verläufen (KayKit-Prinzip), weichem Lambert-Wrap für Organisches, Rauheit 0.65–0.9. Keine harten Cel-Stufen.
6. **Licht erzählt.** Standard ist Dämmerung: tiefer warmer Key (Energie 1.3), kühler Fill, Rim von hinten; praktische Lichter (Ofen, Lichterkette, Fenster) setzen die Hierarchie. Schatten sind getönt (kühl-violett), nie schwarz.
7. **AgX richtig einstellen.** `tonemap_agx_white` ≈ 6, `tonemap_agx_contrast` ≈ 1.3, Glow nur über HDR-Schwelle 1.2 und `glow_bloom = 0`. Kein Grauschleier.
8. **Flüssig zuerst.** Physik-Interpolation an, Kamera in `_process` auf interpolierten Transforms, 60 fps stabil. Kein sichtbares Ruckeln oder Einrasten > 5 cm.
9. **Echte Animation statt Sinus-Gliedmaßen.** Geriggte Figuren (KayKit-Rig, 76 Clips) mit AnimationTree, Blendzeiten 0.06–0.18 s, IK für Hände am Griff, Squash & Stretch mit Feder.
10. **Jede Aktion: Ausholen → Treffer → Nachschwingen.** 80–150 ms / 50–80 ms / 200–300 ms. Jede Aktion hat VFX + SFX + Kamera-Impuls + UI-Reaktion.
11. **Etwas bewegt sich in jedem Frame.** Gras, Rauch, Lichterkette, Funken, Motten, Idle-Atmung. Ein Standbild muss Bewegung andeuten.
12. **Dichte am Rand, Luft in der Mitte.** 1,0 Props/m² am Zaun, ≤ 0,1 in den 1,6 m breiten Laufwegen. Drei Tiefenebenen: Vordergrund, Spielfeld, Hintergrund-Silhouetten.
13. **Konturen sind Farbe, nicht Schwarz.** Post-Kontur = abgedunkelte Eigenfarbe, 1 px bei 1080p, Distanz-Fade 18–35 m. Interaktives bekommt eine Stencil-Kontur.
14. **UI ist Teil der Welt.** Tasten-Glyphen statt „[F halten]“, Prompts über dem Objekt verankert, Schilder als bemalte Bretter, alles animiert rein und raus.
15. **Steam-Deck-Preset ab Tag 1.** Jede Entscheidung hat einen Fallback (SSIL/Volumetrik aus, FSR 0.8, Grasdichte 40 %). Keine Szene ohne Messung auf dem Low-Preset.

---

## 1. Diagnose: Warum der aktuelle Stand nach Prototyp aussieht

Grundlage: `shots/backyard_wide.png`, `backyard_pour.png`, `backyard_reveal.png`, `drawpad_showcase.png`, `menu2.png`
und der Code dahinter. Ehrlich und konkret – jeder Punkt hat eine Ursache im Code.

| # | Problem | Wo sichtbar | Ursache im Code |
|---|---|---|---|
| 1 | **Flache, untexturierte Materialien.** Alles ist ein einziger Farbwert mit Rauheit 0.7: Rasen, Erde, Hauswand, Holz, Overall. Wirkt wie Editor-Greybox. | alle Backyard-Shots | `WorldBuilder.material()` = `StandardMaterial3D` mit nur `albedo_color` + `roughness`. Keine Textur, kein Verlauf, keine Variation. |
| 2 | **Primitive Silhouetten.** Zaun = lose Stäbe ohne Querlatten, Lichterketten-Birnen schweben ohne Kabel, Haus = 14 × 5,5 m Wandscheibe ohne Dach/Rahmen/Regenrinne, Schuppen = Kiste + Platte, Hammer steht senkrecht wie ein Schild. | `backyard_wide` | Alles aus `add_box` / `CylinderMesh` / `SphereMesh`. Keine Sekundär- und Tertiärformen. |
| 3 | **Boden ist ein farbiger Kasten.** 26 × 20 m grüne Box + 2 cm dicke beige Box als „Erde“. Harte Rechteckkante, keine Übergänge, kein Gras, keine Höhe. Ca. 45 % des Wide-Shots sind flache Fläche. | `backyard_wide` | `WorldBuilder.add_box(... GRASS)` und `add_box(... DIRT)` in `backyard.gd`. |
| 4 | **Keine Lichthierarchie.** Mond 0.6 + Himmel-Ambient 0.55 ergibt überall gleiches Lila-Grau. Die 48 leuchtenden Birnen sind die hellsten Punkte und ziehen das Auge an den Bildrand statt zum Ofen. Der Gießstrahl ist dünn und geht unter. | `backyard_wide`, `_pour` | `_build_environment()`, `_build_string_lights()` (Emission 6.0 auf jeder Birne). |
| 5 | **Grauschleier durch Tonemapping.** AgX mit Standard-`tonemap_agx_white` 16.29 drückt alles in flaue Mitten. `glow_bloom 0.08` legt zusätzlich Dunst über alles; `adjustment_saturation 1.15` versucht es zu kaschieren. | alle | `backyard.gd` Environment. |
| 6 | **Leere.** Spielfeld 12 × 8,5 m mit ca. 8 Objekten ≈ 0,07 Props/m². Keine Eimer, Ziegel, Säcke, Werkzeuge, Unkraut, Gerümpel. Untere linke Bildhälfte ist nichts. | `backyard_wide` | Level-Aufbau. |
| 7 | **Steife Prozedural-Animation.** Starre Glieder schwingen per Sinus, keine Knie/Ellbogen, kein Ausholen, keine Sekundärbewegung, Hände greifen nicht die Tiegelgriffe. Figur wirkt wie Actionfigur am Stab. | `backyard_pour` | `PlayerModel.animate()`. |
| 8 | **Ruckeln bei > 60 Hz.** Physik läuft mit 60 Hz, Physik-Interpolation ist aus, die Kamera folgt per `lerp` einem 60-Hz-gestuften Ziel. Auf 120/144-Hz-Monitoren ruckelt Figur und Kamera. | (Spielgefühl) | `physics/common/physics_interpolation = false` (Default), `CameraRig._process`. |
| 9 | **Unsaubere Konturen.** 1,4 px schwarze Kontur überall, auch auf fernem Zaun und auf Bodenkanten; Doppellinien an Fasen der Rounded Boxes; Kontur um Leuchtbirnen. Dicke variiert optisch (dünn an großen, fett an kleinen Objekten). | `backyard_pour`, `_reveal` | `outline_post.gdshader`: feste Farbe, Normal-Schwelle 0.45. |
| 10 | **Keine Tiefe.** Hintergrund ist eine flache Wand; Nebel überall gleich lila; kein Vorder-/Mittel-/Hintergrund, kaum Himmel sichtbar, keine Luftperspektive. | `backyard_wide` | Level + `fog_density 0.012` einfarbig. |
| 11 | **Farben ohne System.** Königsblauer Overall (#3d7dd8) gegen entsättigte Lila-Welt; Tiegel ist knallorange wie ein Plastikeimer und konkurriert mit dem Metall; kaltes und heißes Metall nicht klar getrennt. | `backyard_pour` | Farben verstreut in Skripten (`PlayerModel`, `Crucible`, `backyard.gd`). |
| 12 | **Proportionen.** Kopf 0,6 m breit, Hammer 1 m hoch, Schilder „VERKAUF“/„KATALOG“ als UI-Schrift frei in der Welt. | `backyard_wide`, `_reveal` | `Label3D` mit UI-Font, Maße frei gewählt. |
| 13 | **UI wirkt wie Debug.** Geldanzeige „$ 61“ in dunkler Pille; Hinweis als nackter Text „[F halten] Gießen · 1.4 l · 1150 °C“ unten mittig ohne Tasten-Glyphe/Fortschritt; Hauptmenü zeigt noch „FACTORY GAME – Arbeitstitel – Prototyp“ über grauer Leere mit Förderband-Testobjekten. | `menu2`, alle | `hud.gd`, `main_menu.gd`. |
| 14 | **Kein Juice im Standbild.** Kein Rauch aus dem Ofen, keine Hitzeflimmern, kein Staub, kein Gras im Wind, winzige Funken. Das Bild ist eingefroren. | alle | FX existieren, sind aber zu klein dosiert / fehlen. |

**Was gut ist und bleibt:** das Metall-Shader-System (Schwarzkörper-Rampe, Kruste, Füllkante), Feuer und Gießstrahl
(`fx_showcase.png` wirkt bereits deutlich wertiger, weil warmes Praktisch-Licht dominiert), die DrawPad-Gestaltung
(sauber, gut lesbar), Fredoka als UI-Schrift, die gerundeten Knöpfe mit Unterkante.

---

## 2. Stil-Säule und Referenzen

**Name:** *Cozy-Industrial Toy Diorama* – „Feierabend-Gießerei im Hinterhof“.
**Drei Wörter:** KLOBIG · WARM · LEBENDIG.

1. **Spielzeug-Diorama:** große lesbare Silhouetten, Props 1,15× reale Größe, überall Fasen, leicht schief, liebevoll
   abgenutzt. Man soll die Welt anfassen wollen.
2. **Licht erzählt:** kühle Dämmerung als Bühne, warmes Glühen als Hauptdarsteller. Das Auge landet in < 1 s auf dem Metall.
3. **Alles lebt:** jede Fläche und jedes Objekt hat eine kleine Bewegung oder Reaktion.

**Referenzen (Qualitätslatte, nicht kopieren):**
- *KayKit* (Kay Lousberg) – Formsprache, Fasen, Verlaufs-Atlas-Texturen. Gleiche Familie wie unsere CC0-Assets.
- *Overcooked 2 / Moving Out* – Lesbarkeit von oben, klobige Proportionen, Stationen als Silhouetten erkennbar.
- *PowerWash Simulator* – saubere Materialtrennung, klare Werte, ruhiger Hintergrund.
- *How to Fish* (2026) – Low-Poly-Insel, absurde Figuren, Komik durch Animation.
- *Tiny Glade* – warmes, malerisches Dämmerlicht im Diorama-Maßstab.

---

## 3. Formsprache und Asset-Strategie

### 3.1 Formregeln
- **Fasen überall:** Radius = 6–10 % der kleinsten Kantenlänge (`MeshFactory.rounded_box`, Segmente ≥ 3).
- **Mindeststärken (Spielzeuglook):** Bretter ≥ 6 cm, Ränder ≥ 4 cm, Rohre/Griffe ≥ 4 cm Durchmesser, Kabel ≥ 1 cm.
- **Drei Formebenen pro Objekt** (Regel 3). Beispiel Formkasten: Kasten (1) → einzelne Bretter mit 1–2 cm Fugen,
  Eck-Metallwinkel, zwei Tragegriffe (2) → Nägel, Brandstempel „MM“, Sandkrümel am Rand (3).
- **Schiefe:** statische Props ±1–3° Rotation, ±3 % Skalierung, nie zwei identische nebeneinander.
- **Silhouettentest:** jede Station muss als schwarze Fläche in 64 px Höhe erkennbar sein.
- **Maßstab:** Tür 2,3 m, Zaun 1,2 m, Werkbank 0,85 m, Augenhöhe Figur ≈ 1,35 m, Kopf:Körper ≈ 1 : 2,2 (KayKit-Chibi).

### 3.2 Woher die Assets kommen
Nur CC0 bzw. MIT (mit Lizenzdatei + `CREDITS.md`). Keine KI-generierten Assets.

| Quelle | Lizenz | Nutzung | Beispiele (bereits geprüft, Dateinamen) |
|---|---|---|---|
| KayKit Character Pack: Adventurers 1.0 (GitHub `KayKit-Game-Assets`) | CC0 | **Figuren-Rig + Animationen** | Rig mit 41 Gelenken, 76 Clips u. a. `Idle`, `Walking_A/B/C`, `Running_A`, `PickUp`, `Throw`, `Interact`, `Use_Item`, `2H_Melee_Attack_Chop` (Hammer), `Unarmed_Melee_Attack_Kick` (Blasebalg), `Cheer`, `Hit_A`, `Jump_*`, `Death_A_Pose`/`Lie_Pose` (Bronzefreund). ~6.5k Dreiecke/Figur. |
| KayKit Furniture / Restaurant / City Builder / Dungeon Remastered / Halloween / Prototype / Medieval Hexagon | CC0 | Dressing | `table_medium`, `shelf_B_large_decorated`, `crate`, `crate_lid`, `jar_*`, `chair_stool`, `bench`, `trash_A/B`, `dumpster`, `streetlight`, `bush`, `barrel_large`, `barrel_small_stack`, `box_stacked`, `crates_stacked`, `fence`, `fence_gate`, `fence_pillar`, `lantern_hanging`, `post_lantern`, `path_A–D`, `bucket_empty`, `bucket_water`, `Pallet_Large/Small`, `building_*` (Hintergrund-Silhouetten) |
| Kenney Starter Kits (GitHub `KenneyNL/Starter-Kit-*`) | **MIT** (Repo) → Lizenztext + CREDITS-Eintrag | Ergänzung | `grass-small.glb`, `cloud.glb`, Colormap-Atlas |
| Google Fonts (GitHub `google/fonts`) | OFL | Titel-Font | Lilita One (`ofl/lilitaone`), Fredoka bleibt Haupt-Font |

Beschaffen per `GIT_LFS_SKIP_SMUDGE=1 git clone --depth 1 https://github.com/KayKit-Game-Assets/<Repo>` (Repos u. a.
`KayKit-Character-Pack-Adventures-1.0`, `KayKit-Furniture-Bits-1.0`, `KayKit-Restaurant-Bits-1.0`,
`KayKit-City-Builder-Bits-1.0`, `KayKit-Dungeon-Remastered-1.0`, `KayKit-Halloween-Bits-1.0`, `KayKit-Prototype-Bits-1.0`,
`KayKit-Medieval-Hexagon-Pack-1.0`; die glTF-Dateien liegen unter `addons/<pack>/Assets/gltf/` bzw. `Characters/gltf/`).
Beim Übernehmen: nur benutzte Dateien kopieren nach `game/assets/models/<pack>/`, `LICENSE.txt` daneben legen,
Eintrag in `CREDITS.md`. Vorher prüfen, dass `.glb`/`.png` echte Dateien sind (kein Git-LFS-Pointer).

**Einheitlichkeit:** Alle KayKit-Packs nutzen einen 1024²-**Verlaufs-Atlas** (Farbfelder, oben hell → unten dunkel).
Wir färben die Atlas-PNGs der genutzten Packs auf *unsere* Palette um (Abschnitt 4): Layout und UVs bleiben, pro Farbfeld
wird der Mittelwert auf die nächste Palettenfarbe verschoben und der Hell-Dunkel-Verlauf beibehalten (kleines Tool-Skript,
Ergebnis unter `assets/textures/`). Höchstens zwei Asset-Familien pro Ansicht.

### 3.3 Figuren
- Prozeduralen `PlayerModel` ersetzen durch das KayKit-Rig (Basis Barbarian/Knight-Körper), neu eingekleidet:
  eigener Schutzhelm-Mesh (Halbkugel + Krempe + Spielerfarben-Streifen), Latzhose, Lederhandschuhe, Stiefel.
  Kleidung über Atlas-Felder einfärben (4 Spielerfarben, 4 Hauttöne).
- **API bleibt:** `animate()`, `squash()`, `pose_data()`/`apply_pose()`, `panic_pose()` behalten Signatur und Bedeutung
  (Tests und Netzwerk hängen daran). Intern dürfen sie auf AnimationTree-Zustände abbilden
  (z. B. `pose_data` = Zustands-ID + Clip-Zeit + Blendwerte, weiterhin 7 Floats).
- Bronzefreund-Statue = eingefrorene Pose aus `Death_A_Pose`/`Hit_A` + Metall-Shader.

---

## 4. Palette

Alle Farben als sRGB-Hex. Code-Konstanten zentral in einer neuen `scripts/gfx/palette.gd` (`class_name Palette`),
nicht mehr verstreut in Stationsskripten.

### 4.1 Umgebung (Dämmerung, Standard für den Hinterhof)
| Token | Hex | Verwendung |
|---|---|---|
| `SKY_ZENITH` | `#34407F` | Himmel oben (Golden Hour: `#4A5A9C`) |
| `SKY_HORIZON` | `#F0A07E` | Horizont (Golden Hour: `#F4B58C`) |
| `SKY_GROUND_HORIZON` | `#B9806F` | Himmel unter Horizont |
| `CLOUD_LIT` / `CLOUD_SHADE` | `#FFD2A8` / `#8A7AA8` | Wolken |
| `GRASS_LIGHT` / `GRASS_MID` / `GRASS_DARK` | `#8DB360` / `#5E8C4A` / `#2F5A43` | Rasen (Spitze / Mitte / Basis) |
| `DIRT_LIGHT` / `DIRT_MID` / `DIRT_DARK` | `#C49A6C` / `#9C7552` / `#5E4636` | Erdwege, trocken / normal / feucht |
| `SAND` / `SAND_RAMMED` | `#E3C690` / `#B8955F` | Formsand locker / gestampft |
| `WOOD_LIGHT` / `WOOD_MID` / `WOOD_DARK` | `#C68B59` / `#9A6240` / `#5C3A28` | Holz |
| `FENCE_WEATHERED` | `#8C6A4E` | verwittertes Zaunholz |
| `BRICK` / `BRICK_DARK` / `MORTAR` | `#B5654A` / `#7E3F33` / `#D8C3A5` | Ofen, Hausmauer |
| `PLASTER` / `TRIM_TEAL` | `#E3CDB0` / `#3F7F86` | Hauswand / Fensterrahmen, Türen (Komplementär zu Orange) |
| `ROOF` | `#6B4A4F` | Dachziegel |
| `FOLIAGE` / `FOLIAGE_DARK` | `#4E7F4F` / `#2E5944` | Büsche, Bäume |
| `SOOT` | `#2A2524` | Ruß, Schlacke |
| `SHADOW_TINT` | `#3B3F6B` | Ziel-Tönung der Schatten (Fill-Licht, LUT) |

### 4.2 Figuren
| Token | Hex |
|---|---|
| Spieler 1–4 (Overall) | `#3E7BD6` Blau · `#26B5C4` Türkis · `#9B5BD0` Violett · `#E26AA0` Pink |
| Helm (alle) | `#F2B134` + Spielerfarben-Streifen |
| Haut (Auswahl) | `#F6D2B0` · `#E3A57A` · `#B97A55` · `#7A4B32` |
| Handschuhe / Stiefel | `#5A4636` / `#3A2F2B` |

Spielerfarben haben HSV-Wert 55–75 % und Sättigung ≤ 65 %: sie müssen sich von der Umgebung abheben,
dürfen aber nie mit dem Metallglühen konkurrieren. **Kein Spieler ist orange, gelb oder grün** (grün verschwindet im Rasen).

### 4.3 Metalle
| Kalt | Hex | | Heiß (Emission, HDR) | Hex | Energie |
|---|---|---|---|---|---|
| Alu | `#C9CED6` | | ~550 °C dunkelrot | `#8A1A08` | 1 |
| Eisen | `#6E7277` | | ~800 °C kirschrot | `#E0450F` | 2.5 |
| Messing | `#D9A441` | | ~1000 °C orange | `#FF8A1F` | 4 |
| Bronze | `#B0723E` | | ~1200 °C gelb | `#FFD27A` | 7 |
| Kupfer | `#C8714A` | | weißglühend flüssig | `#FFF4D6` | 10 |
| Gold | `#F2C14E` | | | | |
| Grünspan | `#5FA68A` | | | | |

Tiegel und Ofen-Innenleben sind **kalt** dunkel: Graphit-Ton `#3A3436` (Rauheit 0.85). Nur die Schmelze leuchtet,
plus ein glühender Rand am Tiegel, wenn heiß.

### 4.4 UI
| Token | Hex | | Token | Hex |
|---|---|---|---|---|
| `INK` | `#1F1B2D` | | `GOOD` | `#6CCB5F` |
| `PAPER` | `#FFF8EC` | | `BAD` | `#E5533D` |
| `ACCENT` | `#F2B134` | | `INFO` | `#5BB8E8` |
| `ACCENT_DARK` | `#C98A12` | | `MOLTEN` | `#FF7A1A` → `#FFD27A` (Verlauf) |
| `PANEL` | `#1F1B2D` @ 82 % | | `COIN` | `#F7C948` |

### 4.5 Farbregeln
- **60 / 30 / 10:** 60 % kühl-neutrale Umgebung (Himmel, Rasen, Wand), 30 % warme Mitten (Holz, Erde, Ziegel),
  10 % heiße Akzente (Metall, Feuer, Lichter, UI-Akzent).
- **Wertebereich Albedo:** Umgebung zwischen 15 % und 85 % Helligkeit. Nichts Albedo-Schwarzes, nichts Albedo-Weißes.
- **Sättigung Umgebung:** HSV-S ≤ 55 %. Ausnahmen nur für Akzente.
- **Exklusivität:** helles gesättigtes Orange/Gelb = Hitze. Gold-Gelb in der UI = Geld/Belohnung.

---

## 5. Materialien

### 5.1 Entscheidung: Stylized PBR (kein Toon-Ramp)
Wir bleiben bei Godots PBR-Beleuchtung und erzeugen den Stil über **gemalte Verläufe und prozedurale Variation**.
Gründe:
- Das Metall braucht echte Reflexionen, Emission und Rauheit; Toon-Bänder würden den wichtigsten Effekt des Spiels flach machen.
- SSAO, SSIL, Nebel und Glow integrieren sich nur mit PBR sauber.
- KayKit/Kenney-Assets sind für beleuchtete Verlaufs-Atlanten gebaut, nicht für Cel-Shading.
- Viele bewegte Punktlichter (Lichterkette, Funken, Glut) erzeugen auf Toon-Rampen unruhige, springende Bänder.

Weichheit kommt aus: `diffuse_mode = DIFFUSE_LAMBERT_WRAP` für Organisches (Figuren, Stoff, Pflanzen),
Burley für den Rest; `metallic_specular` 0.2–0.35 für Nichtmetalle; Rauheit 0.65–0.9.

### 5.2 Gemeinsamer Oberflächen-Shader `shaders/stylized_surface.gdshader`
Ersetzt `WorldBuilder.material()` für alle Nicht-Metall-Props (Rückgabetyp entsprechend anpassen oder
`WorldBuilder.surface()` neu anlegen und Aufrufer migrieren). Prozedurale Meshes haben keine UVs → alles über
Objekt-/Weltposition (triplanar).

| Schicht | Rezept | Wert |
|---|---|---|
| Höhenverlauf (Fake-AO/Himmelslicht, wie KayKit-Atlas) | `albedo *= mix(1.0 - g, 1.0, smoothstep(-h / 2, h / 2, obj_y))` (Meshes um den Ursprung zentriert) | `g` = 0.25, `h` = Objekthöhe |
| Bodenkontakt | `albedo *= mix(0.72, 1.0, smoothstep(0.0, 0.15, world_y))` | dunkler Saum 15 cm über Boden |
| Makro-Rauschen | Welt-FBM, Skala 0.25/m | ±8 % Helligkeit, ±3 % Farbton Richtung warm |
| Mikro-Körnung | Welt-Noise, Skala 6/m | ±4 % Helligkeit, ±0.08 Rauheit |
| Kantenabnutzung | Vertex-`COLOR.r` = Fasen-Maske aus `MeshFactory` | Kante +12 % heller, Rauheit −0.1; bei Metall: Lack ab → Metall blank |
| Schmutz/Ruß | optionaler Welt-Maskenwert (z. B. Nähe Ofen) | bis −35 % Helligkeit, Rauheit +0.1 |

**`MeshFactory.rounded_box`**: schreibt zusätzlich `COLOR.r = 1` auf Vertices im Fasenband (Normale ≠ Flächennormale),
sonst 0, und Box-UVs in `UV` (für Atlas/Decals). Das gibt Kantenabnutzung ohne Textur und ohne Krümmungs-Bake.

### 5.3 Material-Rezepte
| Material | Rezept |
|---|---|
| **Rasen-Boden** (`shaders/ground.gdshader`, eine große Mesh-Ebene mit 0,5-m-Raster) | Splat aus einer kleinen Masken-Textur (1 Texel = 25 cm, in GDScript aus dem Level-Layout erzeugt): R = Erdweg, G = Sandstreuung, B = Ruß/Brandfleck. Grün: zwei Töne (`GRASS_MID`/`GRASS_LIGHT`) über Welt-FBM 4 m. Übergänge mit FBM-Offset ±0,3 aufbrechen, nie gerade Kanten. Vertex-Höhe: ±5–10 cm Wellen außerhalb der Stationen. |
| **Erde/Weg** | `DIRT_MID`, trockene Flecken `DIRT_LIGHT` (FBM 1,5 m), feucht `DIRT_DARK` nahe Wasser/Abschreck-Eimer. Kiesel als MultiMesh (8–15/m² am Wegrand). |
| **Holz** | Maserung = FBM gestreckt entlang Brettachse (`p * vec3(1.5, 1.5, 18)`), Brett-Variation pro Instanz über Hash der Position ±8 % Wert, ±4 % Farbton. Stirnholz dunkler. Kanten heller (Abnutzung). Immer einzelne Bretter mit Fugen. |
| **Formsand** | Feine Körnung 40/m ±6 %, gestampft = `SAND_RAMMED` mit Stampfabdrücken (Kreise). Rand des Abdrucks heller. |
| **Kaltes Werkzeugmetall** (Ofenmantel, Hammerkopf, Zange) | `metallic` 0.8, Rauheit 0.45–0.6, Hammerschlag-Dellen per Noise-Normal (Skala 8/m, Stärke 0.2), Ruß-Verlauf von oben (`SOOT`). |
| **Heißes Metall** | bestehender `metal.gdshader`. Pflicht: jedes heiße Teil hat ein Licht (Abschnitt 6.3); Abkühlen sichtbar über 6–12 s. |
| **Ziegel/Mauer** | Ziegel als echte Geometrie an Kanten/Ecken (Sekundärform), Flächen per Shader-Ziegelmuster mit Mörtelfugen, pro Ziegel ±10 % Wert. Unterste 40 cm schmutziger. |
| **Putz** (Hauswand) | `PLASTER`, große Flecken (FBM 3 m, ±6 %), Regenspuren unter Fenstern (vertikal gestreckter Noise), Sockel 40 cm dunkler. |
| **Stoff** (Figuren) | Atlas + Lambert-Wrap, Rauheit 0.9, Nähte/Taschen als Geometrie. |
| **Fenster** | Emission innen `#FFC27A` Energie 1.5–2.5 mit Vorhang-Silhouette (zweistufige Maske), Rahmen `TRIM_TEAL`. |

### 5.4 Kontur-Regeln
- **Post-Kontur** (`outline_post.gdshader`) bleibt, aber:
  - Farbe = Szenenfarbe × 0.35, 50 % gemischt mit `#2A2135` (Bildschirmtextur per `hint_screen_texture`); Deckkraft 0.85.
  - Dicke 1 px bei 1080p, skaliert mit Viewport-Höhe (`thickness = max(1.0, VIEWPORT_SIZE.y / 1080.0)`).
  - Nur Tiefenkanten + Normalkanten mit Schwelle 0.6 (keine Doppellinien an Fasen).
  - Distanz-Fade 18 → 35 m (aktuell 48 → 80 m).
  - Keine Kontur auf: Gras, Partikeln, Himmel, Emissions-Birnen, Boden-zu-Boden-Kanten. Umsetzung: Partikel schreiben
    keine Tiefe; Gras und Birnen schreiben `ROUGHNESS = 0.99` als Marker, der Kontur-Shader ignoriert Pixel mit
    Rauheit > 0.98 (Alpha-Kanal von `hint_normal_roughness_texture`).
- **Stencil-Kontur** (seit Godot 4.5, `BaseMaterial3D.stencil_mode = STENCIL_MODE_OUTLINE`) für Figuren und
  gerade anvisierte Interaktionsobjekte: `stencil_color` `#FFF3D6`, `stencil_outline_thickness` ≈ 0.02,
  0,2-s-Puls beim Betreten der Reichweite. Spielerfiguren bekommen eine dezente Kontur in Spielerfarbe
  (X-Ray-Modus `STENCIL_MODE_XRAY` wenn hinter Wänden).

---

## 6. Licht

### 6.1 Tageszeit-Presets
Standard für den Hinterhof ist **Dämmerung** (Sonne knapp über dem Horizont). Golden Hour ist eine Variante für
Menü/Marketing, Nacht für spätere Runden/Events. Werte für `rendering/lights_and_shadows/use_physical_light_units = false`
(Projekt-Standard). Die Werte sind im Labor-Render kalibriert (Abschnitt 6.6).

| Parameter | **Dämmerung (Standard)** | Golden Hour (Variante) | Nacht |
|---|---|---|---|
| Key (DirectionalLight3D) Farbe / Energie | `#FFA36B` / 1.3 | `#FFC48A` / **≤ 1.6** | Mond `#9FB4FF` / 1.1 |
| Key Höhe / Richtung | 10–14° · 3/4 von hinten-seitlich zu den Showcase-/Menü-Kameras (Rim auf Figuren); im Spiel ist die Kamera frei | 22–26° | 30–35° |
| `light_angular_distance` (weiche Schatten) | 1.5° | 1.2° | 0.8° |
| Fill (2. DirectionalLight3D, ohne Schatten, `light_specular` 0) | `#7F8FD8` / 0.3, Gegenrichtung | `#8796D8` / 0.35 | `#FFB070` / 0.12 (Glut-Bounce) |
| Ambient (Himmel) `ambient_light_energy` | 0.6 | 0.7 | 0.7 |
| Himmel Zenit / Horizont | `#34407F` / `#F0A07E` | `#4A5A9C` / `#F4B58C` | `#1B2452` / `#9A7FB0` |
| Himmel-Energie (`sky_energy_multiplier`) | 1.6 | 1.3 | 1.0 |
| Tiefennebel Farbe / Dichte (`fog_sky_affect` 0) | `#A88A9E` / 0.006 | `#D9A99A` / 0.006 | `#4E5684` / 0.010 |
| Praktische Lichter | 80 % | 30 % | 100 % |
| Emission Lichterketten-Birnen | 2.5 | 2.0 | 3.0 |
| Metall-Glühen (`glow_scale` im Metall-Shader) | 1.0 | 1.5 | 1.0 |

**Hierarchie-Regel (alle Presets):** Metall/Ofen ≥ 2 Blenden über der hellsten beleuchteten Umgebungsfläche;
Lichterkette und Fenster sind *zweite* Ebene, nie heller als die Schmelze. Schatten werden über Fill + LUT
Richtung `SHADOW_TINT` getönt.

### 6.2 Schatten
- Sonne: `shadow_enabled`, `directional_shadow_mode = SHADOW_PARALLEL_2_SPLITS`, `directional_shadow_max_distance` 40,
  `directional_shadow_blend_splits = true`, `shadow_blur` 1.0.
- Projekt: `rendering/lights_and_shadows/directional_shadow/soft_shadow_filter_quality` 3 (High) / 2 / 1 (Deck).
- Kontaktschatten unter Figuren und losen Objekten: Blob-`Decal` (weiche radiale Textur, `modulate` `#1E1A2C` @ 45 %,
  Größe = Grundfläche × 1,3) zusätzlich zum echten Schatten → klebt Objekte an den Boden.

### 6.3 Praktische Lichter
| Licht | Typ | Farbe | Energie / Reichweite | Schatten | Bewegung |
|---|---|---|---|---|---|
| Ofen | OmniLight3D | `#FF7A2A` | 1.5 + 3 × Hitze / 4.5 m | **ja** (einziges Omni mit Schatten), `light_size` 0.15 | Flackern: Noise ±12 % bei 6–9 Hz + langsames Atmen 0,7 Hz |
| Schmelze im Tiegel / heiße Gussteile | OmniLight3D (Pool, max. 4 gleichzeitig) | Farbe aus Schwarzkörper-Rampe | 2 × Temperatur / 2 m | nein | folgt Temperatur |
| Lichterkette | Emissions-Birnen (Energie 2.5, `#FFD08A`, siehe 6.1) + 3 OmniLights | `#FFC27A` | 0.6 / 5 m | nein | Birnen schwingen ±2 cm, 0,4 Hz |
| Fenster | AreaLight3D (neu in 4.7) vor jedem Fenster | `#FFC27A` | 0.8, `area_size` = Fenstergröße | nein | – |
| Hoflampe/Laterne | SpotLight3D | `#FFD9A0` | 1.2 / 8 m, 50° | nein | – |

Kabel der Lichterkette sind echte Kettenlinien (Catenary, Durchhang 0,4–0,6 m) als Rohr-Mesh 8 mm `#2A2423`.

### 6.4 Licht-Budget pro Ansicht
| | High | Medium | Steam Deck |
|---|---|---|---|
| Directional mit Schatten | 1 | 1 | 1 |
| Omni/Spot mit Schatten | 1 (Ofen) + 1 für Enthüllung | 1 | 0 |
| Omni/Spot ohne Schatten (sichtbar) | ≤ 8 | ≤ 6 | ≤ 4 |
| AreaLight3D | ≤ 3 | ≤ 1 | 0 (Omni-Ersatz) |

### 6.5 GI-Entscheidungen
| Feature | Entscheidung | Werte / Begründung |
|---|---|---|
| SDFGI | **aus** (alle Presets) | kleines Diorama, dünne Wände/Zäune → Lichtlecks; Kosten auf Deck; braucht Konvergenzzeit. |
| VoxelGI / LightmapGI | vorerst aus | später evtl. LightmapGI für finale statische Geometrie (braucht UV2). |
| SSAO | **an** | `ssao_radius` 0.6, `ssao_intensity` 1.4, `ssao_power` 1.5, `ssao_detail` 0.5, `ssao_light_affect` 0.1. Deck: `rendering/environment/ssao/quality` 0, halbe Größe. |
| SSIL | **an** (High/Medium) | `ssil_radius` 3, `ssil_intensity` 0.8. Bringt den orangen Bounce von Schmelze/Feuer auf Boden und Figuren – zentral für „das Glühen ist echt“. Deck: aus. |
| Volumetrischer Nebel | nur High | `volumetric_fog_density` 0.006, Albedo `#D9C2B5`, `volumetric_fog_anisotropy` 0.3, `volumetric_fog_length` 40; Ofenlicht `light_volumetric_fog_energy` 1.5 → glühende Luft. Sonst Ersatz: weiche Glow-Karte (Billboard) über dem Ofen. |
| SSR | aus | keine spiegelnden Flächen; Metall nutzt eigene Studio-Reflexion. |
| ReflectionProbe | 1 Box über dem Hof, `update_mode` Once | damit kaltes Metall den Hof spiegelt; auch auf Deck. |

### 6.6 Labor-Kalibrierung (03.10.2026)
Isolierte Projektkopie, nur Licht/Post + triplanares Welt-Rauschen auf `WorldBuilder.material()` geändert,
Geometrie unverändert. Bilder: `shots/artlab_golden_wide.png`, `shots/artlab_dusk_wide.png`, `shots/artlab_dusk_pour.png`
(Vergleich: `shots/backyard_wide.png`, `backyard_pour.png`).

| Befund | Konsequenz in dieser Bibel |
|---|---|
| AgX `white` 6 / `contrast` 1.3 + `glow_bloom` 0 entfernt den Grauschleier sofort; Farben werden satt ohne Sättigungs-Hack. | Abschnitt 7 bestätigt. |
| Golden Hour mit Key 2.4 überstrahlt das Metall: Gießstrahl und Bronzefreund-Glut gehen unter. | Standard = Dämmerung (Key 1.3); Golden Hour nur mit Key ≤ 1.6 und Metall-`glow_scale` 1.5. |
| Auch in der Dämmerung ist die Schmelze nur so hell wie das Helm-Glanzlicht – Regel 2 noch verletzt. | Heißes Metall beim Gießen: Emission ×1.5–2 und Pool-Licht (6.3); Tiegel auf Graphit `#3A3436` umstellen (orange Tiegel ist das gesättigteste Objekt im Bild). |
| Birnen-Emission 6 → 2.5 nimmt der Lichterkette die Bildhoheit, Stimmung bleibt. | Werte in 6.1. |
| Himmel-Zenit wird unter AgX bei Energie 1.0 schlammig braun-schwarz. | `sky_energy_multiplier` 1.6 (Startwert, noch nicht gerendert – beim Umsetzen prüfen), `fog_sky_affect` 0 (6.1); langfristig eigener Sky-Shader (10.5). |
| Isotropes Welt-Rauschen wirkt auf Putz, Erde, Stein gut, auf Holz wie Schmutzschlieren; auf Rasen wie Teppich. | Holz braucht gerichtete Maserung (5.3); Rasen braucht Gras-Geometrie (10.2), Rauschen allein reicht nicht. |
| Checklisten-Schnitt (Abschnitt 14): Ist-Stand ≈ 3,5 → nur Licht/Post/Rauschen ≈ 4,3. | **Licht allein bringt ~1 Punkt.** Der Sprung auf ≥ 8 braucht Boden, Assets, Figuren und Dressing (WP 2–6). |

---

## 7. Post-Processing

| Bereich | Einstellung |
|---|---|
| Tonemapper | `TONE_MAPPER_AGX`, `tonemap_agx_white` **6.0** (Bereich 4–8), `tonemap_agx_contrast` **1.3**, `tonemap_exposure` 1.0. Keine Auto-Belichtung (Metall-Shots „pumpen“ sonst). |
| Glow | `glow_blend_mode` Screen (4.6+-Default), `glow_intensity` 0.6, `glow_strength` 1.0, **`glow_bloom` 0.0**, `glow_hdr_threshold` 1.2, `glow_hdr_scale` 2.0, Levels: 1 = 0, 2 = 0.6, 3 = 0.8, 4 = 0.4, 5 = 0.2 (breiter, weicher Hof um Schmelze). Nur HDR-Emission darf glühen. |
| Farbkorrektur | `adjustment_enabled`, Kontrast 1.05, Sättigung 1.1; `adjustment_color_correction` = 3D-LUT 32³ pro Tageszeit, gebacken von einem Tool-Skript `game/tools/bake_lut.gd`: Split-Toning Schatten → `#3B3F6B` (15 %), Lichter → `#FFD9A0` (10 %), leichte S-Kurve. Kein Photoshop nötig. |
| Vignette | ja, dezent: Ecken −18 %, Radius 0.75, Weichheit 0.45. Als `ColorRect`-Shader in einem `CanvasLayer` unter dem HUD. |
| DOF | Gameplay: **aus**. Menü/Shop/DrawPad-Hintergrund: `CameraAttributesPractical` `dof_blur_far_distance` 8, `dof_blur_far_transition` 6, `dof_blur_amount` 0.08. Enthüllungs-Nahaufnahme: Fern-Unschärfe ab 3 m für 1,2 s. |
| Filmkorn | **nein** (Stream-/TikTok-Kompression macht Matsch; kostet Lesbarkeit). Stattdessen `rendering/anti_aliasing/quality/use_debanding = true` gegen Streifen im Dämmerhimmel. |
| Chromatische Aberration, Lens Dirt | nein |
| Anti-Aliasing | MSAA 3D 4× (High) / 2× (Medium) + SMAA (`screen_space_aa` = 2) für Post-Konturen und Alpha-Gras. **Kein TAA** (Geisterbilder bei Funken). Deck: MSAA aus, SMAA an. |
| Auflösung | Deck: `rendering/scaling_3d/mode` FSR 1.0, `scale` 0.8, `fsr_sharpness` 0.2. |

---

## 8. Kamera

### 8.1 Spielkamera (`CameraRig`)
| Parameter | Wert | aktuell |
|---|---|---|
| FOV (vertikal) | 50° | 55° |
| Abstand (SpringArm) | 7.0 m Standard, Zoom 4,5–9 m (Mausrad/Schultertasten) | 6.5 m fest |
| Neigung | −35° Standard, Grenzen −65° … −12° | −31,5°, −74° … +20° |
| Zielpunkt | Figur + (0, 1.1, 0) + Vorausschau 0,5 m in Laufrichtung (Lerp 3/s) | +1.4 m, keine Vorausschau |
| Positionsdämpfung | kritisch gedämpfte Feder, Halbwertszeit 0.08 s horizontal / 0.18 s vertikal (Sprünge reißen die Kamera nicht) | `lerp` 14/s |
| Maus | direkt, ungeglättet | ok |
| Gamepad | Kurve Exponent 1.6, max. 180°/s Gieren, 110°/s Neigen, Anlauf 0.12 s | linear 2.6 rad/s |
| Update | `_process`, liest `get_global_transform_interpolated()` der Figur | `global_position` |

### 8.2 Kollision und Verdeckung
- `SpringArm3D.shape` = Kugel r 0.25, `margin` 0.2, `collision_mask` = nur Ebene „Kamera-Blocker“ (Hauswand, Schuppen) –
  **nicht** Zaunlatten, Props, Spieler, Items.
- Ausfahren nach Kollision weich über 0.25 s, Einfahren sofort.
- Objekte zwischen Kamera und Figur (Zaun, Baum, Schuppen) blenden per Dither auf 30 % in 0.15 s aus
  (Uniform im Oberflächen-Shader, Raycast/ShapeCast pro Frame).

### 8.3 Kamerawackeln (Trauma-Modell nach Eiserloh, GDC 2016)
`offset = max_offset × trauma² × noise(t × 18 Hz)`; max. Versatz 0.12 m, max. Rollen 1.5°; Abbau 1.6/s;
volle Wirkung ≤ 3 m vom Ereignis, null ab 12 m. Optionen-Regler 0–100 % (Default 70 %, Barrierefreiheit).

| Ereignis | Trauma |
|---|---|
| Hammerschlag auf Form | 0.35 |
| Form zerbricht (Enthüllung) | 0.5 |
| Bronzefreund-Gong | 0.4 |
| Dampfexplosion | 0.6 |
| schweres Ablegen/Fallen | 0.15 |
| Gießen (Dauer-Rumpeln) | 0.05 |

### 8.4 Hitstop
**Nie `Engine.time_scale` anfassen** – das verlangsamt die Host-Physik und damit alle Mitspieler.
Hitstop ist lokal und visuell: AnimationTree der handelnden Figur und das Mesh des getroffenen Objekts
für 60–110 ms einfrieren (Hammer 70 ms, Formbruch 110 ms, perfektes „STOPP“ 90 ms), dazu 1 Frame Weiß-Blitz
auf dem Objekt (Emission +0.6) und FOV-Punch −2°, Rückkehr in 0.2 s.

### 8.5 Enthüllungs- und Marketing-Kamera
- Enthüllung: weicher Zoom (FOV 50 → 42, Abstand −20 %) auf das Gussteil für 1,2 s, Ein-/Ausblendung 0,35 s
  ease-in-out, für alle Spieler im Umkreis von 6 m; nie Steuerung wegnehmen.
- Fotomodus/Trailer-Kamera (Debug-Taste): freie Kamera mit Glättung, DOF, ohne HUD – für Steam-Capsule und Clips.

---

## 9. Animation und Spielgefühl („richtig flüssig“)

### 9.1 Fundament (zuerst umsetzen)
1. `physics/common/physics_interpolation = true`. Teleports rufen `reset_physics_interpolation()`.
2. Kamera und alle Visuals lesen interpolierte Transforms in `_process`.
3. Netzwerk: Remote-Spieler und Items mit Snapshot-Puffer (~100 ms) interpolieren; nie sichtbares Einrasten > 5 cm.
4. VSync an, Ziel 60 fps @1080p auf GTX-1060-Klasse; Deck 60 fps (Fallback: 40-fps-Lock).
5. Reaktion: Bewegungsstart ≤ 1 Frame sichtbar (Beschleunigung 14 reicht: 4,2 m/s in ~0,07 s).
   Dazu Körper-Neigung bis 8° in Beschleunigungsrichtung und 6° Rollen in Kurven.

### 9.2 Figuren-Animation
| Thema | Regel |
|---|---|
| Lokomotion | AnimationTree, BlendSpace1D `Idle` (0) → `Walking_A` (1,5 m/s) → `Running_A` (≥ 4,2 m/s); Abspieltempo = Geschwindigkeit / Clip-Geschwindigkeit (kein Fußrutschen > 10 %). |
| Blendzeiten | Lokomotion 0.15 s · Aktion rein 0.06 s / raus 0.18 s · Landen 0.05 s · Idle-Varianten 0.4 s |
| Oberkörper-Layer | Tragen/Gießen als Filter-Blend auf Wirbelsäule + Arme, Beine laufen weiter. |
| Hände | `TwoBoneIK3D` (in 4.7 vorhanden) an Tiegelgriffe, Hammerstiel, Blasebalg – Hände berühren immer, was sie halten. |
| Kopf | `LookAtModifier3D`: schaut zum nächsten Interaktionsobjekt/Mitspieler in 4 m, max. 60°. |
| Sekundärbewegung | `SpringBoneSimulator3D` für Helmriemen, Latz, Werkzeuggürtel (Steifigkeit 1.5, Drag 0.4). |
| Idle | nie statisch: Atmen (Brust 1.0–1.02 bei 0,25 Hz), Gewichtsverlagerung alle 6–10 s, Blinzeln alle 2–5 s. |

### 9.3 Squash & Stretch, Ausholen
- Volumenerhaltend auf dem Visual-Knoten (nicht dem Physik-Körper).
- Absprung: Strecken 1.12 für 0.08 s · Landung: Stauchen 0.82, Rückkehr über Feder (4 Hz, Dämpfung 0.5) · Aufheben: 0.92.
- **Jede große Aktion:** Ausholen 80–150 ms → Aktion 50–80 ms → Nachschwingen 200–300 ms.
  Hammer: heben 0.15 s, Schlag 0.06 s, Rückprall 0.25 s. Werfen: 0.12 s Rücklehnen 10°, Loslassen 0.05 s.
- Stationen reagieren: Formkasten hüpft 3 cm und staucht beim Stampfen; Ofendeckel klappert bei hoher Hitze;
  Blasebalg drückt mit Ease-Out-Back; Verkaufskiste ploppt (1.15 → 1.0, elastisch 0.35 s); Münzen fliegen zum HUD.

### 9.4 Prozedurale Umgebungsanimation
| Element | Technik | Werte |
|---|---|---|
| Gras | Vertex-Shader, Welt-Noise, globale Shader-Uniforms `wind_dir`/`wind_strength` | Böen 0,6 Hz, Spitzen-Ausschlag 6 cm; Spieler drücken Gras weg (Uniform-Array der Spielerpositionen, Radius 0,6 m) |
| Büsche/Bäume | Vertex-Sway nach Höhe gewichtet | 2 cm oben, 0,3 Hz |
| Lichterkette | Vertex-/Knoten-Schwingen pro Birne mit Phasenversatz | ±2 cm, 0,4 Hz |
| Wäscheleine, Planen, Fahnen | Vertex-Welle zum freien Rand | 1,2 Hz, 5 cm |
| Ofenschornstein | GPU-Partikel Rauch | 6–10 Puffs, Aufstieg 0,6 m/s |
| Motten um Lampen | 3–5 Partikel je Lampe, Orbit | nur Dämmerung/Nacht |
| Glühwürmchen, fallende Blätter | Partikel, sehr sparsam | Nacht / Herbst-Event |

---

## 10. Umgebung und Dressing

### 10.1 Tiefenebenen
- **Vordergrund (0–3 m vor Kamera):** Grasbüschel, Randobjekte, angeschnittene Zaunpfosten – rahmen das Bild.
- **Spielfeld:** Stationen mit klaren Laufwegen.
- **Hintergrund:** Haus mit Satteldach, Nachbardächer (KayKit-City-`building_*` als Silhouetten, entsättigt),
  Baumkronen, Straßenlaterne, ferner Stadtschein am Horizont. Luftperspektive über Tiefennebel `fog_aerial_perspective` 0.4.

### 10.2 Dichte
| Zone | Ziel |
|---|---|
| Laufwege (1,6 m breit zwischen Stationen) | ≤ 0,1 Props/m², kein Gras |
| Spielfeld-Ränder | 0,25–0,4 Props/m² |
| Zaun-/Hausränder | ~1,0 Props/m² (Eimer, Ziegelstapel, Säcke, Bretter, Blumentöpfe, Unkraut, Gießkanne, Schrott) |
| Gras | 250–400 Halme/m² als Büschel (MultiMesh, 8–12 Halme pro Büschel, ~30 Büschel/m²), Höhe 12–25 cm, Sichtweite 30 m. MultiMesh in 8 × 8-m-Kacheln (Frustum-Culling), ab 15 m 4-Halm-Büschel, Dreiecke Gras ≤ 300k (High) / 100k (Deck) |

### 10.3 Boden-Variation
1. Erdwege vom Tor zu den Stationen (Splat-Maske), Trampelpfad-Kanten mit Gras-Ausdünnung.
2. Ofen-Zone: Rußring r 1,5 m, Schlackekrümel; Formkasten-Zone: Sandstreuung; Abschreck-Eimer: Pfütze.
3. Decals (≤ 20): Ruß, Ölflecken, Fußspuren, Brandflecken – Texturen prozedural aus Noise gebacken oder CC0.
4. Leichte Höhenwellen (5–10 cm) im Rasen außerhalb der Stationen.
5. Nichts endet an einer sichtbaren Kante: hinter dem Zaun Nachbargärten, Hecke, Bäume.

### 10.4 Landmarken (Silhouetten gegen den Himmel)
1. **Ziegel-Ofen mit Schornstein** (Heldenobjekt, höchster Kontrast).
2. Haus mit Satteldach, Schornstein, Regenrinne, Hintertür mit Vordach und Lampe.
3. Großer Baum (Apfel/Eiche) mit Reifenschaukel.
4. Schuppen mit Wellblechdach und offener Tür (Werkzeug sichtbar).
5. Wäscheleine mit Wäsche (bewegt sich).
6. Lichterkette als „Decke“ über dem Arbeitsbereich.

### 10.5 Himmel
Eigener Sky-Shader statt `ProceduralSkyMaterial`-Standardlook: 3-Stufen-Verlauf (Zenit/Mitte/Horizont),
Sonnenscheibe mit weichem Hof, zwei Lagen stilisierter Wolken (Noise, flache Unterseite, beleuchtet `CLOUD_LIT`,
Schatten `CLOUD_SHADE`, Drift 0,002 UV/s), Sterne blenden nachts ein. Vorlagen siehe Quellen (godotshaders „Stylized Sky“).

---

## 11. VFX-Sprache
- **Formen:** klobig und klar. Funken = geschwindigkeitsausgerichtete Streifen 2–6 cm, Kern `#FFF1C2` (HDR 8) →
  Schweif `#FF6A1A`. Rauch = weiche runde Puffs, zweitonig (oben `#E9E1D6`, unten `#9C8F9A`). Staub = sandfarben
  `#D8C194`, flach. Dampf = weiß, schnell steigend und wachsend.
- **Timing:** harter Start (0,05 s), lange Ease-Out-Ausläufe, Einblenden mit Überschwingen.
- **Farbbedeutung:** Orange/Weiß = Hitze/Gefahr · Weiß/Blau = Dampf/Kühlung · Gold = Geld/Belohnung · Grün = gute Note · Rot = schlecht.
- **Jedes Ereignis = VFX + SFX + Kamera + UI.** Beispiel Enthüllung: Hammer (Hitstop 110 ms, Trauma 0.5) →
  6–10 Sandbrocken (Physik) + Staubwolke + Funken falls heiß → Glanz-Streiflicht über das Teil (0,4 s) →
  Notenstempel poppt mit Bounce.
- **Hitzeflimmern:** Bildschirm-Verzerrung über Ofen/Schmelze (nur High).
- **Budget:** ≤ 2000 Partikel sichtbar (High), ≤ 800 (Deck); max. 12 große überlappende Rauch-Quads.

---

## 12. UI-Sprache
| Element | Regel |
|---|---|
| Schrift | Fredoka (OFL, vorhanden) 500/600/700; Logo/Titel optional Lilita One (OFL). |
| Größen @1080p | Titel 72 · H2 48 · Text 30 · Hinweis 26 · Klein 22 (Minimum). Skaliert mit Höhe (`canvas_items`). |
| Knöpfe | bestehend: Radius 18, Unterkante 6 px; Hover Scale 1.04 in 0.08 s, Druck 0.96; Fokus-Ring sichtbar für Gamepad. |
| Panels | `PANEL` 82 %, 3 px Innenrand Paper @ 10 %, Schatten 0/4/12 @ 25 %. |
| Bewegung | alles animiert rein (Scale 0.9 → 1.0, Back-Ease 0.25 s, Fade 0.15 s) und raus; Zahlen rollen und hüpfen. |
| Tasten-Prompts | Glyphe statt „[F halten]“: Tastenkappe 44 × 44 px (Paper, Ink-Rand 3 px, Unterkante 4 px) + Aktionswort. Gamepad-Glyphen schalten automatisch auf das zuletzt benutzte Gerät. Halten-Aktionen: radialer Füllring um die Glyphe. |
| Welt-Prompts | über dem Zielobjekt verankert (0,4 m über Bounds), Pop-in 0.12 s – nicht als Text unten mittig. |
| Welt-Labels | `Label3D` nur für dynamische Info (Preise, Noten, Spielernamen): Billboard, Fredoka 700, `outline_size` 18. Stationsschilder („VERKAUF“, „KATALOG“) sind **bemalte Holzschilder** (Textur/Decal), keine schwebende UI-Schrift. |
| Diegetisch zuerst | Temperatur = Zeiger-Thermometer am Tiegelgriff, Füllstand = Steiger im Formkasten. Zahlen nur sekundär. |
| HUD | oben links Geld (Münz-Icon statt „$“), oben rechts Auftragskarte, unten mittig nur kontextuell. Safe Area 5 %. Max. 3 HUD-Elemente gleichzeitig. |
| Hauptmenü | 3D-Diorama des echten Hinterhofs in Dämmerung oder Golden Hour, Kamera kreist langsam (0,02 rad/s), DOF; Logo „MOLTEN MATES“ mit Metall-Verlauf `#FFD27A` → `#FF6A1A`, Ink-Kontur 10 px, Glow. Nie Testszenen zeigen. |
| DrawPad | Papierbogen auf Werkbank (unscharfer 3D-Hintergrund), Stift-Cursor, leicht zittrige Tintenlinie; Vorschau mit Metallglühen. |

---

## 13. Qualitäts-Presets

| Einstellung | High (PC) | Medium | Steam Deck |
|---|---|---|---|
| 3D-Auflösung | 1.0 | 1.0 | FSR 1.0 @ 0.8 |
| MSAA / SMAA | 4× / an | 2× / an | aus / an |
| Sonnenschatten | 4096, 2 Splits, Filter 3 | 2048, 2 Splits, Filter 2 | 2048, 2 Splits, Filter 1, max. 30 m |
| Ofen-Schatten | an | an | aus |
| SSAO | voll | halbe Größe | halbe Größe, Qualität niedrig |
| SSIL | an | halbe Größe | aus |
| Volumetrischer Nebel | an | aus | aus |
| Glow | Levels 2–5 | Levels 2–4 | Levels 2–4 |
| Gras Dichte / Sichtweite | 100 % / 30 m | 70 % / 22 m | 40 % / 15 m |
| Partikel | 100 % | 70 % | 40 % |
| Hitzeflimmern | an | aus | aus |
| AreaLight3D | an | 1 | aus (Omni) |
| Ziel | 60 fps | 60 fps | 60 fps (40-fps-Lock als Fallback) |

Steam setzt auf dem Deck die Umgebungsvariable `SteamDeck=1` → Preset beim ersten Start automatisch wählen.

---

## 14. Screenshot-Checkliste (Kritiker bewertet 1–10)

Jeder Review-Screenshot (mindestens: `--cam=wide`, `pour`, `reveal`, `side` + Menü + DrawPad) wird pro Punkt bewertet.
**Bestanden:** Durchschnitt ≥ 8 und kein Punkt < 6.

| # | Kriterium | 10 = | 5 = |
|---|---|---|---|
| 1 | **Silhouetten** | Alle Stationen und Figuren als Schwarzfläche im 460 × 215-Thumbnail erkennbar | Klötze, die nur mit Farbe unterscheidbar sind |
| 2 | **Fokus / Werthierarchie** | Auge landet in < 1 s auf Metall/Ofen; das ist der hellste Punkt | Hellste Punkte am Bildrand (Lampen, Himmel) |
| 3 | **Palette** | Nur Palette-Farben, 60/30/10, klare Warm-Kalt-Trennung | Zufallsfarben, Akzente konkurrieren |
| 4 | **Material-Reichtum** | Jede Fläche hat Verlauf + Variation + Kantenabnutzung | Einfarbige Flächen > 5 % des Bilds |
| 5 | **Boden** | Gras, Wege, Flecken, Übergänge, Höhe | Platte mit harter Kante |
| 6 | **Dichte / Storytelling** | Ränder voller glaubwürdigem Gerümpel, Laufwege frei | Objekte stehen einsam auf Leere |
| 7 | **Tiefe** | Vorder-, Mittel-, Hintergrund + Luftperspektive | Alles auf einer Ebene, Hintergrund = Wand |
| 8 | **Licht** | Key/Fill/Rim lesbar, getönte weiche Schatten, Praktisch-Lichter erzählen | Gleichmäßig grau, schwarze Schatten |
| 9 | **Figuren-Appeal** | Proportionen, Pose mit Aktionslinie, Hände greifen Objekte | Steife Puppe, Hände schweben |
| 10 | **Bewegung im Standbild** | Funken, Rauch, Wind, Posen deuten Bewegung an | Eingefroren |
| 11 | **VFX** | Klobig, farblich bedeutungsvoll, gut dosiert | Winzig, fehlen oder überstrahlen |
| 12 | **UI** | Glyphen, verankert, Palette, keine Debug-Texte | Nackter Text, Platzhalter-Titel |
| 13 | **Technische Sauberkeit** | Kein Aliasing, Z-Fighting, Schweben, Clipping, Konturrauschen, Lichtlecks | Sichtbare Fehler |
| 14 | **Komposition** | Drittelregel, klare Bühne, ruhige Ränder | Zufällig, Objekte an Bildkante angeschnitten |
| 15 | **Steam-Capsule-Test** | Fremde würden draufklicken; neben Referenzen (Abschnitt 2) nicht peinlich | „Sieht aus wie ein Prototyp“ |

---

## 15. Umsetzungs-Reihenfolge (nach Wirkung pro Aufwand)

| WP | Inhalt | Dateien | Aufwand |
|---|---|---|---|
| 1 | **Licht & Post**: Presets, AgX, Glow, LUT-Tool, Vignette, AA, Physik-Interpolation | `backyard.gd`, `world_builder.gd`, `project.godot`, `tools/bake_lut.gd`, `camera_rig.gd` | 1 Tag |
| 2 | **Boden & Gras**: Boden-Mesh + Splat-Shader, Gras-MultiMesh mit Wind/Trampeln, Decals | `shaders/ground.gdshader`, `shaders/grass.gdshader`, `scripts/gfx/grass_field.gd` | 2 Tage |
| 3 | **Oberflächen-Shader** + Fasen-Maske in `MeshFactory`, Holz/Sand/Metall/Ziegel-Rezepte, Kontur-Update | `shaders/stylized_surface.gdshader`, `mesh_factory.gd`, `outline_post.gdshader` | 2 Tage |
| 4 | **Figuren**: KayKit-Rig, AnimationTree, IK, LookAt, SpringBones (API von `PlayerModel` bleibt) | `player_model.gd`, `assets/models/characters/` | 3–4 Tage |
| 5 | **Stationen neu modellieren** (Ziegel-Ofen, Bretter-Formkasten, Graphit-Tiegel, Werkbank, Verkaufskiste, Schilder) | `foundry/stations/*.gd` | 3 Tage |
| 6 | **Dressing & Landmarken & Himmel** mit CC0-Packs | `backyard.gd`, `assets/models/*`, `shaders/sky.gdshader` | 2 Tage |
| 7 | **Kamera-Feel**: Feder, Zoom, Verdeckung, Trauma, Hitstop | `camera_rig.gd`, neues `scripts/gfx/camera_fx.gd` | 1 Tag |
| 8 | **UI**: Glyphen, Welt-Prompts, HUD, Menü-Diorama, Logo | `ui/*.gd` | 2 Tage |
| 9 | **VFX-Pass** nach Abschnitt 11 | `foundry/fx/*` | 1–2 Tage |
| 10 | **Qualitäts-Presets + Deck-Erkennung** | neues `scripts/core/graphics_settings.gd` | 1 Tag |

Nach jedem WP: Screenshots (`godot-render … --cam=wide|pour|reveal|side`), Checkliste ausfüllen, Tests grün.

---

## 16. Quellen und Techniken (2024–2026 bevorzugt)

**Godot-Features (geprüft gegen 4.7.2)**
- AgX-Parameter `tonemap_agx_white` (Default 16.29) / `tonemap_agx_contrast` (Default 1.25), eingeführt mit PR #106940 („agx-add-white-contrast“): https://remotebranch.eu/Stowage/godot/commit/8105ff7ac735f83be221296a6bb9b22caa7d9253
- Godot 4.5: Stencil-Buffer, Outline/X-Ray-Modi: https://godotengine.org/releases/4.5/ · https://80.lv/articles/mind-bending-power-of-godot-4-5-s-stencil-support · https://engineer-game.org/devlog/2026/02/08/object-outline.html
- Godot 4.6: SSR neu, Glow vor Tonemapping, Screen als Default-Blend, AgX-Steuerung: https://www.phoronix.com/news/Godot-4.6-Released · https://gamefromscratch.com/godot-4-6-sneak-peek/
- Godot 4.7: AreaLight3D, HDR-Ausgabe: https://linuxiac.com/?p=214411 · https://ziva.sh/blogs/godot-4-7
- Physik-Interpolation (3D seit 4.4): https://docs.godotengine.org/en/4.4/tutorials/physics/interpolation/physics_interpolation_introduction.html · Kamera-Jitter: https://bugnet.io/blog/fix-godot-physics-interpolation-jitter-on-camera-follow
- SpringBoneSimulator3D: https://docs.godotengine.org/en/4.5/classes/class_springbonesimulator3d.html
- Decals / Blob-Schatten: https://docs.godotengine.org/en/4.4/tutorials/3d/using_decals.html

**Stilisierte Techniken**
- Gras mit MultiMesh + Wind + Interaktion (Serie, 3 Teile): https://hexaquo.at/pages/grass-rendering-series-part-2-full-geometry-grass-in-godot/ · https://hexaquo.at/pages/grass-rendering-series-part-3-animating-and-interacting-with-grass-in-godot/
- Gras-Shader mit Boden-zu-Spitze-Verlauf (Terrain-Farbe unten): https://godotshaders.com/shader/stylized-cartoon-grass/ · https://godotshaders.com/shader/stylized-multimesh-grass-shader/ · https://github.com/2Retr0/GodotGrass
- Normalen-Trick für Gras (unten Up-Vektor, oben Original): https://polycount.com/discussion/comment/2725667
- Triplanar-Boden-Blending: https://godotshaders.com/shader/terrain-mesh-blending-godot-4-3/
- Toon-Ramp-Varianten (zur Abgrenzung, Abschnitt 5.1): https://godotshaders.com/shader/flexible-toon-shader-godot-4/ · https://godotshaders.com/shader/complete-toon-shader/
- Post-Process-Kontur Tiefe/Normalen: https://godotshaders.com/shader/post-process-outline-depth-normal/ · https://github.com/jocamar/Godot-Post-Process-Outlines
- Stilisierter Himmel: https://godotshaders.com/shader/stylized-sky/ · https://godotshaders.com/shader/stylized-sky-with-procedural-sun-and-moon/
- Verlaufs-Atlas-Technik: https://bazaar.blendernation.com/listing/this-blender-scene-uses-only-one-texture-texture-atlas-colour-palette-tutorial/ · https://polycount.com/discussion/235452/is-there-a-quick-way-to-make-a-color-palette-texture
- Verdeckung per Dither/Maske: https://forum.godotengine.org/t/shader-that-hides-cuts-objects-between-the-player-and-the-camera/52273 · https://pandaqi.itch.io/package-party/devlog/111166/25-tutorial-dynamic-masking

**Spielgefühl**
- Eiserloh, „Juicing Your Cameras With Math“ (GDC 2016), Trauma-Shake: https://www.gamedeveloper.com/programming/video-sprucing-up-cameras-with-math
- Jonasson & Purho, „Juice it or lose it“ (2012): https://roblog.co.uk/2024/03/juicy-games/
- Swink, *Game Feel* – 100-ms-Reaktionsschwelle: https://en.wikipedia.org/wiki/Game_feel
- Hitstop in Godot 4 (und warum wir es nicht global machen): https://dev.to/saltmire/godot-4-screen-shake-and-hit-stop-in-one-script-11eh

**Assets**
- KayKit (CC0): https://kaylousberg.itch.io/kaykit-adventurers · GitHub `KayKit-Game-Assets/*` (Lizenzdateien geprüft)
- Kenney Starter Kits (MIT): GitHub `KenneyNL/Starter-Kit-3D-Platformer` u. a.
- Quaternius Universal Animation Library (CC0, nur außerhalb GitHub verfügbar): https://quaternius.com/packs/universalanimationlibrary.html
- How to Fish (Referenz, Erfolg 2026): https://www.pcgamer.com/games/sim/the-latest-cooperative-craze-is-a-physics-based-fishing-simulator-where-you-can-launch-your-catch-into-the-air-and-no-scope-it-with-a-sniper-rifle/

---

## Anhang A – Shader-Skizzen (kompilieren fehlerfrei mit Godot 4.7.2, Forward+)

Startpunkte, keine fertigen Shader. Alle nutzen `res://shaders/fx_common.gdshaderinc` (`fx_noise`, `fx_fbm`).

### A.1 `stylized_surface.gdshader` (Abschnitt 5.2)
```glsl
shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
#include "res://shaders/fx_common.gdshaderinc"

uniform vec4 base_color : source_color = vec4(0.6, 0.38, 0.25, 1.0);
uniform float gradient_strength : hint_range(0.0, 1.0) = 0.25;
uniform float object_height = 1.0;      // Mesh ist um den Ursprung zentriert (rounded_box)
uniform float macro_strength = 0.08;
uniform float grain_strength = 0.04;
uniform float edge_wear = 0.12;         // braucht COLOR.r = Fasen-Maske aus MeshFactory
uniform float roughness_base : hint_range(0.0, 1.0) = 0.8;
uniform float occlusion_fade : hint_range(0.0, 1.0) = 0.0;  // Kamera-Verdeckung (Abschnitt 8.2)

varying vec3 world_pos;
varying float obj_y;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	obj_y = VERTEX.y;
}

void fragment() {
	float h = smoothstep(-0.5 * object_height, 0.5 * object_height, obj_y);
	vec3 c = base_color.rgb * mix(1.0 - gradient_strength, 1.0, h);      // Höhenverlauf
	c *= mix(0.72, 1.0, smoothstep(0.0, 0.15, world_pos.y));              // Bodenkontakt
	float macro = fx_fbm(world_pos * 0.25) - 0.5;
	float grain = fx_noise(world_pos * 6.0) - 0.5;
	c *= 1.0 + 2.0 * (macro * macro_strength + grain * grain_strength);
	c *= mix(vec3(1.0), vec3(1.03, 1.0, 0.96), clamp(macro * 2.0, 0.0, 1.0)); // warmer Drift
	float wear = COLOR.r;
	c *= 1.0 + wear * edge_wear;                                           // Kantenabnutzung
	ALBEDO = c;
	ROUGHNESS = clamp(roughness_base + grain * 0.16 - wear * 0.1, 0.0, 1.0);
	SPECULAR = 0.3;
	if (occlusion_fade > 0.0) {                                            // Bayer-Dither
		ivec2 px = ivec2(FRAGCOORD.xy) % 4;
		int bayer[16] = int[](0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5);
		if (float(bayer[px.y * 4 + px.x]) / 16.0 < occlusion_fade) {
			discard;
		}
	}
}
```

### A.2 `grass.gdshader` (Abschnitt 9.4, MultiMesh-Büschel)
Globale Uniforms `wind_dir` (vec2) und `wind_strength` (float) unter *Projekteinstellungen → Shader Globals* anlegen.
`trample` setzt ein Skript jedes Frame auf dem gemeinsamen Material (xyz = Spielerposition, w = Radius 0.6, 0 = unbenutzt).
Instanzen nur um Y drehen und uniform skalieren.
```glsl
shader_type spatial;
render_mode cull_disabled, diffuse_lambert_wrap, specular_disabled;
#include "res://shaders/fx_common.gdshaderinc"

global uniform vec2 wind_dir;
global uniform float wind_strength;
uniform vec4 tip_color : source_color = vec4(0.553, 0.702, 0.376, 1.0);   // GRASS_LIGHT
uniform vec4 root_color : source_color = vec4(0.184, 0.353, 0.263, 1.0);  // GRASS_DARK
uniform float blade_height = 0.2;
uniform vec4 trample[4];

varying float tip;

void vertex() {
	tip = clamp(VERTEX.y / blade_height, 0.0, 1.0);
	vec3 world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float gust = fx_noise(vec3(world.xz * 0.35 - wind_dir * TIME * 0.6, TIME * 0.2));
	vec2 bend = wind_dir * (0.02 + 0.06 * gust * wind_strength);
	for (int i = 0; i < 4; i++) {
		vec2 away = world.xz - trample[i].xz;
		float push = trample[i].w > 0.0 ? 1.0 - smoothstep(0.0, trample[i].w, length(away)) : 0.0;
		bend += normalize(away + vec2(1e-4)) * push * 0.12;
	}
	vec3 offset_world = vec3(bend.x, -dot(bend, bend) * 0.5, bend.y) * tip * tip;
	float s2 = dot(MODEL_MATRIX[0].xyz, MODEL_MATRIX[0].xyz);
	VERTEX += (vec4(offset_world, 0.0) * MODEL_MATRIX).xyz / s2;          // Welt -> lokal (Rotation + uniforme Skalierung)
	NORMAL = normalize(mix(vec3(0.0, 1.0, 0.0), NORMAL, tip * 0.5));      // unten Boden-Normale: Gras verschmilzt mit dem Rasen
}

void fragment() {
	ALBEDO = mix(root_color.rgb, tip_color.rgb, tip);
	ROUGHNESS = 0.9;
	BACKLIGHT = vec3(0.15, 0.2, 0.05) * tip;   // Gegenlicht schimmert durch die Halme
}
```

### A.3 Konturfarbe aus der Szene (Änderung an `outline_post.gdshader`, Abschnitt 5.4)
```glsl
uniform sampler2D screen_tex : hint_screen_texture, filter_linear;
uniform vec4 line_color : source_color = vec4(0.165, 0.129, 0.208, 1.0);  // #2A2135
// ... Kantenerkennung wie bisher, Normal-Schwelle 0.6, Distanz-Fade 18 -> 35 m ...
vec3 scene = texture(screen_tex, SCREEN_UV).rgb;
ALBEDO = mix(scene * 0.35, line_color.rgb, 0.5);
ALPHA = edge * fade * 0.85;
```

### A.4 Stencil-Kontur für Interaktives (Abschnitt 5.4)
```gdscript
# BaseMaterial3D: legt automatisch ein next_pass-Material an.
mat.stencil_mode = BaseMaterial3D.STENCIL_MODE_OUTLINE
mat.stencil_color = Color("#FFF3D6")
mat.stencil_outline_thickness = 0.02
```
ShaderMaterials (z. B. `metal.gdshader`) schreiben den Stencil selbst (`stencil_mode write, compare_always, 1;`) und
bekommen ein `next_pass` mit vergrößerter Hülle, das nur bei Stencil ≠ 1 zeichnet.
