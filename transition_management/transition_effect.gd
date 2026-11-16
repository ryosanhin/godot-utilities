extends Control
## 画面を覆う演出と戻す演出を持つシーンのルート。

const COVER := &"cover"
const REVEAL := &"reveal"

## 既定の再生処理で使う、このシーン内のAnimationPlayer。
@export var _animation_player: AnimationPlayer


## 既定の再生処理に必要な設定を検証する。コードで再生する派生スクリプトでは上書きする。
func is_configured() -> bool:
	if _animation_player == null or not is_ancestor_of(_animation_player):
		return false
	if not _animation_player.active or _animation_player.speed_scale <= 0.0:
		return false
	if _animation_player.autoplay != &"":
		return false
	if _animation_player.callback_mode_process == AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL:
		return false

	var node: Node = _animation_player
	while node != self and node.process_mode == Node.PROCESS_MODE_INHERIT:
		node = node.get_parent()
	if node != self and node.process_mode != Node.PROCESS_MODE_ALWAYS:
		return false

	for animation_name: StringName in [COVER, REVEAL]:
		if not _animation_player.has_animation(animation_name):
			return false
		var animation := _animation_player.get_animation(animation_name)
		if animation.loop_mode != Animation.LOOP_NONE:
			return false
		if _animation_player.animation_get_next(animation_name) != &"":
			return false
	return true


## 画面を覆い、覆った状態を保つ。
func cover_async() -> void:
	await _play_async(COVER)


## 覆った画面を表示状態へ戻す。
func reveal_async() -> void:
	await _play_async(REVEAL)


## 指定したアニメーションを再生し、終了を待つ。[br]
## [param animation_name]: 再生するアニメーション名
func _play_async(animation_name: StringName) -> void:
	_animation_player.play(animation_name, 0.0)
	_animation_player.advance(0.0)
	await _animation_player.animation_finished
