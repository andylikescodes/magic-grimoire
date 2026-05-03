class_name BattleScene extends Node2D

## ── Battle Scene ──
## Main battle scene that wires together HexGrid rendering, Unit display, Turn management,
## and UI. This is where the prototype comes to life.

@onready var battle_manager: BattleManager = BattleManager.new()
@onready var hex_drawer: HexDrawer = HexDrawer.new()
@onready var unit_sprites: Node2D = Node2D.new()
@onready var turn_label: Label = Label.new()
@onready var info_panel: Panel = Panel.new()

var hex_size: float = 32.0
var selected_battler: Battler = null
var selected_move: MoveData = null
var highlight_hexes: Array[Vector2i] = []


func _ready():
	_setup_scene()
	_setup_test_battle()


func _setup_scene():
	# Add nodes
	add_child(hex_drawer)
	add_child(unit_sprites)
	add_child(turn_label)
	add_child(info_panel)

	turn_label.position = Vector2(10, 10)
	info_panel.position = Vector2(10, 620)
	info_panel.size = Vector2(1260, 90)

	# Connect signals
	battle_manager.unit_moved.connect(_on_unit_moved)
	battle_manager.battler_defeated.connect(_on_battler_defeated)
	battle_manager.battle_ended.connect(_on_battle_ended)
	battle_manager.turn_changed.connect(_on_turn_changed)


func _setup_test_battle():
	"""Create test cards for prototyping."""
	# Player cards
	var player_cards = [
		_make_test_card("fire_01", "炎之精灵", Element.Type.FIRE, 120, 60, 30, 50, 4),
		_make_test_card("water_01", "水之守护者", Element.Type.WATER, 100, 40, 50, 35, 3),
		_make_test_card("wind_01", "风之使者", Element.Type.WIND, 90, 55, 25, 60, 5),
		_make_test_card("earth_01", "地之巨人", Element.Type.EARTH, 150, 35, 60, 25, 2),
	]

	# Enemy cards
	var enemy_cards = [
		_make_test_card("dark_01", "暗影刺客", Element.Type.DARK, 80, 70, 20, 65, 4),
		_make_test_card("light_01", "光之祭司", Element.Type.LIGHT, 110, 45, 35, 40, 3),
		_make_test_card("fire_02", "熔岩巨兽", Element.Type.FIRE, 140, 50, 40, 30, 3),
		_make_test_card("wind_02", "风暴之鹰", Element.Type.WIND, 85, 60, 20, 70, 6),
	]

	# Setup terrain
	var terrain = {}
	for i in range(-2, 3):
		terrain[Vector2i(0, i)] = TerrainData.Type.FOREST
	for i in range(2, 5):
		terrain[Vector2i(3, i)] = TerrainData.Type.MOUNTAIN
	terrain[Vector2i(-2, 0)] = TerrainData.Type.MAGIC_CIRCLE
	terrain[Vector2i(2, 0)] = TerrainData.Type.MAGIC_CIRCLE
	terrain[Vector2i(0, 5)] = TerrainData.Type.SWAMP
	terrain[Vector2i(0, -5)] = TerrainData.Type.RUINS

	# Start
	battle_manager.start_battle(player_cards, enemy_cards, null, terrain, BattleManager.BattleMode.LOCAL)
	hex_drawer.setup(battle_manager.hex_grid, hex_size)

	# Show turn info
	_update_turn_label()
	_draw_units()


func _make_test_card(id: String, name: String, element: Element.Type,
					 hp: int, atk: int, def: int, spd: int, mov: int) -> CardData:
	var card = CardData.new()
	card.card_id = id
	card.display_name = name
	card.element = element
	card.base_hp = hp
	card.base_atk = atk
	card.base_def = def
	card.base_spd = spd
	card.movement_range = mov

	# Add some moves
	var m1 = _make_test_move("strike", "Strike", Element.Type.NONE, MoveData.Category.PHYSICAL, 50, 100, 0, 1, 1)
	var m2 = _make_test_move("flame", "Flame Burst", element, MoveData.Category.MAGICAL, 80, 90, 15, 1, 2)
	card.move_pool = [m1, m2]
	card.active_moves = [m1, m2]
	return card


func _make_test_move(id: String, name: String, el: Element.Type, cat: MoveData.Category,
					 power: int, acc: int, mp: int, min_r: int, max_r: int) -> MoveData:
	var move = MoveData.new()
	move.move_id = id
	move.display_name = name
	move.element = el
	move.category = cat
	move.base_power = power
	move.accuracy = acc
	move.mp_cost = mp
	move.min_range = min_r
	move.max_range = max_r
	return move


## ── Input Handling ──

func _input(event: InputEvent):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_handle_click(event.position)


func _handle_click(screen_pos: Vector2):
	var hex = HexGrid.pixel_to_hex(screen_pos, hex_size)

	if not battle_manager.hex_grid.cells.has(hex):
		return

	var cell = battle_manager.hex_grid.cells[hex]

	# Player turn handling
	if battle_manager.current_side != 0:
		return  # not player's turn

	var active = battle_manager.current_battler
	if not active:
		return

	if selected_battler == null:
		# Selecting a unit?
		if cell.occupant and cell.occupant.owner_id == 0:
			_on_select_battler(cell.occupant)
	elif selected_move:
		# Using a move
		_try_use_move(hex)
	else:
		# Moving
		_try_move(hex)


func _on_select_battler(battler: Battler):
	selected_battler = battler
	highlight_hexes = battle_manager.get_movement_range()
	hex_drawer.highlight_hexes(highlight_hexes, Color.LIGHT_BLUE)
	_update_info_panel()


func _try_move(hex: Vector2i):
	if hex in highlight_hexes and battle_manager.move_unit(hex):
		hex_drawer.clear_highlights()
		highlight_hexes.clear()
		selected_battler = null
	else:
		# Deselect
		hex_drawer.clear_highlights()
		highlight_hexes.clear()
		selected_battler = null


func _try_use_move(hex: Vector2i):
	# Check if hex has enemy
	var cell = battle_manager.hex_grid.cells[hex]
	if cell and cell.occupant and cell.occupant.owner_id != selected_battler.owner_id:
		var result = battle_manager.use_move(selected_move, hex)
		print("Move result: ", result)
		hex_drawer.clear_highlights()
		highlight_hexes.clear()
		selected_battler = null
		selected_move = null
	else:
		# Cancel
		hex_drawer.clear_highlights()
		highlight_hexes.clear()
		selected_move = null
	_on_turn_changed(battle_manager.current_phase, battle_manager.current_side)


## ── Callbacks ──

func _on_turn_changed(phase, side):
	_update_turn_label()
	_draw_units()

	if side == 1:
		# AI turn — auto-play
		await get_tree().create_timer(1.0).timeout
		var ai = AIController.new(battle_manager)
		ai.take_turn()
		_draw_units()
		_update_turn_label()


func _on_unit_moved(battler: Battler, from_hex: Vector2i, to_hex: Vector2i):
	_draw_units()


func _on_battler_defeated(battler: Battler):
	print("%s defeated!" % battler.card.display_name)
	_draw_units()


func _on_battle_ended(victory: bool):
	turn_label.text = "🏆 Victory!" if victory else "💀 Defeated!"
	turn_label.add_theme_color_override("font_color", Color.GREEN if victory else Color.RED)


func _update_turn_label():
	var active = battle_manager.current_battler
	if active:
		turn_label.text = "⚔️ %s's Turn (HP: %d/%d)" % [
			active.card.display_name,
			active.current_hp,
			active.max_hp,
		]


func _update_info_panel():
	# Show selected unit info
	if selected_battler:
		var b = selected_battler
		var text = "%s | %s | HP:%d/%d | ATK:%d DEF:%d SPD:%d" % [
			b.card.display_name,
			Element.get_name(b.card.element),
			b.current_hp, b.max_hp,
			b.atk, b.def, b.spd,
		]
		# In Godot 4: clear children and add label
		for child in info_panel.get_children():
			child.queue_free()
		var label = Label.new()
		label.text = text
		info_panel.add_child(label)


func _draw_units():
	# Clear old sprites
	for child in unit_sprites.get_children():
		child.queue_free()

	# Draw all units
	for unit in battle_manager.all_units:
		if not unit.is_alive:
			continue

		var pos = HexGrid.hex_to_pixel(unit.hex_position, hex_size)
		var sprite = ColorRect.new()
		sprite.size = Vector2(20, 20)
		sprite.position = pos - Vector2(10, 10)
		sprite.color = Element.get_color(unit.card.element)

		# Player outline vs enemy outline
		if unit.owner_id == 0:
			sprite.color = sprite.color.lightened(0.3)
		else:
			sprite.color = sprite.color.darkened(0.3)

		unit_sprites.add_child(sprite)

		# HP bar above unit
		var hp_bar = ColorRect.new()
		hp_bar.size = Vector2(24, 4)
		hp_bar.position = pos - Vector2(12, 18)
		hp_bar.color = Color.RED

		var hp_fill = ColorRect.new()
		var hp_pct = float(unit.current_hp) / float(unit.max_hp)
		hp_fill.size = Vector2(24 * hp_pct, 4)
		hp_fill.color = Color.GREEN
		hp_bar.add_child(hp_fill)
		unit_sprites.add_child(hp_bar)
