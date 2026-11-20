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

Zwölf weitere Sätze von Poly Haven (CC0) in `game/assets/textures/scan/`, die als ganze Oberfläche dienen (`shaders/env_scan.gdshader`, `EnvMesh.scan`): `asphalt_02` und `concrete_pavers` (2k), `concrete_tiles_02`, `dirty_concrete`, `red_brick_03`, `red_brick`, `painted_worn_brick`, `beige_wall_001`, `yellow_plaster`, `box_profile_metal_sheet`, `bitumen`, `green_metal_rust` (1k). Straße, Gehwege, Hof, Mauern, Hallenwände, die Häuser der Schrotthalle und der Müllcontainer bestehen daraus.

## Foto-Himmel (CC0)

„Kloofendal 48d Partly Cloudy (Pure Sky)“ von Greg Zaal und Jarod Guest, [Poly Haven](https://polyhaven.com/a/kloofendal_48d_partly_cloudy_puresky) (CC0). In `game/assets/sky/`: `day_sky_view.jpg` (oberer Teil des 8k-Bilds, das man sieht) und `day_sky_light.hdr` (2k, beleuchtet die Szene und spiegelt sich in Lack und Glas). Shader: `shaders/env_sky_photo.gdshader`.

## Gescannte Requisiten (CC0)

3D-Modelle von [Poly Haven](https://polyhaven.com) (CC0, 1k-Texturen) in `game/assets/models/polyhaven/`: Barrel_01, Barrel_02, barrel_03, wine_barrel_01, wooden_crate_01, wooden_crate_02, cardboard_box_01, wooden_bucket_01, cement_bag, shrub_02, shrub_03, old_tyre, metal_toolbox, painted_wooden_chair_01, propane_tank, wooden_ladder, street_lamp_01 (Straßenlaterne), fire_hydrant (Hydrant), rollershutter_door (Rolltor), metal_trash_can, trashbag, utility_box_01 (Schaltkasten), exterior_aircon_unit (Klimagerät), water_manhole_cover (Kanaldeckel), painted_wooden_bench (Bank), concrete_road_barrier (Betonsperre), covered_car (Auto unter Plane), industrial_wall_lamp (Wandlampe), CashRegister_01 (Kasse), metal_office_desk (Schreibtisch), standing_chalkboard_01 (Kreidetafel), barrel_stove (Fass-Ofen); mit auf 512 Pixel verkleinerten Texturen: boombox, television_02, Ukulele_01, alarm_clock_01, brass_vase_02, Megaphone_01, vintage_electric_kettle, marble_bust_01, american_football, Drill_01, vintage_oil_lamp, horse_statue_01, clipboard, small_oil_can_01, oil_tin, book_encyclopedia_set_01, classic_laptop, mounted_fluorescent_lights (Leuchtstoffröhren), metal_jerrycan_green, plastic_crate_02, plastic_monobloc_chair_01. `PhotoProp` tauscht sie gegen die Bausatz-Requisiten oder stellt sie an ihren Platz (`place`, `stand`, `mount`, `hang`).

Werkstatt-Geräte (ebenfalls Poly Haven, CC0): tool_cart, metal_tool_chest, old_drill_press, bench_vice_01, hand_truck, industrial_storage_cart, old_military_compressor, power_box_01, steel_frame_shelves_01, cross_pein_hammer, pipe_wrench, WetFloorSign_01.

## Figuren (Stadt) – KI-erzeugt

Die fünf Stadtbewohner in `game/assets/models/people/` (Mann mit Schiebermütze, Pfandleiher, Polizist, Frau in gelber Jacke, junger Mann im Kapuzenpulli) sind **KI-erzeugte Inhalte**. Niemand hat sie von Hand modelliert, und sie zeigen keine echten Personen: Gesichter und Kleidung hat das Bildmodell aus einer Beschreibung erfunden.

- Entstehung (November 2026, alles über das Higgsfield-Konto des Inhabers, https://higgsfield.ai): je ein Studiobild der Person (Bildmodell „GPT Image 2.6“), daraus eine texturierte Figur mit Skelett und einem langsamen Gang („Meshy 7 image-to-3D“, rund 25.000 Dreiecke); für die erste Figur weitere Bewegungen aus derselben Bibliothek („Meshy rigging“: zügiges Gehen, Rennen, Winken).
- `tools/people.py` setzt daraus die Spielfiguren zusammen: Die Bewegungen der ersten Figur werden auf die anderen übertragen (alle haben dasselbe Skelett), ruhiges Stehen wird aus der Wink-Aufnahme gebaut, jede Bewegung wird auf den Boden gestellt, und die Texturen werden neu angeordnet (die Vorlage packt tausende kleine Flicken Kante an Kante, deren Farben aus ein paar Metern ineinanderlaufen; das Werkzeug legt gleichfarbige Flicken zusammen und lässt Abstand).
- Die Vorgangsnummern aller Erzeugungen stehen in `game/assets/models/people/NOTICE.txt`; die Ausgangsdateien liegen nicht im Repository (je 10 bis 13 MB), sind aber im Higgsfield-Konto abrufbar.
- **Rechte:** Laut Higgsfields Hilfeseite „Who owns my generations and can I use them commercially?“ (https://higgsfield.ai/creator-hub/help-center/account/who-owns-my-generations-and-can-i-use-them-commercially, Verweis auf Abschnitt 4.4 der Nutzungsbedingungen) beansprucht Higgsfield kein Eigentum an den Ergebnissen und schränkt die gewerbliche Nutzung nicht ein; die Ergebnisse sind nicht exklusiv, und für den Inhalt bleibt der Nutzer verantwortlich. Gelesen über eine Websuche am 20.11.2026, die Seite selbst war von der Arbeitsumgebung aus nicht erreichbar: vor einer Veröffentlichung die aktuellen Nutzungsbedingungen (https://higgsfield.ai/terms-of-use-agreement) noch einmal lesen.
- **Steam:** Das sind vorab erzeugte KI-Inhalte, die Spieler sehen. Sie müssen im Steam-Fragebogen zu Inhalten angegeben werden, zusammen mit der KI-komponierten Musik.

Ersatzfiguren, falls eine der Dateien fehlt: Quaternius, „Ultimate Modular Men Pack“, „Ultimate Modular Women Pack“ und „Cyberpunk Game Kit“ (Bewegungen), CC0 1.0 – https://quaternius.com – `game/assets/models/quaternius/`

## Maschinen

- Hydraulikbagger (`game/assets/models/machinery/zx200_hd.glb`): „20 t class hydraulic excavator“, prozedural modelliert von den Mitwirkenden des Projekts „Construction Site Simulation“ (https://github.com/dtt-github/construction-site-simulation) nach den Maßen des OPERA-ZX200-Modells des Public Works Research Institute, Japan. Copyright 2026 DigitalTwin Technology GmbH and the Construction Site Simulation contributors. Apache License 2.0 (`game/assets/models/machinery/LICENSE-Apache-2.0.txt`; `NOTICE.txt` gibt die zugehörigen Hinweise aus der NOTICE-Datei des Projekts wieder). Datei unverändert übernommen; das Spiel bewegt die Teile, lackiert sie um und zeigt die Kabine aus `zx200_cab_open.glb`.
- Kipper-LKW (`game/assets/models/machinery/dump_truck.glb`): nach „Dump Truck“ von ElectroNick, https://sketchfab.com/3d-models/dump-truck-781c616da8f44982a59cb3fc3fa67f98, Lizenz CC BY 4.0 (http://creativecommons.org/licenses/by/4.0/). Die Vorlage liegt so, wie sie geholt wurde, mit ihrer Lizenzdatei in `tools/blender/sources/dump_truck_electronick/`. Änderungen (`tools/blender/dump_truck.py`): auf echte Größe gebracht, sechs Räder als eigene Teile abgetrennt, neue Materialien und Farben (roter Lack, graue Mulde; die Räder behalten die Reifen-und-Felgen-Textur der Vorlage), klare Scheiben, Kabine innen ausgekleidet, Rücklichter und Rundumleuchten ergänzt. Die Namensnennung steht auch im Spiel unter „Lizenzen“. Herkunft: Die Dateien stammen nicht direkt von Sketchfab, sondern aus einer Kopie des Sketchfab-Downloads im GitHub-Repository `Karanlashkari/Automotive-E-commerce-Website` (Commit `4e087f07e9db887810444e59ce830f9050c958fa`, Ordner `public/`; alle neun Dateien sind bytegleich mit dieser Kopie). Die Lizenzangabe steht in der `license.txt`, die Sketchfab jedem Download beilegt, und in der Modelldatei selbst. Die Sketchfab-Seite war von der Arbeitsumgebung aus nicht erreichbar: Vor einer Veröffentlichung dort prüfen, ob das Modell noch unter CC BY 4.0 steht und vom Urheber selbst stammt (die Materialnamen sehen nach einem Unreal-Engine-Projekt aus).
- Absetzmulde (`game/assets/models/machinery/skip.glb`): nach „Old rubbish Skip“ von Sousinho, https://sketchfab.com/3d-models/old-rubbish-skip-2f9aa03ede3a46a0888e76fed382667f, Lizenz CC BY 4.0 (http://creativecommons.org/licenses/by/4.0/). Die Vorlage liegt mit ihrer Lizenzdatei in `tools/blender/sources/old_rubbish_skip_sousinho/`. Änderungen (`tools/blender/skip.py`): auf 3,2 m Länge gebracht, gedreht, auf den Boden gestellt; die drei Texturen von 4096 auf 2048 Pixel verkleinert und als JPEG gespeichert. Form und Bemalung stammen vom Urheber. Die Namensnennung steht auch im Spiel unter „Lizenzen“. Herkunft: Die Dateien stammen nicht direkt von Sketchfab, sondern aus einer Kopie des Sketchfab-Downloads im GitHub-Repository `AleksLitynski/metalshears` (Commit `81ce4721aa9b187046a743973e77494046aeceb9`, Ordner `game/models/dumpster/`; `license.txt`, `scene.gltf` und `scene.bin` sind bytegleich mit dieser Kopie). Die Lizenzangabe steht in der `license.txt`, die Sketchfab jedem Download beilegt, und in der Modelldatei selbst. Die Sketchfab-Seite war von der Arbeitsumgebung aus nicht erreichbar: vor einer Veröffentlichung dort Urheber und Lizenz gegenprüfen.
- Lieferwagen (`game/assets/models/vehicles/delivery_van.glb`): nach „European Delivery Van“ von Evan Hiltz, https://sketchfab.com/3d-models/european-delivery-van-0b2f1ad95a79419f9a092420024d329c, Lizenz CC BY 4.0 (http://creativecommons.org/licenses/by/4.0/). Die Vorlage liegt mit ihrer Lizenzdatei in `tools/blender/sources/european_delivery_van_hiltz/`. Änderungen (`tools/blender/van.py`): gedreht und mittig gesetzt, die 61 Teile nach Material zusammengefügt, vier Räder als eigene Teile, Texturen als JPEG gespeichert und drei davon von 4096 auf 2048 Pixel verkleinert. Form und Bemalung stammen vom Urheber; im Spiel werden die Scheiben klar, Straßenschmutz liegt auf der Karosserie, die Lampen sind aus. Die Namensnennung steht auch im Spiel unter „Lizenzen“. Herkunft: Die Dateien stammen nicht direkt von Sketchfab, sondern aus einer Kopie des Sketchfab-Downloads im GitHub-Repository `manojtharindu11/Truck-drive` (Commit `9a8757aee493298f3e9cef7f926065dd45d29a39`, Ordner `models/van/`; `license.txt`, `scene.gltf` und `scene.bin` sind bytegleich mit dieser Kopie). Die Lizenzangabe steht in der `license.txt`, die Sketchfab jedem Download beilegt, und in der Modelldatei selbst. Die Sketchfab-Seite war von der Arbeitsumgebung aus nicht erreichbar: vor einer Veröffentlichung dort Urheber und Lizenz gegenprüfen.
- Parkende Autos (`game/assets/models/vehicles/car_kiri86.glb`, `car_fairheaven_lt80.glb`, `car_fairheaven_sw84.glb`): nach „Kiri '86 - Low poly model“ (https://sketchfab.com/3d-models/kiri-86-low-poly-model-5c17c582ef9549798f694b660feea42a), „Fairheaven LT '80 - Low poly model“ (https://sketchfab.com/3d-models/fairheaven-lt-80-low-poly-model-e2678da920cc4be68dbc193727919ffb) und „Fairheaven SW '84 - Low poly model“ (https://sketchfab.com/3d-models/fairheaven-sw-84-low-poly-model-aa0becb6e854422596cac6b21bf79787) von Daniel Zhabotinsky (https://sketchfab.com/DanielZhabotinsky), Lizenz CC BY 4.0 (http://creativecommons.org/licenses/by/4.0/). Autos mit erfundenen Marken. Die Vorlagen liegen mit ihren Lizenzdateien in `tools/blender/sources/zhabotinsky_cars/`. Änderungen (`tools/blender/cars.py`): aufgerichtet und mittig gesetzt, in Karosserie, Innenraum und Scheiben geteilt, Scheiben mit eigenem klarem Material, Markenzeichen weggelassen (der Zeichen-Atlas der Vorlage enthält erfundene Marken, von denen einige echten ähneln). Im Spiel bekommt jedes Auto eine eigene Lackfarbe, Klarlack und Straßenschmutz. Die Namensnennung steht auch im Spiel unter „Lizenzen“. Herkunft: nicht direkt von Sketchfab, sondern aus den aufbereiteten Kopien im GitHub-Repository `raisimTech/raisim2Lib` (Commit `d9df2c979c9ddc44ec6b6727ff72c660688fdb62`, Ordner `rsc/city/cars/`; `license.txt`, `model.gltf`, `model.bin` und `model_paint1.gltf` je Auto sind bytegleich mit dieser Kopie; dort wurden die Netze zu einem Teil je Auto verschmolzen, die Texturen auf 1K verkleinert und der Lack durch eine schlichte Farbe ersetzt). Die Sketchfab-Seiten waren von der Arbeitsumgebung aus nicht erreichbar: vor einer Veröffentlichung dort Urheber und Lizenz gegenprüfen.
- Straßenbaum (`game/assets/models/nature/street_tree.glb`): aus „Tree Small 02“ von Poly Haven (https://polyhaven.com/a/tree_small_02, CC0), in der aufbereiteten Kopie des Projekts `raisimTech/raisim2Lib` (`rsc/forest/tree_small_02`, Commit wie oben; dort ein Baum aus der Reihe der Vorlage). Die Vorlage hat rund zwei Millionen Dreiecke und liegt deshalb nicht im Repository; `tools/blender/tree.py` behält jedes achte Blattstück, vergrößert es, dünnt Äste und Stamm aus und füllt den schwarzen Grund der Blatt-Textur (etwa 73.000 Dreiecke).
- Blender-Werkzeug `tools/blender/mm_kit.py`: in Teilen aus `assets/blender/blendkit.py` desselben Projekts übernommen (Copyright 2026 DigitalTwin Technology GmbH and the Construction Site Simulation contributors, Apache License 2.0), für dieses Spiel angepasst und erweitert. Wird nicht mit dem Spiel ausgeliefert.
- Bagger-Kabine (`zx200_cab_open.glb`): aus dem Kabinenteil des Baggers oben abgeleitet (Apache 2.0); `tools/blender/zx200_cab.py` höhlt den Block aus und schneidet die Fensteröffnungen.

## Code

Shader hash functions (`game/shaders/env_common.gdshaderinc`, `fx_common.gdshaderinc`, `vehicle_dirt.gdshader`) follow „Hash without Sine“ by Dave Hoskins (https://www.shadertoy.com/view/4djSRW), MIT License, Copyright (c) 2014 David Hoskins.
