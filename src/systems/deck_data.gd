class_name DeckData extends Resource

@export var deck_name: String = "Default Deck"
@export var cards: Array[CardData] = []

## Max cards in a battle deck
const MAX_DECK_SIZE: int = 6

func can_add(card: CardData) -> bool:
	return cards.size() < MAX_DECK_SIZE


func add_card(card: CardData) -> bool:
	if cards.size() >= MAX_DECK_SIZE:
		return false
	# Don't add duplicates
	if cards.has(card):
		return false
	cards.append(card)
	return true


func remove_card(card: CardData) -> bool:
	var idx = cards.find(card)
	if idx >= 0:
		cards.remove_at(idx)
		return true
	return false


func get_active_battle_cards(banned: Array[String] = []) -> Array[CardData]:
	"""Return cards available for battle after removing banned ones."""
	var active: Array[CardData] = []
	for card in cards:
		if not banned.has(card.card_id):
			active.append(card)
	return active


func to_dict() -> Dictionary:
	var card_ids: Array[String] = []
	for card in cards:
		card_ids.append(card.card_id)
	return {
		"deck_name": deck_name,
		"card_ids": card_ids
	}
