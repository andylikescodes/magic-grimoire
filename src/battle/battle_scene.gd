extends Node2D

## ── Magic Grimoire — Battle Scene ──
## Playable prototype: hex grid, unit movement, combat, AI turns.

# Preload all scripts that define class_name — Godot headless requires this
# for cross-file class resolution. The array is discarded; only side-effects matter.
const _ALL_CLASSES = [
	preload("res://src/battle/hex_grid.gd"),
	preload("res://src/battle/terrain_data.gd"),
	preload("res://src/core/element.gd"),
	preload("res://src/battle/ai_controller.gd"),
	preload("res://src/battle/battle_manager.gd"),
	preload("res://src/core/card_data.gd"),
	preload("res://src/core/move_data.gd"),
	preload("res://src/battle/battler.gd"),
]

# ── State ──
var bm: BattleManager
var hex_grid: HexGrid
var hex_size: float = 32.0
var selected_move: MoveData = null
var highlight_hexes: Array[Vector2i] = []
var battle_over: bool = false
var ai_busy: bool = false

# ── Nodes ──
var hex_layer: Node2D
var unit_layer: Node2D
var ui_layer: Control
var turn_label: Label
var info_label: Label
var move_panel: Control
var log_label: RichTextLabel
var battle_log: Array[String] = []


func _ready():
	_setup_nodes()
	_start_battle()


func _setup_nodes():
	hex_layer = Node2D.new(); hex_layer.name = "HexLayer"; add_child(hex_layer)
	unit_layer = Node2D.new(); unit_layer.name = "UnitLayer"; add_child(unit_layer)
	ui_layer = Control.new(); ui_layer.name = "UILayer"
	ui_layer.anchor_right = 1.0; ui_layer.anchor_bottom = 1.0; add_child(ui_layer)

	turn_label = Label.new()
	turn_label.position = Vector2(10, 10)
	turn_label.add_theme_font_size_override("font_size", 16)
	ui_layer.add_child(turn_label)

	info_label = Label.new()
	info_label.position = Vector2(10, 680)
	info_label.add_theme_font_size_override("font_size", 12)
	ui_layer.add_child(info_label)

	move_panel = Control.new()
	move_panel.position = Vector2(980, 10)
	ui_layer.add_child(move_panel)

	var end_btn = Button.new()
	end_btn.text = "End Turn"
	end_btn.position = Vector2(10, 35)
	end_btn.size = Vector2(100, 30)
	end_btn.pressed.connect(_on_end_turn)
	ui_layer.add_child(end_btn)

	log_label = RichTextLabel.new()
	log_label.position = Vector2(800, 400)
	log_label.size = Vector2(450, 250)
	log_label.bbcode_enabled = true
	log_label.scroll_following = true
	ui_layer.add_child(log_label)


func _start_battle():
	bm = BattleManager.new()
	bm.unit_moved.connect(_on_moved)
	bm.battler_defeated.connect(_on_defeated)
	bm.battle_ended.connect(_on_ended)
	bm.turn_changed.connect(_on_turn_changed)

	var player_cards = _make_roster([
		["light_priestess", "光之圣女·露米娜", 5, 120, 55, 35, 50, 3],
		["water_siren",      "水之妖精·温蒂妮", 2, 100, 45, 50, 40, 3],
		["dark_assassin",    "暗影刺客·诺克斯", 6, 85, 75, 20, 80, 5],
		["fire_phoenix",     "不死鸟·菲尼克斯", 1, 105, 60, 30, 55, 4],
	])

	var enemy_cards = _make_roster([
		["dark_assassin",  "暗影猎手",  6, 90, 70, 22, 75, 5],
		["earth_golem",    "岩石守卫",  4, 150, 35, 55, 20, 2],
		["water_siren",    "深海祭司",  2, 110, 40, 45, 35, 3],
		["fire_salamander","熔岩幼兽",  1, 125, 55, 30, 45, 4],
	])

	var terrain: Dictionary = {}
	for i in range(-2, 3): terrain[Vector2i(0, i)] = TerrainData.Type.FOREST
	for i in range(2, 5): terrain[Vector2i(3, i)] = TerrainData.Type.MOUNTAIN
	terrain[Vector2i(-2, 0)] = TerrainData.Type.MAGIC_CIRCLE
	terrain[Vector2i(2, 0)] = TerrainData.Type.MAGIC_CIRCLE
	terrain[Vector2i(0, 5)] = TerrainData.Type.SWAMP
	terrain[Vector2i(0, -5)] = TerrainData.Type.RUINS
	terrain[Vector2i(5, -3)] = TerrainData.Type.LAVA

	bm.start_battle(player_cards, enemy_cards, null, terrain)
	hex_grid = bm.hex_grid
	hex_size = 32.0 + hex_grid.radius * 1.5
	hex_size = clampf(hex_size, 28.0, 45.0)

	_draw_all()
	_update_info()


func _make_roster(defs: Array) -> Array[CardData]:
	var cards: Array[CardData] = []
	for d in defs:
		var c = CardData.new()
		c.card_id = d[0]; c.display_name = d[1]; c.element = d[2]
		c.base_hp = d[3]; c.base_atk = d[4]; c.base_def = d[5]
		c.base_spd = d[6]; c.movement_range = d[7]

		var m1 = MoveData.new()
		m1.move_id = d[0] + "_basic"; m1.display_name = "攻击"
		m1.element = d[2]; m1.category = MoveData.Category.PHYSICAL
		m1.base_power = 50; m1.mp_cost = 0; m1.min_range = 1; m1.max_range = 1

		var m2 = MoveData.new()
		m2.move_id = d[0] + "_special"; m2.display_name = "魔法"
		m2.element = d[2]; m2.category = MoveData.Category.MAGICAL
		m2.base_power = 75; m2.mp_cost = 15; m2.min_range = 1; m2.max_range = 2
		m2.status_effect = "burn"; m2.status_chance = 0.15

		c.active_moves = [m1, m2]
		cards.append(c)
	return cards


## ── Drawing ──

func _draw_all():
	_draw_hexes()
	_draw_units()


func _draw_hexes():
	for child in hex_layer.get_children(): child.queue_free()

	for hex in hex_grid.cells:
		var cell: HexGrid.HexCell = hex_grid.cells[hex]
		var center = HexGrid.hex_to_pixel(hex, hex_size) + Vector2(400, 360)
		var verts = _hex_verts(center, hex_size)

		var fill = _terrain_color(cell.terrain)
		if cell.is_highlighted: fill = fill.lerp(Color.WHITE, 0.3)

		var poly = Polygon2D.new()
		poly.polygon = verts; poly.color = fill
		hex_layer.add_child(poly)

		var border = Line2D.new()
		border.points = verts; border.points.append(verts[0])
		border.width = 1.0; border.default_color = Color(0, 0, 0, 0.3)
		hex_layer.add_child(border)


func _draw_units():
	for child in unit_layer.get_children(): child.queue_free()

	var offset = Vector2(400, 360)
	for unit: Battler in bm.all_units:
		if not unit.is_alive: continue

		var pos = HexGrid.hex_to_pixel(unit.hex_position, hex_size) + offset
		var sprite_path = "res://assets/sprites/" + unit.card.card_id + ".png"
		var sprite: Node2D = null

		if ResourceLoader.exists(sprite_path):
			var tex = load(sprite_path)
			if tex is Texture2D:
				var sr = Sprite2D.new()
				sr.texture = tex; sr.scale = Vector2(0.35, 0.35)
				sr.position = pos
				if unit.owner_id == 1: sr.scale.x = -0.35
				sprite = sr

		if not sprite:
			var cr = ColorRect.new()
			cr.size = Vector2(20, 20); cr.position = pos - Vector2(10, 10)
			cr.color = Element.get_color(unit.card.element)
			if unit.owner_id == 0: cr.color = cr.color.lightened(0.3)
			sprite = cr

		unit_layer.add_child(sprite)

		# HP bar
		var bar_bg = ColorRect.new()
		bar_bg.size = Vector2(28, 5); bar_bg.position = pos - Vector2(14, 18)
		bar_bg.color = Color(0.3, 0.1, 0.1)
		unit_layer.add_child(bar_bg)

		var pct = float(unit.current_hp) / float(unit.max_hp)
		var bar_fill = ColorRect.new()
		bar_fill.size = Vector2(28 * pct, 5); bar_fill.position = pos - Vector2(14, 18)
		bar_fill.color = Color.GREEN if pct > 0.5 else Color.ORANGE if pct > 0.25 else Color.RED
		unit_layer.add_child(bar_fill)

		# Current battler ring
		if unit == bm.current_battler and unit.owner_id == 0:
			var ring_pts = PackedVector2Array()
			for i in range(24):
				var a = deg_to_rad(i * 15.0)
				ring_pts.append(pos + Vector2(cos(a) * 16, sin(a) * 16))
			var line = Line2D.new()
			line.points = ring_pts; line.points.append(ring_pts[0])
			line.width = 2.0; line.default_color = Color.YELLOW
			unit_layer.add_child(line)


func _hex_verts(center: Vector2, size: float) -> PackedVector2Array:
	var v = PackedVector2Array()
	for i in range(6):
		var a = deg_to_rad(60.0 * i - 30.0)
		v.append(center + Vector2(cos(a) * size, sin(a) * size))
	return v


func _terrain_color(t: int) -> Color:
	match t:
		TerrainData.Type.GRASS:        return Color(0.30, 0.60, 0.20)
		TerrainData.Type.FOREST:       return Color(0.12, 0.40, 0.12)
		TerrainData.Type.MOUNTAIN:     return Color(0.45, 0.40, 0.35)
		TerrainData.Type.SWAMP:        return Color(0.25, 0.35, 0.18)
		TerrainData.Type.WATER:        return Color(0.15, 0.35, 0.85)
		TerrainData.Type.LAVA:         return Color(0.85, 0.25, 0.08)
		TerrainData.Type.SAND:         return Color(0.80, 0.75, 0.45)
		TerrainData.Type.RUINS:        return Color(0.35, 0.30, 0.40)
		TerrainData.Type.MAGIC_CIRCLE: return Color(0.60, 0.40, 0.85)
	return Color.GRAY


## ── Input ──

func _input(event):
	if battle_over or ai_busy: return
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT): return
	if bm.current_side != 0: return

	var pos = event.position - Vector2(400, 360)
	var hex = HexGrid.pixel_to_hex(pos, hex_size)
	if hex_grid.cells.has(hex): _click_hex(hex)


func _click_hex(hex: Vector2i):
	var cell: HexGrid.HexCell = hex_grid.cells[hex]
	var active = bm.current_battler
	if not active: return

	if selected_move:
		if cell.occupant and cell.occupant.owner_id != 0:
			_do_attack(hex)
		else:
			_cancel_action()
	elif hex in highlight_hexes and not cell.occupant:
		_do_move(hex)
	else:
		_clear_highlights()
		if cell.occupant and cell.occupant.owner_id == 0 and cell.occupant == active:
			_show_movement(active)
		_update_move_buttons()
	_update_info()


func _show_movement(_battler: Battler):
	highlight_hexes = bm.get_movement_range()
	for h in highlight_hexes:
		if hex_grid.cells.has(h): hex_grid.cells[h].is_highlighted = true
	_draw_hexes()


func _clear_highlights():
	for h in highlight_hexes:
		if hex_grid.cells.has(h): hex_grid.cells[h].is_highlighted = false
	highlight_hexes.clear()
	selected_move = null
	_draw_hexes()


func _cancel_action():
	_clear_highlights()
	_update_info()


func _do_move(hex: Vector2i):
	if not bm.move_unit(hex):
		_add_log("❌ Cannot move there")
	else:
		_add_log("🚶 %s moved" % bm.current_battler.card.display_name)
	_clear_highlights()
	_update_move_buttons()
	_draw_all()
	_update_info()


func _do_attack(hex: Vector2i):
	var result = bm.use_move(selected_move, hex)
	if result.get("success"):
		var line = "⚔ %s -> %s on %s" % [bm.current_battler.card.display_name, selected_move.display_name, result.get("target", "?")]
		if result.has("damage"): line += " (-%d HP)" % result["damage"]
		if result.get("defeated"): line += " DEFEATED!"
		_add_log(line)
	else:
		_add_log("No: %s" % result.get("error", "Failed"))

	_clear_highlights()
	_update_move_buttons()
	_draw_all()
	_update_info()


func _on_end_turn():
	if bm.current_side != 0 or battle_over: return
	_clear_highlights()
	_update_move_buttons()
	bm.current_battler.has_acted = true
	_add_log(">> %s waits" % bm.current_battler.card.display_name)
	bm._advance_turn()
	_draw_all()
	_update_info()
	_update_move_buttons()


func _update_move_buttons():
	for child in move_panel.get_children(): child.queue_free()

	if not bm.current_battler or bm.current_side != 0: return
	var active = bm.current_battler
	var y = 0

	var title = Label.new()
	title.text = "%s [%s]" % [active.card.display_name, Element.get_name(active.card.element)]
	title.position = Vector2(0, y)
	title.add_theme_font_size_override("font_size", 14)
	title.add_theme_color_override("font_color", Element.get_color(active.card.element))
	move_panel.add_child(title); y += 20

	var stats = Label.new()
	stats.text = "HP %d/%d | ATK %d | DEF %d | SPD %d | MP %d" % [active.current_hp, active.max_hp, active.atk, active.def, active.spd, active.current_mp]
	stats.position = Vector2(0, y)
	stats.add_theme_font_size_override("font_size", 11)
	move_panel.add_child(stats); y += 20

	for move: MoveData in active.card.active_moves:
		if not move: continue
		var ready = active.is_move_ready(move) and active.current_mp >= move.mp_cost
		var btn = Button.new()
		var label = "%s P%d R%d-%d" % [move.display_name, move.base_power, move.min_range, move.max_range]
		if move.mp_cost > 0: label += " MP%d" % move.mp_cost
		if not ready: label += " [CD]"
		btn.text = label; btn.position = Vector2(0, y); btn.size = Vector2(200, 26)
		btn.disabled = not ready
		btn.pressed.connect(_on_move_btn.bind(move))
		move_panel.add_child(btn); y += 28


func _on_move_btn(move: MoveData):
	if bm.current_side != 0: return
	_clear_highlights()
	selected_move = move

	var targets = bm.get_attack_targets(move)
	highlight_hexes = targets
	for h in highlight_hexes:
		if hex_grid.cells.has(h): hex_grid.cells[h].is_highlighted = true
	_draw_hexes()
	_add_log("Pick target for %s" % move.display_name)


## ── Signals ──

func _on_turn_changed(_phase, side):
	_update_info()
	_draw_all()
	_update_move_buttons()
	if side == 1 and not battle_over: _do_ai_turn()


func _do_ai_turn():
	if ai_busy or battle_over: return
	ai_busy = true
	var timer = get_tree().create_timer(0.6)
	timer.timeout.connect(_ai_step)
	_add_log("AI thinking...")


func _ai_step():
	if battle_over: ai_busy = false; return
	var ai = AIController.new(bm)
	var result = ai.take_turn()
	if result.get("success") and result.get("action") == "wait":
		_add_log("AI %s waits" % bm.current_battler.card.display_name)
	_draw_all(); _update_info(); _update_move_buttons()
	ai_busy = false
	if bm.current_side == 1 and not battle_over:
		var timer = get_tree().create_timer(0.5)
		timer.timeout.connect(_ai_step)


func _on_moved(_b, _f, _t): _draw_all()
func _on_defeated(battler: Battler): _add_log("%s defeated!" % battler.card.display_name); _draw_all()

func _on_ended(victory: bool):
	battle_over = true
	var msg = "VICTORY!" if victory else "DEFEATED!"
	turn_label.text = msg
	turn_label.add_theme_color_override("font_color", Color.GREEN if victory else Color.RED)
	_add_log(msg)


func _update_info():
	if battle_over: return
	var active = bm.current_battler
	if active:
		var side = "YOU" if active.owner_id == 0 else "ENEMY"
		turn_label.text = "%s - %s [%s]" % [side, active.card.display_name, Element.get_name(active.card.element)]
	info_label.text = "Click unit: show moves | Click hex: move | Pick move: click enemy | End Turn: pass"


func _add_log(text: String):
	battle_log.append(text)
	if battle_log.size() > 80: battle_log.pop_front()
	var lines: Array[String] = []
	for i in range(maxi(0, battle_log.size() - 12), battle_log.size()):
		lines.append(battle_log[i])
	log_label.text = "\n".join(lines)
