extends Node2D

## ── Magic Grimoire — Battle Scene v2 ──
## Fixes: full map view, unit name labels, AI stuck bug, error log on screen.

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
var hex_size: float = 28.0
var map_offset: Vector2 = Vector2.ZERO
var selected_move: MoveData = null
var highlight_hexes: Array[Vector2i] = []
var battle_over: bool = false

# ── Error / debug log (visible on screen) ──
var error_log: Array[String] = []

# ── Nodes ──
var hex_layer: Node2D
var unit_layer: Node2D
var ui_layer: Control
var turn_label: Label
var info_label: Label
var move_panel: Control
var log_label: RichTextLabel
var error_label: RichTextLabel


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
	turn_label.add_theme_font_size_override("font_size", 18)
	ui_layer.add_child(turn_label)

	info_label = Label.new()
	info_label.position = Vector2(10, 690)
	info_label.add_theme_font_size_override("font_size", 11)
	ui_layer.add_child(info_label)

	move_panel = Control.new()
	move_panel.position = Vector2(980, 40)
	ui_layer.add_child(move_panel)

	var end_btn = Button.new()
	end_btn.text = "End Turn"
	end_btn.position = Vector2(10, 40)
	end_btn.size = Vector2(120, 34)
	end_btn.pressed.connect(_on_end_turn)
	ui_layer.add_child(end_btn)

	# Battle log (top-right)
	log_label = RichTextLabel.new()
	log_label.position = Vector2(960, 10)
	log_label.size = Vector2(300, 28)
	log_label.bbcode_enabled = true
	ui_layer.add_child(log_label)

	# Error log (bottom-right, always visible)
	error_label = RichTextLabel.new()
	error_label.position = Vector2(800, 420)
	error_label.size = Vector2(460, 260)
	error_label.bbcode_enabled = true
	error_label.scroll_following = true
	ui_layer.add_child(error_label)


func _start_battle():
	bm = BattleManager.new()
	bm.unit_moved.connect(_on_moved)
	bm.battler_defeated.connect(_on_defeated)
	bm.battle_ended.connect(_on_ended)
	# Do NOT connect turn_changed — we drive AI manually to avoid signal reentrancy bugs

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

	# Calculate hex_size and offset to fit the ENTIRE map on screen
	_calc_viewport()

	_draw_all()
	_update_info()
	_update_move_buttons()


func _calc_viewport():
	# Find the bounding box of all hexes
	var min_x = INF; var max_x = -INF
	var min_y = INF; var max_y = -INF
	for hex in hex_grid.cells:
		var p = HexGrid.hex_to_pixel(hex, 1.0)  # unit-size coords
		min_x = minf(min_x, p.x); max_x = maxf(max_x, p.x)
		min_y = minf(min_y, p.y); max_y = maxf(max_y, p.y)

	var map_w = max_x - min_x + 1.0
	var map_h = max_y - min_y + 1.0

	# Available screen space (leave margins for UI)
	var avail_w = 920.0
	var avail_h = 670.0

	hex_size = minf(avail_w / map_w, avail_h / map_h)
	hex_size = clampf(hex_size, 20.0, 50.0)

	# Center the map
	var center_x = (min_x + max_x) * hex_size / 2.0
	var center_y = (min_y + max_y) * hex_size / 2.0
	map_offset = Vector2(avail_w / 2.0 - center_x + 40, avail_h / 2.0 - center_y + 30)

	_log_error("Map: %d hexes, hex_size=%.1f, offset=(%.0f,%.0f)" % [hex_grid.cells.size(), hex_size, map_offset.x, map_offset.y])


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
		var center = HexGrid.hex_to_pixel(hex, hex_size) + map_offset
		var verts = _hex_verts(center, hex_size)

		var fill = _terrain_color(cell.terrain)
		if cell.is_highlighted: fill = fill.lerp(Color.WHITE, 0.3)

		var poly = Polygon2D.new()
		poly.polygon = verts; poly.color = fill
		hex_layer.add_child(poly)

		var border = Line2D.new()
		border.points = verts; border.points.append(verts[0])
		border.width = 1.0; border.default_color = Color(0, 0, 0, 0.25)
		hex_layer.add_child(border)


func _draw_units():
	for child in unit_layer.get_children(): child.queue_free()

	for unit: Battler in bm.all_units:
		if not unit.is_alive: continue

		var pos = HexGrid.hex_to_pixel(unit.hex_position, hex_size) + map_offset

		# ── Name label ABOVE unit ──
		var name_lbl = Label.new()
		name_lbl.text = unit.card.display_name
		name_lbl.position = pos - Vector2(40, 28)
		name_lbl.size = Vector2(80, 16)
		name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_lbl.add_theme_font_size_override("font_size", 10)

		if unit.owner_id == 0:
			name_lbl.add_theme_color_override("font_color", Color.WHITE)
		else:
			name_lbl.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
		unit_layer.add_child(name_lbl)

		# ── Sprite ──
		var sprite_path = "res://assets/sprites/" + unit.card.card_id + ".png"
		var sprite: Node2D = null

		if ResourceLoader.exists(sprite_path):
			var tex = load(sprite_path)
			if tex is Texture2D:
				var sr = Sprite2D.new()
				sr.texture = tex; sr.scale = Vector2(0.30, 0.30)
				sr.position = pos
				if unit.owner_id == 1: sr.scale.x = -0.30
				sprite = sr

		if not sprite:
			var cr = ColorRect.new()
			cr.size = Vector2(18, 18); cr.position = pos - Vector2(9, 9)
			cr.color = Element.get_color(unit.card.element)
			if unit.owner_id == 0: cr.color = cr.color.lightened(0.3)
			sprite = cr

		unit_layer.add_child(sprite)

		# ── HP bar ──
		var bar_w = 28.0
		var bar_bg = ColorRect.new()
		bar_bg.size = Vector2(bar_w, 5); bar_bg.position = pos - Vector2(bar_w/2, 14)
		bar_bg.color = Color(0.3, 0.1, 0.1)
		unit_layer.add_child(bar_bg)

		var pct = float(unit.current_hp) / float(unit.max_hp)
		var bar_fill = ColorRect.new()
		bar_fill.size = Vector2(bar_w * pct, 5); bar_fill.position = pos - Vector2(bar_w/2, 14)
		bar_fill.color = Color.GREEN if pct > 0.5 else Color.ORANGE if pct > 0.25 else Color.RED
		unit_layer.add_child(bar_fill)

		# ── Current battler ring ──
		if unit == bm.current_battler and unit.owner_id == 0 and not battle_over:
			var ring_pts = PackedVector2Array()
			for i in range(24):
				var a = deg_to_rad(i * 15.0)
				ring_pts.append(pos + Vector2(cos(a) * 14, sin(a) * 14))
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
	if battle_over: return
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT): return
	if bm.current_side != 0: return

	var pos = event.position - map_offset
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
		_add_log("Cannot move there")
	else:
		_add_log("%s moved" % bm.current_battler.card.display_name)
	_clear_highlights()
	_update_move_buttons()
	_draw_all()
	_update_info()


func _do_attack(hex: Vector2i):
	var result = bm.use_move(selected_move, hex)
	if result.get("success"):
		var line = "%s -> %s on %s" % [bm.current_battler.card.display_name, selected_move.display_name, result.get("target", "?")]
		if result.has("damage"): line += " (-%d)" % result["damage"]
		if result.get("defeated"): line += " DEFEATED"
		_add_log(line)
	else:
		_add_log("FAIL: %s" % result.get("error", "?"))

	_clear_highlights()
	_update_move_buttons()
	_draw_all()
	_update_info()

	# After player attack, check if next unit is enemy → AI turn
	if not battle_over and bm.current_side == 1:
		_do_ai_turns()


func _on_end_turn():
	if bm.current_side != 0 or battle_over: return
	_clear_highlights()
	_update_move_buttons()
	bm.current_battler.has_acted = true
	_add_log("%s passes" % bm.current_battler.card.display_name)
	bm._advance_turn()
	_draw_all()
	_update_info()
	_update_move_buttons()

	# If enemy turn now, run AI
	if not battle_over and bm.current_side == 1:
		_do_ai_turns()


## ── AI (fixed: sequential processing, no signal reentrancy) ──

func _do_ai_turns():
	"""Process ALL enemy units sequentially using await."""
	_process_next_ai()


func _process_next_ai():
	if battle_over or bm.current_side != 0:
		return

	var unit = bm.current_battler
	if not unit or not unit.is_alive:
		bm._advance_turn()
		_draw_all(); _update_info(); _update_move_buttons()
		if bm.current_side == 1:
			await get_tree().create_timer(0.3).timeout
			_process_next_ai()
		return

	_log_error("AI: %s thinking..." % unit.card.display_name)
	await get_tree().create_timer(0.4).timeout

	var unit_before = bm.current_battler  # track who was acting
	var ai = AIController.new(bm)
	var result = ai.take_turn()

	# If AI didn't manage to attack (use_move advances turn internally),
	# we need to manually advance the turn
	if bm.current_battler == unit_before and bm.current_side == 1:
		_log_error("AI: %s passes (no action)" % unit_before.card.display_name)
		bm._advance_turn()

	_draw_all(); _update_info(); _update_move_buttons()

	if battle_over: return

	if bm.current_side == 1:
		await get_tree().create_timer(0.3).timeout
		_process_next_ai()


func _update_move_buttons():
	for child in move_panel.get_children(): child.queue_free()

	if not bm.current_battler or bm.current_side != 0 or battle_over: return
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
	if bm.current_side != 0 or battle_over: return
	_clear_highlights()
	selected_move = move

	var targets = bm.get_attack_targets(move)
	highlight_hexes = targets
	for h in highlight_hexes:
		if hex_grid.cells.has(h): hex_grid.cells[h].is_highlighted = true
	_draw_hexes()
	_add_log("Pick target for %s" % move.display_name)


## ── Signals ──

func _on_moved(_b, _f, _t): _draw_all()
func _on_defeated(battler: Battler):
	_add_log("%s defeated!" % battler.card.display_name)
	_draw_all()

func _on_ended(victory: bool):
	battle_over = true
	var msg = "VICTORY!" if victory else "DEFEATED!"
	turn_label.text = msg
	turn_label.add_theme_color_override("font_color", Color.GREEN if victory else Color.RED)
	_add_log("=== " + msg + " ===")


func _update_info():
	if battle_over: return
	var active = bm.current_battler
	if active:
		var side = "YOU" if active.owner_id == 0 else "ENEMY"
		turn_label.text = "%s - %s [%s]" % [side, active.card.display_name, Element.get_name(active.card.element)]
	info_label.text = "Click unit: moves | Click hex: move | Move btn: attack | End Turn: pass"


func _add_log(text: String):
	_log_error(text)


## ── Error / debug log (always visible on screen) ──

func _log_error(text: String):
	error_log.append(text)
	if error_log.size() > 80: error_log.pop_front()
	var lines: Array[String] = []
	for i in range(maxi(0, error_log.size() - 15), error_log.size()):
		lines.append(error_log[i])
	error_label.text = "[Debug Log]\n" + "\n".join(lines)
