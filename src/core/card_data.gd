class_name CardData extends Resource

## Unique identifier for this card (e.g. "fire_salamander_001")
@export var card_id: String = ""
## Display name (e.g. "炎之精灵·伊芙利特")
@export var display_name: String = ""
@export var element: Element.Type = Element.Type.NONE

## Rarity tiers
enum Rarity { COMMON, UNCOMMON, RARE, EPIC, LEGENDARY }
@export var rarity: Rarity = Rarity.COMMON

## Base stats (level 1)
@export var base_hp: int = 100
@export var base_atk: int = 50
@export var base_def: int = 30
@export var base_spd: int = 40
@export var movement_range: int = 3  # hex tiles per turn

## Level & growth
@export var level: int = 1
var experience: int = 0

## Move pool — all moves this card can learn
@export var move_pool: Array[MoveData] = []
## Currently equipped moves (max 4)
@export var active_moves: Array[MoveData] = []

## Evolution
@export var evolution_line: Array[String] = []  # card_ids
@export var evolve_level: int = 0  # 0 = no evolution

## Visual
@export var sprite_path: String = ""  # res://assets/sprites/...
@export var portrait_path: String = ""
@export var summon_anim: String = ""

## Current stats (computed from base + level)
func get_hp() -> int:
	return base_hp + (level - 1) * 10

func get_atk() -> int:
	return base_atk + (level - 1) * 5

func get_def() -> int:
	return base_def + (level - 1) * 3

func get_spd() -> int:
	return base_spd + (level - 1) * 4
