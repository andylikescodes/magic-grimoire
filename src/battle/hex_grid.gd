class_name HexGrid extends Resource

## ── Axial Coordinate System ──
## q = column, r = row
## See: https://www.redblobgames.com/grids/hexagons/

## Hex directions (axial)
const DIRECTIONS: Array[Vector2i] = [
	Vector2i(1, 0),   Vector2i(1, -1),  Vector2i(0, -1),
	Vector2i(-1, 0),  Vector2i(-1, 1),  Vector2i(0, 1),
]

## Grid dimensions
@export var radius: int = 8  # radius from center for hex map
var cells: Dictionary = {}   # Vector2i -> HexCell

## ── Initialization ──

func generate_hex_map(radius: int = 8) -> void:
	self.radius = radius
	cells.clear()
	for q in range(-radius, radius + 1):
		for r in range(-radius, radius + 1):
			var hex = Vector2i(q, r)
			if abs(q + r) <= radius:  # ensures hex-shaped map
				cells[hex] = HexCell.new(hex)


## ── Geometry ──

## Convert axial coordinates to world pixel position (pointy-top hex)
## hex_size = the distance from center to a vertex
static func hex_to_pixel(hex: Vector2i, hex_size: float = 32.0) -> Vector2:
	var x: float = hex_size * (sqrt(3) * hex.x + sqrt(3) / 2.0 * hex.y)
	var y: float = hex_size * (3.0 / 2.0 * hex.y)
	return Vector2(x, y)

## Convert pixel position to nearest axial hex coordinates
static func pixel_to_hex(pos: Vector2, hex_size: float = 32.0) -> Vector2i:
	var q: float = (sqrt(3) / 3.0 * pos.x - 1.0 / 3.0 * pos.y) / hex_size
	var r: float = (2.0 / 3.0 * pos.y) / hex_size
	return hex_round(q, r)

## Round floating-point hex to nearest integer hex
static func hex_round(q_f: float, r_f: float) -> Vector2i:
	var s_f: float = -q_f - r_f
	var q: int = roundi(q_f)
	var r: int = roundi(r_f)
	var s: int = roundi(s_f)

	var q_diff: float = abs(q - q_f)
	var r_diff: float = abs(r - r_f)
	var s_diff: float = abs(s - s_f)

	if q_diff > r_diff and q_diff > s_diff:
		q = -r - s
	elif r_diff > s_diff:
		r = -q - s
	# else s stays

	return Vector2i(q, r)


## ── Navigation ──

## Get all 6 neighbors of a hex
func get_neighbors(hex: Vector2i) -> Array[Vector2i]:
	var neighbors: Array[Vector2i] = []
	for dir in DIRECTIONS:
		var neighbor = hex + dir
		if cells.has(neighbor) and cells[neighbor].is_passable:
			neighbors.append(neighbor)
	return neighbors

## Get all hexes within a given range (movement / attack range)
func get_range(center: Vector2i, distance: int) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var visited: Dictionary = {}
	var frontier: Array[Vector2i] = [center]
	visited[center] = 0

	while frontier.size() > 0:
		var current = frontier.pop_front()
		var dist = visited[current]

		if dist <= distance and current != center:
			result.append(current)

		if dist < distance:
			for neighbor in get_neighbors(current):
				if not visited.has(neighbor):
					visited[neighbor] = dist + 1
					frontier.append(neighbor)

	return result

## A* pathfinding between two hexes
func find_path(start: Vector2i, goal: Vector2i) -> Array[Vector2i]:
	if not cells.has(start) or not cells.has(goal):
		return []
	if not cells[goal].is_passable:
		return []

	var frontier: Array[Vector2i] = [start]
	var came_from: Dictionary = {}
	var cost_so_far: Dictionary = {}
	came_from[start] = null  # use a sentinel
	cost_so_far[start] = 0

	while frontier.size() > 0:
		# Find lowest-cost hex in frontier
		var current: Vector2i = frontier[0]
		for hex in frontier:
			if cost_so_far[hex] < cost_so_far[current]:
				current = hex

		if current == goal:
			break

		frontier.erase(current)

		for next in get_neighbors(current):
			var move_cost = cells[next].movement_cost
			var new_cost = cost_so_far[current] + move_cost

			if not cost_so_far.has(next) or new_cost < cost_so_far[next]:
				cost_so_far[next] = new_cost
				came_from[next] = current
				if not frontier.has(next):
					frontier.append(next)

	# Reconstruct path
	if not came_from.has(goal):
		return []  # no path

	var path: Array[Vector2i] = []
	var current = goal
	while current != start:
		path.push_front(current)
		current = came_from[current]

	return path

## Hex distance (axial)
static func distance(a: Vector2i, b: Vector2i) -> int:
	var dq = abs(a.x - b.x)
	var dr = abs(a.y - b.y)
	var ds = abs((-a.x - a.y) - (-b.x - b.y))
	return maxi(dq, maxi(dr, ds))

func get_line(from: Vector2i, to: Vector2i) -> Array[Vector2i]:
	"""Get all hexes in a straight line from 'from' to 'to' (for line-of-sight attacks)"""
	var result: Array[Vector2i] = []
	var dist = distance(from, to)
	if dist == 0:
		return result

	for i in range(1, dist + 1):
		var t = float(i) / float(dist)
		var q = lerpf(from.x, to.x, t)
		var r = lerpf(from.y, to.y, t)
		var hex = hex_round(q, r)
		if hex != from and cells.has(hex):
			result.append(hex)

	return result


## ── Cell Data ──

class HexCell:
	var coords: Vector2i
	var terrain: TerrainData.Type = TerrainData.Type.GRASS
	var is_passable: bool = true
	var movement_cost: float = 1.0
	var occupant: Battler = null  # unit currently on this tile
	var is_highlighted: bool = false

	func _init(p_coords: Vector2i) -> void:
		coords = p_coords

	func set_terrain(p_terrain: TerrainData.Type) -> void:
		terrain = p_terrain
		var terrain_data = TerrainData.get_data(terrain)
		is_passable = terrain_data.is_passable
		movement_cost = terrain_data.movement_cost
