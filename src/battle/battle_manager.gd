class_name BattleManager extends Node

signal battle_started
signal turn_changed(phase: Phase, side: int)
signal unit_moved(battler: Battler, from_hex: Vector2i, to_hex: Vector2i)
signal move_used(attacker: Battler, target: Battler, move: MoveData, damage: int)
signal battler_defeated(battler: Battler)
signal battle_ended(victory: bool)

enum Phase {
	DEPLOY,
	PLAYER_TURN,
	ENEMY_TURN,
	RESOLVE,
	VICTORY,
	DEFEAT,
}

enum BattleMode {
	PVE,
	PVP,
	LOCAL,
}

## ── References ──
var hex_grid: HexGrid
var terrain_map: Dictionary = {}  # Vector2i -> TerrainData.Type

## ── Units ──
var player_units: Array[Battler] = []   # deployed player battlers (max 4)
var enemy_units: Array[Battler] = []    # deployed enemy battlers (max 4)
var all_units: Array[Battler] = []

## ── Turn order ──
var turn_queue: Array[Battler] = []
var current_battler: Battler = null
var current_phase: Phase = Phase.DEPLOY
var current_side: int = 0  # 0 = player, 1 = enemy

## ── Mode ──
var battle_mode: BattleMode = BattleMode.LOCAL

## ── PVP ──
var banned_cards: Dictionary = {}  # player_index -> Array[String] of banned card_ids

## ── Summoners ──
var player_summoner: SummonerData
var enemy_summoner: SummonerData

## ── Move Target ──
var pending_move: MoveData = null
var pending_target_hex: Vector2i = Vector2i.ZERO


## ── Initialization ──

func start_battle(p_player_cards: Array[CardData], p_enemy_cards: Array[CardData],
				  p_grid: HexGrid = null, p_terrain: Dictionary = {},
				  mode: BattleMode = BattleMode.LOCAL) -> void:

	battle_mode = mode

	# Init grid
	if p_grid:
		hex_grid = p_grid
	else:
		hex_grid = HexGrid.new()
		hex_grid.generate_hex_map()

	terrain_map = p_terrain
	_apply_terrain_to_grid()

	# Create battlers (up to 4 each)
	_create_battlers(p_player_cards, 0)
	_create_battlers(p_enemy_cards, 1)

	# Deploy
	_auto_deploy()

	# Build turn queue
	_build_turn_queue()

	current_phase = Phase.PLAYER_TURN
	current_side = 0
	battle_started.emit()
	_advance_turn()


func _create_battlers(cards: Array[CardData], owner: int) -> void:
	for card in cards.slice(0, 4):
		var battler = Battler.new()
		battler.setup(card)
		battler.owner_id = owner
		if owner == 0:
			player_units.append(battler)
		else:
			enemy_units.append(battler)
		all_units.append(battler)


func _apply_terrain_to_grid() -> void:
	for hex in terrain_map:
		if hex_grid.cells.has(hex):
			var cell = hex_grid.cells[hex]
			cell.set_terrain(terrain_map[hex])


func _auto_deploy() -> void:
	"""Place units on their side of the map."""
	var player_start_hexes = _get_spawn_hexes(0)
	var enemy_start_hexes = _get_spawn_hexes(1)

	for i in range(mini(player_units.size(), player_start_hexes.size())):
		player_units[i].hex_position = player_start_hexes[i]
		hex_grid.cells[player_start_hexes[i]].occupant = player_units[i]

	for i in range(mini(enemy_units.size(), enemy_start_hexes.size())):
		enemy_units[i].hex_position = enemy_start_hexes[i]
		hex_grid.cells[enemy_start_hexes[i]].occupant = enemy_units[i]


func _get_spawn_hexes(side: int) -> Array[Vector2i]:
	"""Get spawn hexes for a side."""
	var spawns: Array[Vector2i] = []
	var q_range = hex_grid.radius
	var q_sign = -1 if side == 0 else 1  # player on left, enemy on right

	# Try to find passable hexes on the side
	for r in range(-2, 3):  # 5 hexes wide, pick first 4 passable
		var hex = Vector2i(q_sign * (q_range - 1), r * 2)
		if hex_grid.cells.has(hex) and hex_grid.cells[hex].is_passable:
			spawns.append(hex)
			if spawns.size() >= 4:
				break
	return spawns


## ── Turn Queue ──

func _build_turn_queue() -> void:
	"""Build turn order sorted by SPD (fastest first)."""
	turn_queue.clear()
	for unit in all_units:
		if unit.is_alive:
			turn_queue.append(unit)

	# Sort by speed descending
	turn_queue.sort_custom(func(a, b): return a.get_effective_spd() > b.get_effective_spd())


func _advance_turn() -> void:
	"""Move to the next battler in the turn queue."""
	if _check_battle_end():
		return

	# Find next alive battler
	while turn_queue.size() > 0:
		current_battler = turn_queue.pop_front()
		if current_battler.is_alive:
			current_battler.reset_turn()

			# Check frozen — skip turn
			if current_battler.is_frozen():
				continue

			current_side = current_battler.owner_id
			turn_changed.emit(current_phase, current_side)
			return

	# Queue exhausted — rebuild
	_build_turn_queue()
	if turn_queue.size() > 0:
		_advance_turn()


func _check_battle_end() -> bool:
	"""Check if all units on one side are defeated."""
	var player_alive = _count_alive(player_units)
	var enemy_alive = _count_alive(enemy_units)

	if player_alive == 0:
		current_phase = Phase.DEFEAT
		battle_ended.emit(false)
		return true
	elif enemy_alive == 0:
		current_phase = Phase.VICTORY
		battle_ended.emit(true)
		return true
	return false


func _count_alive(units: Array[Battler]) -> int:
	var count = 0
	for u in units:
		if u.is_alive:
			count += 1
	return count


## ── Player Actions ──

func get_movement_range() -> Array[Vector2i]:
	"""Get valid movement hexes for the current battler."""
	if not current_battler:
		return []
	return hex_grid.get_range(current_battler.hex_position, current_battler.movement)


func get_attack_targets(move: MoveData) -> Array[Vector2i]:
	"""Get hexes in range for a given move."""
	if not current_battler:
		return []

	var current_hex = current_battler.hex_position
	var range_hexes = hex_grid.get_range(current_hex, move.max_range)

	# Filter: must have an enemy unit
	var targets: Array[Vector2i] = []
	for hex in range_hexes:
		var dist = HexGrid.distance(current_hex, hex)
		if dist >= move.min_range and dist <= move.max_range:
			var cell = hex_grid.cells.get(hex)
			if cell and cell.occupant and cell.occupant.owner_id != current_battler.owner_id:
				targets.append(hex)

	return targets


func move_unit(to_hex: Vector2i) -> bool:
	"""Move the current battler to a new hex."""
	if not current_battler:
		return false

	var path = hex_grid.find_path(current_battler.hex_position, to_hex)
	if path.size() == 0 or path.size() > current_battler.movement:
		return false

	# Check if destination has occupant
	if hex_grid.cells[to_hex].occupant:
		return false

	# Move
	var from_hex = current_battler.hex_position
	hex_grid.cells[from_hex].occupant = null
	current_battler.hex_position = to_hex
	hex_grid.cells[to_hex].occupant = current_battler
	current_battler.movement -= path.size()
	current_battler.has_moved = true

	unit_moved.emit(current_battler, from_hex, to_hex)
	return true


func use_move(move: MoveData, target_hex: Vector2i) -> Dictionary:
	"""Execute a move against a target hex. Returns result dict."""
	if not current_battler:
		return {"success": false, "error": "No active battler"}

	if not current_battler.is_move_ready(move):
		return {"success": false, "error": "Move on cooldown"}

	var target_cell = hex_grid.cells.get(target_hex)
	if not target_cell or not target_cell.occupant:
		return {"success": false, "error": "No target at hex"}

	var target = target_cell.occupant

	var result = {"success": true, "move": move.display_name, "target": target.card.display_name}

	if move.category == MoveData.Category.SUPPORT:
		# Heal / buff
		if move.heal_amount > 0:
			var actual_heal = mini(move.heal_amount, current_battler.max_hp - current_battler.current_hp)
			current_battler.current_hp += actual_heal
			result["healed"] = actual_heal

		if move.buff_atk != 0 or move.buff_def != 0 or move.buff_spd != 0:
			var buff = Battler.Buff.new(move.buff_def, move.buff_atk, move.buff_spd, 3)
			current_battler.buffs.append(buff)
			result["buffed"] = true

	else:
		# Attack
		var damage = target.take_damage(move, current_battler)
		result["damage"] = damage

		# Apply status
		if move.status_effect != "":
			var applied = target.apply_status(move.status_effect, move.status_chance)
			result["status_applied"] = applied

		move_used.emit(current_battler, target, move, damage)

		if not target.is_alive:
			battler_defeated.emit(target)
			result["defeated"] = true

	# Start cooldown
	if move.cooldown > 0:
		current_battler.start_cooldown(move.move_id, move.cooldown)

	current_battler.has_acted = true
	current_battler.current_mp -= move.mp_cost

	_advance_turn()
	return result


func swap_unit(new_card: CardData) -> bool:
	"""Swap current battler with a benched card (consumes turn)."""
	# Future: implement swapping
	return false
