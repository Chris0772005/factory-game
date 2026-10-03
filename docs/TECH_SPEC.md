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
