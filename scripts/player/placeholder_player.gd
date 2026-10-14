class_name PlaceholderPlayer
extends CharacterBody2D

# Temporary visual-test speed only. This is not an ITank MR conversion.
const PLACEHOLDER_SPEED_PX_PER_SECOND: float = 240.0
const HALF_SIZE: float = 16.0


func _physics_process(_delta: float) -> void:
	var direction := Vector2.ZERO
	direction.x = float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A))
	direction.y = float(Input.is_physical_key_pressed(KEY_S)) - float(Input.is_physical_key_pressed(KEY_W))
	velocity = direction.normalized() * PLACEHOLDER_SPEED_PX_PER_SECOND
	move_and_slide()
	_keep_inside_viewport()


func _keep_inside_viewport() -> void:
	var viewport_size := get_viewport_rect().size
	position.x = clampf(position.x, HALF_SIZE, viewport_size.x - HALF_SIZE)
	position.y = clampf(position.y, HALF_SIZE, viewport_size.y - HALF_SIZE)
