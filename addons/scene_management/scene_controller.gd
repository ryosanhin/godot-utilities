extends Node
class_name SceneController

const AsyncResourceLoader := preload("res://addons/async_resource_loading/async_resource_loader.gd")
const TransitionController := preload("transition_management/transition_controller.gd")

## シーン切り替えと画面を覆う演出の開始を通知する。
signal scene_change_started(scene_id: StringName)

## 新シーンの追加とID更新後、画面を戻す演出の前に通知する。
## シーン独自の非同期初期化や受信側の非同期処理の完了は待たない。
signal scene_replaced(scene_id: StringName)

## 画面を戻す演出を含むシーン切り替え全体の完了を通知する。
signal scene_changed(scene_id: StringName)

## シーン切り替え要求の結果。
enum ChangeResult {
	SUCCESS,
	BUSY,
	ALREADY_CURRENT,
	INVALID_SCENE,
	LOAD_FAILED,
}

@export var _scene_registry: SceneRegistry

@export var _transition_controller: TransitionController

## 交換対象のシーンだけを子に配置する専用ルート。
@export var _main_scenes_root: Node

@export_range(0.0, 10.0) var _transition_duration := 1.0

## 外部で専用ルートに配置した初期シーンのID。
@export var init_scene_id: StringName = &""

var current_main_scene_id: StringName = &""

var is_changing := false


func _ready() -> void:
	current_main_scene_id = init_scene_id


## 該当シーンが読み込まれているか[br]
## [param scene_id]: シーンのID
func is_loaded(scene_id: StringName) -> bool:
	var entry := _scene_registry.get_scene_data(scene_id)

	if entry == null or entry.scene_path.is_empty():
		return false

	var scene_path := AsyncResourceLoader.resolve_resource_path(entry.scene_path)
	if scene_path.is_empty():
		return false

	for scene in _main_scenes_root.get_children():
		if scene.scene_file_path == scene_path:
			return true

	return false


## シーンを切り替え、要求の結果を返す。[br]
## awaitで待つと、成功時は演出完了後、読み込み失敗時は復帰後に結果を受け取れる。[br]
## [param scene_id]: シーンのID[br]
## [param transition_id]: 遷移エフェクトのID[br]
## 処理中・現在シーンへの要求・無効な設定では、切り替えずに結果を返す。
func change_main_scene_async(
	scene_id: StringName,
	transition_id: StringName
) -> ChangeResult:
	if is_changing:
		return ChangeResult.BUSY
	if scene_id == current_main_scene_id:
		return ChangeResult.ALREADY_CURRENT

	var entry := _resolve_scene_entry(scene_id)
	if entry == null:
		return ChangeResult.INVALID_SCENE

	is_changing = true
	scene_change_started.emit(scene_id)

	await _transition_controller.fade_in(
		transition_id,
		_transition_duration
	)

	var next_scene := await _instantiate_scene(entry)

	if next_scene == null:
		await _transition_controller.fade_out(
			transition_id,
			_transition_duration
		)

		_reset_change_state()
		return ChangeResult.LOAD_FAILED

	_replace_main_scene(scene_id, next_scene)
	scene_replaced.emit(scene_id)

	await _transition_controller.fade_out(
		transition_id,
		_transition_duration
	)

	_reset_change_state()
	_complete_scene_change(scene_id)
	return ChangeResult.SUCCESS


## シーン切り替えリクエストを検証し、切り替え先のエントリーを返す。
func _resolve_scene_entry(scene_id: StringName) -> SceneEntry:
	var entry := _scene_registry.get_scene_data(scene_id)
	if entry == null:
		return null

	if entry.scene_path.is_empty():
		push_error("切り替え先のシーンのUIDまたはパスが設定されていません")
		return null

	return entry


## シーンをバックグラウンドで読み込み、切り替え先のノードを生成する。[br]
## [param entry]: 切り替え先のシーンのUIDまたはパスを持つエントリー
func _instantiate_scene(entry: SceneEntry) -> Node:
	var request := AsyncResourceLoader.new(
			entry.scene_path,
			get_tree().process_frame,
			"PackedScene",
	)
	if not request.is_completed():
		await request.completed
	if not request.is_successful():
		push_error(request.format_error())
		return null

	var packed_scene := request.resource as PackedScene
	if packed_scene == null:
		push_error("切り替え先のPackedSceneを読み込めませんでした: %s" % entry.scene_path)
		return null

	var next_scene := packed_scene.instantiate()
	if next_scene == null:
		push_error("シーンの生成に失敗しました")

	return next_scene


## 現在のメインシーンを解放し、切り替え先のノードに入れ替える。
func _replace_main_scene(next_scene_id: StringName, next_scene: Node) -> void:
	for current_scene: Node in _main_scenes_root.get_children():
		_main_scenes_root.remove_child(current_scene)
		current_scene.queue_free()

	current_main_scene_id = next_scene_id
	_main_scenes_root.add_child(next_scene)


## シーン切り替えの完了を記録し、通知する。
func _complete_scene_change(scene_id: StringName) -> void:
	scene_changed.emit(scene_id)


## シーン切り替え中の状態を解除する。
func _reset_change_state() -> void:
	is_changing = false
