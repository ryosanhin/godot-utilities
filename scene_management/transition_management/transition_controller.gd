extends CanvasLayer

@export var _transition_registry: TransitionRegistry

@export var _transition_rect: ColorRect

var _material: ShaderMaterial

const VALUE_PARAMETER := &"Value"
const TEXTURE_PARAMETER := &"Texture"


func _ready() -> void:
	var screen_material := _transition_rect.material

	_material = screen_material.duplicate() as ShaderMaterial
	_transition_rect.material = _material

	_set_value(0.0)
	_transition_rect.hide()
	_transition_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE


## 画面を覆う。[br]
## [param transition_id]: 遷移エフェクトのID[br]
## [param duration]: 演出の秒数
func fade_in(
		transition_id: StringName,
		duration: float,
) -> void:
	if not _try_apply_transition(transition_id):
		return

	_transition_rect.show()
	_transition_rect.mouse_filter = Control.MOUSE_FILTER_STOP

	await _animate(0.0, 1.0, duration)


## 画面を表示状態へ戻す。[br]
## [param transition_id]: 遷移エフェクトのID[br]
## [param duration]: 演出の秒数
func fade_out(
		transition_id: StringName,
		duration: float,
) -> void:
	if not _try_apply_transition(transition_id):
		return

	await _animate(1.0, 0.0, duration)

	_transition_rect.hide()
	_transition_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _try_apply_transition(transition_id: StringName) -> bool:
	var entry := _transition_registry.get_entry(transition_id)

	if entry == null:
		return false

	_transition_rect.color = entry.color
	_material.set_shader_parameter(
			TEXTURE_PARAMETER,
			entry.transition_texture,
	)

	return true


func _animate(
		from_value: float,
		to_value: float,
		duration: float
) -> void:
	_set_value(from_value)

	if duration <= 0.0:
		_set_value(to_value)
		return

	var tween := create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_method(
			_set_value,
			from_value,
			to_value,
			duration
	)

	await tween.finished


func _set_value(value: float) -> void:
	_material.set_shader_parameter(
			VALUE_PARAMETER,
			clampf(value, 0.0, 1.0),
	)
