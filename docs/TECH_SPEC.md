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

## Modul O – Musik und Steam (vorbereitet)

- Autoload `Music` (`core/music.gd`): spielt `res://assets/music/<szene>.ogg|.mp3` (`menu`, `backyard`, `garage`, `bell_foundry`, `iron_hall`), sonst `theme`; Schleife, Überblendung `FADE`. Lautstärke `GameSettings.music_volume` (Einstellungen → Musik). Ohne Datei bleibt es still. Regeln für Dateien: `game/assets/music/LIESMICH.md`.
- Autoload `SteamService` (`core/steam_service.gd`): nur aktiv, wenn die GodotSteam-GDExtension installiert ist und Steam läuft; sonst tut jeder Aufruf nichts. App-ID aus Projekt-Einstellung `steam/app_id` (Standard 480 = Valves Test-App). Steam-Name wird Spielername, Erfolge nach `ACHIEVEMENTS` über `earned(world)`. Gegen einen laufenden Steam-Client noch nicht getestet.
- Offen bis zum eigenen Steamworks-Konto: App-ID, GodotSteam-Erweiterung einbinden, Erfolge in Steamworks anlegen, Koop über Steam-Lobbys statt IP, Upload der Builds.

## Modul P – Eisenhalle automatisch, Abwesenheits-Einnahmen, Musik

- `foundry/auto/auto_iron.gd` (`AutoIron`, Gruppe `auto_irons`, interactable = Schaltschrank am Gebläse): `auto_charger` (alle `CHARGE_EVERY` s 6 l Eisen in den Schacht, solange das Formband braucht), `auto_blast` (Hitze 0,94), `auto_tap` (Bodenkanal pumpt `PUMP_RATE` l/s in den Gießkasten, nur bei >90 % Eisen im Herd). Schrank schaltet alles aus/an. Test `tests/test_autoiron.tscn` (+112 $ in 12 s).
- `progression/offline_income.gd` (`OfflineIncome`): misst bei Vollautomatik die Einnahmen (Fenster 180 s), Spielstand merkt `time` und `rate`; beim Laden `payout(rate, sekunden)` = halbe Rate, höchstens 2 h, ab 2 min, mit Banner „Willkommen zurück“.
- Musik: `tools/music_gen.py` erzeugt `menu`, `backyard`, `garage`, `bell_foundry`, `iron_hall` (KI-komponiert, siehe CREDITS).
- `test_net_foundry`: Ursache des seltenen Ausfalls war ein unter Last verrutschter Testspieler (goss neben die Form); der Test hält die Position jetzt fest.

## Modul Q – Runde Kulissen

- `environment/car_art.gd` (`CarArt.station_wagon`): Kombi in der Garage aus Lofts; das Bausatz-Auto bleibt unsichtbar nur für den Kollisionskörper.
- `environment/prop_art.gd` (`PropArt`): glatte Ersatzformen für runde Bausatz-Requisiten (Stahlfässer, Holzfässer, Farbdosen, Eimer). `PropKit.place` tauscht sie über den Modellnamen aus; Größe und Kollision kommen weiter aus dem Bausatzmodell.
- Studiobilder: `scenes/machine_showcase.tscn -- --cam=car|carback|props|blower|trolley|scrap|hands`.

## Modul R – Spielgefühl nach dem ersten Test

- **Sprung** (`player/player.gd`): eigene Schwerkraft beim Steigen (×2,0), Fallen (×2,7) und nach Loslassen der Taste (×3,6); `COYOTE_TIME` 0,1 s, `JUMP_BUFFER` 0,12 s. Etwa 0,75 m hoch, eine halbe Sekunde lang.
- **Eigener Körper** (`player/first_person_legs.gd`): Bauch, Schürze, Hosenbeine und Stiefel unter der Kamera, laufen mit und ziehen in der Luft an. Nur lokal, ohne Schatten (den wirft das versteckte Modell).
- **Hände** (`player/first_person_hands.gd`): jeder Finger hat drei Gelenke (`_set_curl`). Posen `REST`, `REACH`, `CARRY`, `PRESS`, `DIG_NEAR`, `DIG_FAR`. Greifen = hinreichen, schließen, heranziehen; F halten = Hand über Hand; Werfen = Stoß nach vorn. Hände schwingen mit den Schritten und hängen bei schnellen Drehungen nach.
- **Wäsche** (`shaders/env_cloth.gdshader`): `trample[4]` wie beim Gras; `GrassField` setzt die Spielerpositionen.
- **F halten** (`interact_tick`): Formkasten stampft und schlägt im Takt (`HOLD_BEAT` 0,42 s), der Ofen tritt den Blasebalg alle 0,5 s.
- **Einstieg**: `ui/intro_letter.gd` zeigt bei neuem Spielstand den Brief mit den vier Schritten. `NextStepCard.next_step` richtet sich in den ersten beiden Briefen nach dem Ziel des Briefs und setzt `NextStepCard.target`; darüber schwebt ein gelber Pfeil (`_update_marker`).
- **Einstellungen** (`ui/settings_panel.gd`): Bereiche links (Spiel, Ton, Steuerung, Grafik), Zeilen als Karten mit Erklärung, Tastenübersicht.
- **Oberflächen** (`station_metal.gdshader`): `dust` (Staub auf Flächen, die nach oben zeigen), `grime` (Schmutzstreifen und Flecken), `edge_wear` (abgeriebene Kanten). Gilt für alle Stationsmetalle.
- **Förderband** (`MachineArt.conveyor`): Einlaufbleche mit Gummilippen, Spannschrauben, Not-Aus, Schutzblech mit Warnstreifen.
- **Test**: `test_bells` läuft um die Glocke herum statt durch ihren Rand; die Kran-Steuerbirne stößt keine Lasten mehr an.

## Modul S – Foto-Oberflächen (realistischer Look)

- `shaders/env_photo.gdshaderinc`: legt CC0-Scans (Poly Haven, `assets/textures/pbr/`, je Farbe, Normal, ARM in 1k) dreiseitig projiziert über die entworfenen Flächen. Die Scan-Farbe moduliert nur um ihren eigenen Mittelwert, die gewählten Farbtöne bleiben also erhalten; Normal und Rauheit bringen Körnung, Poren und Kratzer.
- `env_photo_world` für feste Kulissen (Boden, Putz, Erde), `env_photo_object` für Bewegliches (Holz, Stationsmetall), damit die Körnung mitwandert.
- Die Texturen sind globale Shader-Uniforms (`ph_*` in `project.godot`); `photo_detail` (0..1) regelt die Stärke.
- Die Tusche-Umrisslinien sind aus (`OutlinePass`, `-- --outline` schaltet sie für Vergleiche ein).
- `environment/photo_prop.gd` (`PhotoProp`): ersetzt Bausatz-Requisiten (Fässer, Kisten, Kartons, Eimer, Säcke, Büsche, Stühle) durch gescannte Poly-Haven-Modelle in gleicher Größe; `"name:2"` wählt eine Variante aus einem Modell mit mehreren.
- Foto-Detail auch auf Laub (`leaves`), Dach, allgemeinen Flächen und Bausatz-Requisiten; Blütenköpfe im Gras sind kleiner und werden direkt vor der Kamera ausgeblendet.
- Prüfhilfe: `-- --pitch=-60` startet mit Blick nach unten (eigene Beine).
- Vorlage des Nutzers (rot-orange Industrieroboter in einer Halle): Greifarm glänzend rot-orange auf dunklem Sockel mit Bodenplatte und Kabelbündel; `YardLighting` schaltet Spiegelungen (SSR) und Dunst ab mittlerer Qualität ein, die Hallen haben dichteren Dunst (`GarageLighting`); `env_concrete` hat `polish` für den versiegelten Hallenboden.
- `GarageSet._workshop_gear`: stellt bis zu fünf gescannte Geräte an freie Wandstücke (mindestens 2,1 m von Stationen und anderen Kulissen entfernt), mit Kollision.
- `StylizedTree`: Stamm mit Rinden-Scan (`bark_material`), Kronen mit gescannten Zweigen (`PhotoProp.clump`); Hintergrundbäume nur auf hoher Qualität.

## Modul T – Neuer Spielstart: Schrotthalle (nach dem zweiten Test)

- Start ist `scenes/scrap_hall.tscn` (`levels/scrap_hall.gd`, Kulisse `environment/scrap_hall_set.gd`): große Halle mit offenem Tor, davor Straße mit Zebrastreifen, gegenüber der Schrott-Ankauf. Der Hinterhof bleibt als Menü-Hintergrund und für die Tests.
- `stations/scrap_mountain.gd` (`ScrapMountain`, erbt `ScrapPile`): Berg mit `GRABS` Griffen, wächst nicht nach, schrumpft sichtbar (`size_now`), von jeder Seite abtragbar (`interact_point_for`). Leer: Prämie und neue Ladung mit weniger Blech (`junk_share`).
- `stations/scrap_bucket.gd` (`ScrapBucket`): steht er beim Wühlen in der Nähe, fallen die Funde hinein. F am Ankauf verkauft alles, F am Ofen kippt das Metall hinein und behält das Blech.
- `stations/scrap_shop.gd` (`ScrapShop`, erbt `SellCrate`): kauft Gussstücke, rohe Funde und Blech (`FoundryRules.raw_price`, `JUNK`).
- Gießerei-Ecke (Ofen, Zeichentisch, zwei Formkästen, Auftragstafel) entsteht erst mit dem Upgrade `foundry_corner`; die übrigen Gießerei-Upgrades werden erst danach angeboten (`Upgrades.offered`).
- `Guide.letters()`: die Halle hat zwei eigene Briefe (`HALL_LETTERS`); gespeichert wird die Brief-Kennung statt des Index. Spielstand-Version 2 (alte Stände starten neu).
- Steuerung: Getragenes folgt den Händen direkt (`Player.TIGHT_HOLD_MASS`) und stößt den Träger nicht (`_update_carry_exception`); Ziel ist, was der Blickrichtung am nächsten liegt; `toss_targets` (Ofen, Verkaufskiste, Eimer, Ankauf) nehmen Losgelassenes im Bogen auf, der Tiegel rastet in den Ofen (`toss_place`). Der Tiegel kippt nur über einer Form (`Crucible._receiver_below`).
- `drawing/drawing_templates.gd` (`DrawingTemplates`): acht Motive als Ein-Klick-Vorlagen am Zeichentisch, `score`/`best` erkennen auch frei gezeichnete Motive; `OrderBoard`-Aufträge der Art `motif` zahlen dafür einen Bonus.
- Anzeige: Vollbild als Standard, Seitenverhältnis `expand` (keine Balken), Menü-Elemente verankert, Einstellungen zentriert. Schrift: Barlow Condensed.
- Flammen (`shaders/fx_flame.gdshader`): weich, additiv, zwei Turbulenz-Schichten statt harter Farbbänder.
- Geräusche: Aufnahmen aus Kenney „Impact Sounds“ (CC0) in `assets/sfx/real/` haben Vorrang vor den erzeugten Klängen; Schritte auf Hallenboden.
- Prüfhilfen: `-- --hold=<kind>` gibt dem Spieler einen Gegenstand in die Hand, `--yaw=<Grad>` dreht den Startblick, `--menu=settings|coop` öffnet Menüteile.

## Modul U – Das Viertel: offene Stadt, heiße Ware, Polizei (Richtung „Schedule I“)

Ziel des Nutzers: der Kern bleibt „im Schrott wühlen und ausbauen“ (Find the Needle), dazu eine offene Stadt mit begehbaren Häusern, die einen Zweck haben, und ein zweiter, krimineller Weg zu schnellerem Geld mit höherem Risiko. Erste Stufe:

- `environment/town_block.gd` (`TownBlock`): `house` baut ein begehbares Haus (Türöffnung, Fenster mit Glas, Innenputz, Boden, Decke mit Lampe, Schild), `closed` ein geschlossenes mit Rollladen, dazu `counter`, `shelves`, `barrier`. `ScrapHallSet._town` stellt Pfandhaus und Polizeiwache (beide begehbar), ein Haus „zu vermieten“ und einen Kiosk in die Reihe gegenüber; die Straße endet links und rechts an Absperrungen (`TOWN_X`).
- Heiße Ware (`FoundryRules.HOT`): Kennzeichen, Geldkassette, Pistole, Schmuck. Kommt nur beim Wühlen von Hand aus dem Berg (`ScrapPile.hot_share`, Berg 2,5 %), Maschinen übergehen sie. Kowalski kauft sie nicht; sie bleibt im Eimer (`ScrapBucket.hot`, `take_hot`, `sell_scrap`).
- `town/town_counter.gd` (`TownCounter`) mit `FenceCounter` (Pfandhaus: Schwarzmarktpreis, Fahndung steigt) und `PoliceDesk` (Polizeiwache: Finderlohn, Fahndung sinkt). Abgabe: Ware an der Theke loslassen oder [F] mit dem Eimer.
- `town/town_law.gd` (`TownLaw`): `heat` 0..1 („Fahndung“, fünf Stufen im HUD, kühlt in 5 min ab), `carried_hot` (offen in der Hand oder versteckt im Eimer), `arrest` (Ware weg, Strafe = halber Schwarzmarktwert), `weapon_of` (Gussstück in Waffenform).
- `town/police_patrol.gd` (`PolicePatrol`): Streife auf dem Gehweg. Offen getragene Ware sieht sie auf 11 m im Blickfeld, Ware im Eimer erst auf 3,2 m; bleibt der Spieler in Sicht, füllt sich `alert`, bei 1 beginnt die Verfolgung. Eingeholt mit Ware: `arrest`. Ware fallen lassen oder 5 s außer Sicht bleiben beendet die Verfolgung ohne Strafe; herumliegende heiße Ware sammelt die Streife ein. In die Häuser folgt sie noch nicht (`max_z`): wer es ins Pfandhaus schafft und verkauft, ist die Ware los, bevor sie ihn hat. Der Host rechnet, die anderen bekommen Position, Zustand und `alert`.
- `town/law_hud.gd` (`LawHud`): Fahndungsanzeige unter dem Geld, Warnung oben, solange ein Polizist Verdacht schöpft oder verfolgt.
- Waffenschmiede: `DrawingTemplates` hat drei dunkle Motive (Schlagring, Dolch, Pistole; `dark`), die Zeichenfläche zeigt sie in einer eigenen Zeile. `OrderBoard.dark` ist die Tafel im Pfandhaus mit den dunklen Aufträgen; ein Guss in Waffenform bringt an der Theke das Dreifache seines Werts plus den Auftragsbonus (`OrderBoard.fulfil(world, piece, true)`). Mit einer Waffe in der Hand gilt dasselbe wie mit heißer Ware.
- `town/town_npc.gd` (`TownNpc`): Pfandleiher und Wachhabender hinter den Theken (das Arbeiter-Modell in anderer Kleidung; eigene Stadtfiguren fehlen noch).
- Test: `tests/test_town`. Prüfhilfe: `-- --at=x,z` stellt den Spieler an eine Stelle.
- Noch offen für die offene Welt: weitere Straßen und Häuser (Werkzeugladen, Bank, Kneipe, Hafen), Kunden und Passanten, Grundstücke kaufen, Fahrzeuge, Nacht, Gefängnis/Kaution, mehrere Streifen, Mitarbeiter.

## Modul V – Hochfahren: Missionen, Bagger, LKW, Werkbank (Nebengeschäft)

- Schilder an Häusern und Tafeln sind englisch (POLICE, PAWN SHOP, SCRAP DEALER, FOR RENT, ROAD CLOSED, ORDERS, OFF THE BOOKS, SALE); Spieltexte bleiben deutsch und nennen die Orte so, wie sie auf den Schildern stehen.
- `progression/missions.gd` (`Missions`): drei Missionen laufen gleichzeitig, eine je Strang (Schrott, Betrieb, Unter der Hand). Jeder Strang ist eine Liste von Vorlagen, die immer wieder durchlaufen wird; jede Runde verlangt 60 % mehr und zahlt 50 % mehr. Vorlagen mit `needs` werden übersprungen, bis der Ausbau da ist. Stationen melden mit `Missions.report(tree, stat, n)`; „verdient“ zählt über `money_changed`. Im Spielstand gespeichert. Anzeige: `ui/missions_panel.gd` links unter dem Geld.
- `auto/excavator.gd` (`Excavator`): Zyklus 8 s (mit `excavator_fast` 5 s), nimmt bei 30 % drei Teile aus dem Berg (`ScrapPile.take_bulk`: Schrott und Blech, nie heiße Ware) und kippt sie bei 75 % in die Mulde. Steht, solange die Mulde voll oder der Berg leer ist.
- `auto/scrap_skip.gd` (`ScrapSkip`): 60 Teile. [F] mit dem Eimer kippt hinein (heiße Ware bleibt im Eimer). Ohne LKW: [F] an der Mulde, Kowalski holt ab und zahlt 80 %. Mit LKW: `auto/scrap_truck.gd` (`ScrapTruck`) fährt bei voller Mulde vor, lädt, fährt durch die Schranke (`town/boom_gate.gd`) aus dem Viertel und kommt am anderen Ende wieder herein; bezahlt wird der Großhandelspreis (120 %).
- `stations/workbench.gd` (`Workbench`): [F] mit dem Eimer baut aus dem Inhalt Waffen nach `FoundryRules.RECIPES` (Rohrpistole, Federstock, Zahnrad-Schlagring, Blechklinge); sie liegen danach als heiße Ware im Eimer und gehen an den Pawn Shop.
- Ausbauten in der Halle (`Upgrades`, `hall = true`): `workbench` 120 $, `excavator` 450 $, `truck` 600 $ und `excavator_fast` 800 $ (beide mit `needs = excavator`).
- Tests: `tests/test_missions`. Prüfhilfe: `-- --machines` kauft Werkbank, Bagger und LKW.
- Figuren der Stadt: `town/town_figure.gd` (`TownFigure`) lädt Quaternius-Menschen (CC0, normale Proportionen; `assets/models/quaternius/`: Swat, Suit, Worker, Casual, Casual_Woman) und spielt darauf Gehen, Rennen, Stehen und Gesten aus `Anim_Character.glb` (gleiche Rig-Familie; Spuren für fehlende Knochen werden entfernt). Polizist (Swat in Blau) und Pfandleiher (Suit) nutzen sie; die Mitspieler-Figur ist noch das alte Modell.

## Modul W – Arbeitsregel Vergleichsbilder, Menüs, LKW

- **Regel des Nutzers (gilt immer):** Vor jedem Modell und jedem Menü Vergleichsbilder aus passenden Spielen holen und danach bauen. Quelle, die von hier aus erreichbar ist: Steam (`store.steampowered.com/api/storesearch/?term=…` für die App-ID, `…/api/appdetails?appids=…` für die Screenshots). Die Bilder bleiben außerhalb des Repos (fremdes Bildmaterial). Bisher genutzt: Construction Simulator und SnowRunner (Bagger, LKW), Supermarket Simulator und Find the Needle (HUD, Laden), Schedule I (Stadt, Figuren).
- Menüs nach diesen Vorbildern: fast schwarze, eckige Flächen (Radius 3–4, 1 px Rand, kein Schatten), HUD-Kästen mit orangem Balken links, kaum Umrisslinien an Schrift, Großbuchstaben nur für kurze Überschriften. Texte im HUD sind Stichworte mit Zahl („Schrott wühlen 3/15 +20 $“), keine ganzen Sätze. Der Ausbau-Laden (`progression/upgrade_shop.gd`) ist ein Vollbild-Raster aus Karten (Name, ein Satz, Preis) wie der Forschungsbildschirm von Find the Needle. Das Ziel unten links erscheint nur noch, solange ein Brief offen ist; die Aufgabe steht im Kasten „AUFGABE“.
- LKW (`auto/scrap_truck.gd`): Dreiachs-Kipper nach Construction Simulator. Fahrerhaus als Seitenprofil, das über die Breite gezogen wird (`_prism`), geneigte Scheibe, Stoßfänger mit Scheinwerfern, Grill, Spiegel, Trittstufen, Rahmen, Tank, Auspuff, gedrehte Reifen mit Felgen und Radmuttern, Kippmulde mit Rippen, Bordwand und Schutzdach, Rücklichter, Rundumleuchten. Fahrzeuglack ohne die Schmutzschlieren der Wände (`grime` klein).

## Modul X – Fahrzeuge in Modellqualität (Blender-Werkzeugkette, echter Bagger)

Kritik des Nutzers: LKW und Bagger aus Spielcode-Klötzen wirken eckig; sie sollen wie die Fahrzeuge in den Vergleichsbildern aussehen, mit Blick durch die Scheiben auf Sitze und Armaturen. Langfristiges Ziel des Nutzers: Grafik „wie im echten Leben“.

- **Blender als Werkzeug:** `pip install bpy` (Blender 5.3 als Python-Modul, liegt außerhalb des Repos). `tools/blender/mm_kit.py` (abgeleitet von `assets/blender/blendkit.py` aus dem Projekt des Baggers, Apache 2.0, angepasst und erweitert): Formen in ein bmesh (`add_box`, `add_obox`, `add_cyl`, `add_prism`, `add_tube`, `add_lathe_y`, `fillet`, `arc`), `make` macht daraus ein Objekt mit abgerundeten Kanten (Bevel + Weighted Normal), glatter Schattierung und Box-UVs; `surface` erzeugt PBR-Materialien mit Albedo-, Rauheit/Metall- und Normal-Textur (Lack, abgenutzter Lack, Stahl, Gummi, Kunststoff); `export_glb` schreibt GLB (Y-up) und entfernt eingebettete Farbprofile aus den JPEGs (Godot liest sie sonst nicht).
- **LKW:** Der erste, aus Formen zusammengesetzte Kipper (`truck_hd.py`) ist ersetzt, siehe Modul Y. Räder sind eigene Knoten (`wheel_*`, Ursprung an der Nabe) und drehen sich im Spiel mit der gefahrenen Strecke (`ScrapTruck._roll_wheels`).
- **Bagger:** fertiges Modell `zx200_hd.glb` (Apache 2.0, siehe CREDITS). `auto/digger_rig.gd` (`DiggerRig`) dreht Oberwagen, Ausleger, Stiel und Löffel in ihren Gelenken und setzt die losen Teile der Datei für jede Stellung an ihre Bolzen: drei Hydraulikzylinder (Rohr und Stange) zwischen Fuß- und Augenbolzen, das Löffelgestänge als Gelenkviereck. `Excavator.KEYS` beschreibt einen Arbeitstakt (greifen, eindrehen, heben, schwenken, auskippen, zurück).
- **Schnelle Vorschau:** `game/tools/model_view.tscn` zeigt ein Modell in Tageslicht (`-- --model=res://… --yaw= --pitch= --dist= --h=`, `--rig=schwenk,ausleger,stiel,löffel` für den Bagger); ein Bild dauert etwa 25 s statt 5–8 min in der Halle.
- **Weitere freie Quellen, geprüft:** Poly Haven (CC0) hat keine Fahrzeuge, aber fotorealistische Straßen- und Werkstattteile (Laternen, Hydrant, Betonbarrieren, Rolltore, Fabrikfassade, Zäune, Werkzeugschrank, Schraubstock); im selben Projekt wie der Bagger liegen Planierraupe, Walze und Kettendumper (Apache 2.0).

## Modul Y – Grafikstandard „wie auf dem Vorbild“ (verbindliche Regel)

Vorgabe des Nutzers: Ein Bild aus dem Construction Simulator (gelber Bagger im Schlamm, rot-oranger LKW mit Licht, Arbeiter, Herbstwald) ist ab jetzt der Maßstab für **alles**: Fahrzeuge, Maschinen, Häuser, offene Welt. Seine Kritik am Stand davor: „zu eckig, zu kantig, zu verschachtelt, sieht 3D-modelliert aus“; es soll aussehen wie ein echter Bagger und ein echter LKW, mit Blick durch die Scheiben auf Sitze und Armaturen. Das Vorbild ist urheberrechtlich geschützt und liegt nur außerhalb des Repos.

**Die Regel.** Vor jedem neuen Modell, Gebäude oder Bildschirm Vergleichsbilder aus passenden Spielen ansehen (Modul W) und das Ergebnis im Licht des Spiels daneben legen. Ein Teil gilt erst als fertig, wenn es im Bild besteht:

1. **Form:** echte Proportionen und runde Übergänge. Fahrzeuge und Maschinen kommen aus fertigen Modellen mit freier Lizenz oder aus sauber gebauten Blender-Modellen, nicht aus Spielcode-Klötzen.
2. **Oberfläche:** Lack unter Klarlack, der den Himmel spiegelt; Glas, durch das man hineinsieht; Gummi und Stahl matt; unten Schlamm, oben sauber.
3. **Licht:** Lampen leuchten wirklich (Leuchtfläche mit Schein und ein Lichtkegel), wenn die Maschine arbeitet.
4. **Umgebung:** Foto-Himmel, harte Sonne, klare Luft. Böden, Wände und Requisiten aus Foto-Texturen und Scans (Poly Haven, CC0) statt gemalter Muster.
5. **Ehrlich bleiben:** Im Bericht steht, was noch vom Vorbild abweicht.

**Umgesetzt in diesem Schritt**

- **Tageslicht der Schrotthalle** (`GarageLighting.daylight`): Foto-Himmel `shaders/env_sky_photo.gdshader` aus zwei Bildern in `assets/sky/` – das 8k-Bild, das man sieht (`day_sky_view.jpg`, als BPTC importiert), und sein 2k-HDR-Original, das die Szene beleuchtet und sich in Lack und Glas spiegelt (`day_sky_light.hdr`, die Sonnenscheibe ist dort gekappt). Die Sonne des Fotos steht 47,9° hoch; `DAY_SUN` richtet das Sonnenlicht genauso aus. Sonne 3,0 mit scharfem Schatten (Winkelgröße 0,55°, vier Schattenstufen bis 80 m; auf niedriger Stufe zwei bis 45 m), kein Dunst im Raum, kein Abend-Farbstich, mehr Kontrast und Sättigung, kräftigere Umgebungsverdeckung. Das Fülllicht und die Randabdunklung der Abendhallen entfallen am Tag. Die Halle selbst bekommt neutrales Streulicht (`ScrapHallSet._reflection_probe`).
- **`VehicleFinish`** (`foundry/visuals/vehicle_finish.gd`): ein Finish für alle Fahrzeuge, nach Materialnamen. `paint*` bekommt Klarlack (auf Wunsch eine neue Farbe), `glass*` wird durchsichtig und wirft keinen Schatten, `chrome*` spiegelt, `lamp*`/`lens*` leuchten, und über jedes Teil liegt der Schmutz aus `shaders/vehicle_dirt.gdshader`: unten angebackener Schlamm, darüber Spritzer in Streifen, oben ein Hauch Staub, dazwischen sauberer Lack. Muster und Schlammgrenze sind an der Maschine in Ruhestellung festgemacht (jedes Teil bekommt beim Auftragen seine Lage auf der Maschine als Instanz-Wert `rest_x/y/z`): Der Schmutz wandert weder beim Fahren noch wenn sich Ausleger oder Räder bewegen. Innenräume (Sitze, Armaturen, Auskleidung) bleiben sauber. `VehicleFinish.lamps` und `.light` schalten die Leuchten, `.beam` setzt einen Lichtkegel.
- **Bagger** (`DiggerRig`): gelb mit weißer Kabine. Die Kabine der Datei ist ein geschlossener Block mit aufgeklebten Scheiben; `tools/blender/zx200_cab.py` höhlt ihn aus und schneidet die Fenster (`zx200_cab_open.glb`), sodass man Sitz, Konsole und Hebel sieht. Arbeitsscheinwerfer (Leuchtfläche und Lichtkegel) und ein gelber Warnbalken auf dem Dach laufen, solange der Bagger arbeitet (`Excavator.working`).
- **LKW:** neues Modell `dump_truck.glb` nach „Dump Truck“ von ElectroNick (CC BY 4.0, Namensnennung in `CREDITS.md` und im Spiel unter „Lizenzen“). `tools/blender/dump_truck.py` zerlegt die Vorlage (ein verschmolzenes Objekt) in Teile, bringt sie auf 7,6 m Länge, trennt die sechs Räder ab (`wheel_fl` … `wheel_r2r`), vergibt Materialien nach Bauteil (roter Lack, graue Mulde, Kunststoff, Gummi, Sitzstoff), macht die Scheiben klar, kleidet die Kabine innen aus und ergänzt Rücklichter und Rundumleuchten. `ScrapTruck` schaltet Scheinwerfer, Rücklichter und zwei Lichtkegel für die Fahrt ein.
- **Vorschau** (`game/tools/model_view.tscn`): zeigt ein Modell jetzt im Licht der Halle (`--plain` für das alte schlichte Licht), mit `--finish`, `--lamps` und `--hide=teil1,teil2`.
- **Foto-Oberflächen als ganze Fläche:** `shaders/env_scan.gdshader` legt einen Poly-Haven-Scan (Farbe, Relief, Rauheit; `assets/textures/scan/`) von drei Seiten im Weltraster auf, in der echten Größe des Scans; die schlichten Kästen der Kulissen brauchen keine UVs. `EnvMesh.scan(schlüssel, scan, {tint, drift, foot …})` baut das Material, `EnvMesh.toward(scan, farbe)` tönt einen Scan auf eine nahe Wunschfarbe, `EnvMesh.repainted(schlüssel, scan, farbe)` lackiert einen kräftig gefärbten Scan um (nur sein Hell-Dunkel bleibt), `EnvMesh.SCANS` hält Kachelgröße und Mittelfarbe. Der Shader liest auf geraden Flächen nur die eine Seite, die zählt (drei statt neun Texturzugriffe), und kann wie die gemalten Wände für die Draufsicht-Kamera aufgehen (`cutaway`). Eingebaut in der Schrotthalle: Straße (`asphalt_02`), Vorplatz (`concrete_pavers`), Gehweg gegenüber (`concrete_tiles_02`), Höfe (`dirty_concrete`), Hofmauern mit Betonabdeckung (`red_brick_03`), Ankauf (`red_brick`), Hallenwände als Ziegelsockel bis 2,2 m mit Trapezblech darüber (`ScrapHallSet._wall_box`), Hallendach von unten Trapezblech.
- **Häuser** (`TownBlock`): Wände aus Scans (`wall_material`: `scan`, `tone` oder `plaster`), Dachrand als aufgemauerte Attika mit Betonabdeckung und Dachpappe (`_crown`), Sockel und Gesims aus Betonwerkstein (`_stonework`). `TownBlock.block` baut die Häuser im Hintergrund neu: drei bis vier Geschosse, Fensterreihen mit Rahmen, Sohlbank und Sturz auf allen Seiten, Haustür, Sockel, Gesims, Attika. Sie ersetzen die Bausatz-Häuser.
- **Gescannte Straßenmöbel:** Straßenlaterne und Hydrant von Poly Haven über `PhotoProp.SWAPS` (gilt für alle Hallen, die die Bausatz-Teile setzen). Eine Datei mit mehreren Varianten wählt man mit `"name:2"` (drittes Teil) oder `"name:_aged"` (alle Teile, deren Name so endet).
- **Straße belebt (nach Vergleichsbildern aus Supermarket Simulator und Schedule I):** gescannte Rolltore an den geschlossenen Läden (`PhotoProp.mount` hängt einen Scan an eine Wand und streckt ihn auf Wunschmaß; „FOR RENT“ mit Graffiti), Mülltonnen und Müllsäcke, Schaltkasten, Bank, Kanaldeckel, Betonsperren an den Straßenenden, Wandlampe und Klimageräte an den Fassaden, ein Auto unter einer Plane auf dem Vorplatz (`ScrapHallSet._street_dressing`). Der Müllcontainer ist aus Blechkästen mit fotografiertem grünem Lack gebaut (`TownBlock.dumpster`).
- **Absetzmulde:** fertiges Modell `skip.glb` nach „Old rubbish Skip“ von Sousinho (CC BY 4.0, Namensnennung in `CREDITS.md` und im Spiel unter „Lizenzen“): gelber Lack mit Rost, Warnstreifen, Kettenösen. `tools/blender/skip.py` bringt die Vorlage auf 3,2 m Länge und stellt sie auf den Boden; Form und Bemalung bleiben, die Texturen sind auf 2048 px verkleinert. `ScrapSkip` zeigt das Modell mit Schlamm am Fuß (`VehicleFinish`), der Füllstand steht mit Kreide auf der Längsseite.
- **Schrott als Ladung:** `ScrapLoadArt.pile(boden, rand, höhe, kuppe)` schichtet die Teile des Schrottbergs (Bleche, Träger, Platten, Rohre, Fässer, Dosen) vom Boden eines Behälters bis über seinen Rand, in der Form des Behälters (unten schmal, oben breit) und mit Abstand zu den Wänden. Jedes Teil kennt den Füllstand, ab dem es zu sehen ist; `ScrapLoadArt.reveal(haufen, k)` zeigt den Haufen bis dahin (`MultiMesh.visible_instance_count`, die Teile sind nach Füllstand sortiert). So wächst der Schrott in der Mulde Teil für Teil vom Boden her, ohne dass etwas durch die schrägen Wände stößt. Auf dem LKW liegt derselbe Haufen als volle Ladung über den Bordwänden (nur seine obere Hälfte wird gebaut).
- **Speicher:** `EnvMesh.release_scans()` gibt die Scan-Materialien frei, wenn die Schrotthalle den Baum verlässt.
- **Schnelle Kontrollbilder:** `tools/shot_tool.gd` nimmt `--scale=0.6` (3D-Bild kleiner gerechnet); ein Bild aus der Halle dauert damit im Software-Renderer etwa 3 statt 25 Minuten.

**Geprüft und verworfen oder zurückgestellt**

- Ein eigener LKW aus Blender-Formen (zwei Anläufe) blieb sichtbar kantig; ein echtes Modell als Grundlage bringt mehr als weiteres Feilen.
- Zweite Wahl für den LKW: `Truck.fbx` aus OpenConstructionSimulator (Apache 2.0, sechs Radknoten, kippbare Mulde, kein Innenraum). Er bildet eine echte Marke nach und trägt deren Schriftzug als Geometrie; deshalb nicht genommen.
- Weitere Funde mit freier Lizenz für später: Radlader, Gabelstapler, Autos ohne echte Marke. Listen mit Quelle und Lizenz: Recherche-Berichte vom 18.11.2026 (nicht im Repo).

**Offen**

- Die anderen Hallen (Hinterhof, Garage, Glockengießerei, Eisenhalle) haben noch gemalte Wände und Böden und das Abendlicht.
- In der Stadt fehlen noch: Regenrinnen, Schaufenster-Auslagen, fahrende und parkende Autos, Bäume, Passanten mit Zielen.
- Innenräume der Läden (Regale, Theke) sind noch die alten Holzkästen.
- Alles hier ist als Standbild geprüft; Bewegung (Radlauf, Blinken) und die Leistung auf echter Grafikkarte nicht.
- Herkunft des LKW-Modells vor einer Veröffentlichung auf der Sketchfab-Seite gegenprüfen (siehe `CREDITS.md`).
