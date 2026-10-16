class_name ArenaBattlefieldView
extends Node2D

const ArenaBattlefield = preload("res://scripts/combat/arena_battlefield.gd")

@export var pixels_per_foot: float = 24.0


func _ready() -> void:
	queue_redraw()


func _draw() -> void:
	var battlefield := ArenaBattlefield.create_task16_test_arena()
	var bounds := _rect_microfeet_to_pixels(battlefield.bounds_microfeet)
	draw_rect(bounds, Color(0.09, 0.16, 0.13, 1.0), true)
	draw_rect(bounds, Color(0.36, 0.68, 0.5, 1.0), false, 3.0)
	for obstacle: Dictionary in battlefield.get_obstacles():
		var obstacle_rect := _rect_microfeet_to_pixels(obstacle["rect_microfeet"])
		draw_rect(obstacle_rect, Color(0.22, 0.24, 0.28, 1.0), true)
		draw_rect(obstacle_rect, Color(0.65, 0.68, 0.72, 1.0), false, 2.0)
		draw_string(ThemeDB.fallback_font, obstacle_rect.position + Vector2(0.0, 18.0), "WALL", HORIZONTAL_ALIGNMENT_CENTER, obstacle_rect.size.x, 11, Color(0.9, 0.92, 0.95, 0.9))
	for hazard: Dictionary in battlefield.get_hazards():
		var hazard_rect := _rect_microfeet_to_pixels(hazard["rect_microfeet"])
		draw_rect(hazard_rect, Color(0.55, 0.2, 0.08, 0.48), true)
		draw_rect(hazard_rect, Color(0.9, 0.45, 0.16, 0.8), false, 2.0)
		draw_string(ThemeDB.fallback_font, hazard_rect.position + Vector2(0.0, 18.0), "WALKABLE DODGE TEST", HORIZONTAL_ALIGNMENT_CENTER, hazard_rect.size.x, 9, Color(1.0, 0.84, 0.64, 0.95))


func get_geometry_legend_for_testing() -> Dictionary:
	return {
		"center_wall": "blocks movement and line of sight",
		"non_damaging_test_hazard_zone": "walkable; Dodge hazard tier only",
	}


func _rect_microfeet_to_pixels(value: Rect2i) -> Rect2:
	var scale := pixels_per_foot / float(ArenaBattlefield.MICROFEET_PER_FOOT)
	return Rect2(Vector2(value.position) * scale, Vector2(value.size) * scale)
