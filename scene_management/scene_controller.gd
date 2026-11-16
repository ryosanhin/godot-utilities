class_name SceneController
extends Node

## 演出の準備が完了し、画面を覆い始める直前に通知する。
signal scene_change_started(scene_reference: String)
## 新シーンを追加した後、画面を戻す演出の前に通知する。
## シーン独自の非同期初期化や受信側の非同期処理の完了は待たない。
signal main_scene_added(scene_reference: String)
## 画面を戻し、演出と入力遮断を片付けた後に通知する。
signal scene_change_completed(scene_reference: String)

## シーン切り替え要求の結果。
enum ChangeResult {
	SUCCESS,
	BUSY,
	ALREADY_CURRENT,
	INVALID_SCENE,
	LOAD_FAILED,
	TRANSITION_PREPARATION_FAILED,
}

const AsyncResourceLoadRequest := preload(
		"res://async_resource_load_request/async_resource_load_request.gd"
)
const TransitionController := preload("transition_management/transition_controller.gd")

@export var _transition_controller: TransitionController
## 交換対象のシーンだけを子に配置する専用ルート。
@export var _main_scenes_root: Node

## 現在のメインシーンの正規化したパス。まだシーンがなければ空文字列。
var current_main_scene_path: String
var is_changing := false


func _ready() -> void:
	if is_instance_valid(_main_scenes_root) and _main_scenes_root.get_child_count() > 0:
		current_main_scene_path = AsyncResourceLoadRequest.resolve_resource_path(
				_main_scenes_root.get_child(0).scene_file_path
		)


## 専用ルートに指定したシーンが配置されているか。[br]
## [param scene_reference]: シーンのUIDまたはパス
func is_loaded(scene_reference: String) -> bool:
	var scene_path := AsyncResourceLoadRequest.resolve_resource_path(scene_reference)
	if scene_path.is_empty() or not is_instance_valid(_main_scenes_root):
		return false

	for scene in _main_scenes_root.get_children():
		if AsyncResourceLoadRequest.resolve_resource_path(scene.scene_file_path) == scene_path:
			return true
	return false


## 演出付きでシーンを切り替え、画面を戻してから結果を返す。[br]
## [param scene_reference]: 切り替え先のシーンのUIDまたはパス[br]
## [param transition_reference]: 遷移エフェクトのシーンのUIDまたはパス
func change_main_scene_async(
		scene_reference: String,
		transition_reference: String,
) -> ChangeResult:
	if is_changing:
		return ChangeResult.BUSY

	var scene_path := AsyncResourceLoadRequest.resolve_resource_path(scene_reference)
	if scene_path.is_empty() or not is_instance_valid(_main_scenes_root):
		return ChangeResult.INVALID_SCENE
	if scene_path == current_main_scene_path:
		return ChangeResult.ALREADY_CURRENT
	if not is_instance_valid(_transition_controller):
		return ChangeResult.TRANSITION_PREPARATION_FAILED

	is_changing = true
	if not await _transition_controller.prepare_async(transition_reference):
		is_changing = false
		return ChangeResult.TRANSITION_PREPARATION_FAILED

	scene_change_started.emit(scene_path)
	await _transition_controller.cover_async()

	var next_scene := await _instantiate_scene_async(scene_path)
	var is_replaceable := next_scene != null
	if is_replaceable:
		_replace_main_scene(scene_path, next_scene)
		main_scene_added.emit(scene_path)

	await _transition_controller.reveal_async()
	_transition_controller.finish()
	is_changing = false

	if not is_replaceable:
		return ChangeResult.LOAD_FAILED
	scene_change_completed.emit(scene_path)
	return ChangeResult.SUCCESS


## シーンをバックグラウンドで読み込み、切り替え先のノードを生成する。[br]
## [param scene_path]: 切り替え先のシーンのパス
func _instantiate_scene_async(scene_path: String) -> Node:
	var request := AsyncResourceLoadRequest.new(scene_path)
	var loaded_resource := await request.get_resource_async()
	if loaded_resource == null:
		push_error(request.format_error())
		return null

	var packed_scene := loaded_resource as PackedScene
	if packed_scene == null:
		push_error("切り替え先がPackedSceneではありません: %s" % scene_path)
		return null

	var next_scene := packed_scene.instantiate()
	if next_scene == null:
		push_error("切り替え先のシーンを生成できませんでした: %s" % scene_path)
	return next_scene


## 旧シーンを専用ルートから外して解放し、新シーンを追加する。[br]
## [param scene_path]: 切り替え先のシーンのパス[br]
## [param next_scene]: 切り替え先のノード
func _replace_main_scene(scene_path: String, next_scene: Node) -> void:
	for current_scene in _main_scenes_root.get_children():
		_main_scenes_root.remove_child(current_scene)
		current_scene.queue_free()

	current_main_scene_path = scene_path
	_main_scenes_root.add_child(next_scene)
