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
	ADD_FAILED,
	TRANSITION_PREPARATION_FAILED,
}

const TransitionController := preload("res://transition_management/transition_controller.gd")

@export var _transition_controller: TransitionController
## 交換対象のシーンだけを子に配置する専用ルート。
@export var _main_scene_parent: Node

var is_changing := false


## シーン切り替えに必要なノードの設定と配置を確認する。
func _ready() -> void:
	if _main_scene_parent == null or not _main_scene_parent.is_inside_tree():
		push_error("SceneController の _main_scene_parent にシーンツリー内の専用ルートを設定してください。")
		return
	if _transition_controller == null or not _transition_controller.is_inside_tree():
		push_error("SceneController の _transition_controller にシーンツリー内の演出コントローラーを設定してください。")
		return


func get_current_main_scene_path() -> String:
	if _main_scene_parent.get_child_count() == 0:
		return ""
	var current_main_scene := _main_scene_parent.get_child(0)
	return current_main_scene.scene_file_path


## 専用ルートに指定したシーンが配置されているか。[br]
## [param scene_reference]: シーンのUIDまたはパス
func is_loaded(scene_reference: String) -> bool:
	var scene_path := AsyncResourceLoadRequest.resolve_resource_path(scene_reference)
	if scene_path.is_empty():
		return false

	for scene in _main_scene_parent.get_children():
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
	# 進行中の切り替えと重なる要求を拒否する。
	if is_changing:
		return ChangeResult.BUSY

	# 切り替え先の参照を解決し、現在のシーンと比較する。
	var scene_path := AsyncResourceLoadRequest.resolve_resource_path(scene_reference)
	if scene_path.is_empty():
		return ChangeResult.INVALID_SCENE
	if scene_path == get_current_main_scene_path():
		return ChangeResult.ALREADY_CURRENT

	# 切り替え中として扱い、画面遷移の演出を準備する。
	is_changing = true
	if not await _transition_controller.prepare_async(transition_reference):
		is_changing = false
		return ChangeResult.TRANSITION_PREPARATION_FAILED

	# 切り替えの開始を通知し、画面を覆う。
	scene_change_started.emit(scene_path)
	await _transition_controller.cover_async()

	# 画面を覆っている間にシーンを差し替える。
	var result := await _replace_main_scene_async(scene_path)

	# 差し替えに成功した場合は、画面を戻す前に新シーンの追加を通知する。
	if result == ChangeResult.SUCCESS:
		main_scene_added.emit(scene_path)

	# 差し替えの結果にかかわらず、画面を戻し、演出と入力遮断を片付ける。
	await _transition_controller.reveal_async()
	_transition_controller.finish()
	is_changing = false

	# 片付けを終えたら、成功時は完了を通知し、差し替え結果を返す。
	if result == ChangeResult.SUCCESS:
		scene_change_completed.emit(scene_path)
	return result


## 新シーンを読み込んで差し替え、その結果を返す。[br]
## [param scene_path]: 切り替え先のシーンのパス
func _replace_main_scene_async(scene_path: String) -> ChangeResult:
	# リソースを読み込み、新シーンのノードを生成する。
	var next_scene := await _instantiate_scene_async(scene_path)
	if next_scene == null:
		return ChangeResult.LOAD_FAILED

	# 新シーンを追加できた場合に旧シーンを外す。
	if _try_replace_main_scene(next_scene):
		return ChangeResult.SUCCESS

	# 追加に失敗した場合は、生成したノードが残っていれば解放を予約する。
	if is_instance_valid(next_scene):
		next_scene.queue_free()
	return ChangeResult.ADD_FAILED


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


## 新シーンを専用ルートに追加できた場合、旧シーンを外して解放する。[br]
## [param next_scene]: 切り替え先のノード
func _try_replace_main_scene(next_scene: Node) -> bool:
	var scenes_root := _main_scene_parent
	var former_scenes := scenes_root.get_children()

	# 追加に失敗したときに旧シーンを残せるよう、新シーンの追加を先に確認する。
	scenes_root.add_child(next_scene)
	if not is_instance_valid(next_scene) or next_scene.get_parent() != scenes_root:
		return false

	for former_scene in former_scenes:
		scenes_root.remove_child(former_scene)
		former_scene.queue_free()
	return true
