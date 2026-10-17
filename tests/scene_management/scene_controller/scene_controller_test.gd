extends SceneTree

const TestHelper := preload("res://tests/supports/test_helper.gd")
const NEXT_SCENE_UID := "uid://ckgibjkn1ktgt"
const NEXT_SCENE_PATH := "res://tests/scene_management/scene_controller/fixtures/example.tscn"

const ControllerScene := preload("res://scene_management/scene_controller.tscn")

var _helper := TestHelper.new(true)


## 任意のIDでのシーン交換と、暗転中・演出終了後の通知を確認する。
func _initialize() -> void:
	call_deferred("_run_tests")


## ノード追加が可能になってからテストを開始する。
func _run_tests() -> void:
	await _test_scene_replacement()
	await _test_loading_failure()
	await _helper.finish(self, "scene_controller")


## 交換完了時の状態、通知順序、および連続要求の抑制を確認する。
func _test_scene_replacement() -> void:
	_helper.change_test_name("scene_replacement")
	var controller: SceneController = ControllerScene.instantiate()
	var scenes_root := Node.new()
	var old_scene := Node.new()
	scenes_root.add_child(old_scene)
	root.add_child(scenes_root)

	var entry := SceneEntry.new()
	entry.scene_path = NEXT_SCENE_UID
	var registry := SceneRegistry.new()
	registry._data_dict[&"other_project_level"] = entry

	var transitions := TransitionRegistry.new()
	transitions._entries[&"other_project_effect"] = TransitionEntry.new()
	var transition := controller.get_node("TransitionController")
	transition._transition_registry = transitions
	controller._scene_registry = registry
	controller._main_scenes_root = scenes_root
	controller.init_scene_id = &"initial_level"
	controller._transition_duration = 0.05

	var events: Array[StringName] = []
	controller.scene_change_started.connect(func(id: StringName) -> void:
		events.append(&"started")
		_helper.assert_equal(id, &"other_project_level", "開始通知に要求IDを渡す")
		_helper.assert_same(scenes_root.get_child(0), old_scene, "開始時には旧シーンが残る")
		var busy_result := await controller.change_main_scene_async(id, &"other_project_effect")
		_helper.assert_equal(busy_result, SceneController.ChangeResult.BUSY, "処理中の要求はBUSYを返す")
	)
	controller.scene_replaced.connect(func(id: StringName) -> void:
		events.append(&"replaced")
		_helper.assert_equal(id, &"other_project_level", "交換通知に要求IDを渡す")
		_helper.assert_equal(controller.current_main_scene_id, id, "交換通知前に現在IDを更新する")
		_helper.assert_equal(scenes_root.get_child_count(), 1, "専用ルートには新シーンだけを置く")
		_helper.assert_equal(scenes_root.get_child(0).name, &"NextScene", "新シーンが追加済みである")
		_helper.assert_true(controller.is_loaded(id), "UIDで追加済みシーンを判定できる")
		_helper.assert_true(controller.is_changing, "交換通知時には遷移中である")
		_helper.assert_true(transition._transition_rect.visible, "交換通知時には画面を覆っている")
		_helper.assert_equal(transition._material.get_shader_parameter(&"Value"), 1.0, "画面を戻す演出は未開始である")
	)
	controller.scene_changed.connect(func(id: StringName) -> void:
		events.append(&"changed")
		_helper.assert_equal(id, &"other_project_level", "完了通知に要求IDを渡す")
		_helper.assert_false(controller.is_changing, "完了通知時には遷移中状態を解除する")
		_helper.assert_false(transition._transition_rect.visible, "完了通知時には画面を戻している")
	)
	root.add_child(controller)
	_helper.assert_equal(controller.current_main_scene_id, &"initial_level", "外部指定の初期IDを使用する")

	var result := await controller.change_main_scene_async(&"other_project_level", &"other_project_effect")
	_helper.assert_equal(result, SceneController.ChangeResult.SUCCESS, "演出完了後にSUCCESSを返す")
	_helper.assert_false(controller.is_changing, "結果を返す前に遷移中状態を解除する")
	_helper.assert_false(transition._transition_rect.visible, "結果を返す前に画面を戻す")
	_helper.assert_array(events, [&"started", &"replaced", &"changed"], "通知順序を守り、重複要求を拒否する")
	entry.scene_path = NEXT_SCENE_PATH
	_helper.assert_true(controller.is_loaded(&"other_project_level"), "通常のパスでも同じ追加済みシーンを判定できる")
	entry.scene_path = "uid://invalid"
	_helper.assert_false(controller.is_loaded(&"other_project_level"), "無効なUIDを追加済みと判定しない")
	entry.scene_path = NEXT_SCENE_UID
	result = await controller.change_main_scene_async(&"other_project_level", &"other_project_effect")
	_helper.assert_equal(result, SceneController.ChangeResult.ALREADY_CURRENT, "現在のシーンへの要求を区別する")
	_helper.assert_equal(events.size(), 3, "現在のシーンへの再要求では通知しない")
	controller.queue_free()
	scenes_root.queue_free()
	await process_frame


## 読み込めないシーンや型の違うResourceでは旧シーンとIDを維持する。
func _test_loading_failure() -> void:
	_helper.change_test_name("loading_failure")
	var controller: SceneController = ControllerScene.instantiate()
	var scenes_root := Node.new()
	var old_scene := Node.new()
	scenes_root.add_child(old_scene)
	root.add_child(scenes_root)
	var registry := SceneRegistry.new()
	var entry := SceneEntry.new()
	registry._data_dict[&"failed_level"] = entry
	controller._scene_registry = registry
	controller._main_scenes_root = scenes_root
	controller.init_scene_id = &"initial_level"
	controller._transition_duration = 0.0
	var transition := controller.get_node("TransitionController")
	var transitions := TransitionRegistry.new()
	transitions._entries[&"effect"] = TransitionEntry.new()
	transition._transition_registry = transitions
	var started := [0]
	controller.scene_change_started.connect(func(_id: StringName) -> void: started[0] += 1)
	var completed := [0]
	controller.scene_replaced.connect(func(_id: StringName) -> void: completed[0] += 1)
	controller.scene_changed.connect(func(_id: StringName) -> void: completed[0] += 1)
	root.add_child(controller)

	var result := await controller.change_main_scene_async(&"unregistered_level", &"effect")
	_helper.assert_equal(result, SceneController.ChangeResult.INVALID_SCENE, "未登録のIDはINVALID_SCENEを返す")
	result = await controller.change_main_scene_async(&"failed_level", &"effect")
	_helper.assert_equal(result, SceneController.ChangeResult.INVALID_SCENE, "未設定の参照はINVALID_SCENEを返す")
	_helper.assert_equal(started[0], 0, "無効な設定では遷移を開始しない")
	_helper.assert_false(controller.is_changing, "無効な設定では遷移中にならない")
	_helper.assert_same(scenes_root.get_child(0), old_scene, "無効な設定では旧シーンを残す")

	for path: String in [
		"uid://invalid",
		"res://tests/scene_controller/fixtures/missing.tscn",
		"res://tests/resource_loading/example.tres",
	]:
		entry.scene_path = path
		result = await controller.change_main_scene_async(&"failed_level", &"effect")
		_helper.assert_equal(result, SceneController.ChangeResult.LOAD_FAILED, "読み込み失敗はLOAD_FAILEDを返す")
		_helper.assert_same(scenes_root.get_child(0), old_scene, "失敗時は旧シーンを残す")
		_helper.assert_equal(controller.current_main_scene_id, &"initial_level", "失敗時は現在IDを維持する")
		_helper.assert_false(controller.is_changing, "失敗時も遷移中状態を解除する")
		_helper.assert_false(transition._transition_rect.visible, "失敗時も画面を戻す")
	_helper.assert_equal(completed[0], 0, "失敗時は交換・全体完了を通知しない")
	entry.scene_path = NEXT_SCENE_UID
	result = await controller.change_main_scene_async(&"failed_level", &"effect")
	_helper.assert_equal(result, SceneController.ChangeResult.SUCCESS, "失敗後の再試行も成功結果を返す")
	_helper.assert_equal(controller.current_main_scene_id, &"failed_level", "失敗後に正しいUIDで再試行できる")
	controller.queue_free()
	scenes_root.queue_free()
	await process_frame
