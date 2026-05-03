class_name HexDrawer extends Node2D

## ── HexGrid Renderer ──
## Draws the hex map, terrain colors, and highlights.

var hex_grid: HexGrid
var hex_size: float = 32.0


func setup(p_grid: HexGrid, p_hex_size: float = 32.0):
	hex_grid = p_grid
	hex_size = p_hex_size
	queue_redraw()


func highlight_hexes(hexes: Array[Vector2i], color: Color = Color.LIGHT_BLUE):
	"""Highlight specific hexes (e.g., movement range, attack range)."""
	for hex in hexes:
		if hex_grid.cells.has(hex):
			hex_grid.cells[hex].is_highlighted = true
	queue_redraw()


func clear_highlights():
	for cell in hex_grid.cells.values():
		cell.is_highlighted = false
	queue_redraw()


func _draw():
	if not hex_grid:
		return

	for hex in hex_grid.cells:
		var cell = hex_grid.cells[hex]
		var center = HexGrid.hex_to_pixel(hex, hex_size)
		var vertices = _get_hex_vertices(center, hex_size)

		# Fill color based on terrain
		var fill_color = _get_terrain_color(cell.terrain)
		if cell.is_highlighted:
			fill_color = fill_color.lerp(Color.WHITE, 0.4)

		draw_colored_polygon(vertices, fill_color)

		# Border
		var border_color = Color.BLACK
		border_color.a = 0.3
		draw_polyline(vertices + [vertices[0]], border_color, 1.0)

		# Occupied hex — draw a ring
		if cell.occupant:
			var ring_color = Color.LIME_GREEN if cell.occupant.owner_id == 0 else Color.ORANGE_RED
			draw_polyline(vertices + [vertices[0]], ring_color, 2.0)


func _get_hex_vertices(center: Vector2, size: float) -> PackedVector2Array:
	var vertices = PackedVector2Array()
	for i in range(6):
		var angle_deg = 60.0 * i - 30.0  # pointy-top hex
		var angle_rad = deg_to_rad(angle_deg)
		vertices.append(center + Vector2(size * cos(angle_rad), size * sin(angle_rad)))
	return vertices


func _get_terrain_color(terrain: TerrainData.Type) -> Color:
	match terrain:
		TerrainData.Type.GRASS:        return Color(0.35, 0.65, 0.25)
		TerrainData.Type.FOREST:       return Color(0.15, 0.45, 0.15)
		TerrainData.Type.MOUNTAIN:     return Color(0.5, 0.45, 0.4)
		TerrainData.Type.SWAMP:        return Color(0.3, 0.4, 0.2)
		TerrainData.Type.WATER:        return Color(0.2, 0.4, 0.9)
		TerrainData.Type.LAVA:         return Color(0.9, 0.3, 0.1)
		TerrainData.Type.SAND:         return Color(0.85, 0.8, 0.5)
		TerrainData.Type.RUINS:        return Color(0.4, 0.35, 0.45)
		TerrainData.Type.MAGIC_CIRCLE: return Color(0.7, 0.5, 0.9)
	return Color.GRAY
