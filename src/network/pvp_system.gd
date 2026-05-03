class_name PVPSystem extends Node

## ── PVP Ban/Pick System ──

signal ban_phase_started
signal ban_made(player: int, banned_card_id: String)
signal pick_phase_complete(player_0_cards: Array[CardData], player_1_cards: Array[CardData])

var player_0_deck: Array[CardData] = []
var player_1_deck: Array[CardData] = []
var banned_0: Array[String] = []  # cards player 0 banned from player 1
var banned_1: Array[String] = []  # cards player 1 banned from player 0
var current_banner: int = 0  # whose turn to ban
var ban_round: int = 0       # 0-3 (4 bans total, 2 each)

func start_ban_phase(deck_0: Array[CardData], deck_1: Array[CardData]) -> void:
	player_0_deck = deck_0.slice(0, 6)
	player_1_deck = deck_1.slice(0, 6)
	banned_0.clear()
	banned_1.clear()
	current_banner = 0
	ban_round = 0
	ban_phase_started.emit()


func make_ban(player: int, card_id: String) -> bool:
	"""Player bans a card from the opponent's deck. Returns true if valid."""
	if player != current_banner:
		return false

	var opponent_deck = player_1_deck if player == 0 else player_0_deck
	var opponent_bans = banned_0 if player == 0 else banned_1

	# Check the card exists in opponent's deck
	var found = false
	for card in opponent_deck:
		if card.card_id == card_id:
			found = true
			break

	if not found:
		return false

	# Check not already banned
	if opponent_bans.has(card_id):
		return false

	opponent_bans.append(card_id)
	ban_made.emit(player, card_id)

	# Advance
	ban_round += 1
	current_banner = 1 - current_banner  # swap

	if ban_round >= 4:
		_complete_ban_phase()
	else:
		ban_phase_started.emit()  # signal ready for next ban

	return true


func _complete_ban_phase() -> void:
	"""After ban phase, select 4 cards each for battle."""
	var active_0: Array[CardData] = []
	for card in player_0_deck:
		if not banned_1.has(card.card_id):
			active_0.append(card)
			if active_0.size() >= 4:
				break

	var active_1: Array[CardData] = []
	for card in player_1_deck:
		if not banned_0.has(card.card_id):
			active_1.append(card)
			if active_1.size() >= 4:
				break

	pick_phase_complete.emit(active_0, active_1)


func get_available_cards(player: int) -> Array[CardData]:
	"""Get cards still available to a player (not banned by opponent)."""
	var deck = player_0_deck if player == 0 else player_1_deck
	var enemy_bans = banned_1 if player == 0 else banned_0

	var available: Array[CardData] = []
	for card in deck:
		if not enemy_bans.has(card.card_id):
			available.append(card)
	return available
