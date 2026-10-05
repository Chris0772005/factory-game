# MOLTEN MATES – 3D-Asset-Inventar

Stand: 03.10.2026 · Godot 4.7.2 · Ergänzt `docs/ART_BIBLE.md` (Abschnitt 3.2/3.3).
Alle Pfade relativ zu `game/` (also `res://…`). Lizenzen und Namensnennung: `/CREDITS.md`.

## 0. Kurzfassung

- **160 Modelle aus 9 Packs, 19 MB**, alle **CC0** (Kenney-Repo selbst MIT, die Modelle laut README CC0).
  Keine Git-LFS-Stubs, keine KI-Assets, keine FBX (nur glTF/GLB, Godot importiert direkt).
- **Figur:** KayKit *Adventurers* – 4 niedliche Chibi-Figuren (Barbarian, Knight, Mage, Rogue) auf **einem gemeinsamen
  Rig** (`Rig/Skeleton3D`, 41 Knochen) mit **76 Clips**, alle *in-place* (keine Root-Motion). Idle, Walk, Run, Jump,
  PickUp, Interact, Use_Item, Throw, Hammer (`2H_Melee_Attack_Chop`), Tritt (`Unarmed_Melee_Attack_Kick`), Hit, Death,
  Lie-Down/Stand-Up, Cheer sind da. **Fehlt:** Tragen/Halten, Schieben, Kippen/Gießen → AnimationTree-Oberkörper-Overlay
  + `TwoBoneIK3D` (in 4.7.2 vorhanden, geprüft).
- **Props:** 8 KayKit-Packs teilen Formensprache und denselben 1024²-Verlaufs-Atlas-Aufbau (8×4 Farbfelder) → mischen
  sich nahtlos. Fässer, Kisten, Paletten, Eimer, Schubkarre, Werkbänke, Regale, Laternen, Zäune, Wege, Steine, Bäume,
  Hintergrund-Häuser, Mülltonnen, Münzen sind abgedeckt.
- **Lücken:** Ofen/Eimerofen, Tiegel, Gießpfanne, Formkasten, Amboss, Vorschlaghammer, Schaufel, Blasebalg,
  Lichterkette, Schornstein/Rohre, Schrott-Teile, Schutzhelm/Schürze für die Figur, Gras-Teppich → prozedural
  (`MeshFactory`) oder Kitbash aus den vorhandenen Teilen (Vorschläge in Abschnitt 6).
- **Kontaktbögen** (lokal, `shots/` ist gitignored): `shots/asset_sheet.png` (alle 160), `asset_sheet_scale.png`
  (Spielmaßstab neben den Figuren), `asset_sheet_anims.png` (24 Schlüssel-Clips), je Pack
  `asset_sheet_{characters,dungeon,restaurant_furniture,halloween,hexagon,city_prototype_kenney}.png`,
  `asset_sheet_scale_day.png` (Neutrallicht).

## 1. Was importiert wurde

| Ordner `res://assets/models/…` | Quelle (GitHub, Commit) | Modelle | Format | Textur | Maßstab → Meter |
|---|---|---|---|---|---|
| `kaykit_adventurers/` | `KayKit-Game-Assets/KayKit-Character-Pack-Adventures-1.0` @672074b | 4 Figuren + 7 Accessoires | `.glb` (Figuren, je 3,6 MB inkl. 76 Clips), `.gltf+.bin` | je Figur ein Atlas (`*_texture.png`, 1024²) | **0.8** |
| `kaykit_dungeon/` | `KayKit-Game-Assets/KayKit-Dungeon-Remastered-1.0` @b0ca9bd | 41 | `.gltf+.bin` (*konvertiert*, s. u.) | `dungeon_texture.png` | **0.8** |
| `kaykit_restaurant/` | `KayKit-Game-Assets/KayKit-Restaurant-Bits-1.0` @153c8a7 | 15 | `.gltf+.bin` | `restaurantbits_texture.png` | **0.8** |
| `kaykit_furniture/` | `KayKit-Game-Assets/KayKit-Furniture-Bits-1.0` @96d5930 | 14 | `.gltf+.bin` | `furniturebits_texture.png` | **0.8** |
| `kaykit_halloween/` | `KayKit-Game-Assets/KayKit-Halloween-Bits-1.0` @6dc69bf | 24 | `.gltf+.bin` | `halloweenbits_texture.png` | **0.8** |
| `kaykit_prototype/` | `KayKit-Game-Assets/KayKit-Prototype-Bits-1.0` @bb15959 | 13 | `.gltf+.bin` | `prototypebits_texture.png` | **0.8** |
| `kaykit_hexagon/` | `KayKit-Game-Assets/KayKit-Medieval-Hexagon-Pack-1.0` @84fa4e9 | 26 | `.gltf+.bin` | `hexagons_medieval.png` | **4.0** (Tischmaßstab; Zäune 2.4, Eimer 3–3.5, Schubkarre 2.8) |
| `kaykit_city/` | `KayKit-Game-Assets/KayKit-City-Builder-Bits-1.0` @6397691 | 14 | `.gltf+.bin` | `citybits_texture.png` | **4.0** (Tischmaßstab) |
| `kenney_platformer/` | `KenneyNL/Starter-Kit-3D-Platformer` @3fa8a04 | 2 (Gras-Büschel) | `.glb` | `Textures/colormap.png` (512²) | 1.0 |

**Maßstab:** Die KayKit-„Figurenfamilie“ ist in Einheiten gebaut, in denen eine Figur ≈ 2,2 hoch ist. Mit **0.8** wird
die Figur ≈ 1,75 m (mit Helm/Hut bis 1,95/2,4 m), Augenhöhe ≈ 1,3 m, Tisch 0,8 m, kleines Fass 0,8 m – passt zur
Art Bible (Werkbank 0,85 m, Augenhöhe ≈ 1,35 m). Hexagon und City Builder sind Brettspiel-Miniaturen (×4).
Konstanten dafür: `PACK_SCALE` in `scripts/tools/asset_sheet.gd`.

**Dungeon-Konvertierung:** Upstream liefert nur `*.gltf.glb` mit eingebettetem Atlas. Godot würde daraus 41 identische
1024²-Texturen extrahieren (41 Materialien, mehrere Dutzend MB VRAM). `tools/glb_to_gltf.py` hat jede Datei verlustfrei in
`.gltf + .bin` zerlegt und das eingebettete Bild (byte-identisch geprüft) durch das gemeinsame `dungeon_texture.png`
ersetzt. Geometrie, UVs und Materialwerte sind unverändert. Die Figuren-`.glb` blieben unverändert; Godot legt beim
Import `Barbarian_barbarian_texture.png` usw. daneben (Duplikat des Pack-Atlas – harmlos, aber beim Umfärben beachten).

**Materialien:** alle KayKit-Materialien `metallic 0`, `roughness 0.4–0.6`, nur Albedo-Atlas. Für die Art Bible
(Rauheit 0.65–0.9, Höhenverlauf, Kantenabnutzung) entweder Import-Material-Override oder ein gemeinsamer
`ShaderMaterial`, der die Atlas-Textur als Albedo nimmt.

## 2. Lizenzen (Zitate aus den mitkopierten Lizenzdateien)

Alle acht KayKit-Packs (`kaykit_*/LICENSE.txt`), z. B. Dungeon Remastered:

> KayKit : Dungeon Remastered (1.0) · Created/distributed by Kay Lousberg (www.kaylousberg.com)
> License: (Creative Commons Zero, CC0) http://creativecommons.org/publicdomain/zero/1.0/
> This content is free to use in personal, educational and commercial projects.
> Support me by using a brand resource provided in this pack or by crediting Kay Lousberg, www.kaylousberg.com (this is not mandatory)

Kenney Starter Kit 3D Platformer (`kenney_platformer/LICENSE.md` = MIT für den Code, `LICENSE-ASSETS.txt` zitiert das README):

> Assets included in this package (2D sprites, 3D models and sound effects) are [CC0 licensed](https://creativecommons.org/publicdomain/zero/1.0/)

## 3. Figuren – KayKit Adventurers

### 3.1 Dateien und Szenenaufbau
`kaykit_adventurers/{Barbarian,Knight,Mage,Rogue}.glb`. Importierte Szene (alle vier gleich):

```
<Name> (Node3D)
├─ Rig (Node3D)
│  └─ Skeleton3D            ← 41 Knochen, Meshes sind Kinder des Skeletts
│     ├─ handslot_l (BoneAttachment3D, bone "handslot.l")  → Offhand-Waffen/Schilde
│     ├─ handslot_r (BoneAttachment3D, bone "handslot.r")  → Waffen
│     ├─ head (BoneAttachment3D, bone "head")               → nur Knight/Barbarian/Mage (Helm/Hut)
│     └─ chest (BoneAttachment3D, bone "chest")             → Umhang
└─ AnimationPlayer           ← 76 Clips, root_node ".."
```

Blickrichtung **+Z** (rechte Hand auf −X), wie der bisherige `PlayerModel`. Ruhepose: Hüfte y = 0,41, Kopf-Knochen
y = 1,24 (×0.8 → 0,33 m / 0,99 m).

Mesh-Knoten (Waffen/Requisiten werden für den Arbeiter-Look ausgeblendet, siehe `CHARACTER_PROPS` in `asset_sheet.gd`):

| Figur | Körper (immer an) | Kopfbedeckung / Umhang | Requisiten (ausblenden) | Dreiecke ohne Requisiten |
|---|---|---|---|---|
| Barbarian | `Barbarian_Body/Head/ArmLeft/ArmRight/LegLeft/LegRight` | `Barbarian_Hat` (Bärenmütze, @head), `Barbarian_Cape` (@chest) | `1H_Axe`, `1H_Axe_Offhand`, `2H_Axe`, `Barbarian_Round_Shield`, `Mug` | 4 777 |
| Knight | `Knight_Body/Head/…` | `Knight_Helmet` (@head), `Knight_Cape` (@chest) | `1H_Sword`, `1H_Sword_Offhand`, `2H_Sword`, `Badge_Shield`, `Rectangle_Shield`, `Round_Shield`, `Spike_Shield` | 4 712 |
| Mage | `Mage_Body/Head/…` | `Mage_Hat` (@head), `Mage_Cape` (@chest) | `1H_Wand`, `2H_Staff`, `Spellbook`, `Spellbook_open` | 4 509 |
| Rogue | `Rogue_Body/Head/…` (Haare im Kopf-Mesh) | `Rogue_Cape` (@chest) | `1H_Crossbow`, `2H_Crossbow`, `Knife`, `Knife_Offhand`, `Throwable` | 4 347 |

Empfehlung Arbeiter-Basis: **Rogue** (kein Hut, Haare im Kopf → Schutzhelm passt drauf) und **Barbarian** (Bart,
Bärenmütze aus → eigener Helm). Knight/Mage nur mit ausgeblendetem Helm/Hut; deren Köpfe sind unter dem Helm
vollständig modelliert (Knight_Head = Gesicht + Haare). Umhänge (`*_Cape`) für den Gießerei-Look ausblenden
(oder als „Schürze“ umfärben).

### 3.2 Skelett (exakte Godot-Knochennamen, Punkte bleiben erhalten)
`root, hips, spine, chest, upperarm.l, lowerarm.l, wrist.l, hand.l, handslot.l, upperarm.r, lowerarm.r, wrist.r, hand.r,
handslot.r, head, upperleg.l, lowerleg.l, foot.l, toes.l, upperleg.r, lowerleg.r, foot.r, toes.r, kneeIK.l,
control-toe-roll.l, control-heel-roll.l, control-foot-roll.l, heelIK.l, IK-foot.l, IK-toe.l, kneeIK.r,
control-toe-roll.r, control-heel-roll.r, control-foot-roll.r, heelIK.r, IK-foot.r, IK-toe.r, elbowIK.l, handIK.l,
elbowIK.r, handIK.r`

Für Gameplay relevant:

| Zweck | Knochen |
|---|---|
| Wurzel / Hüfte (Squash, Ragdoll-Basis, Sitz) | `root`, `hips` |
| Oberkörper-Filter für Tragen/Hämmern-Overlay | `spine`, `chest`, `upperarm.*`, `lowerarm.*`, `wrist.*`, `hand.*`, `handslot.*`, `head` |
| Hand-IK-Kette (`TwoBoneIK3D`) | `upperarm.l → lowerarm.l → wrist.l` (bzw. `.r`), Ziel = Tiegelgriff; Pol = `elbowIK.*`-Richtung |
| Gehaltene Objekte anhängen | `handslot.r` / `handslot.l` (Griffpunkt, schon als BoneAttachment3D vorhanden) |
| Schutzhelm / Brille | neue `BoneAttachment3D` auf `head` (Rogue hat keine) |
| Kopf-Blick (`LookAtModifier3D`) | `head` (ggf. `chest` mit geringem Gewicht) |
| Fuß-IK / Bodenanpassung | `upperleg.* → lowerleg.* → foot.*` |

`kneeIK.*, heelIK.*, IK-foot.*, IK-toe.*, control-*, elbowIK.*, handIK.*` sind Blender-Steuerknochen ohne Haut-Gewichte;
ihre Bewegung ist in die Clips eingebacken. Nicht als Deform-Knochen benutzen.

### 3.3 Clips (AnimationPlayer, exakte Namen, Länge in s)
Alle Clips sind **in-place** (Knochen `root` steht still; `Dodge_*` haben 0,25 Einheiten Vorschub). Import-Loop-Modus
ist überall `NONE` → für Idle/Walk/Run/Jump_Idle/Spellcasting/Blocking/`*_Idle` im Code (`Animation.loop_mode =
LOOP_LINEAR`) oder per Import-Option (`_subresources` → animations → loop) setzen.

`1H_Melee_Attack_Chop 1.07, 1H_Melee_Attack_Slice_Diagonal 1.00, 1H_Melee_Attack_Slice_Horizontal 1.07,
1H_Melee_Attack_Stab 1.60, 1H_Ranged_Aiming 1.07, 1H_Ranged_Reload 1.17, 1H_Ranged_Shoot 1.07, 1H_Ranged_Shooting 1.60,
2H_Melee_Attack_Chop 1.63, 2H_Melee_Attack_Slice 1.10, 2H_Melee_Attack_Spin 2.40, 2H_Melee_Attack_Spinning 0.67,
2H_Melee_Attack_Stab 1.60, 2H_Melee_Idle 1.07, 2H_Ranged_Aiming 1.60, 2H_Ranged_Reload 1.60, 2H_Ranged_Shoot 1.07,
2H_Ranged_Shooting 1.07, Block 1.07, Block_Attack 1.07, Block_Hit 1.07, Blocking 1.07, Cheer 1.67, Death_A 0.80,
Death_A_Pose 0, Death_B 2.63, Death_B_Pose 0, Dodge_Backward 0.40, Dodge_Forward 0.40, Dodge_Left 0.40, Dodge_Right 0.40,
Dualwield_Melee_Attack_Chop 1.27, Dualwield_Melee_Attack_Slice 1.17, Dualwield_Melee_Attack_Stab 1.60, Hit_A 0.67,
Hit_B 0.87, Idle 1.07, Interact 1.30, Jump_Full_Long 2.33, Jump_Full_Short 1.17, Jump_Idle 1.07, Jump_Land 0.67,
Jump_Start 0.60, Lie_Down 3.00, Lie_Idle 2.67, Lie_Pose 0, Lie_StandUp 2.33, PickUp 1.30, Running_A 0.80, Running_B 1.07,
Running_Strafe_Left 0.80, Running_Strafe_Right 0.80, Sit_Chair_Down 0.80, Sit_Chair_Idle 3.60, Sit_Chair_Pose 0,
Sit_Chair_StandUp 0.80, Sit_Floor_Down 1.00, Sit_Floor_Idle 4.00, Sit_Floor_Pose 0, Sit_Floor_StandUp 1.13,
Spellcast_Long 2.53, Spellcast_Raise 2.10, Spellcast_Shoot 0.93, Spellcasting 0.67, T-Pose 0, Throw 1.37,
Unarmed_Idle 1.07, Unarmed_Melee_Attack_Kick 0.93, Unarmed_Melee_Attack_Punch_A 1.47, Unarmed_Melee_Attack_Punch_B 1.67,
Unarmed_Pose 0, Use_Item 1.60, Walking_A 1.07, Walking_B 1.07, Walking_Backwards 1.07, Walking_C 1.60`

### 3.4 Spielverben → Clips (Sichtprüfung: `shots/asset_sheet_anims.png`)

| Verb | Clip(s) | Hinweis |
|---|---|---|
| Stehen | `Idle` (Atmen), `Unarmed_Idle` | `Idle` hat leicht erhobene Arme (für Waffen) – für leere Hände `Unarmed_Idle` |
| Gehen / Laufen | `Walking_A` (1.07 s), `Running_A` (0.80 s); `Walking_C` behäbig (schwer beladen) | in-place → Abspielrate an Geschwindigkeit koppeln (BlendSpace1D) |
| Rückwärts / seitlich | `Walking_Backwards`, `Running_Strafe_Left/Right` | |
| Springen | `Jump_Start` → `Jump_Idle` (Loop) → `Jump_Land` | `Jump_Full_*` nur für Cutscenes |
| Aufheben / Ablegen | `PickUp` | Greifmoment ≈ 0.55–0.65 s |
| Interagieren (Knopf, Kurbel, Form einlegen) | `Interact`, `Use_Item` | |
| Werfen (Schrott in Ofen, Ware in Kiste) | `Throw` | Loslassen ≈ 0.6 s |
| Hämmern / Form zerschlagen | `2H_Melee_Attack_Chop` (Ausholen bis ≈ 0.5 s, Treffer ≈ 0.8 s); kurz: `1H_Melee_Attack_Chop` | Hammer an `handslot.r` |
| Stampfen (Formsand) | `2H_Melee_Attack_Stab` oder `1H_Melee_Attack_Chop` nach unten | Rhythmus-Eingabe → Clip neu starten |
| Blasebalg treten | `Unarmed_Melee_Attack_Kick` | |
| Tragen / Halten (Tiegel, Stange) | **kein Clip** → Oberkörper aus `2H_Melee_Idle` oder `Blocking` (Arme vorn) über `Walking_A`, Hände per `TwoBoneIK3D` an die Griffe | AnimationTree `Blend2` mit Bone-Filter (Abschnitt 3.2) |
| Kippen / Gießen | **kein Clip** → IK-Hände folgen dem Tiegel; `Spellcast_Raise` als Ausgangspose | |
| Getroffen / Stolpern | `Hit_A`, `Hit_B`, `Block_Hit` | |
| Hinfallen / Ragdoll-artig | `Death_A` → `Lie_Idle` → `Lie_StandUp`; echtes Ragdoll: `PhysicalBoneSimulator3D` auf `hips, spine, chest, head, upperarm.*, lowerarm.*, upperleg.*, lowerleg.*` | |
| Bronzefreund (Statue) | `Death_A_Pose`, `Death_B_Pose`, `Lie_Pose`, `Sit_Floor_Pose`, `T-Pose`, eingefrorener `Hit_A`/`Cheer` | Pose einfrieren + Metall-Shader |
| Jubeln / Enthüllung | `Cheer` | |
| Ausweichen / Schubsen | `Dodge_Forward`, `Unarmed_Melee_Attack_Punch_A` | |
| Sitzen (Pause, Lobby) | `Sit_Floor_*`, `Sit_Chair_*` | |

Zusätzliche Clips gibt es im gleichen Rig im Pack *KayKit Character Pack: Skeletons 1.0* (95 Clips, u. a. `Taunt`,
`Idle_B`, `Running_C`, `Walking_D_Skeletons`, `Spawn_Ground`) – nicht importiert, bei Bedarf als `AnimationLibrary`
übernehmbar (gleiche Knochennamen).

### 3.5 Spielerfarben über den Atlas
Atlas = 8 Spalten × 4 Zeilen à 128 px, jede Zelle ein vertikaler Verlauf (oben hell → unten dunkel), rechts ein
heller Kantenstreifen. Gemessene Zellen (Spalte, Zeile von oben links) je Mesh:

| Figur | Haut | Haare | Hemd/Torso | Umhang | Hose | Leder/Gürtel |
|---|---|---|---|---|---|---|
| Rogue (`rogue_texture.png`) | (0,0) | (1,0) | (0,1) | (1,1) | (3,2) | (6,0), (7,1), (5,0) |
| Barbarian (`barbarian_texture.png`) | (0,0) | (1,0) Bart | (2,1), (6,0) | (7,0) | (3,2) | (7,1), (7,2) |
| Knight (`knight_texture.png`) | (0,0) | (1,0) | (3,0) Rüstung | (0,1) | (3,0) | (7,0), (6,0) |

Umsetzung: entweder 4 Atlas-Kopien mit umgefärbten Zellen (billig, 15 KB je PNG) oder ein Shader, der Albedo nur in
der UV-Zelle der Kleidung mit der Spielerfarbe multipliziert (eine Textur, Farbe als Instance-Uniform).

## 4. Props nach Bedarf (Hinterhof-Gießerei)

Größen in m bei Pack-Maßstab (B × H × T), Dreiecke. Vollständige Liste in Abschnitt 7.

| Bedarf | Beste Wahl | Alternativen / Hinweis |
|---|---|---|
| Fässer | `kaykit_dungeon/barrel_small` (0,8 m), `barrel_large`, `barrel_small_stack`, `keg` | Ölfässer: `kaykit_prototype/Barrel_A/B/C` (rot/gelb/blau, 0,8 m), `kaykit_hexagon/barrel` |
| Eimer | `kaykit_hexagon/bucket_empty`, `bucket_water` (Skala 3–3.5) | Holzeimer mit Wasser = Abschreckbecken |
| Kisten | `kaykit_restaurant/crate` + `crate_lid` (Verkaufskiste!), `kaykit_dungeon/box_small/large`, `crates_stacked` | Karton: `kaykit_city/box_A/B`, `kaykit_prototype/Box_A–C`; `kaykit_hexagon/crate_open` (mit Inhalt) |
| Paletten | `kaykit_prototype/Pallet_Small`, `Pallet_Large`, `Pallet_Small_Decorated_A/B` (mit Fässern) | `kaykit_hexagon/pallet` |
| Werkbank / Tisch | `kaykit_dungeon/table_long`, `table_medium` (Holz, 0,8 m) | Edelstahl: `kaykit_restaurant/kitchentable_A`, `kitchentable_B_large`; `kaykit_furniture/table_medium_long` |
| Regale | `kaykit_dungeon/shelves`, `shelf_small`, `kaykit_furniture/shelf_B_large_decorated` | `cabinet_medium` |
| Sitzen | `kaykit_dungeon/stool`, `chair`, `kaykit_furniture/chair_stool_wood`, `kaykit_halloween/bench` | |
| Zaun | `kaykit_hexagon/fence_wood_straight` + `_gate` (Holz-Palisade, **Skala 2.4** → 1,3 m) | Eisenzaun `kaykit_halloween/fence`, `fence_pillar`, `fence_gate`, `fence_broken` (Skala 0.6 → 1,3 m) |
| Haus / Schuppen | Hintergrund: `kaykit_city/building_A/C/F_withoutBase` (6–9 m, Silhouetten) | Mauerteile `kaykit_dungeon/wall*`, `pillar` (Glockengießerei-Stil); `kaykit_hexagon/building_home_A_blue`, `building_blacksmith_blue` (Deko/Easter-Egg) |
| Lampen | `kaykit_halloween/lantern_hanging`, `lantern_standing`, `post_lantern` | `kaykit_city/streetlight`, `kaykit_furniture/lamp_standing`, `kaykit_dungeon/torch_lit/torch_mounted`, `candle_triple` |
| Esse / Abzug | `kaykit_restaurant/extractorhood` (hängt auf 1,6 m) | über Ofen + Rohr prozedural |
| Töpfe (Tiegel-Platzhalter) | `kaykit_restaurant/pot_large`, `pot_A/B`, `lid_large`, `pan_A` | Gasbrenner: `stove_single` |
| Schubkarre (Solo-Modus) | `kaykit_hexagon/wheelbarrow` (Skala 2.8) | |
| Sack / Formsand | `kaykit_hexagon/sack` | `resource_stone`, `resource_lumber` |
| Steine / Pflanzen | `kaykit_hexagon/rock_single_A–E`, `tree_single_A/B`, `trees_A_small`, `kaykit_city/bush`, `kaykit_furniture/cactus_*` | Herbst: `kaykit_halloween/tree_pine_*`, `tree_dead_medium`, `pumpkin_*` |
| Gras-Büschel | `kenney_platformer/grass`, `grass-small` (MultiMesh-tauglich, 72 Dreiecke) | |
| Boden / Wege | `kaykit_halloween/path_A–D` (Trittsteine), `floor_dirt` | `kaykit_dungeon/floor_dirt_large(_rocky)`, `floor_dirt_small_weeds`, `floor_wood_large`, `floor_tile_grate` |
| Müll / Schrott-Deko | `kaykit_city/trash_A/B`, `dumpster`, `kaykit_dungeon/rubble_half/large`, `sword_shield_broken` | `kaykit_prototype/Can_A/B`, Adventurers-Waffen als Schrott |
| Geld / Belohnung | `kaykit_dungeon/coin`, `coin_stack_small/large`, `chest` | `kaykit_prototype/Coin_A` |
| Wolken / Himmel | `kaykit_hexagon/cloud_big`, `cloud_small` | |
| Auto (Garage-Level) | `kaykit_city/car_stationwagon` | `firehydrant`, `watertower` |

## 5. Stil-Paarung

- **Eine Familie:** Alle 8 KayKit-Packs stammen von Kay Lousberg, gleiche Fasen-Formsprache, gleicher Atlas-Aufbau
  (8×4 Verlaufszellen, 1024²), gleiche Materialwerte. Sie mischen sich ohne Nacharbeit – sichtbar in
  `shots/asset_sheet_scale.png`.
- **Kern-Mischung Hinterhof:** Adventurers (Figuren) + Dungeon (Fässer, Kisten, Tische, Münzen) + Restaurant (Kiste mit
  Deckel, Töpfe, Edelstahl, Abzug) + Furniture (Regale, Hocker, Lampe) + Halloween (Laternen, Wege, Bank, Herbst-Deko)
  + Hexagon-Props (Eimer, Schubkarre, Sack, Holzzaun, Steine, Bäume).
- **Hintergrund:** City-Builder-Häuser als entsättigte Silhouetten hinter dem Zaun (Art Bible 3.2), Hexagon-Wolken.
- **Vorsicht:**
  - Hexagon und City sind Miniaturen (×4): weniger Detail pro Meter – gut für Mittel-/Hintergrund, Nahaufnahmen eher
    mit Dungeon/Restaurant-Teilen.
  - Prototype-Teile außer Fässern/Paletten/Kartons (gelbe Blöcke, Zielscheiben) haben Greybox-Look – nicht verwendet.
  - Dungeon-Mauern (grauer Burgstein) passen in die Glockengießerei, nicht in den Hinterhof.
  - Kenney-Gras hat flache Farben statt Verlauf; nur als kleine Büschel, eingefärbt über die Gras-Palette.
  - Halloween-Kürbisse/Gräber nur saisonal; Totenköpfe/Särge nicht importiert.
- **Art-Bible-Hinweis:** Die Art Bible will die Fremd-Atlanten auf eine eigene Palette (`mm_atlas.png`) umfärben. Da alle
  Packs das 8×4-Raster nutzen, reicht pro Pack eine umgefärbte PNG gleicher Größe (UVs bleiben).

## 6. Lücken (deckt kein Pack ab) und Vorschlag

| Fehlt | Vorschlag |
|---|---|
| **Eimerofen / Ofen** | Kitbash: `kaykit_hexagon/bucket_empty` (×5) oder `kaykit_dungeon/barrel_small` als Mantel + prozeduraler Deckel/Düse; Glut/Feuer bleibt FX |
| **Tiegel, Gießpfanne, Gießstange** | prozedural (`MeshFactory`), Form an `restaurant/pot_A` (Henkel) orientiert; Metall-Shader existiert |
| **Formkasten (Sandkiste)** | prozedural (Bretter + Metallwinkel, Art Bible 3.1); `restaurant/crate` als Vorlage für Proportionen |
| **Amboss, Vorschlaghammer, Schaufel, Zange, Schürhaken** | prozedural (einfache Formen); Hammer an `handslot.r` (Adventurers-Waffen zeigen Griffposition) |
| **Blasebalg** | prozedural (Leder-Balg = gestauchter Zylinder + zwei Bretter), Tritt-Clip vorhanden |
| **Lichterkette** | prozedural: Kabel als `Curve3D`-Röhre + Birnen (MultiMesh); Masten aus `kaykit_halloween/post` |
| **Schornstein / Ofenrohr** | prozedural (Zylinder + Bögen); `restaurant/extractorhood` als Abzugshaube |
| **Schrott-Teile** (Rohre, Felgen, Dosen, Bleche) | Mischung aus `prototype/Can_A/B`, `restaurant/pan_A`, `lid_large`, `adventurers/*` Waffen + prozedurale Bleche |
| **Schutzhelm, Schutzbrille, Lederschürze, Handschuhe** | prozedural an `head`/`chest`-BoneAttachment; Schürze alternativ als umgefärbter `*_Cape` |
| **Gras-Teppich / Boden-Übergänge** | Shader + MultiMesh mit `kenney_platformer/grass*` |
| **Holz-Lattenzaun im Wohngebiet-Stil** | `hexagon/fence_wood_straight` (Palisade) oder prozedural; Eisenzaun aus Halloween als Alternative |
| **Glocken, Hallenkran, Gießpfanne für 4** (spätere Level) | prozedural |

## 7. Alle importierten Modelle (B × H × T in m bei Pack-Maßstab · Dreiecke)

Figurenmaße aus der T-Pose-Ruheform (Breite = Armspanne) und ohne ausgeblendete Requisiten.
Erzeugt mit `asset_sheet.tscn` (Zeilen `MODEL …` im Log).
**kaykit_adventurers** (11)

`Barbarian` 1.6×1.9×1.0 · 4777 · `Knight` 1.6×2.0×1.0 · 4712 · `Mage` 1.7×2.4×1.9 · 4509 · `Rogue` 1.6×1.8×0.8 · 4347 · `axe_1handed` 0.6×1.0×0.1 · 274 · `dagger` 0.2×1.0×0.1 · 172 · `mug_empty` 0.4×0.4×0.3 · 366 · `mug_full` 0.4×0.4×0.3 · 426 · `shield_round` 0.7×0.7×0.3 · 284 · `shield_square` 0.7×0.9×0.2 · 262 · `sword_1handed` 0.4×1.4×0.1 · 300

**kaykit_city** (14)

`bench` 1.6×0.4×0.6 · 44 · `box_A` 0.8×0.7×0.8 · 32 · `box_B` 0.6×0.7×0.6 · 20 · `building_A_withoutBase` 4.8×6.2×5.8 · 435 · `building_C_withoutBase` 4.8×9.0×5.2 · 666 · `building_F_withoutBase` 8.0×9.0×5.2 · 1097 · `bush` 0.8×1.5×0.8 · 72 · `car_stationwagon` 1.7×1.5×3.8 · 1234 · `dumpster` 2.3×1.3×1.4 · 126 · `firehydrant` 0.5×0.9×0.5 · 180 · `streetlight` 1.1×3.8×0.3 · 176 · `trash_A` 0.5×0.2×0.5 · 18 · `trash_B` 0.3×0.2×0.3 · 18 · `watertower` 2.0×2.7×2.0 · 146

**kaykit_dungeon** (41)

`barrel_large` 1.4×1.6×1.4 · 561 · `barrel_small` 0.8×0.8×0.8 · 207 · `barrel_small_stack` 1.5×1.4×0.8 · 1149 · `bottle_A_brown` 0.3×0.7×0.3 · 144 · `box_large` 1.2×1.2×1.2 · 188 · `box_small` 0.8×0.8×0.8 · 188 · `box_stacked` 2.8×2.6×2.9 · 2173 · `candle_triple` 0.4×0.7×0.3 · 198 · `chair` 0.6×1.0×0.6 · 294 · `chest` 1.4×1.0×1.2 · 728 · `coin` 0.3×0.1×0.3 · 80 · `coin_stack_large` 1.1×0.9×1.3 · 1776 · `coin_stack_small` 0.8×0.4×0.7 · 416 · `crates_stacked` 1.7×1.7×1.8 · 1331 · `floor_dirt_large` 3.2×0.2×3.2 · 104 · `floor_dirt_large_rocky` 3.2×0.3×3.2 · 187 · `floor_dirt_small_A` 1.6×0.1×1.6 · 45 · `floor_dirt_small_weeds` 1.6×0.2×1.6 · 416 · `floor_tile_grate` 3.2×0.8×1.6 · 142 · `floor_tile_large` 3.2×0.1×3.2 · 188 · `floor_wood_large` 3.2×0.1×3.2 · 272 · `keg` 1.4×1.6×1.6 · 807 · `pillar` 1.2×3.2×1.2 · 136 · `rubble_half` 3.2×2.8×2.4 · 390 · `rubble_large` 6.5×2.8×2.5 · 788 · `shelf_small` 0.8×0.3×0.4 · 60 · `shelves` 1.6×1.6×0.4 · 152 · `stairs_wood` 2.6×3.2×4.8 · 296 · `stool` 0.6×0.4×0.6 · 172 · `sword_shield_broken` 1.1×1.6×0.3 · 396 · `table_long` 1.6×0.8×3.2 · 280 · `table_medium` 1.6×0.8×1.6 · 256 · `table_medium_broken` 1.8×0.8×1.9 · 247 · `table_small` 0.8×0.8×0.8 · 192 · `torch_lit` 0.4×0.9×0.4 · 270 · `torch_mounted` 0.4×0.8×0.5 · 278 · `wall` 3.2×3.2×0.8 · 494 · `wall_corner` 2.0×3.2×2.0 · 443 · `wall_doorway_sides` 4.0×3.2×3.2 · 1160 · `wall_half` 1.6×3.2×0.8 · 272 · `wall_window_open` 3.2×3.2×0.8 · 604

**kaykit_furniture** (14)

`armchair` 1.4×1.0×1.3 · 528 · `cabinet_medium` 1.6×0.8×0.8 · 428 · `cactus_medium_A` 0.7×0.7×0.7 · 448 · `cactus_small_A` 0.4×0.4×0.4 · 252 · `chair_A_wood` 0.6×1.0×0.7 · 308 · `chair_stool_wood` 0.6×0.4×0.6 · 216 · `lamp_standing` 0.8×2.0×0.8 · 320 · `lamp_table` 0.8×0.8×0.8 · 392 · `rug_oval_A` 2.4×0.1×1.6 · 176 · `shelf_B_large` 1.6×0.3×0.4 · 212 · `shelf_B_large_decorated` 1.6×0.7×0.4 · 482 · `table_low` 1.9×0.4×1.2 · 276 · `table_medium` 1.6×0.8×1.6 · 168 · `table_medium_long` 2.4×0.8×1.6 · 168

**kaykit_halloween** (24)

`bench` 1.6×0.4×0.6 · 172 · `bench_decorated` 1.6×1.3×0.8 · 978 · `candle_triple` 0.4×0.6×0.3 · 198 · `fence` 3.2×1.8×0.4 · 380 · `fence_broken` 3.2×1.8×0.4 · 446 · `fence_gate` 3.2×2.4×0.4 · 620 · `fence_pillar` 0.4×1.8×0.4 · 94 · `fence_seperate` 3.2×1.6×0.1 · 312 · `floor_dirt` 3.2×0.4×3.2 · 120 · `floor_dirt_small` 1.6×0.4×1.6 · 80 · `lantern_hanging` 0.5×1.1×0.5 · 472 · `lantern_standing` 0.5×0.7×0.5 · 264 · `path_A` 1.5×0.1×1.5 · 361 · `path_B` 1.5×0.1×1.5 · 370 · `path_C` 1.5×0.1×1.5 · 393 · `path_D` 1.3×0.1×1.4 · 275 · `post` 0.3×2.6×1.2 · 96 · `post_lantern` 0.5×2.6×1.2 · 568 · `pumpkin_orange` 0.8×0.6×0.8 · 306 · `pumpkin_orange_small` 0.5×0.4×0.5 · 322 · `pumpkin_yellow_small` 0.5×0.4×0.5 · 322 · `tree_dead_medium` 1.4×3.4×0.4 · 216 · `tree_pine_orange_large` 3.8×6.0×3.3 · 318 · `tree_pine_yellow_medium` 2.7×4.7×2.5 · 318

**kaykit_hexagon** (26)

`barrel` 0.8×0.8×0.8 · 240 · `bucket_empty` 0.6×0.5×0.6 · 128 · `bucket_water` 0.6×0.4×0.6 · 128 · `building_blacksmith_blue` 5.2×3.9×5.0 · 2410 · `building_home_A_blue` 3.2×3.7×3.4 · 1011 · `cloud_big` 14.4×7.8×9.0 · 672 · `cloud_small` 9.3×7.4×7.2 · 366 · `crate_A_big` 0.8×0.8×0.8 · 132 · `crate_long_empty` 1.6×0.6×0.8 · 42 · `crate_open` 1.3×0.8×0.8 · 260 · `fence_wood_straight` 0.4×2.2×4.6 · 212 · `fence_wood_straight_gate` 0.6×2.6×4.6 · 308 · `ladder` 1.0×3.1×0.2 · 84 · `pallet` 1.2×0.3×1.2 · 72 · `resource_lumber` 2.7×0.8×1.3 · 220 · `resource_stone` 1.7×1.1×1.4 · 220 · `rock_single_A` 1.2×0.3×1.1 · 18 · `rock_single_B` 1.1×0.5×1.0 · 26 · `rock_single_C` 1.4×0.8×1.4 · 40 · `rock_single_D` 1.1×0.7×1.0 · 22 · `rock_single_E` 1.9×0.8×1.4 · 71 · `sack` 0.4×0.3×0.6 · 92 · `tree_single_A` 2.3×4.8×2.2 · 50 · `tree_single_B` 2.7×4.8×2.9 · 220 · `trees_A_small` 5.7×4.4×5.7 · 432 · `wheelbarrow` 0.9×0.8×2.0 · 396

**kaykit_prototype** (13)

`Barrel_A` 0.8×0.8×0.8 · 384 · `Barrel_B` 0.8×0.8×0.8 · 384 · `Barrel_C` 0.8×0.8×0.8 · 384 · `Box_A` 0.4×0.4×0.4 · 56 · `Box_B` 0.5×0.3×0.3 · 80 · `Box_C` 0.6×0.3×0.5 · 98 · `Can_A` 0.2×0.4×0.2 · 208 · `Can_B` 0.2×0.4×0.2 · 208 · `Coin_A` 0.8×0.8×0.3 · 236 · `Pallet_Large` 3.2×0.4×3.2 · 132 · `Pallet_Small` 1.6×0.4×1.6 · 132 · `Pallet_Small_Decorated_A` 1.6×1.2×1.6 · 1668 · `Pallet_Small_Decorated_B` 1.6×2.4×1.6 · 3130

**kaykit_restaurant** (15)

`chair_stool` 0.6×0.4×0.6 · 272 · `crate` 1.6×0.6×1.6 · 132 · `crate_lid` 1.6×0.2×1.6 · 164 · `cuttingboard` 1.2×0.1×0.8 · 38 · `extractorhood` 1.6×1.6×1.3 · 204 · `jar_A_large` 0.4×0.6×0.4 · 168 · `jar_C_medium` 0.4×0.5×0.4 · 188 · `kitchentable_A` 1.6×0.8×1.6 · 236 · `kitchentable_B_large` 2.4×0.8×1.6 · 236 · `lid_large` 1.2×0.2×1.0 · 200 · `pan_A` 0.8×0.2×1.2 · 310 · `pot_A` 1.1×0.4×0.8 · 324 · `pot_B` 1.1×0.4×0.8 · 324 · `pot_large` 1.6×0.6×1.0 · 388 · `stove_single` 1.6×1.0×1.8 · 680

**kenney_platformer** (2)

`grass-small` 0.2×0.3×0.3 · 72 · `grass` 0.5×0.3×0.5 · 72

## 8. Geprüft und nicht übernommen

| Kandidat | Ergebnis |
|---|---|
| KayKit Character Pack: Skeletons 1.0 | CC0, **gleiches Rig**, 95 Clips (Extra: `Taunt`, `Idle_B`, `Running_C`, `Spawn_*`). Skelett-Figuren passen thematisch nicht; nur als Clip-Quelle interessant (4,7 MB je Datei) |
| KayKit Space Base Bits 1.0 | CC0, Sci-Fi-Basismodule – Stilbruch, nicht übernommen |
| Restliche Dateien der übernommenen KayKit-Packs | Banner, Gräber, Totenköpfe, Lebensmittel, Betten, Sofas, Straßen, Hex-Kacheln, Burgmauern usw. – für die Gießerei nicht gebraucht |
| Kenney Starter Kits 3D-Platformer (Figur), FPS, City-Builder | Assets CC0, Repos MIT. Platformer-Figur ist ein ungeriggter Roboter mit 4 Knoten-Animationen; FPS/City-Teile haben Kenney-Flachfarben-Look. Nur Gras-Büschel übernommen. Racing/Basic-Scene nur per `ls-remote` geprüft (Rennstrecke bzw. Minimalszene – kein Bedarf) |
| GDQuest `godot-4-3d-third-person-controller` | **Art-Assets CC-BY-NC-SA 4.0 → kommerziell verboten.** Ausgeschlossen |
| godotengine `tps-demo` | Modelle CC-BY 3.0, realistischer Sci-Fi-Stil (Roboter, Industriehalle), 6–29 MB je Datei – Stilbruch |
| godotengine `godot-demo-projects` | Repo zu groß zum Auflisten im Zeitbudget (Abbruch nach 5 min); enthält Engine-Demo-Kunst ohne einheitlichen Stil |
| `pmndrs/market-assets` | Sammlung frei nutzbarer Modelle (Feld `license: 1`, Zuordnung zu CC0 nur auf der Website; u. a. Kenney: `shovel`, `pot`, `survivor-male`), aber Meshes **Draco-komprimiert** (Godot 4.7.2 bricht ab: „required extension 'KHR_draco_mesh_compression' is not supported“, getestet) und Figuren ohne Animationen |
| GDQuest `godot-3d-mannequin`, ToxSam `open-source-avatars`, polygonalmind `100Avatars`, KhronosGroup `glTF-Sample-Assets`, mrdoob `three.js` | nur per `ls-remote` als erreichbar bestätigt, Lizenzen nicht im Detail geprüft: graues Mannequin, VRM-Avatare ohne Clips bzw. technische Testmodelle – kein Stil-Treffer neben KayKit |
| Nicht erreichbar (kein Repo unter dem Namen) | `KayKit-Character-Animations(-1.0)`, `KayKit-Prototype-Bits`, `KayKit-Forest-Nature-Pack(-1.0)`, `KayKit-Mystery-Series-1.0`, `KayKit-Holiday-Bits-1.0`, `KayKit-Platformer-Pack-1.0`, `KayKit-Resource-Bits-1.0`, `KayKit-Block-Bits-1.0`, `KayKit-Mini-Characters-1.0`, `KayKit-Character-Pack-Adventurers-2.0`, `KayKit-Farm/Survival/Pirate/Fantasy-*`, `KenneyNL/Starter-Kit-{Farming,Survival,Top-Down,3D-Shooter}`, alle geratenen Quaternius-Mirrors |

## 9. Werkzeuge

- **Kontaktbogen:** `scenes/asset_sheet.tscn` + `scripts/tools/asset_sheet.gd`. Nutzt die Umgebung aus
  `backyard.gd::_build_environment()` (Distanznebel aus, weil die Kamera weit weg ist) plus warme Fülllichter.
  ```
  timeout -s KILL 600 /opt/tools/godot-render --path game res://scenes/asset_sheet.tscn --fixed-fps 60 -- \
      [--mode=sheet|scale|anims] [--pack=kaykit_dungeon,kaykit_city] [--light=dusk|day] [--dump] \
      --shot=shots/asset_sheet.png --frames=30
  ```
  `--dump` druckt Clips (mit Länge), Skelettpfad, Knochen und Mesh-Knoten (inkl. BoneAttachment) aller geriggten
  Modelle; im Sheet-Modus steht pro Modell eine `MODEL …`-Zeile mit Maßen und Dreiecken im Log.
- **`tools/glb_to_gltf.py <shared.png> <out_dir> <files.glb…>`:** zerlegt GLB in glTF + BIN und ersetzt eine
  eingebettete Textur durch eine gemeinsame PNG (prüft Byte-Gleichheit). Für die Dungeon-Dateien verwendet.
- Neue Packs: nur benötigte Dateien kopieren (`.gltf` + zugehörige `.bin` + Atlas-PNG laut `uri`), `LICENSE` daneben,
  Eintrag in `CREDITS.md`, dann `godot --headless --import`.
