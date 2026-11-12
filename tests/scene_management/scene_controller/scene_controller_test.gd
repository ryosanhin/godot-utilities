extends SceneTree

const TestHelper := preload("res://tests/supports/test_helper.gd")
const ControllerScene := preload("res://scene_management/scene_controller.tscn")

const SCENE_A_UID := "uid://ckgibjkn1ktgt"
const SCENE_A_PATH := "res://tests/scene_management/scene_controller/fixtures/example.tscn"
const SCENE_B_PATH := "res://tests/scene_management/scene_controller/fixtures/another.tscn"
const NON_SCENE_PATH := "res://tests/scene_management/scene_controller/fixtures/example.tres"
const MISSING_SCENE_PATH := "res://tests/scene_management/scene_controller/fixtures/missing.tscn"
const TRANSITION_ID := &"effect"

var _helper := TestHelper.new(true)


## ノード追加が可能になってからテストを開始する。
func _initialize() -> void:
	call_deferred("_run_tests")


## 正常な繰り返し交換と、失敗時の状態維持・再試行を確認する。
func _run_tests() -> void:
	await _test_scene_replacement()
	await _test_unregistered_scene()
	await _test_missing_scene()
	await _test_non_scene_resource()
	await _helper.finish(self, "scene_controller")


## A→B→Aと交換し、各交換で追加・旧シーン解放・ID更新を確認する。
func _test_scene_replacement() -> void:
	_helper.change_test_name("scene_replacement")
	var registry := SceneRegistry.new()
	var entry_a := SceneEntry.new()
	entry_a.scene_reference = SCENE_A_UID
	registry._data_dict[&"scene_a"] = entry_a
	var entry_b := SceneEntry.new()
	entry_b.scene_reference = SCENE_B_PATH
	registry._data_dict[&"scene_b"] = entry_b
	var controller := _create_controller(registry)
	var scenes_root := controller._main_scenes_root

	for scene_id: StringName in [&"scene_a", &"scene_b", &"scene_a"]:
		var old_scene: Node = scenes_root.get_child(0) if scenes_root.get_child_count() > 0 else null
		var result := await controller.change_main_scene_async(scene_id, TRANSITION_ID)
		_helper.assert_equal(result, SceneController.ChangeResult.SUCCESS, "正常な交換はSUCCESSを返す")
		var expected_path := SCENE_A_PATH if scene_id == &"scene_a" else SCENE_B_PATH
		_assert_current_scene(controller, scene_id, expected_path)
		_helper.assert_false(controller.is_changing, "交換完了後は処理中状態を解除する")
		if is_instance_valid(old_scene):
			_helper.assert_null(old_scene.get_parent(), "旧シーンを専用ルートから外す")
		await process_frame
		_helper.assert_false(is_instance_valid(old_scene), "旧シーンを解放する")

	controller.queue_free()
	await process_frame


## 未登録IDは開始前に拒否し、登録後には同じIDで切り替えられる。
func _test_unregistered_scene() -> void:
	_helper.change_test_name("unregistered_scene")
	await _test_failed_change("", SceneController.ChangeResult.INVALID_SCENE)


## 存在しないパスでの失敗後も、参照を修正して再試行できる。
func _test_missing_scene() -> void:
	_helper.change_test_name("missing_scene")
	await _test_failed_change(MISSING_SCENE_PATH, SceneController.ChangeResult.LOAD_FAILED)


## 実在するシーン以外のResourceを拒否し、参照修正後は再試行できる。
func _test_non_scene_resource() -> void:
	_helper.change_test_name("non_scene_resource")
	var resource := load(NON_SCENE_PATH)
	_helper.assert_true(resource != null and not resource is PackedScene, "失敗用Resourceは実在し、PackedSceneではない")
	await _test_failed_change(NON_SCENE_PATH, SceneController.ChangeResult.LOAD_FAILED)


## 失敗時の状態・通知と、同じコントローラーでの再試行を確認する。[br]
## [param scene_path]: 失敗させる参照。空文字列ではエントリーを登録しない[br]
## [param expected_result]: 想定する失敗結果
func _test_failed_change(
		scene_path: String,
		expected_result: SceneController.ChangeResult,
) -> void:
	var registry := SceneRegistry.new()
	var entry := SceneEntry.new()
	entry.scene_reference = scene_path
	if not scene_path.is_empty():
		registry._data_dict[&"target"] = entry
	var old_scene := Node.new()
	var controller := _create_controller(registry, old_scene)
	var scenes_root := controller._main_scenes_root
	var transition := controller._transition_controller
	var events: Array[StringName] = []
	controller.scene_change_started.connect(func(_id: StringName) -> void: events.append(&"started"))
	controller.scene_replaced.connect(func(_id: StringName) -> void: events.append(&"replaced"))
	controller.scene_changed.connect(func(_id: StringName) -> void: events.append(&"changed"))

	var result := await controller.change_main_scene_async(&"target", TRANSITION_ID)
	_helper.assert_equal(result, expected_result, "失敗の種類に応じた結果を返す")
	_helper.assert_equal(scenes_root.get_child_count(), 1, "失敗時はシーンを追加・除去しない")
	if scenes_root.get_child_count() == 1:
		_helper.assert_same(scenes_root.get_child(0), old_scene, "失敗時は元のシーンを残す")
	_helper.assert_equal(controller.current_main_scene_id, &"initial", "失敗時は現在IDを維持する")
	_helper.assert_false(controller.is_changing, "失敗後は処理中状態を解除する")
	_helper.assert_false(transition._transition_rect.visible, "失敗後は画面を覆う演出を解除する")
	var expected_events: Array[StringName] = []
	if expected_result == SceneController.ChangeResult.LOAD_FAILED:
		expected_events.append(&"started")
	_helper.assert_array(events, expected_events, "未登録IDでは開始せず、いずれの失敗でも成功通知を出さない")
	await process_frame
	_helper.assert_true(is_instance_valid(old_scene), "失敗時は元のシーンを解放しない")

	entry.scene_reference = SCENE_A_UID
	registry._data_dict[&"target"] = entry
	result = await controller.change_main_scene_async(&"target", TRANSITION_ID)
	_helper.assert_equal(result, SceneController.ChangeResult.SUCCESS, "参照修正後の再試行はSUCCESSを返す")
	_assert_current_scene(controller, &"target", SCENE_A_PATH)
	_helper.assert_false(controller.is_changing, "再試行完了後も処理中状態を解除する")
	controller.queue_free()
	await process_frame


## 演出と専用ルートを設定したコントローラーをツリーへ追加する。[br]
## [param registry]: 使用するシーン登録情報[br]
## [param initial_scene]: 専用ルートに配置する初期シーン
func _create_controller(registry: SceneRegistry, initial_scene: Node = null) -> SceneController:
	var controller: SceneController = ControllerScene.instantiate()
	var scenes_root := Node.new()
	controller.add_child(scenes_root)
	if initial_scene != null:
		scenes_root.add_child(initial_scene)
		controller.init_scene_id = &"initial"
	controller._scene_registry = registry
	controller._main_scenes_root = scenes_root
	controller._transition_duration = 0.0
	var transitions := TransitionRegistry.new()
	transitions._entries[TRANSITION_ID] = TransitionEntry.new()
	controller._transition_controller._transition_registry = transitions
	root.add_child(controller)
	return controller


## 指定したシーンだけが専用ルートに追加され、現在IDが更新されたか確認する。[br]
## [param controller]: 確認対象[br]
## [param scene_id]: 期待する現在ID[br]
## [param scene_path]: 期待するシーンファイルのパス
func _assert_current_scene(controller: SceneController, scene_id: StringName, scene_path: String) -> void:
	_helper.assert_equal(controller.current_main_scene_id, scene_id, "現在IDを要求したIDへ更新する")
	var scenes_root := controller._main_scenes_root
	_helper.assert_equal(scenes_root.get_child_count(), 1, "専用ルートには新シーンだけを置く")
	if scenes_root.get_child_count() == 1:
		_helper.assert_equal(scenes_root.get_child(0).scene_file_path, scene_path, "要求したシーンファイルを追加する")
