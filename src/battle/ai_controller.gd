class_name AIController extends RefCounted

## ── AI Controller for PVE ──
## Simple but effective AI that evaluates moves and picks the best action.

var battle_manager: BattleManager

func _init(p_bm: BattleManager):
	battle_manager = p_bm


func take_turn() -> Dictionary:
	"""Execute the best action for the current AI battler. Returns result dict."""
	var battler = battle_manager.current_battler
	if not battler or battler.owner_id == 0:
		return {"success": false, "error": "Not AI's turn"}

	# 1. Try to attack the best target
	var attack_result = _try_attack(battler)
	if attack_result.get("success", false):
		return attack_result

	# 2. Move toward nearest enemy
	var move_result = _move_toward_enemy(battler)
	if move_result.get("moved", false):
		# After moving, try attack again if we have range
		pass

	return {"success": true, "action": "wait"}


func _try_attack(battler: Battler) -> Dictionary:
	"""Find the best move and target — pick highest damage prediction."""
	var best_score: float = -1.0
	var best_move: MoveData = null
	var best_target_hex: Vector2i = Vector2i.ZERO

	for move in battler.card.active_moves:
		if not battler.is_move_ready(move):
			continue
		if battler.current_mp < move.mp_cost:
			continue

		var target_hexes = battle_manager.get_attack_targets(move)
		for target_hex in target_hexes:
			var target_cell = battle_manager.hex_grid.cells[target_hex]
			if not target_cell or not target_cell.occupant:
				continue

			var target = target_cell.occupant
			var damage = battler.predict_damage(move, target,
				HexGrid.distance(battler.hex_position, target_hex))

			# Scoring: prioritize killing blows > damage > element advantage
			var score: float = damage
			if damage >= target.current_hp:
				score += 100.0  # huge bonus for kill shot
			if move.element == battler.card.element:
				score += 10.0   # STAB bonus

			if score > best_score:
				best_score = score
				best_move = move
				best_target_hex = target_hex

	if best_move:
		return battle_manager.use_move(best_move, best_target_hex)

	return {"success": false}


func _move_toward_enemy(battler: Battler) -> Dictionary:
	"""Move toward the nearest enemy."""
	if battler.movement <= 0:
		return {"moved": false}

	# Find nearest enemy
	var nearest_enemy: Battler = null
	var nearest_dist: int = 9999

	for unit in battle_manager.all_units:
		if unit.owner_id == battler.owner_id or not unit.is_alive:
			continue
		var dist = HexGrid.distance(battler.hex_position, unit.hex_position)
		if dist < nearest_dist:
			nearest_dist = dist
			nearest_enemy = unit

	if not nearest_enemy:
		return {"moved": false}

	# Move toward enemy
	var move_range = battle_manager.get_movement_range()
	var best_hex = battler.hex_position
	var best_new_dist = nearest_dist

	for hex in move_range:
		var new_dist = HexGrid.distance(hex, nearest_enemy.hex_position)
		if new_dist < best_new_dist:
			best_new_dist = new_dist
			best_hex = hex

	if best_hex != battler.hex_position:
		battle_manager.move_unit(best_hex)
		return {"moved": true, "from": battler.hex_position, "to": best_hex}

	return {"moved": false}
