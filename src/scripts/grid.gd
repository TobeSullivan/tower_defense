extends Node
class_name Grid

# Map dimensions in tiles.
# TRIAL (2026-06-02): halved 40x22 -> 20x11 (same aspect) so the board fits a phone
# screen at a finger-friendly size with NO zoom/scroll (BTD6-style: design for the
# smallest screen, PC scales up). Generated PVE/PVP maps use these; authored campaign
# .tres still bake 40x22. Revert to 40/22 to undo the trial.
const TILE_SIZE := 48
const COLS := 20
const ROWS := 11  # Trial half-size board: 960 x 528 world px

const ORIGIN := Vector2.ZERO  # top-left of grid in world coordinates

static func cell_to_world(cell: Vector2i) -> Vector2:
	return ORIGIN + Vector2(cell.x * TILE_SIZE + TILE_SIZE / 2.0, cell.y * TILE_SIZE + TILE_SIZE / 2.0)

static func world_to_cell(pos: Vector2) -> Vector2i:
	var local := pos - ORIGIN
	return Vector2i(int(floor(local.x / TILE_SIZE)), int(floor(local.y / TILE_SIZE)))

static func in_bounds(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.x < COLS and cell.y >= 0 and cell.y < ROWS
