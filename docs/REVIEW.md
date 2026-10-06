# MOLTEN MATES – Art-Director-Review (Stand d3f10f0)

Stand: 06.10.2026 · Prüfer: Art Director (Publisher-Sicht) · Grundlage: `docs/ART_BIBLE.md` §14 (Screenshot-Checkliste),
dazu `GDD.md`, `ENVIRONMENT.md` und der Code dahinter.
Bilder (lokal, nicht im Git): `shots/ad_before_wide.png`, `_pour`, `_reveal`, `_side`, `_menu`, `_drawpad`
(Software-Vulkan, 1920 × 1080, 150 Frames, HIGH).

**Kurzurteil:** Großer Sprung gegenüber dem Prototyp (Bibel §6.6: 3,5 → jetzt **6,1**). Haus, Formkästen, Funken/Gießstrahl,
Logo und UI-Kit sind auf Store-Niveau. **Bestanden ist kein einziges Bild** (Ziel: Ø ≥ 8 und kein Punkt < 6).
Die drei Dinge, die das Spiel noch nach „gut gemeintem Asset-Flip“ aussehen lassen:
1. **Der Held hat kein Gesicht.** In jedem Gameplay-Bild sieht man einen riesigen blauen Helm, beim Gießen darunter einen schwarzen
   Tiegel wie einen Maulkorb, darunter einen Barbaren-Fellrock.
2. **Alles ist orange.** 76–87 % der Pixel sind warm-gesättigt, nur 5–7 % kühl. Das Metall „poppt“ nicht, weil die ganze
   Welt dieselbe Farbe hat wie die Hitze.
3. **Der Clip-Moment (Enthüllung) sieht nach Debug aus:** zwei riesige blaue 3D-Schriftzüge über dem Haus, die Form
   zerbricht sichtbar nicht, die Gussteile sind klein und verdeckt.

---

## 1. Bewertung pro Bild (Bibel §14, 1–10)

| # | Kriterium | wide | pour | reveal | side | Menü | DrawPad |
|---|---|---|---|---|---|---|---|
| 1 | Silhouetten | 7 | 6 | 6 | 5 | 7 | 7 |
| 2 | Fokus / Werthierarchie | 7 | 6 | **4** | 7 | 6 | 8 |
| 3 | Palette | **5** | **5** | **5** | **5** | 7 | 7 |
| 4 | Material-Reichtum | 7 | 7 | 7 | 7 | 7 | **4** |
| 5 | Boden | 6 | 6 | **5** | 6 | 6 | 6 |
| 6 | Dichte / Storytelling | 7 | 7 | 7 | 7 | 7 | **5** |
| 7 | Tiefe | 7 | 7 | 7 | 7 | 8 | 7 |
| 8 | Licht | 6 | 6 | 6 | 6 | 7 | 6 |
| 9 | Figuren-Appeal | **5** | **3** | **5** | **4** | **5** | **5** |
| 10 | Bewegung im Standbild | 6 | 7 | 7 | 7 | 6 | **5** |
| 11 | VFX | **5** | 7 | **5** | 7 | **5** | **4** |
| 12 | UI | 7 | 7 | **3** | 7 | 6 | 7 |
| 13 | Technische Sauberkeit | 7 | 7 | 6 | 6 | 7 | 8 |
| 14 | Komposition | 6 | **5** | **5** | **5** | 7 | 7 |
| 15 | Steam-Capsule-Test | 6 | **5** | **5** | **5** | 7 | 6 |
| | **Ø** | **6,3** | **6,1** | **5,5** | **6,1** | **6,5** | **6,1** |
| | **Würde als Steam-Screenshot durchgehen?** | als hinterer Store-Screenshot (#4–5) eines kleinen Indies ja, als Lead-Bild nein | **nein** | **nein** | **nein** | fast – IP-Feld verrät den Prototyp | grenzwertig – sauber, aber Allerwelts-App |

Gesamt-Ø **6,1**, schlechtester Einzelwert 3 (Figur im pour-Shot, UI im reveal-Shot).

### Messwerte (PIL, 1920 × 1080, Helligkeit = Rec.709-Luma nach AgX)
| Bild | Metall p99 | stärkster Konkurrent | warm-gesättigte Pixel (H < 60° oder > 330°, S > 0,2) | kühle Pixel (H 180–300°, S > 0,15) | Farbe „besonnter Boden“ |
|---|---|---|---|---|---|
| wide | Form 0,87 | Lichterkette rechts 0,73, Fenster 0,60 | **76 %** | 6 % | Erde H 9° S 0,55; Rasen **H 38°** (oliv-braun statt grün) |
| pour | Strahl 0,96 | **Helm-Glanzband 0,92** (p95 0,90) | **83 %** | 7 % | Erde H 12° S 0,62 |
| side | – | – | **87 %** | 5 % | – |
| reveal | – | Grade-Schrift (größte helle Fläche) | 64 % | 24 % | – |
| Menü | – | Logo (gewollt) | 63 % | 27 % | Himmel H 244° |

Bibel §4.5 verlangt 60 % kühl-neutral / 30 % warm / 10 % heiß und Umgebungs-Sättigung ≤ 55 %. Die Albedos im Boden-Shader
stimmen (`dirt_mid` ≈ `#94775A`, H ≈ 30°); der Rotstich kommt aus dem Licht (Sonne `#FFA36B`, schwache Himmels-Ambient,
`adjustment_saturation` 1.1, keine LUT).

### Was gut ist und bleibt
Formkasten (Bretter, Winkel, Brandzeichen, Griffe), Gießstrahl + Spritzring + Funken, Haus/Fassade/Fensterläden,
KATALOG-Brett, Dämmerhimmel mit Mond (Menü), Logo + Knopf-Kit, Tasten-Glyphen-Prompts, Kamera-Feder, Hitstop/Trauma,
Münzflug ins HUD. Diese Systeme nicht umbauen, nur füttern.

---

## 2. Probleme, geordnet nach Wirkung auf „sieht aus wie ein fertiges Spiel“

Aufwand: S ≤ ½ Tag · M ≈ 1 Tag · L ≈ 2 Tage. In eckigen Klammern die Batch (Abschnitt 3).

### 1. Der Held hat kein Gesicht und trägt noch Barbaren-Kostüm [A] · L
> **✅ done (Batch A)** – Helm eng angepasst und 0,22 rad in den Nacken gekippt (Schale (0,48 | 0,37 | 0,49) bei y 1,88 – die vorgeschlagenen Radien (0,44 | 0,42 | 0,47) hätten den kantigen Chibi-Schädel durchstoßen, Fit gegen das Kopf-Mesh), Krempe vorn 0,11, matter Lack + Streifen `#CDBF9F` (Helm-p95 im pour-Shot 0,83 → **0,45**, Strahl bleibt 0,95), Kopf gleicht 60 % der Rumpfbeuge aus, Fell → Leder (Saum `#5A4636`, Handschuhe `#5A4636`, Stiefel `#3A2F2B` per Atlas-Zellen), neue an den Körper gehäutete Lederschürze mit Saumnaht, Tasche, Nieten, Nacken- und Hüftbändern (`WorkerGear.apron_mesh`, `worker_apron.gdshader`).
*Sichtbar:* pour (Figur 3/10), side, reveal, wide. Helm ≈ 0,8 m breit, Kopf beim Tragen ~24° gesenkt + 0,2 rad Rumpfbeuge
→ Krempe verdeckt Augen aus jeder Kamera über Kopfhöhe. Fellrock mit Zickzack-Saum, Fellstiefel, nackte Hautfarbe-Fäuste.
Helm-Glanzstreifen (`#e6e0d2`, `metallic_specular` 0.4, Clearcoat 0.3, Rim 0.15) ist mit p95 0,90 fast so hell wie die
Schmelze (Regel 2 verletzt).
*Fix:*
- `scripts/player/worker_gear.gd`: `SHELL_RADII` (0.5, 0.5, 0.53) → (0.44, 0.42, 0.47); `BRIM_FRONT` 0.19 → 0.11.
- `scripts/player/player_model.gd` `_dress()`: Helm-Neigung `Basis(Vector3.RIGHT, -0.1)` → `-0.22` (weiter in den Nacken);
  `_hat_mat`: `clearcoat` 0.3 → 0.1, `rim` 0.15 → 0.05, `roughness` 0.45 → 0.6; Streifen-Material `albedo` → `#CDBF9F`,
  `metallic_specular` 0.4 → 0.2.
- `_update_look()`: beim Tragen Blick nach unten max. 0.15 rad (Faktor 0.7 → 0.35, Clamp-Obergrenze 0.5 → 0.15) und
  die Rumpfbeuge mit dem Kopf ausgleichen (`look.x -= 0.6 * bend.x`), damit das Gesicht beim Gießen nach vorn schaut.
- Kostüm (`assets/models/characters/worker_outfit.gdshader` + `_apply_colors`): `TRIM_TINT` → dunkles Leder `#5A4636`
  (Zickzack-Saum liest dann als Schürzenkante, nicht als Fell); Hand- und Stiefelzellen im Atlas bestimmen (wie
  `trim_rect`) und auf Handschuh `#5A4636` / Stiefel `#3A2F2B` tönen (Bibel §4.2).
- Neu `WorkerGear.apron_mesh()`: Lederschürze (0,42 × 0,5 m, Fase 0,02, Riemen um den Hals), an `chest`-BoneAttachment,
  unten frei – verdeckt den Fellrock von vorn. Material Lambert-Wrap, Rauheit 0.85, `#5A4636`.
*Abnahme:* Augenpartie in pour, side und wide sichtbar; Helm p95 ≤ 0,75 im pour-Shot; keine Fellkanten von vorn.

### 2. Sepia-Einheitsbrei statt Warm-Kalt-Kontrast [B] · L
> **✅ done (Batch B)** – Sonne/Fill/Ambient/Sättigung wie angegeben; LUT wird zur Laufzeit gebacken (`YardLighting.create_grade_lut()`, 32³ `ImageTexture3D`, Split-Toning `#3B3F6B`/`#FFD9A0` + S-Kurve, nicht headless) statt als PNG eingecheckt; Vignette als CanvasLayer −1 (`create_vignette()`). `tools/shot_stats.py` offen.
*Sichtbar:* alle Gameplay-Bilder (Tabelle oben). Schatten sind braun-violett (pour: H 343°, S 0,49), Rasen oliv.
*Fix* (`scripts/environment/yard_lighting.gd`):
- `SUN_COLOR` `#FFA36B` → `#FFBE8E`, `SUN_ENERGY` 1.2 → 1.1.
- `FILL_COLOR` `#7F8FD8` → `#6F84E0`, `FILL_ENERGY` 0.32 → 0.5.
- `ambient_light_sky_contribution` 0.75 → 1.0, `ambient_light_energy` 0.78 → 0.7, `adjustment_saturation` 1.1 → 1.0.
- Farb-LUT nach Bibel §7: neues `game/tools/bake_lut.gd` → `assets/textures/lut_dusk.png` (32³), Split-Toning Schatten
  → `#3B3F6B` 15 %, Lichter → `#FFD9A0` 10 %, leichte S-Kurve; `env.adjustment_color_correction` setzen.
- Vignette (Bibel §7, fehlt komplett): `YardLighting.build()` hängt einen `CanvasLayer` (Layer −1) mit Vignetten-ColorRect
  an (Ecken −18 %, Radius 0.75, Weichheit 0.45) – so bekommen Spiel, Menü und Showcases sie ohne HUD-Änderung.
- Messwerkzeug einchecken: `tools/shot_stats.py` (Luma-p99 je Region, Anteil warm/kühl wie oben definiert).
*Abnahme:* wide/pour: warm-gesättigt ≤ 55 %, kühl ≥ 18 %, besonnter Rasen H ≥ 70°, Metall-p99 bleibt höchster
Nicht-UI-Wert (≥ 0,9).

### 3. Die Enthüllung – der wichtigste Clip des Spiels – sieht nach Debug aus [C] · L
> **✅ done (Batch C)** – `_break_open()` spawnt sofort, `_present_reveal()` staffelt Stempel-Popups (0,35 s) und zeigt ein `GameWorld.banner_near()` (RPC, 6 m, `grade_good`/`grade_bad`); `popup()` Schrift 64 / pixel_size 0,0022; `MoldArt.shatter()` (Kasten hüpft, Sand lose, neues `ClodSpray` mit 10 Brocken); Impuls 4,2. Glanz-Streiflicht beim Landen offen.
*Sichtbar:* reveal (UI 3/10, Fokus 4/10). `HUD.popup()` baut `Label3D` mit `font_size` 104, `pixel_size` 0.0032,
`no_depth_test` → bei 4 m Abstand über 10 % Bildhöhe, zwei Zeilen „MAKELLOS! 92 $ / 101 $“ gleichzeitig, an der
Oberkante angeschnitten, über dem Haus statt am Gussteil. `GradeBanner`/`HUD.banner()` existiert, wird im Spiel aber nie
aufgerufen; `grade_good.wav`/`grade_bad.wav` sind ungenutzt. Das Sandbett bleibt nach dem Bruch glatt liegen.
*Fix:*
- `scripts/foundry/stations/mold_box.gd` `_break_open()`: Gussteile und `state = EMPTY` **sofort** wie bisher (Test
  `test_foundry` prüft nach 10 Frames), aber die Präsentation pro Kavität staffeln (0,35 s Abstand): Stempel-Popup am
  Teil, danach **ein** `HUD.banner()` für das beste Teil („MAKELLOS!“, Note-Farbe, Untertitel „Stern · Bronze · 101 $“)
  nur für Spieler im Umkreis von 6 m; Fehlguss → `grade_bad`, sonst `grade_good` (`Sfx.play_ui`).
- `scripts/ui/hud.gd` `popup()`: `fixed_size = true`, Schrift so, dass die Versalhöhe ≤ 4 % der Bildhöhe ist; Position
  in die Safe Area klemmen (nie über den Bildrand); Popup folgt dem Gussteil 1,2 s.
- `scripts/foundry/visuals/mold_art.gd`: neues `shatter()` (aus dem `sand_burst`-FX-Pfad, läuft auf allen Peers):
  Sandoberfläche ausblenden, 8–10 klobige Sandbrocken (RigidBody ohne Spieler-Kollision, 1,5 s, dann einsinken/ausblenden),
  Formkasten hüpft (vorhandene Feder). Gussteil-Impuls nach oben 3.2 → 4.2 und zur Kameraseite des Schlagenden,
  Glanz-Streiflicht 0,4 s beim Landen (Bibel §11).
*Abnahme:* reveal-Shot: Gussteil ist der Blickfang, keine Schrift > 8 % Bildhöhe, nichts angeschnitten, Sandbett sichtbar zerbrochen.

### 4. Ein Koop-Partyspiel – aber auf jedem Bild nur ein Arbeiter; Spielerfarben brechen die Palette [B + A] · M
> **✅ done (Teil A)** – `PLAYER_COLORS` = `#3E7BD6` / `#26B5C4` / `#9B5BD0` / `#E26AA0`, `LOOKS`-Schlüssel und Standardfarben (`Player.color`, `PlayerModel.suit_color`) nachgezogen.
> **✅ done (Teil B)** – Showcase-Crew: Türkis tritt den Blasebalg, Violett jubelt hinter der zweiten Form (`_add_crew`, `_animate_crew`).
*Sichtbar:* wide, pour, side, reveal zeigen genau eine Figur. Das Kernversprechen „Koop-Ritual mit Geschrei“ (GDD §1)
kommt in keinem Bild vor. `GameWorld.PLAYER_COLORS` = Blau, **Rot `#e2574c`**, **Grün `#3fae6a`**, Violett – Bibel §4.2
verbietet Orange/Gelb/Grün (Rot konkurriert mit Hitze und „schlecht“, Grün verschwindet im Rasen).
*Fix:*
- [A] `scripts/game_world.gd` `PLAYER_COLORS` → `#3E7BD6`, `#26B5C4`, `#9B5BD0`, `#E26AA0`; in `player_model.gd` die
  Schlüssel von `LOOKS` mitziehen (sie sind die Hex-Werte der Farben!).
- [B] `scripts/levels/backyard_showcase.gd`: zwei weitere Arbeiter als `PlayerModel` (wie `main_menu.gd`): Türkis tritt den
  Blasebalg (`play_action(&"kick")` im Takt), Violett hält jubelnd ein frisches Gussteil (`cheer`) bzw. trägt im reveal-Shot
  Schrott. Alle drei Gesichter zur Kamera ¾.

### 5. Tiegel-Haltung verdeckt das Gesicht, der Tiegel ist unlesbar [A] · M
> **✅ done (Batch A)** – Gießhaltung `lerpf(0.64, 0.78, tilt)` und `POUR_HEIGHT` 0,74 (Lippe 15 cm über dem Sand), `CARRY_BEND` 0,28 mit Kopfausgleich, Schaftband/Bügel `#8E969C`; Topf steht im pour-/side-Shot unter dem Kinn, Augen frei. Hinweis: der hintere Topfrand liegt bei voller Neigung auf ≈ 1,10 m – ≤ 1,05 m geht mit dieser Topfgeometrie nur, wenn die Lippe unter 15 cm über den Sand sinkt; Gießtests treffen weiter.
*Sichtbar:* pour, side. `Crucible.POUR_HEIGHT` 0.86 + Topfhöhe 0.43 → Topfrand auf ≈ 1,3 m, direkt vor dem Mund; im side-Shot
sieht man vom Tiegel nur den Ausguss, im pour-Shot liest er sich als Maulkorb unter der Krempe.
*Fix* (`scripts/foundry/stations/crucible.gd`, `player_model.gd`):
- `carry_offset()`: Abstand mit der Neigung vergrößern `lerpf(0.64, 0.78, tilt)`, `POUR_HEIGHT` 0.86 → 0.74, so dass der
  Topfrand bei voller Neigung ≤ 1,05 m (unter dem Kinn) liegt und die Lippe ≥ 0,15 m über dem Sand bleibt.
- Körper statt Kopf beugt sich zum Gießen (`CARRY_BEND` 0.2 → 0.28, Kopf kompensiert, siehe Punkt 1), Arme gestreckt.
- `crucible_art.gd`: Schaftband/Griffe hell-stahlgrau (`#8E969C`, Rauheit 0.5), damit das Gestell sich vom dunklen Topf trennt.
*Achtung Gameplay:* `test_foundry` Schritt 4 und `test_net_foundry` gießen aus dieser Haltung – Strahl muss weiter in die Form treffen.

### 6. Der Ofen ist kein Heldenobjekt [B] · M
> **✅ done (Batch B)** – Flammenhöhe 0,95, 20 Mündungsfunken pro Tritt, Rauch zweitonig/α 0,8/`scale_max` 1,6/Menge 21, Hinweis „[F] Blasebalg treten · Hitze 80 % · …“ bzw. „Kein Tiegel im Ofen!“. Hitzeflimmer-Quad offen.
*Sichtbar:* wide, pour, side, Menü – ein dunkles Fass mit orangem Rand, bei Hitze 0,95 **keine Flamme über dem Rand**
(`furnace.gd`: `_fire.height` 0.62 + `position.y` 0.15 = 0,77 m = `FurnaceArt.TOP` 0,766 – die Flammen enden exakt an
der Kante), Rauch kaum sichtbar, keine Funken, kein Hitzeflimmern (Bibel §10.4: „höchster Kontrast“).
*Fix:*
- `scripts/foundry/stations/furnace.gd`: `_fire.height` 0.62 → 0.95 (Zungen 0,3 m über den Rand, wenn kein Tiegel drin
  steckt); mit Tiegel `FurnaceFire.radius` so, dass 3–4 Zungen außen am Topf hochlecken. Pro Blasebalg-Tritt 20 Funken aus
  der Mündung (in `interact()` und `_pump_fx()`).
- `scripts/foundry/visuals/furnace_art.gd` `_make_smoke()`: Puffs zweitonig `#E9E1D6` → `#9C8F9A`, Alpha 0.55 → 0.8 am
  Anfang, `scale_max` 1.0 → 1.6, Menge ×1,5 – muss vor der Hauswand im wide-Shot lesbar sein. Hitzeflimmer-Quad über der
  Mündung (nur HIGH, Bildschirm-Verzerrung). Mündungsring-Emission so, dass Ofen-p99 im wide ≥ 0,8.
- Hinweis-Text (gleiche Datei, Lesbarkeit): „Blasebalg treten · Hitze 80 % · Schmelze 2/3“, ohne Tiegel
  „Kein Tiegel im Ofen!“ (BAD-Farbe).

### 7. Gießen ist für den Spieler nicht lesbar [C] · M–L
> **✅ done (Batch C, ohne Steiger)** – `Crucible.held_hint()` zeigt „Form N %“, ab 98 % „STOPP! … (Grat!)“, „zu schnell!“ über `SAFE_POUR_RATE`. Steiger-Becher offen.
*Sichtbar:* pour/side – der Hinweis zeigt beim Gießen „1.1 l · 1150 °C“ (Tiegel), nicht den Füllstand der Form. Es gibt
keinen Steiger, kein „STOPP!“; Übergießen setzt still den Defekt `flash`, Absetzen > 1,2 s still `cold_shut`, zu schnell
still `spatter`. GDD §1.3 nennt genau diesen Moment als Kern des Koop-Rituals.
*Fix:*
- `scripts/ui/hud.gd` `_update_prompts()`: hält der Spieler einen Tiegel und liegt `crucible.pour_target` in einer Form
  (`MoldBox.find_at`), zeigt der Prompt „Gießen · Form 62 %“; ab 98 % „STOPP!“ (GOOD-Grün, Puls, `pop`), danach bei
  weiterem Gießen „Grat!“ (BAD); Fluss > `MoldBox.SAFE_POUR_RATE` → Infotext rot „zu schnell“.
- `scripts/foundry/visuals/mold_art.gd`: Steiger-Becher (Ø 8 cm, 6 cm hoch) an der vorderen rechten Kastenecke, Pegel
  = Gesamtfüllung, glüht (MetalMaterial), läuft bei 100 % mit Funken über. `mold_box.gd` reicht die Füllung durch.

### 8. Showcase-Kameras: angeschnittene Objekte, Tangenten, „0 $“ [B] · S
> **✅ done (Batch B)** – Geld 1240, Statue/Crew umgesetzt, Kameras wie angegeben; im reveal-Shot steht Violett hinter der Form (sonst verdeckt er die Kamera).
*Sichtbar:* pour/side: Bronzefreund vom linken Bildrand halbiert; side: Schaufel steht senkrecht vor dem Körper der Figur;
wide: Verkaufskiste und Lichterkettenmast unten rechts angeschnitten, Kabel quer durchs rechte Drittel; reveal: ~30 %
leerer dunkler Vordergrund; alle: Geldanzeige „0“.
*Fix* (`scripts/levels/backyard_showcase.gd`):
- `world.money = 1240` vor dem Staging (Spielstand ist `SaveGame.disabled`, nichts wird gespeichert).
- Statue für pour/side ganz ins Bild oder ganz raus (z. B. `mold.global_position + Vector3(-2.6, 0.05, -1.4)`, Gesicht zur
  Kamera); side-Kamera so drehen, dass die Schaufel hinter der Figur liegt (bzw. nach Punkt 15 wandert der Haufen ohnehin).
- wide: Kamera näher/niedriger, z. B. `(6.2, 5.6, 8.0)` → Ziel `(-0.3, 0.6, -0.8)`; Regel: kein Mast/Kabel im vorderen
  Bilddrittel, Kiste ganz drin oder ganz draußen.
- reveal: `mold2 + Vector3(1.0, 1.6, 2.9)` → Ziel `mold2 + Vector3(-0.3, 0.9, 0.0)`, Figur ¾ von vorn statt Rücken.

### 9. Hauptmenü verrät den Prototyp [C] · M
> **✅ done (Batch C)** – „Koop spielen“ öffnet Karte (Hosten / Beitreten + Adresse), Footer rechts unten 60 %, Diorama: Form 1 mit abkühlenden Güssen, Form 2 gestampft mit Muster.
*Sichtbar:* Menü. Rohes IP-Feld „127.0.0.1“ in der Titelspalte; beide Formkästen im Vordergrund sind leere graue Kisten;
die zwei Arbeiter stehen mit dem Rücken zur Kamera bzw. untätig neben dem Ofen.
*Fix* (`scripts/ui/main_menu.gd`):
- Spalte: „Solo spielen“, „Koop spielen“ (öffnet Karte mit „Hosten“ / „Beitreten“ + Adressfeld), „Einstellungen“, „Beenden“.
  `_on_host`/`_on_join` bleiben. Footer „v0.1“ nach rechts unten, 60 % Deckkraft.
- Diorama: Formkasten 1 mit zwei abkühlenden Gussteilen (wie `backyard_showcase._fill`), Formkasten 2 gestampft mit Muster;
  Zeichner ¾ zur Kamera; der Heizer tritt sichtbar (Takt ≤ 1,2 s) und steht mit dem Gesicht zur Kamera.

### 10. DrawPad: generische App-Optik und eine falsche Zahl [C] · M
> **✅ done (Batch C, Teil)** – Bedarf korrekt als „≈ ½ Tiegel“ (`DrawPad.metal_need_text`), Papier gedreht mit Klebeband und Fasern, Punktraster entfernt. Strich-Zittern und Vorschau-Glühen offen.
*Sichtbar:* DrawPad (Material 4/10, VFX 4/10). Weiße Karte mit Punktraster, perfekte Vektorstriche, Vorschau als
beige Scheibe auf Navy ohne Glühen, 120-px-Loch zwischen Vorschau und Knöpfen, Hinweiszeile als Text statt Glyphen.
**Bug:** „Metallbedarf: 7,2 l“ = `CastMeshBuilder.build(d, 0.6, 0.08).volume × 1000`; die Form braucht aber
`volume(0.5, 0.07) × MoldBox.LITRES_PER_M3 (260)` ≈ 1,3 l – der Tiegel fasst 3 l. Der Spieler denkt, das passt nie.
*Fix* (`scripts/foundry/drawing/draw_pad.gd`):
- Bedarf mit `MoldBox.CAST_SIZE`, `CAST_THICKNESS`, `LITRES_PER_M3` rechnen und als Tiegel-Anteil zeigen („≈ ½ Tiegel“,
  kleines Tiegel-Symbol mit Füllstand).
- Papier: Creme `#FFF8EC` mit Faser-Rauschen, −1,2° gedreht, zwei Klebeband-Streifen, weicher Schatten; Striche beim Zeichnen
  (nur Darstellung!) mit Druck-Verjüngung und 1–1,5 px Zittern – `Drawing`-Daten bleiben unverändert (Round-Trip-Test).
- Stift-Cursor; Vorschau glüht nach jedem Strich kurz auf (Temperatur 0.6 → 0 in 1,5 s) und dreht langsam; Loch schließen.
- Hinweiszeile mit `KeyPrompt`-Glyphen; `_hint_label` mit `HINT_FULL` bleibt (Test `test_drawing`).

### 11. Steife bzw. fehlende Aktions-Animationen und -Sounds [A] · M
> **✅ done (Batch A)** – Hammer `2H_Melee_Attack_Chop` + zweihändiger Überkopf-Schwung der `HammerArt` im Rahmen des Trägers (beide Fäuste per IK am Stiel, Kopf dreht in Schlagrichtung und trifft die Form), Kopf r 0,062 / 0,26 m, Stiel +25 %; Greifen `PickUp`, Stampfen `2H_Melee_Attack_Stab`; Clips per Startversatz/Tempo (`ACTION_TIMING`) so verschoben, dass Tiefpunkt/Treffer 0,13–0,21 s nach dem Tastendruck liegen; Sounds auf allen Peers: Greifen `pickup` −8 dB, Ablegen `drop_thud` −14 dB, Werfen neues `throw_whoosh`, Schritte neue `step_dirt_1..4` / `step_grass_4` nach Bodenmaske (Erde/Sand vs. Rasen).
*Abgeleitet aus Code + reveal:* Hammer nutzt `1H_Melee_Attack_Chop` (Einhand-Hieb mit einem Vorschlaghammer), der Hammer liest
sich als dünner Stock (`HammerArt.HEAD_R` 0.046). Greifen hat keine Animation (`_action_anim` liefert für `grab` nichts,
obwohl `PickUp` im Rig liegt); Stampfen nutzt das generische `Interact`. Aufheben/Ablegen/Werfen sind stumm (nur der Hammer
spielt `pickup.wav`); `PlayerModel.footstep` wird gesendet, aber nur Staub hängt dran – keine Schritte.
*Fix:*
- `player_model.gd` `ACTIONS`: `hammer` → `2H_Melee_Attack_Chop`; neu `ram` → `2H_Melee_Attack_Stab` (Stoß nach unten).
- `player.gd` `_action_anim()`: `grab` → `pickup`, Stampfen am `MoldBox` → `ram`; Sounds: Greifen `pickup` (−8 dB),
  Ablegen `drop_thud` (−14 dB), Werfen neuer `throw_whoosh`; Schritte über `footstep` → neue `step_dirt_1..4` /
  `step_grass_1..4` (−20 dB, Pitch ±8 %) aus `tools/sfx_gen.py`.
- `scripts/foundry/visuals/hammer_art.gd`: `HEAD_R` 0.046 → 0.062, `HEAD_LEN` 0.2 → 0.26, Stielradien +25 %.

### 12. Man sieht nicht, was man gleich greift oder benutzt [A] · M
> **✅ done (Batch A)** – `Player.grab_candidate()` herausgelöst (ohne Seiteneffekte; der Förderband-Fallback `pick_item` bleibt in `try_grab`), neues `TargetHighlight`: Stencil-Maske als `material_overlay` + gewachsene Hülle im `next_pass` (wirkt auch auf geteilte ShaderMaterials, ohne sie anzufassen), `#FFF3D6`, 2 cm, 0,2-s-Puls, Flammen/Rauch/Strahl ausgenommen; nur lokaler Spieler, nicht headless.
*Abgeleitet:* `try_grab()` nimmt den nächsten Körper in einer Kugel; es gibt keine Hervorhebung (Bibel §5.4 Stencil-Kontur
fehlt im ganzen Projekt). Im Gedränge zu viert greift man das Falsche.
*Fix:* `player.gd`: Auswahl aus `try_grab()` in `grab_candidate() -> RigidBody3D` herauslösen (Verhalten gleich). Neues
`scripts/player/target_highlight.gd` (nur lokaler Spieler): Kontur `#FFF3D6`, Dicke 0.02, 0,2-s-Puls beim Wechsel, auf
`grab_candidate()` bzw. `nearest_interactable()`; `BaseMaterial3D` per `STENCIL_MODE_OUTLINE`, ShaderMaterials per
`next_pass`-Hülle (Bibel Anhang A.4).

### 13. Arbeitsfläche = große rot-braune Platte [B] · M
*Sichtbar:* wide (Boden 6/10) – die Erdfläche nimmt ≈ 25 % des Bilds ein und hat auf Distanz kaum Mittel-Struktur;
der Rasen rechts vorn liest sich als flaches Grün mit dunklen Strichen; reveal: dunkler leerer Vordergrund.
*Fix:* `scripts/environment/yard_layout.gd` + `shaders/env_ground.gdshader`: Gras-Inseln und ausgedünnte Grasränder in der
Erdfläche außerhalb der Laufwege; Sandfächer um die Formkästen r 0,9 m; festgetretene Wege ±12 % Wert-Kontrast;
Erd-Makro-FBM 1,5 m ±10 % Wert. `yard_dressing.gd`: eine Palette/Laufbohlen zwischen Ofen und Formkästen, Plane unter der
Werkbank. `grass_field.gd`: Büschelhöhe variieren (0,6–1,3×) und dunklere Wurzelfarbe im kameranahen Rasen.

### 14. Bronzefreund liest sich nicht als Statue [A] · S–M
> **✅ done (Batch A)** – erstarrte Pfütze als Sockel (r 0,45 m, 6 cm, gelappter Rand, 7 Spritzer, eigener Zylinder-Collider), Statuen-Rauheit +0,15, neue `PANIC_POSE` (per Bone-Aiming erzeugt: Arme als Y neben dem Kopf, Gesicht frei, rechtes Knie hoch, Rücklage); die Schürze deckt den Rock auch in Bronze.
*Sichtbar:* pour (riesig, angeschnitten), wide (verschmilzt mit dem Schrotthaufen). Kein Sockel, Hände vor dem Gesicht,
Fellrock in Bronze, Glanzlichter an Beinen p99 0,63 konkurrieren im pour-Shot.
*Fix:* `scripts/foundry/stations/bronze_statue.gd`: erstarrte Metall-Pfütze als Sockel (Scheibe r 0,45 m, 6 cm, Spritzer-
Rand, gleiches Metall); Statuen-Material Rauheit +0.15. `PANIC_POSE` in `player_model.gd` neu (per `pose_data()` aus einer
Editor-Pose): Arme in Y-Form über dem Kopf, Gesicht frei, ein Knie hoch – lustig und lesbar als Silhouette.

### 15. Zustände ohne Rückmeldung, HUD-Feinschliff [C] · M
> **✅ done (Batch C)** – „Kühlt ab · N s“, READY mit Dampf + `steam_hiss` + `pop` + Hüpfer, Geld-Pille schrumpft, `NextStepCard` (erste 10 min / nach 8 s Untätigkeit), Sandhaufen hinten links.
*Abgeleitet:* „Kühlt ab…“ 4,5 s ohne Fortschritt; „bereit zum Zerschlagen“ hat kein Signal außer Text; Geld-Pille zeigt „0“
mit leerem Rest (`custom_minimum_size.x = 120`); kein „Was jetzt?“ für neue Spieler (Bibel §12: Auftragskarte oben rechts).
Der Ersatzsand-Haufen mit Schaufel (`mold_art.gd`, vordere linke Ecke) steht genau dort, wo man von der Stirnseite gießt
(side-Shot: Schaufel im Körper).
*Fix:*
- `mold_box.gd` Hinweis „Kühlt ab · 3 s“ + Fortschrittsring im Prompt (`PromptBubble`, Ring wie bei Halte-Aktionen);
  bei READY kurzer Dampf-Stopp + `pop`, Kasten pulsiert einmal.
- `hud.gd`: Geld-Pille auf Inhalt schrumpfen; „Nächster Schritt“-Karte oben rechts aus dem Weltzustand (Zeichnen → Stampfen →
  Ofen füllen + Blasebalg → Tiegel tragen → Gießen → Zerschlagen → Verkaufen), nur in den ersten 10 Minuten oder nach 8 s
  Untätigkeit; max. 3 HUD-Elemente.
- `mold_art.gd`: Sandhaufen an die hintere linke Ecke `(-hx - 0.32, 0, -hz - 0.1)`.

### 16. Keine Musik, keine Abend-Atmosphäre [B] · M
> **⏳ Teil done (Batch B)** – Grillen-Loop `evening_crickets.wav` (−20 dB). Musik wartet auf einen CC0-Titel vom Projektinhaber (keine KI-generierte Musik).
*Abgeleitet:* `assets/` hat kein Musikverzeichnis; Abendgeräusche fehlen (nur Ofenrauschen und Gießzischen).
*Fix:* Autoload `scripts/core/music.gd` (Menü-Loop, Spiel-Loop, Crossfade 1,5 s, eigener Bus „Music“, neuer Regler `music_volume` in `GameSettings` + `settings_panel.gd`),
Quellen ausschließlich CC0 (z. B. OpenGameArt mit CC0-Filter, HoliznaCC0) mit Lizenzdatei + `CREDITS.md`;
`yard_ambience.gd`: Grillen-/Fernstadt-Loop (−24 dB) aus `tools/sfx_gen.py`.

### 17. Kleinere Set-Fehler [B] · S
> **✅ Teil done (Batch B)** – Tafel sagt „VERKAUF“, Blech `#8E969C` mit metallic 0,25. Wellprofil und Mast offen.
- `yard_props.gd` `scrap_lean()`: „Wellblech“ sind flache Boxen mit `metallic_base` 0.5 → spiegeln den Himmel als rosa
  Schliere (wide, links). Echtes Wellprofil (Sinus, 5 Wellen), `metallic_base` 0.25, Basis `#8E969C`, Rost `#8A4B2E`.
- Verkaufskiste (`crate_art.gd`): Tafel sagt „ANKAUF“, die Kiste „VERKAUF“ – ein Begriff (VERKAUF); die Tafelschrift ist aus
  der Spielkamera unlesbar → großes gemaltes Münz-Piktogramm + Pfeil statt Fließtext.
- Lichterketten: Mast/Kabel rechts im wide-Shot – Mast 1 m nach außen (hinter die Kamera-Sichtlinie der Showcases) oder
  Kabel höher (Durchhang 0,4 m statt Diagonale durchs Bild).

### 18. Netz-Glätte der Mitspieler [A] · M
> **✅ done (Batch A)** – Snapshot-Puffer (16 Pakete) mit jitter-gefilterten lokalen Zeitstempeln, Darstellung 100 ms in der Vergangenheit (Host 50 ms, weil er das Getragene simuliert), Extrapolation ≤ 150 ms, Sprünge > 3 m (Teleport) springen sofort; Gieren interpoliert, RPC `_state` unverändert.
*Abgeleitet (nicht im Standbild sichtbar):* `player.gd` `_follow_network()` jagt dem letzten 30-Hz-Paket mit halber
Geschwindigkeit hinterher, kein Snapshot-Puffer (Bibel §9.1.3) – bei Paket-Jitter ruckeln Mitspieler.
*Fix:* Ringpuffer der `_state`-Pakete mit Zeitstempel, Darstellung 100 ms in der Vergangenheit interpoliert (Position,
Gieren), Extrapolation max. 150 ms; RPC-Signatur `_state` bleibt unverändert.

---

## 3. Batches (nacheinander: A → B → C)

Jede Batch hat eigene Dateien. Gemeinsam genutzt, aber nur **anhängend**: `tools/sfx_gen.py`, `assets/sfx/`,
`CREDITS.md`, `docs/ENVIRONMENT.md`, dieses Dokument. Jede Batch endet mit: Import, alle 6 Renders, Score-Tabelle hier als
„Nach Batch X“ ergänzen, `tools/run_tests.sh` grün, Commit + Push.

**Render-Hinweis:** Renders **einzeln** starten (je 7,5–8 min). Zwei parallel brauchen > 15 min und werden vom
`timeout -s KILL 900` ohne Bild beendet (in diesem Review passiert).

### Batch A – Figuren & Spielgefühl (≈ 4–5 Tage)
Punkte **1, 4 (Farben), 5, 11, 12, 14, 18**.
Dateien: `scripts/player/player_model.gd`, `player.gd`, `worker_gear.gd`, neu `scripts/player/target_highlight.gd`,
`assets/models/characters/*.gdshader`, `scripts/game_world.gd` (nur `PLAYER_COLORS`),
`scripts/foundry/stations/crucible.gd`, `scripts/foundry/visuals/crucible_art.gd`, `scripts/foundry/visuals/hammer_art.gd`,
`scripts/foundry/stations/bronze_statue.gd`.
Nicht anfassen: API `animate()`, `squash()`, `pose_data()`/`apply_pose()`, `panic_pose()`, `_hand_target()`, RPCs.
Ziel: Figuren-Appeal ≥ 7 in pour/side/reveal, Helm p95 ≤ 0,75.

### Batch B – Licht, Welt, Ofen & Inszenierung (≈ 4–5 Tage)
Punkte **2, 4 (Showcase-Mitspieler), 6, 8, 13, 16, 17**.
Dateien: `scripts/environment/*` (u. a. `yard_lighting.gd`, `yard_layout.gd`, `yard_dressing.gd`, `yard_props.gd`,
`grass_field.gd`, `yard_ambience.gd`, `string_lights.gd`), `shaders/env_*.gdshader`,
`scripts/foundry/visuals/crate_art.gd`, neu `game/tools/bake_lut.gd`,
`assets/textures/lut_dusk.png`, `tools/shot_stats.py`, `scripts/foundry/stations/furnace.gd`,
`scripts/foundry/fx/furnace_fire.gd`, `scripts/foundry/visuals/furnace_art.gd`, `scripts/levels/backyard_showcase.gd`,
neu `scripts/core/music.gd` + Autoload in `project.godot`, `assets/music/`, `scripts/ui/game_settings.gd` +
`settings_panel.gd` (nur Musik-Regler).
Ziel: Palette ≥ 7 und Licht ≥ 7 in allen Gameplay-Shots, Messwerte aus Punkt 2 erfüllt, Ofen sichtbar lodernd.

### Batch C – Enthüllung, Gieß-Lesbarkeit, UI (≈ 4–5 Tage)
Punkte **3, 7, 9, 10, 15**.
Dateien: `scripts/foundry/stations/mold_box.gd`, `scripts/foundry/visuals/mold_art.gd`, `scripts/ui/hud.gd`,
`prompt_bubble.gd`, `grade_banner.gd`, neu `scripts/ui/next_step_card.gd`, `scripts/ui/main_menu.gd`,
`scripts/foundry/drawing/draw_pad.gd`.
Nicht anfassen: Zustandswechsel/Timing in `MoldBox` (`COOL_TIME`, `HITS_TO_BREAK*`, sofortiges Spawnen beim Bruch),
`DrawPad.HINT_FULL`/`_hint_label`, `Drawing`-Daten.
Ziel: reveal UI ≥ 8 und Fokus ≥ 8, Menü ≥ 8, DrawPad ≥ 7,5; danach Gesamt-Ø ≥ 8, kein Punkt < 6.
