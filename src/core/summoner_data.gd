class_name SummonerData extends Resource

@export var summoner_name: String = "Wizard"
@export var level: int = 1

## Active summoner skills (used during battle)
@export var skills: Array[SummonerSkill] = []
## Passive abilities
@export var passive_abilities: Array[PassiveAbility] = []

## Current grimoire (collection of cards)
var grimoire: GrimoireData
## Current active deck (6 cards for battle)
var active_deck: Array[CardData] = []

## Equipment slots
@export var weapon: String = ""
@export var robe: String = ""
@export var accessory: String = ""


class SummonerSkill extends Resource:
	@export var skill_id: String = ""
	@export var display_name: String = ""
	@export var cooldown: int = 3       # turns
	@export var description: String = ""
	var current_cooldown: int = 0

	func is_ready() -> bool:
		return current_cooldown <= 0

	func use():
		current_cooldown = cooldown

	func tick():
		if current_cooldown > 0:
			current_cooldown -= 1


class PassiveAbility extends Resource:
	@export var ability_id: String = ""
	@export var display_name: String = ""
	@export var description: String = ""
