# Credits

Third-party content shipped with Molten Mates. Every pack's license file sits next to the files in `game/assets/`.
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
| Lilita One | Juan Montoreano | SIL Open Font License 1.1 (github.com/google/fonts, `ofl/lilitaone`) | `game/assets/ui/fonts/LilitaOne-Regular.ttf` (`OFL.txt` next to it) – logo, banners, money counter |

## Sound

All sound effects in `game/assets/sfx/` are synthesized by our own `tools/sfx_gen.py`.

## Music

All music in `game/assets/music/` (`menu`, `backyard`, `garage`, `bell_foundry`, `iron_hall`) is written as notes and
synthesized by our own `tools/music_gen.py`. The pieces were composed by an AI assistant (Claude) at the owner's request:
no third-party rights, but this counts as AI-generated content and has to be declared in the Steam content survey.

## Foto-Oberflächen (CC0)

Fünf Textursätze von [Poly Haven](https://polyhaven.com) (CC0, 1k): `concrete_floor_worn_001`, `painted_plaster_wall`, `weathered_brown_planks`, `rusty_metal_02`, `brown_mud_dry`. Sie liegen in `game/assets/textures/pbr/` und werden über `shaders/env_photo.gdshaderinc` auf Boden, Wände, Holz, Erde und Metall gelegt.

Dazu `bark_brown_02` (Rinde) und `leafy_grass` (Laub).

## Gescannte Requisiten (CC0)

3D-Modelle von [Poly Haven](https://polyhaven.com) (CC0, 1k-Texturen) in `game/assets/models/polyhaven/`: Barrel_01, Barrel_02, barrel_03, wine_barrel_01, wooden_crate_01, wooden_crate_02, cardboard_box_01, wooden_bucket_01, cement_bag, shrub_02, shrub_03, old_tyre, metal_toolbox, painted_wooden_chair_01, propane_tank, wooden_ladder. `PhotoProp` tauscht sie gegen die Bausatz-Requisiten.
