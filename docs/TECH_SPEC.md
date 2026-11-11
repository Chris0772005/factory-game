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

## Modul I – Eisenhalle (`foundry/iron/`, `levels/iron_hall.gd`, `environment/iron_hall_set.gd`)

- `MeltTargets.deliver`: ein gemeinsamer Weg für jeden Gießstrahl (Tiegel, Pfanne, Abstich). Der Strahl trifft
  per Raycast; der erste Empfänger an der Stelle nimmt das Metall: Formkasten → Formband (Kasten oder Gießautomat)
  → Glockengrube → Pfanne → stehender Tiegel. Sonst Funken – und wer darunter steht, wird zum Bronzefreund
  (Träger der Quelle ausgenommen).
- `CupolaFurnace` (Kupolofen): Ladungen (`ChargeBox`: Eisenkorb 6 l gratis am Gussbruch, Glockenbronze 8 l für 240 $;
  auch Schrott und Kisten) in den Gichtkübel, Gebläse mit gehaltenem F (pro Arbeiter +0,16 Hitze/s, Upgrade
  Heißwind halbiert den Verlust), Bad bis 120 l, Abstich (`TapHole`, F auf/zu) mit 3,2 l/s aus der Rinne.
- `Player`: hält F an einer Station mit `interact_tick(player, delta)` (Pfannen-Handrad, Gebläse), solange sie die
  nächste Station bleibt.
- `HallCrane` (erbt `ChainHoist`, aufgeteilt in `_drive`/`_hook_step`): trägt die `Ladle` fest; F senkt auf Gießhöhe
  (Boden 0,85 m: über Formband, Gießautomat, Formkasten, Grubenrand) bzw. hebt auf Fahrhöhe (2,35 m). Unten fährt
  die Brücke halb so schnell; gekippt hebt sie nicht.
- `Ladle` (50 l, Upgrade 75 l): Handrad hinten (gegenüber der Schnauze, Kurbler stehen hinter Band/Grube);
  Kippen 0,17/s für einen, +60 % je weiterem Kurbler (Fenster 140 ms), loslassen = Schneckengetriebe richtet auf.
  Bis 4,5 l/s. Sync 15 Hz.
- `MoldLine` (Formband): 12 Kästen auf einer Schleife (Vorlauf 6 Plätze: Formmaschine 0, Gießplatz 2, Kühlhaube 3–4,
  Ausleerrost 5; Rücklauf dahinter). Taktet eine Teilung (1,1 s), wenn der Kasten am Gießplatz nicht auf Metall
  wartet, der am Rost nicht mehr heiß ist und an der Maschine geformt wurde. Formen: 3 × F oder Formautomat;
  Gießen: Pfanne/Tiegel direkt oder Gießautomat (30 l Kasten, 0,7 l/s). Ausleeren → `CastPiece.series` rutscht in
  die eigene Verkaufskiste (passives Einkommen). Muster von der Musterbank (`ModelBench.line_mode`).
  Netz: Zustände zuverlässig, Füllung/Takt 10 Hz, Nachzügler über `peer_ready`.
- Aufträge Stufe 3: Serien (`kind = &"series"`, `count` Teile vom Band, Bonus mit dem letzten Teil, Fortschritt
  auf der Karte und im Sync) und die Kaiserglocke (`first_order`, `min_radius` 0,75, Bronze). Die Eisenhalle würfelt
  nur Serien und den Bronzefreund. Upgrades Stufe 3: Formautomat, Gießautomat, Heißwind, Große Pfanne;
  Freischaltung „Eisenhalle kaufen“ (9000 $) in der Glockengießerei.
- Kaiserglocke: `BellPit` mit Mundradius 0,8 (≈ 100 l, H3) und `pour_gap` 40 s (Pfannenwechsel ohne Kaltlauf).
  `Bell.is_great()`: passt in keine Kiste – F an der kalten Glocke liefert sie an den Dom (Wert + Auftrag),
  drei Schläge, dann weg. Mit Auftrag: `on_great_bell_delivered` → `FinaleScreen` bei allen (Abspann, Weiterspielen).
- Kran-Träger und Laufschienen nutzen den Cutaway (`station_metal.gdshader` hat jetzt `cutaway`), Ziegelfugen im
  Putz-Shader sind per `fwidth` geglättet (kein Moiré auf großen Wänden).
- Tests: `tests/test_iron_hall.tscn` (Ofen, Pfanne, Band, Automaten, Serie, Bronzefreund, Kaiserglocke, Finale),
  `tests/test_net_iron.tscn` (Koop: Abstich, Muster, Formen, zwei am Handrad); Bilder:
  `scenes/iron_showcase.tscn -- --cam=hall|tap|kaiser|line|finale`.

## Modul J – Suchaufträge (`progression/search_hunt.gd`, `ui/search_panel.gd`)

- `SearchHunt` hängt in jeder Halle (`FoundryLevel.build_level`). Alle 70–120 s (erster nach 50 s) ist etwas Kleines
  verloren (je Hallenstufe vier Dinge: Ring, Schlüssel, Münze, Nadel, Mutter …). Versteck: freier Boden 0,8–1,9 m
  neben einer Station (Raycast + Kugel-Überlappung), nicht bei einem Arbeiter. 75 s Zeit.
- Wettstreit: Wer zuerst darauf tritt (0,75 m), hat den Fund. Prämie in die gemeinsame Kasse (Stufe 60/140/300/600 $,
  sinkt bis zur Hälfte), Fund auf die eigene Strichliste (`scores` je Arbeiterfarbe).
- Hinweise: Aufblitzen alle 2–4 s, leises ortbares Ticken, HUD-Anzeige „eiskalt … glühend heiß!“ für den eigenen
  Arbeiter (`SearchPanel`, unter dem Geldzähler, mit Spürnasen-Tabelle).
- Netz: Host entscheidet; Zustand zuverlässig per RPC, Nachzügler über `peer_ready`; das Fundstück ist kein Entity,
  jeder Peer baut dasselbe kleine Mesh.
- Tests: `tests/test_search.tscn`, `tests/test_net_search.tscn`.

## Modul K – Ego-Perspektive, Wühlen, Leitfaden, Schrottlinie

**Ego-Perspektive** (`player/camera_rig.gd`, `player/player.gd`, `player/first_person_hands.gd`)
- `CameraRig.first_person_default` (static, true). Headless bleibt `first_person` aus; Tests steuern über `facing`.
- Eigener Körper liegt auf `SELF_LAYER` (1<<9) und ist aus der Cull-Maske der eigenen Kamera genommen. Mitspieler sehen ihn normal.
- `Player.eye_position()`, `look_direction()`; `aims`/`look_pitch` gehen im `_state`-rpc mit. Griff, Tragen und Reichweite folgen dem Blick.
  Tragepunkt ist begrenzt (Höhe ≥ 0,55, Abstand ≥ 0,9), sonst reitet der Spieler auf dem gehaltenen Teil.
- Stationen können gehaltenes F bekommen: `interact_tick(player, delta)`.

**Schrotthaufen** (`foundry/stations/scrap_pile.gd`, Gruppe `scrap_piles`)
- F halten wühlt (`DIG_TIME` 2,2 s, geteilt durch `dig_speed()` aus Handschuhen/Schaufel/Magnet). Vorrat `STOCK_MAX` 30, füllt sich nach.
- `_roll()` würfelt den Fund; Detektor erhöht die Chance auf Seltenes (`DETECTOR_BOOST`). `take_one()` ist der Zugang für Maschinen.

**Leitfaden** (`progression/guide.gd` Klasse `Guide`, Gruppe `guides`; `ui/mail_panel.gd`)
- Briefe von Onkel Heinz (`LETTERS`): je ein Ziel, ein Bonus, ein nächster Schritt. Host prüft `_reached(i)` und schickt `_sync(i, new_letter)`.
- Stationen melden per `guide.note(&"dig" | &"sold" | &"great_bell")`. Der Stand (`index`) liegt im Spielstand.
- `MailPanel` unten links: neuer Brief klappt 14 s auf, danach nur die Zeile „ZIEL“.

**Schrottlinie** (`foundry/auto/scrap_line.gd` Klasse `ScrapLine`, Gruppe `scrap_lines`; `shaders/fx_belt.gdshader`)
- `ScrapLine.build_for(level)` legt in jeder Halle ein Band vom Haufen zum nächsten Ofen an; sichtbar und fest erst mit Upgrade.
- Upgrade `conveyor`: Teile in den Trichter werfen, das Band (`BELT_SPEED`) trägt sie in den Ofen (`_deliver` → `furnace.charge`).
- Upgrade `robot_arm`: Greifarm (Zwei-Gelenk-IK, `ARM_CYCLE` 3,4 s) holt mit `pile.take_one()` selbst und legt aufs Band.
- Simulation nur beim Host; Teile auf dem Band werden per rpc gespiegelt.
- Test: `tests/test_auto.tscn`. Bilder: `scenes/dig_showcase.tscn -- --cam=line|arm`.

## Modul L – Vollautomatik (`foundry/auto/auto_foundry.gd`, `auto_art.gd`, `machine_art.gd`)

- `AutoFoundry.build_for(level)` (Gruppe `auto_foundries`) in jeder Halle mit `Furnace` und `MoldBox`. Host simuliert, Stationen syncen sich selbst, die Pfanne per `_ladle_sync`.
- Fünf Upgrades, jedes nimmt einen Handgriff ab:
  - `auto_bellows` (Stufe 0): Gebläse hält `furnace.heat` auf 0,92, solange Schrott, Schmelze oder eine Fahrt ansteht. Tiegel muss im Ofen stehen.
  - `auto_rammer` (Stufe 1): Form merkt sich ihre letzten Modelle, legt sie nach `REPATTERN_TIME` neu ein und stampft nach `RAM_TIME` selbst (Güte 0,82).
  - `auto_pour`: Pfanne an der Hängebahn (`Trip` IDLE→FILL→GO→POUR→BACK) nimmt den Bedarf der Form aus dem Tiegel und gießt mit `POUR_RATE`. Rest geht zurück in den Tiegel.
  - `auto_breaker`: fertige Form bricht nach `BREAK_DELAY` selbst auf (`_break_open`).
  - `auto_ship`: ruhende Gussstücke (Gruppe `castings`) werden nach `SHIP_REST` ballistisch in die Verkaufskiste geworfen, höchstens `SHIP_TRIES` Versuche.
- Mit `conveyor` + `robot_arm` läuft die Halle ohne Eingriff: Test `tests/test_autofoundry.tscn` (2 Güsse, +150 $ in 47 s).
- `MachineArt`: `loft` (weiche Gussgehäuse), `hose`, `pipe`, `turned` (Drehteile in Achsrichtung), `motor`, `cap`, `bolt_circle`, fertiger Greifarm (`arm`) und Bandrahmen (`conveyor`). `AutoArt`: Gebläse, Schaltschrank an der Form, Schiene, Laufkatze mit Pfanne.
- Studiobilder: `scenes/machine_showcase.tscn -- --cam=arm|close|grip|belt|drive`; Halle: `scenes/dig_showcase.tscn -- --cam=auto`.

## Modul M – Feinschliff

- `foundry/visuals/scrap_models.gd` (`ScrapModels`): echte Formen für getragenen Schrott (Dose, Schlüssel, Rohr, Kessel, Zahn, Ring); `Item.create` und das Band nutzen sie.
- `player/first_person_hands.gd`: Handschuhe aus `MachineArt.loft` (Handfläche, vier Finger, Daumen, Stulpe).
- Metalldetektor: `ScrapPile` würfelt den nächsten Fund vor (`_next`) und piept schneller, je näher ein seltener Fund ist (`Sfx` Ton `detector_beep`, zur Laufzeit erzeugt).
- `environment/sway_lamp.gd` (`SwayLamp.hang`): Hängelampen in der Garage, schwingen bei Kopfstößen und bei `Juice.impacted`; Licht wandert mit.
- `ui/license_screen.gd`: Hauptmenü → „Lizenzen“: Danksagung, Godot-Lizenz, Drittbestandteile (`Engine.get_license_text/get_copyright_info/get_license_info`).
- Bekannt: `test_net_foundry` fällt selten beim Gießen aus (nicht reproduzierbar, Diagnosezeile `DIAG` eingebaut).

## Modul N – Schalter, Fundbuch, Namen

- `foundry/auto/auto_switch.gd` (`AutoSwitch`, interactable am Schaltschrank): schaltet je Form das Nachformen und Stampfen aus/an (`AutoFoundry.enabled[i]`, `set_enabled`, rpc `_enabled_sync`). Ein begonnenes Stück wird trotzdem gegossen, aufgerüttelt und verschickt.
- `progression/find_book.gd` (`FindBook`, Gruppe `find_books`): sieben Schätze (`ScrapPile.RARE`), erster Fund zahlt `BONUS` × Anzahl, das volle Buch `FULL_BONUS`. Liste im Spielstand (`finds`). Neue Schrottarten: Pokal, Kerzenständer, Goldmünze, Fahrradklingel.
- `ui/find_panel.gd`: Pille neben dem Geld mit „≈ N $/min“ (Einnahmen der letzten 60 s) und Fundbuch-Stand.
- Spielernamen: `GameSettings.player_name` (Einstellungen → Spieler), `Player.display_name`, rpc `_name_sync` alle 4 s vom Besitzer, `Label3D` über fremden Spielern.
- `SwayLamp` auch über den Werkbänken der Glockengießerei (Eisenhalle nicht: der Hallenkran fährt überall).
