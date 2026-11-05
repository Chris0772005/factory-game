# Technische Schnittstellen (Vertical Slice „Hinterhof“)

Engine: Godot 4.7.2, Forward+, Jolt. GDScript mit statischen Typen, Tabs, `##`-Doc-Kommentare.
Tools im Container: `/opt/tools/godot` (headless), `/opt/tools/godot-render` (rendert per Software-Vulkan;
Screenshot: `godot-render --path game res://scenes/x.tscn -- --shot=/abs/path.png --frames=N`).
Tests: Szene unter `game/tests/` mit Node-Skript, das `get_tree().quit(code)` aufruft (siehe `test_factory.gd`).
Bestehende Helfer: `MeshFactory.rounded_box`, `WorldBuilder` (Umgebung, Boden, Material), `OutlinePass`, `UITheme`, `HUD.popup`.

## Modul A – Zeichnen → Gussmodell (`game/scripts/foundry/drawing/`)

```gdscript
class_name Drawing extends RefCounted
var strokes: Array[PackedVector2Array]   # Punkte in [0,1]², y nach unten
var brush := 0.06                        # Strichbreite relativ zur Zeichenfläche
func add_stroke(points: PackedVector2Array) -> void
func is_empty() -> bool
func to_code() -> String                 # kompakter, URL-sicherer Text (Design-Code), < 2 KB typisch
static func from_code(code: String) -> Drawing   # null bei ungültigem Code
func polygons() -> Array                 # [{outer: PackedVector2Array, holes: Array[PackedVector2Array]}] in [0,1]², bereinigt

class_name CastMeshBuilder
## Relief: Zeichnung liegt flach (Zeichen-XY -> Welt-XZ), Dicke entlang Y,
## zentriert im Ursprung (y von -thickness/2 bis +thickness/2).
static func build(drawing: Drawing, size := 0.6, thickness := 0.08) -> Dictionary
# -> {mesh: ArrayMesh, shapes: Array[Shape3D] (konvex, für RigidBody), aabb: AABB, area: float (m²), volume: float (m³)}

class_name DrawPad extends Control
signal finished(drawing: Drawing)
signal cancelled
@export var time_limit := 30.0           # 0 = ohne Limit
func open(prompt: String) -> void
```

## Modul B – Metall & Effekte (`game/scripts/foundry/fx/`, `game/shaders/`)

```gdscript
# shaders/metal.gdshader  uniforms: base_color, roughness, temperature (0 kalt … 1 weißglühend flüssig),
#   fill_level (Objekt-Y; darüber discard), use_fill, defect_amount (0…1 Poren/Kaltlauf-Flecken)
class_name Alloys      # const TABLE {id: {name, color, roughness, value_mult}}: alu, brass, bronze, iron, gold, rotgold, verdigris
class_name MetalMaterial
static func create(alloy_id: StringName) -> ShaderMaterial
static func set_temperature(mat: ShaderMaterial, t: float) -> void
static func set_fill(mat: ShaderMaterial, level: float, enabled := true) -> void
class_name PourStream extends Node3D     # set_endpoints(from, to), var flow := 0.0 (0…1), Funken an der Aufprallstelle
class_name FurnaceFire extends Node3D    # var heat := 0.0 (0…1): Flammen, Licht, Glut
class_name FoundryFX                     # static sand_burst(parent, pos, size), steam_puff(parent, pos, strength), sparks(parent, pos, amount), dust(parent, pos)
```

## Modul C – Stationen (`game/scripts/foundry/stations/`) – Integration durch Hauptsession

Ofen (Schrott rein, Blasebalg), Tiegel (tragbar, Inhalt + Temperatur, Gießen), Formkasten (Kavitäten, Stampfen,
Füllen, Abkühlen, Zerschlagen), Hammer, Modellbank (öffnet DrawPad), Verkaufskiste, `CastPiece` (Item mit Zeichnungs-Code, Legierung, Note).

## Modul F – Hallen & Levelwechsel (`game/scripts/levels/`, `net/network.gd`)

- `FoundryLevel extends GameWorld`: gemeinsame Basis von Hinterhof und Garage (Gieß-Entities, Upgrades, Spielstand,
  Hallen-Freischaltung). Ein Level überschreibt `build_stations()`, optional `spawn_items()`, `hammer_spot()`,
  `spawn_position(i)`, `respawn_point()`, `upgrade_tier()`.
- Freischalten: Upgrade mit `unlock = true` → `FoundryLevel.on_unlock(id)` → Banner für alle → nach 3,5 s
  `travel_to(path)` (speichert `level` in `SaveGame`, „Solo“/„Hosten“ setzen dort fort).
- Koop-Beitritt: **erst Szene laden, dann verbinden** (`Network.join_after_load` → `GameWorld._ready` →
  `Network.connect_pending`). Der Client meldet sein Level (`Network.announce_level` → Host-Signal `peer_ready`);
  der Host gibt ihm erst dann einen Arbeiter oder schickt ihn ins richtige Level (`send_travel`).
- Levelwechsel: `Network.travel(path)` – Clients tauschen den Peer unter dem Iris-Cover aus, laden das Level und
  verbinden neu (gleicher Weg wie ein frischer Beitritt). Test: `tests/test_net_travel.tscn`.

## Modul G – Garage (`levels/garage.gd`, `environment/garage_set.gd`, `garage_lighting.gd`)

- Puppenhaus-Ansicht: Front offen, Dach und Türsturz nur als Schattenwerfer, Wände mit `env_cutaway`
  (globaler Shader-Parameter `cutaway_target`, gesetzt von `CameraRig`; Wände sind `camera_passthrough`).
- Boden `env_concrete.gdshader` (Fugen, Flecken-Array aus dem Stations-Layout, Parkbucht-Linie, Einfahrt-Pflaster).
  Achtung lavapipe: in Shader-Schleifen keine teuren Noise-Aufrufe und Uniform-Arrays immer in voller Länge setzen.
- Stationen neu: `QuenchTrough` + `WaterBucket` (Abschrecken: `MoldBox.quench()`, Rissrisiko = Anteil verbleibender
  Abkühlzeit × 0,85, Defekt `crack`), `CrateDelivery` + `SealedCrate` (`FoundryRules.CRATES`, Mischung schmilzt als
  eine Charge), `OrderBoard` (Aufträge, Bonus beim Verkauf über `SellCrate`; erste Karte = Bronzefreund-Auftrag),
  HUD `OrdersPanel`. Formkästen kühlen 14 s (`MoldBox.cool_time`).
- Upgrades Stufe 1 (`Upgrades.CATALOG`, `tier = 1`): Gießbaum, Härteöl, Elektrogebläse, Stammkunde.
- Test: `tests/test_garage.tscn`; Bilder: `scenes/garage_showcase.tscn -- --cam=wide|quench`.

## Modul H – Glockengießerei (`foundry/bells/`, `levels/bell_foundry.gd`, `environment/bell_hall_set.gd`)

- `BellProfile`: längster Strich einer Zeichnung = Silhouette (Abstand zur Mittellinie x = 0,5 = Radius, y = Höhe),
  28 Stützstellen Krone→Mund, Drehkörper (`StationKit.lathe`, hohl, Wand 0,16 × Mundradius), Volumen → Liter
  (`LITRES_PER_M3` = 260 wie Formkästen). `lumpiness`/`irregularity` aus der zweiten Differenz der Rohkontur.
- `BellTone`: Grundton f ∝ Wand/D² (bei fester relativer Wand ∝ 1/D), Legierungsfaktor, Schlankheit; Partialtöne
  der Moll-Terz-Glocke (Unterton 0,5 · Prim 1 · Terz 1,2 · Quinte 1,5 · Nominal 2 · 3 · 4), schiefe Kontur verstimmt
  sie; Modalsynthese per Rotationsoszillator in `AudioStreamWAV` (22,05 kHz, ≤ 7 s, ~120 ms, gecacht).
  Notennamen deutsch (H = B♮). Hörproben: `tools/bell_audition.gd`.
- `BellPit` (Zustände EMPTY → PROFILED → TURNED → FILLING → COOLING → READY): Schablone drehen (Takt = Qualität,
  Upgrade Kurbel ×2), Guss in einem Zug (Pause > 2,5 s = Kaltlauf), 16 s Abkühlen, Wasser = gesprungen,
  Lehmmantel aufschlagen → `Bell` steigt heraus, läutet, Banner mit Note.
- `Bell` (Item): Achsen gegen Umkippen gesperrt, läutet bei Hammer und hartem Aufprall (`ring_all`), Wert aus Größe,
  Legierung, Reinheit und Note. `ModelBench.bell_mode` + `DrawPad.bell_mode` (Mittellinie, gespiegelte Hälfte, Ton-Vorschau).
- `ChainHoist` + `ChainHoist.Pendant`: Brückenkran; der Haken hängt `HOOK_AHEAD` vor dem Arbeiter mit der Steuerbirne,
  Last per Feder am Haken (bleibt dynamisch → normal repliziert). Federn: k ≤ ~400 bei 60 Hz, sonst instabil.
- Aufträge Stufe 2 (`OrderBoard.TEMPLATES`, `kind = &"bell"`: Note, Legierung, Reinheit, gesprungen, max. Frequenz),
  erste Karte je Halle über `OrderBoard.first_order`. Upgrades Stufe 2: Gießpfanne (8 l), Kurbel, Stimmbank.
- Tests: `tests/test_bells.tscn` (Profil, Ton, Grube, Halle, Kran), `tests/test_net_bells.tscn` (Koop);
  Bilder: `scenes/bell_showcase.tscn -- --cam=hall|pour|reveal`.
