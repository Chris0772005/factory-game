# Credits

Third-party content shipped with Molten Mates. Where a pack came with a license file, it sits next to the files in `game/assets/`. Poly Haven content (CC0: `textures/`, `sky/`, `models/polyhaven/`) came without one, and the dump truck's `license.txt` (CC BY 4.0) is kept with its source in `tools/blender/sources/dump_truck_electronick/`; `game/assets/models/machinery/NOTICE.txt` says which file there is under which license.
Details on what was taken from each pack: `docs/ASSETS.md`.

## 3D models

| Pack | Author | License | Source | Used in |
|---|---|---|---|---|
| KayKit Character Pack: Adventurers 1.0 | Kay Lousberg (www.kaylousberg.com) | CC0 1.0 | github.com/KayKit-Game-Assets/KayKit-Character-Pack-Adventures-1.0 | `game/assets/models/kaykit_adventurers/` |
| KayKit Dungeon Remastered 1.0 | Kay Lousberg | CC0 1.0 | github.com/KayKit-Game-Assets/KayKit-Dungeon-Remastered-1.0 | `game/assets/models/kaykit_dungeon/` (GLB split into glTF + shared atlas by `tools/glb_to_gltf.py`) |
| KayKit Restaurant Bits 1.0 | Kay Lousberg | CC0 1.0 | github.com/KayKit-Game-Assets/KayKit-Restaurant-Bits-1.0 | `game/assets/models/kaykit_restaurant/` |
| KayKit Furniture Bits 1.0 | Kay Lousberg | CC0 1.0 | github.com/KayKit-Game-Assets/KayKit-Furniture-Bits-1.0 | `game/assets/models/kaykit_furniture/` |
| KayKit Halloween Bits 1.0 | Kay Lousberg | CC0 1.0 | github.com/KayKit-Game-Assets/KayKit-Halloween-Bits-1.0 | `game/assets/models/kaykit_halloween/` |
| KayKit Prototype Bits 1.0 | Kay Lousberg | CC0 1.0 | github.com/KayKit-Game-Assets/KayKit-Prototype-Bits-1.0 | `game/assets/models/kaykit_prototype/` |
| KayKit Medieval Hexagon Pack 1.0 | Kay Lousberg | CC0 1.0 | github.com/KayKit-Game-Assets/KayKit-Medieval-Hexagon-Pack-1.0 | `game/assets/models/kaykit_hexagon/` |
| KayKit City Builder Bits 1.0 | Kay Lousberg | CC0 1.0 | github.com/KayKit-Game-Assets/KayKit-City-Builder-Bits-1.0 | `game/assets/models/kaykit_city/` |
| Starter Kit 3D Platformer (grass models + colormap) | Kenney (www.kenney.nl) | Models CC0 1.0 (per README); repository code MIT, © Kenney | github.com/KenneyNL/Starter-Kit-3D-Platformer | `game/assets/models/kenney_platformer/` |

CC0 needs no attribution; we credit Kay Lousberg (the KayKit license text invites optional credit) and Kenney as a
courtesy. The Kenney MIT notice
(`kenney_platformer/LICENSE.md`) is kept with the files and must ship with the game.

## Fonts

| Font | Author | License | Used in |
|---|---|---|---|
| Fredoka | The Fredoka Project Authors | SIL Open Font License 1.1 | `game/assets/fonts/Fredoka.ttf` (`OFL.txt` next to it) |
| Barlow Condensed | The Barlow Project Authors (github.com/jpt/barlow) | SIL Open Font License 1.1 (github.com/google/fonts, `ofl/barlowcondensed`) | `game/assets/fonts/BarlowCondensed-*.ttf` (`BarlowCondensed-OFL.txt` next to them) – all game text |
| Patrick Hand | Patrick Wagesreiter | SIL Open Font License 1.1 | `game/assets/models/props/fonts/PatrickHand-Regular.ttf` (`OFL_PatrickHand.txt` next to it) – handwriting on notes |
| Cabin Sketch | The Cabin Project Authors | SIL Open Font License 1.1 | `game/assets/models/props/fonts/CabinSketch-Bold.ttf` (`OFL_CabinSketch.txt` next to it) – chalk lettering |
| Lilita One | Juan Montoreano | SIL Open Font License 1.1 (github.com/google/fonts, `ofl/lilitaone`) | `game/assets/ui/fonts/LilitaOne-Regular.ttf` (`OFL.txt` next to it) – logo, banners, money counter |

## Sound

Sound effects in `game/assets/sfx/real/` (scrap clatter, digging, hammer blows, ramming, pick-up, steps on concrete) are recordings from **Impact Sounds 1.0** by Kenney (www.kenney.nl), Creative Commons Zero (CC0 1.0); the pack's licence text is `game/assets/sfx/real/Kenney-License.txt`. All other sound effects in `game/assets/sfx/` are synthesized by our own `tools/sfx_gen.py`.

## Music

All music in `game/assets/music/` (`menu`, `backyard`, `garage`, `bell_foundry`, `iron_hall`) is written as notes and
synthesized by our own `tools/music_gen.py`. The pieces were composed by an AI assistant (Claude) at the owner's request:
no third-party rights, but this counts as AI-generated content and has to be declared in the Steam content survey.

## Foto-Oberflächen (CC0)

Fünf Textursätze von [Poly Haven](https://polyhaven.com) (CC0, 1k): `concrete_floor_worn_001`, `painted_plaster_wall`, `weathered_brown_planks`, `rusty_metal_02`, `brown_mud_dry`. Sie liegen in `game/assets/textures/pbr/` und werden über `shaders/env_photo.gdshaderinc` auf Boden, Wände, Holz, Erde und Metall gelegt.

Dazu `bark_brown_02` (Rinde) und `leafy_grass` (Laub).

Elf weitere Sätze von Poly Haven (CC0) in `game/assets/textures/scan/`, die als ganze Oberfläche dienen (`shaders/env_scan.gdshader`, `EnvMesh.scan`): `asphalt_02` und `concrete_pavers` (2k), `concrete_tiles_02`, `dirty_concrete`, `red_brick_03`, `red_brick`, `painted_worn_brick`, `beige_wall_001`, `yellow_plaster`, `box_profile_metal_sheet`, `bitumen` (1k). Straße, Gehwege, Hof, Mauern, Hallenwände und die Häuser der Schrotthalle bestehen daraus.

## Foto-Himmel (CC0)

„Kloofendal 48d Partly Cloudy (Pure Sky)“ von Greg Zaal und Jarod Guest, [Poly Haven](https://polyhaven.com/a/kloofendal_48d_partly_cloudy_puresky) (CC0). In `game/assets/sky/`: `day_sky_view.jpg` (oberer Teil des 8k-Bilds, das man sieht) und `day_sky_light.hdr` (2k, beleuchtet die Szene und spiegelt sich in Lack und Glas). Shader: `shaders/env_sky_photo.gdshader`.

## Gescannte Requisiten (CC0)

3D-Modelle von [Poly Haven](https://polyhaven.com) (CC0, 1k-Texturen) in `game/assets/models/polyhaven/`: Barrel_01, Barrel_02, barrel_03, wine_barrel_01, wooden_crate_01, wooden_crate_02, cardboard_box_01, wooden_bucket_01, cement_bag, shrub_02, shrub_03, old_tyre, metal_toolbox, painted_wooden_chair_01, propane_tank, wooden_ladder, street_lamp_01 (Straßenlaterne), fire_hydrant (Hydrant). `PhotoProp` tauscht sie gegen die Bausatz-Requisiten.

Werkstatt-Geräte (ebenfalls Poly Haven, CC0): tool_cart, metal_tool_chest, old_drill_press, bench_vice_01, hand_truck, industrial_storage_cart, old_military_compressor, power_box_01, steel_frame_shelves_01, cross_pein_hammer, pipe_wrench, WetFloorSign_01.

## Figuren (Stadt)

- Quaternius, „Ultimate Modular Men Pack“, „Ultimate Modular Women Pack“ und „Cyberpunk Game Kit“ (Bewegungen), CC0 1.0 – https://quaternius.com – `game/assets/models/quaternius/`

## Maschinen

- Hydraulikbagger (`game/assets/models/machinery/zx200_hd.glb`): „20 t class hydraulic excavator“, prozedural modelliert von den Mitwirkenden des Projekts „Construction Site Simulation“ (https://github.com/dtt-github/construction-site-simulation) nach den Maßen des OPERA-ZX200-Modells des Public Works Research Institute, Japan. Copyright 2026 DigitalTwin Technology GmbH and the Construction Site Simulation contributors. Apache License 2.0 (`game/assets/models/machinery/LICENSE-Apache-2.0.txt`; `NOTICE.txt` gibt die zugehörigen Hinweise aus der NOTICE-Datei des Projekts wieder). Datei unverändert übernommen; das Spiel bewegt die Teile, lackiert sie um und zeigt die Kabine aus `zx200_cab_open.glb`.
- Kipper-LKW (`game/assets/models/machinery/dump_truck.glb`): nach „Dump Truck“ von ElectroNick, https://sketchfab.com/3d-models/dump-truck-781c616da8f44982a59cb3fc3fa67f98, Lizenz CC BY 4.0 (http://creativecommons.org/licenses/by/4.0/). Die Vorlage liegt so, wie sie geholt wurde, mit ihrer Lizenzdatei in `tools/blender/sources/dump_truck_electronick/`. Änderungen (`tools/blender/dump_truck.py`): auf echte Größe gebracht, sechs Räder als eigene Teile abgetrennt, neue Materialien und Farben (roter Lack, graue Mulde; die Räder behalten die Reifen-und-Felgen-Textur der Vorlage), klare Scheiben, Kabine innen ausgekleidet, Rücklichter und Rundumleuchten ergänzt. Die Namensnennung steht auch im Spiel unter „Lizenzen“. Herkunft: Die Dateien stammen nicht direkt von Sketchfab, sondern aus einer Kopie des Sketchfab-Downloads im GitHub-Repository `Karanlashkari/Automotive-E-commerce-Website` (Commit `4e087f07e9db887810444e59ce830f9050c958fa`, Ordner `public/`; alle neun Dateien sind bytegleich mit dieser Kopie). Die Lizenzangabe steht in der `license.txt`, die Sketchfab jedem Download beilegt, und in der Modelldatei selbst. Die Sketchfab-Seite war von der Arbeitsumgebung aus nicht erreichbar: Vor einer Veröffentlichung dort prüfen, ob das Modell noch unter CC BY 4.0 steht und vom Urheber selbst stammt (die Materialnamen sehen nach einem Unreal-Engine-Projekt aus).
- Blender-Werkzeug `tools/blender/mm_kit.py`: in Teilen aus `assets/blender/blendkit.py` desselben Projekts übernommen (Copyright 2026 DigitalTwin Technology GmbH and the Construction Site Simulation contributors, Apache License 2.0), für dieses Spiel angepasst und erweitert. Wird nicht mit dem Spiel ausgeliefert.
- Bagger-Kabine (`zx200_cab_open.glb`): aus dem Kabinenteil des Baggers oben abgeleitet (Apache 2.0); `tools/blender/zx200_cab.py` höhlt den Block aus und schneidet die Fensteröffnungen.

## Code

Shader hash functions (`game/shaders/env_common.gdshaderinc`, `fx_common.gdshaderinc`, `vehicle_dirt.gdshader`) follow „Hash without Sine“ by Dave Hoskins (https://www.shadertoy.com/view/4djSRW), MIT License, Copyright (c) 2014 David Hoskins.
