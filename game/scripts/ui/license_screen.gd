class_name LicenseScreen
extends Control
## "Lizenzen": credits for the shipped assets and the license texts the
## engine requires to be shown (Godot's MIT license and its third-party
## components), in one scrolling card. Closes with the button or Escape.

signal closed

var _back: Button


func _ready() -> void:
	theme = UITheme.get_theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color(UITheme.INK, 0.7)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var card := PanelContainer.new()
	card.theme_type_variation = &"CardPanel"
	card.custom_minimum_size = Vector2(1180, 860)
	center.add_child(card)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	card.add_child(col)
	var title := Label.new()
	title.text = "Lizenzen und Danksagung"
	title.add_theme_font_override("font", UITheme.display_font())
	title.add_theme_font_size_override("font_size", UITheme.SIZE_H2)
	col.add_child(title)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(scroll)
	var text := Label.new()
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.add_theme_font_size_override("font_size", 20)
	text.text = build_text()
	scroll.add_child(text)
	_back = Button.new()
	_back.text = "Zurück"
	_back.custom_minimum_size = Vector2(260, 64)
	_back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_back.pressed.connect(func() -> void: closed.emit())
	UITheme.juice_button(_back)
	col.add_child(_back)
	_back.grab_focus.call_deferred()


## Credits, then Godot's license, then every third-party component in the engine.
static func build_text() -> String:
	var out := PackedStringArray()
	out.append("MOLTEN MATES\n")
	out.append("3D-Modelle: KayKit (Kay Lousberg, www.kaylousberg.com), Kenney (www.kenney.nl) und Quaternius (quaternius.com) – CC0 1.0.")
	out.append("Foto-Oberflächen, gescannte Requisiten und Himmel („Kloofendal 48d Partly Cloudy (Pure Sky)“, Greg Zaal und Jarod Guest): Poly Haven (polyhaven.com) – CC0 1.0.")
	out.append("Bagger: „20 t class hydraulic excavator“ aus dem Projekt Construction Site Simulation (github.com/dtt-github/construction-site-simulation), Copyright 2026 DigitalTwin Technology GmbH and the Construction Site Simulation contributors; Maße und Gelenke nach dem OPERA-ZX200-Modell des Public Works Research Institute, Japan (github.com/pwri-opera/zx200_ros2). Apache License 2.0; der Lizenztext steht unten bei den Lizenztexten. Für das Spiel verändert: umlackiert, Kabine ausgehöhlt und Fenster geöffnet.")
	out.append("Kipper: nach „Dump Truck“ von ElectroNick (sketchfab.com/3d-models/dump-truck-781c616da8f44982a59cb3fc3fa67f98) – CC BY 4.0 (creativecommons.org/licenses/by/4.0). Für das Spiel zerlegt, umlackiert und ergänzt.")
	out.append("Absetzmulde: nach „Old rubbish Skip“ von Sousinho (sketchfab.com/3d-models/old-rubbish-skip-2f9aa03ede3a46a0888e76fed382667f) – CC BY 4.0 (creativecommons.org/licenses/by/4.0). Für das Spiel in der Größe angepasst, Texturen verkleinert.")
	out.append("Lieferwagen: nach „European Delivery Van“ von Evan Hiltz (sketchfab.com/3d-models/european-delivery-van-0b2f1ad95a79419f9a092420024d329c) – CC BY 4.0 (creativecommons.org/licenses/by/4.0). Für das Spiel neu zusammengefügt, Texturen verkleinert.")
	out.append("Parkende Autos: nach „Kiri '86“, „Fairheaven LT '80“ und „Fairheaven SW '84“ (Low poly models) von Daniel Zhabotinsky (sketchfab.com/DanielZhabotinsky) – CC BY 4.0 (creativecommons.org/licenses/by/4.0). Für das Spiel aufgerichtet, geteilt, mit klaren Scheiben und ohne Markenzeichen.")
	out.append("Stadtbewohner (Passanten, Pfandleiher, Schrotthändler, Polizei) und die Arbeiter der Spieler: KI-erzeugte Figuren – Bilder mit GPT Image 2.6, 3D-Figuren und Bewegungen mit Meshy 7, beides über Higgsfield (higgsfield.ai). Sie zeigen keine echten Personen.")
	out.append("Schriften: Fredoka (The Fredoka Project Authors), Barlow Condensed (The Barlow Project Authors), Lilita One (Juan Montoreano), Patrick Hand (Patrick Wagesreiter) und Cabin Sketch (The Cabin Project Authors) – SIL Open Font License 1.1.")
	out.append("Geräusche: Aufnahmen aus „Impact Sounds“ von Kenney (www.kenney.nl) – CC0 1.0 – und eigene Synthese. Glockenklang und Musik: eigene Synthese (Musik von einer KI komponiert).")
	out.append("Shader-Rauschen nach „Hash without Sine“ von Dave Hoskins, Copyright (c) 2014 David Hoskins – MIT-Lizenz (Text unten unter „Expat“).\n")
	out.append("Dieses Spiel verwendet die Godot Engine, verfügbar unter der folgenden Lizenz:\n")
	out.append(Engine.get_license_text())
	out.append("\nBestandteile von Dritten in der Godot Engine:\n")
	for comp: Dictionary in Engine.get_copyright_info():
		out.append(str(comp.name))
		for part: Dictionary in comp.parts:
			for c: String in part.copyright:
				out.append("    © " + c)
			out.append("    Lizenz: " + str(part.license))
	out.append("\nLizenztexte:\n")
	var licenses := Engine.get_license_info()
	for name: String in licenses:
		out.append(name + "\n")
		out.append(str(licenses[name]) + "\n")
	return "\n".join(out)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_cancel"):
		closed.emit()
		get_viewport().set_input_as_handled()
