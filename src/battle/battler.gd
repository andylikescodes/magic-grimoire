class_name Battler extends RefCounted

## ── Identity ──
var card: CardData
var owner_id: int = 0  # player index (0 = player, 1+ = AI/opponent)
var is_alive: bool = true
var b_unique_id: String  # unique instance ID for this battler

## ── Current Position ──
var hex_position: Vector2i = Vector2i.ZERO
var facing: int = 0  # 0-5, which neighbor direction

## ── Current Stats (can be modified by buffs/debuffs) ──
var current_hp: int = 0
var max_hp: int = 0
var current_mp: int = 100
var max_mp: int = 100
var atk: int = 0
var def: int = 0
var spd: int = 0
var movement: int = 0  # remaining movement this turn
var max_movement: int = 0

## ── Combat State ──
var has_acted: bool = false      # has used a move this turn
var has_moved: bool = false      # has moved this turn
var status_effects: Array[StatusEffect] = []
var buffs: Array[Buff] = []
var move_cooldowns: Dictionary = {}  # move_id -> turns remaining

## ── Initialize from CardData ──
func setup(p_card: CardData) -> void:
	card = p_card
	b_unique_id = "%s_%d_%d" % [card.card_id, owner_id, Time.get_ticks_msec()]
	_reset_stats()


func _reset_stats() -> void:
	max_hp = card.get_hp()
	current_hp = max_hp
	atk = card.get_atk()
	def = card.get_def()
	spd = card.get_spd()
	max_movement = card.movement_range
	movement = max_movement


## ── Damage Calculation ──

func predict_damage(move: MoveData, target: Battler, hex_distance: int) -> int:
	"""Predict damage this battler would deal to target with given move."""
	if move.category == MoveData.Category.SUPPORT:
		return 0

	var power: float = move.base_power
	var attack_stat: float = atk
	var defense_stat: float = target.get_effective_def()

	# Base damage formula (similar to Pokemon)
	var damage: float = ((2.0 * card.level / 5.0 + 2.0) * power * attack_stat / defense_stat) / 50.0 + 2.0

	# Element type multiplier
	damage *= Element.get_multiplier(move.element, target.card.element)

	# Terrain bonuses on target
	var target_terrain = TerrainData.get_data(target.get_terrain_type())
	if target_terrain.get("elemental_boost", Element.Type.NONE) == target.card.element:
		damage /= target_terrain.get("elemental_multiplier", 1.0)  # weaker on home terrain

	# Random factor (will be applied in actual damage)
	return maxi(1, int(damage * 0.85))  # minimum damage estimate


func get_effective_def() -> float:
	var d: float = def
	for buff in buffs:
		d += buff.def_mod
	return maxf(1.0, d)


func get_effective_spd() -> float:
	var s: float = spd
	for buff in buffs:
		s += buff.spd_mod
	return maxf(1.0, s)


## ── Take Damage ──

func take_damage(move: MoveData, attacker: Battler) -> int:
	"""Apply damage from a move. Returns actual damage dealt."""
	var power: float = move.base_power
	var attack_stat: float = attacker.atk
	var defense_stat: float = get_effective_def()

	var damage: float = ((2.0 * attacker.card.level / 5.0 + 2.0) * power * attack_stat / defense_stat) / 50.0 + 2.0

	# Element multiplier
	damage *= Element.get_multiplier(move.element, card.element)

	# STAB (Same Type Attack Bonus) — 1.5x if move element matches card element
	if move.element == card.element:
		damage *= 1.5

	# Terrain defense
	var terrain_data = TerrainData.get_data(get_terrain_type())
	var def_bonus = terrain_data.get("defense_bonus", 0)
	damage -= def_bonus

	# Evasion check
	var evasion = terrain_data.get("evasion_bonus", 0.0)
	if randf() < evasion:
		damage = 0  # dodged!

	# Random factor 0.85 - 1.0
	damage *= randf_range(0.85, 1.0)

	var final_damage = maxi(1, int(damage))
	current_hp = maxi(0, current_hp - final_damage)

	if current_hp <= 0:
		is_alive = false

	return final_damage


## ── Status Effects ──

func apply_status(effect: String, chance: float) -> bool:
	if randf() > chance:
		return false

	match effect:
		"burn":
			add_status(StatusEffect.new("Burn", 3, {"dot": 8}))  # 8 damage/turn for 3 turns
		"freeze":
			add_status(StatusEffect.new("Freeze", 1, {"skip": true}))  # skip next turn
		"poison":
			add_status(StatusEffect.new("Poison", 4, {"dot": 5}))
		"paralyze":
			add_status(StatusEffect.new("Paralyze", 3, {"slow": 0.5}))  # half SPD
	return true


func add_status(se: StatusEffect) -> void:
	# Don't stack same status
	for existing in status_effects:
		if existing.name == se.name:
			return
	status_effects.append(se)


func tick_statuses() -> void:
	var to_remove: Array = []
	for se in status_effects:
		se.remaining -= 1
		if se.remaining <= 0:
			to_remove.append(se)
	for se in to_remove:
		status_effects.erase(se)


func is_paralyzed() -> bool:
	for se in status_effects:
		if se.name == "Paralyze":
			return true
	return false


func is_frozen() -> bool:
	for se in status_effects:
		if se.name == "Freeze":
			return true
	return false


## ── Cooldowns ──

func start_cooldown(move_id: String, turns: int) -> void:
	move_cooldowns[move_id] = turns


func tick_cooldowns() -> void:
	var to_remove: Array = []
	for move_id in move_cooldowns:
		move_cooldowns[move_id] -= 1
		if move_cooldowns[move_id] <= 0:
			to_remove.append(move_id)
	for move_id in to_remove:
		move_cooldowns.erase(move_id)


func is_move_ready(move: MoveData) -> bool:
	return not move_cooldowns.has(move.move_id)


## ── Helpers ──

func get_terrain_type() -> TerrainData.Type:
	# Will be set by BattleManager based on grid position
	return TerrainData.Type.GRASS  # default, overridden externally


func reset_turn() -> void:
	has_acted = false
	has_moved = false
	movement = max_movement
	current_mp = mini(max_mp, current_mp + 20)  # regen 20 MP per turn
	tick_statuses()
	tick_cooldowns()


## ── Data Classes ──

class StatusEffect:
	var name: String
	var remaining: int
	var params: Dictionary  # e.g. {"dot": 5, "skip": false}

	func _init(p_name: String, p_dur: int, p_params: Dictionary):
		name = p_name
		remaining = p_dur
		params = p_params


class Buff:
	var def_mod: int = 0
	var atk_mod: int = 0
	var spd_mod: int = 0
	var remaining: int

	func _init(p_def: int, p_atk: int, p_spd: int, p_dur: int):
		def_mod = p_def
		atk_mod = p_atk
		spd_mod = p_spd
		remaining = p_dur
