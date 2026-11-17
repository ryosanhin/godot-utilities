extends CanvasLayer
## 画面切り替えごとに演出を準備し、再生中のマウス入力を遮断する。

const TransitionEffect := preload("transition_effect.gd")

@export var _input_blocker: Control

var _effect: TransitionEffect
var _is_preparing := false


## 入力遮断ノードの設定と配置を確認する。
func _ready() -> void:
	if _input_blocker == null or not _input_blocker.is_inside_tree():
		push_error("TransitionController の _input_blocker にシーンツリー内の入力遮断ノードを設定してください。")
		return


## 演出を非同期で読み込み、表示前に構成を検証する。[br]
## [param transition_reference]: 遷移エフェクトのシーンのUIDまたはパス
func prepare_async(transition_reference: String) -> bool:
	if _is_preparing or _effect != null:
		return false

	_is_preparing = true
	_effect = await _instantiate_effect_async(transition_reference)
	_is_preparing = false
	if _effect == null:
		return false

	_input_blocker.add_child(_effect)
	return true


## 入力を遮断し、準備した演出で画面を覆う。
func cover_async() -> void:
	_input_blocker.show()
	await _effect.cover_async()


## 同じ演出インスタンスで画面を表示状態へ戻す。
func reveal_async() -> void:
	await _effect.reveal_async()


## 入力遮断を解除し、この要求で使用した演出を解放する。
func finish() -> void:
	if _effect == null:
		return
	_input_blocker.hide()
	_input_blocker.remove_child(_effect)
	_effect.queue_free()
	_effect = null


## 指定した演出シーンを生成し、再生可能な場合はインスタンスを返す。[br]
## [param transition_reference]: 遷移エフェクトのシーンのUIDまたはパス
func _instantiate_effect_async(transition_reference: String) -> TransitionEffect:
	var request := AsyncResourceLoadRequest.new(transition_reference)
	var loaded_resource := await request.get_resource_async()
	if loaded_resource == null:
		push_error(request.format_error())
		return null

	var packed_scene := loaded_resource as PackedScene
	if packed_scene == null:
		push_error("遷移エフェクトがPackedSceneではありません: %s" % transition_reference)
		return null

	var instance := packed_scene.instantiate()
	if instance == null:
		push_error("遷移エフェクトのシーンを生成できませんでした: %s" % transition_reference)
		return null

	instance.process_mode = Node.PROCESS_MODE_ALWAYS
	var effect := instance as TransitionEffect
	if effect == null or not effect.is_configured():
		instance.free()
		push_error("遷移エフェクトのルートの型または設定が不正です: %s" % transition_reference)
		return null
	return effect
