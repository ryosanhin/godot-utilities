extends SceneTree

const TestHelper := preload("res://tests/supports/test_helper.gd")
const ControllerScene := preload("res://scene_management/scene_controller.tscn")
const TestEffect := preload("fixtures/test_effect.gd")

const SCENE_A_UID := "uid://ckgibjkn1ktgt"
const SCENE_A_PATH := "res://tests/scene_management/scene_controller/fixtures/example.tscn"
const SCENE_B_PATH := "res://tests/scene_management/scene_controller/fixtures/another.tscn"
const NON_SCENE_PATH := "res://tests/scene_management/scene_controller/fixtures/example.tres"
const MISSING_SCENE_PATH := "res://tests/scene_management/scene_controller/fixtures/missing.tscn"
const TEST_EFFECT_PATH := "res://tests/scene_management/scene_controller/fixtures/test_effect.tscn"
const INCOMPLETE_EFFECT_PATH := "res://tests/scene_management/scene_controller/fixtures/incomplete_effect.tscn"
const CIRCLE_FADE_UID := "uid://dsa1axpkvfqo0"

var _helper := TestHelper.new(true)


## ノード追加が可能になってからテストを開始する。
func _initialize() -> void:
	_run_tests.call_deferred()


## シーン差し替えと失敗からの復帰を確認する。
func _run_tests() -> void:
	await _test_scene_replacement()
	await _test_same_scene()
	await _test_transition_preparation_failure()
	await _test_failed_change("", SceneController.ChangeResult.INVALID_SCENE)
	await _test_failed_change(MISSING_SCENE_PATH, SceneController.ChangeResult.LOAD_FAILED)
	await _test_failed_change(NON_SCENE_PATH, SceneController.ChangeResult.LOAD_FAILED)
	await _test_paused_circle_fade()
	await _helper.finish(self, "scene_controller")


## A→B→Aと交換し、各交換で追加・旧シーン解放・現在パス更新を確認する。
func _test_scene_replacement() -> void:
	_helper.change_test_name("scene_replacement")
	var controller := _create_controller()
	var scenes_root := controller._main_scenes_root

	for reference: String in [SCENE_A_UID, SCENE_B_PATH, SCENE_A_PATH]:
		var old_scene := scenes_root.get_child(0) if scenes_root.get_child_count() > 0 else null
		var result := await controller.change_main_scene_async(reference, TEST_EFFECT_PATH)
		_helper.assert_equal(result, SceneController.ChangeResult.SUCCESS, "正常な交換はSUCCESSを返す")
		var expected_path := SCENE_B_PATH if reference == SCENE_B_PATH else SCENE_A_PATH
		_assert_current_scene(controller, expected_path)
		_assert_idle(controller)
		if is_instance_valid(old_scene):
			_helper.assert_null(old_scene.get_parent(), "旧シーンを専用ルートから外す")
		await process_frame
		_helper.assert_false(is_instance_valid(old_scene), "旧シーンを解放する")

	controller.queue_free()
	await process_frame


## 初期シーンと差し替え後のシーンを、UIDとパスで等しく扱うことを確認する。
func _test_same_scene() -> void:
	_helper.change_test_name("same_scene")
	var controller := _create_controller(SCENE_A_PATH)
	_assert_current_scene(controller, SCENE_A_PATH)

	for reference: String in [SCENE_A_UID, SCENE_A_PATH]:
		_helper.assert_true(controller.is_loaded(reference), "初期シーンのパスとUIDを判定できる")
		var result := await controller.change_main_scene_async(reference, MISSING_SCENE_PATH)
		_helper.assert_equal(result, SceneController.ChangeResult.ALREADY_CURRENT, "同一シーンは演出準備前に判定する")

	await controller.change_main_scene_async(SCENE_B_PATH, TEST_EFFECT_PATH)
	await controller.change_main_scene_async(SCENE_A_UID, TEST_EFFECT_PATH)
	var result := await controller.change_main_scene_async(SCENE_A_PATH, TEST_EFFECT_PATH)
	_helper.assert_equal(result, SceneController.ChangeResult.ALREADY_CURRENT, "UIDで切り替えたシーンをパスでも判定する")
	_helper.assert_true(controller.is_loaded(SCENE_A_UID), "差し替え後もUIDで判定できる")
	_helper.assert_false(controller.is_loaded(SCENE_B_PATH), "差し替え前のシーンは読み込まれていない")
	_assert_idle(controller)

	controller.queue_free()
	await process_frame


## 演出の参照・リソース型・ルートの型・設定が不正なら、画面を覆う前に拒否する。
func _test_transition_preparation_failure() -> void:
	_helper.change_test_name("transition_preparation_failure")
	var controller := _create_controller(SCENE_B_PATH)
	var old_scene := controller._main_scenes_root.get_child(0)
	var blocker := controller._transition_controller._input_blocker
	var events: Array[String] = []
	controller.scene_change_started.connect(func(_reference: String) -> void: events.append("started"))
	blocker.child_entered_tree.connect(func(_node: Node) -> void: events.append("mounted"))
	blocker.visibility_changed.connect(func() -> void: events.append("visibility_changed"))

	for effect_reference: String in [
		MISSING_SCENE_PATH, NON_SCENE_PATH, SCENE_A_PATH, INCOMPLETE_EFFECT_PATH,
	]:
		var result := await controller.change_main_scene_async(SCENE_A_UID, effect_reference)
		_helper.assert_equal(
				result,
				SceneController.ChangeResult.TRANSITION_PREPARATION_FAILED,
				"演出の準備失敗を判別できる",
		)
		_helper.assert_same(controller._main_scenes_root.get_child(0), old_scene, "旧シーンを維持する")
		_assert_idle(controller)
	_helper.assert_array(events, [], "不正な演出は配置・表示せず、開始通知も出さない")

	var result := await controller.change_main_scene_async(SCENE_A_UID, TEST_EFFECT_PATH)
	_helper.assert_equal(result, SceneController.ChangeResult.SUCCESS, "有効な演出で再試行できる")
	controller.queue_free()
	await process_frame


## 無効なシーン参照と、演出開始後の失敗で旧シーンを維持して再試行できることを確認する。[br]
## [param scene_reference]: 失敗させるシーンの参照[br]
## [param expected_result]: 想定する失敗結果
func _test_failed_change(scene_reference: String, expected_result: SceneController.ChangeResult) -> void:
	_helper.change_test_name("failed_change (%s)" % scene_reference)
	var controller := _create_controller(SCENE_B_PATH)
	var scenes_root := controller._main_scenes_root
	var old_scene := scenes_root.get_child(0)
	var blocker := controller._transition_controller._input_blocker
	var effects: Array[TestEffect] = []
	var success_events: Array[String] = []
	controller.scene_change_started.connect(
			func(_reference: String) -> void: effects.append(blocker.get_child(0)),
			CONNECT_ONE_SHOT,
	)
	controller.scene_replaced.connect(func(_reference: String) -> void: success_events.append("replaced"))
	controller.scene_changed.connect(func(_reference: String) -> void: success_events.append("changed"))

	var result := await controller.change_main_scene_async(scene_reference, TEST_EFFECT_PATH)
	_helper.assert_equal(result, expected_result, "失敗の種類に応じた結果を返す")
	_assert_current_scene(controller, SCENE_B_PATH)
	_helper.assert_same(scenes_root.get_child(0), old_scene, "失敗時は元のインスタンスを残す")
	_helper.assert_array(success_events, [], "失敗時には成功の通知を出さない")
	_assert_idle(controller)

	if expected_result == SceneController.ChangeResult.LOAD_FAILED:
		_helper.assert_equal(effects.size(), 1, "演出を一度だけ開始する")
		if not effects.is_empty():
			_helper.assert_equal(effects[0].phase, TestEffect.Phase.REVEALED, "同じ演出で画面を戻す")
			_helper.assert_true(effects[0].is_queued_for_deletion(), "演出の解放を予約する")
	else:
		_helper.assert_array(effects, [], "無効な参照では演出を開始しない")

	await process_frame
	_helper.assert_true(is_instance_valid(old_scene), "失敗時は元のシーンを解放しない")
	if not effects.is_empty():
		_helper.assert_false(is_instance_valid(effects[0]), "失敗時も演出を解放する")

	result = await controller.change_main_scene_async(SCENE_A_UID, TEST_EFFECT_PATH)
	_helper.assert_equal(result, SceneController.ChangeResult.SUCCESS, "参照修正後に再試行できる")
	_assert_current_scene(controller, SCENE_A_PATH)
	_assert_idle(controller)
	controller.queue_free()
	await process_frame


## ポーズ中も円形フェードが進み、覆ってから交換し、戻してから完了することを確認する。
func _test_paused_circle_fade() -> void:
	_helper.change_test_name("paused_circle_fade")
	var controller := _create_controller(SCENE_B_PATH)
	var blocker := controller._transition_controller._input_blocker
	var effects: Array[Control] = []
	var events: Array[String] = []
	var results: Array[SceneController.ChangeResult] = []
	controller.scene_change_started.connect(
			func(reference: String) -> void:
				events.append("started")
				_helper.assert_equal(reference, SCENE_A_PATH, "開始通知は正規化したシーン参照を渡す")
				_assert_current_scene(controller, SCENE_B_PATH)
				var effect := blocker.get_child(0) as Control
				effects.append(effect)
				var player := effect.get_node("AnimationPlayer") as AnimationPlayer
				player.animation_started.connect(
						func(animation: StringName) -> void:
							if animation == &"cover":
								_assert_current_scene(controller, SCENE_B_PATH)
								_helper.assert_true(blocker.visible, "画面を覆い始める時点で入力遮断を表示する")
				)
	)
	controller.scene_replaced.connect(
			func(reference: String) -> void:
				events.append("replaced")
				_helper.assert_equal(reference, SCENE_A_PATH, "差し替え通知は正規化したシーン参照を渡す")
				_assert_current_scene(controller, SCENE_A_PATH)
				_helper.assert_true(blocker.visible, "差し替え時は入力遮断を維持する")
				_helper.assert_same(blocker.get_child(0), effects[0], "同じ円形フェードのインスタンスを使う")
				_helper.assert_equal(_get_circle_fade_value(effects[0]), 1.0, "画面を完全に覆った後で差し替える")
	)
	controller.scene_changed.connect(
			func(reference: String) -> void:
				events.append("changed")
				_helper.assert_equal(reference, SCENE_A_PATH, "完了通知は正規化したシーン参照を渡す")
				_helper.assert_equal(_get_circle_fade_value(effects[0]), 0.0, "画面を戻した後で完了を通知する")
				_assert_idle(controller)
	)

	paused = true
	_record_circle_change_async(controller, results)
	_helper.assert_true(controller.is_changing, "演出準備の待機前に処理中になる")
	var busy_result := await controller.change_main_scene_async(SCENE_A_UID, TEST_EFFECT_PATH)
	_helper.assert_equal(busy_result, SceneController.ChangeResult.BUSY, "並行要求にBUSYを返す")
	while results.is_empty():
		await process_frame
	_helper.assert_array(results, [SceneController.ChangeResult.SUCCESS], "ポーズ中も切り替えが完了する")
	_helper.assert_array(events, ["started", "replaced", "changed"], "差し替えの順序を保つ")
	_helper.assert_true(paused, "呼び出し元のポーズ状態を維持する")

	paused = false
	controller.queue_free()
	await process_frame


## 並行要求を検証できるよう、円形フェードの結果を配列へ記録する。[br]
## [param controller]: 検証対象[br]
## [param results]: 完了結果を追加する配列
func _record_circle_change_async(
		controller: SceneController,
		results: Array[SceneController.ChangeResult],
) -> void:
	var result := await controller.change_main_scene_async(SCENE_A_UID, CIRCLE_FADE_UID)
	results.append(result)


## 円形フェードのシェーダーを駆動するアニメーションの値を返す。[br]
## [param effect]: 円形フェードのルート
func _get_circle_fade_value(effect: Control) -> float:
	var rect := effect.get_node("ColorRect") as ColorRect
	return (rect.material as ShaderMaterial).get_shader_parameter(&"Value")


## 専用ルートを設定したコントローラーをツリーへ追加する。[br]
## [param initial_scene_path]: 専用ルートへ事前に配置する初期シーンのパス
func _create_controller(initial_scene_path := "") -> SceneController:
	var controller: SceneController = ControllerScene.instantiate()
	var scenes_root := Node.new()
	controller.add_child(scenes_root)
	if not initial_scene_path.is_empty():
		var initial_scene := load(initial_scene_path) as PackedScene
		scenes_root.add_child(initial_scene.instantiate())
	controller._main_scenes_root = scenes_root
	root.add_child(controller)
	return controller


## 専用ルートの現在シーンと公開パスが一致しているか確認する。[br]
## [param controller]: 検証対象[br]
## [param scene_path]: 期待するシーンの正規化パス
func _assert_current_scene(controller: SceneController, scene_path: String) -> void:
	_helper.assert_equal(controller.current_main_scene_path, scene_path, "現在シーンの正規化したパスを公開する")
	var scenes_root := controller._main_scenes_root
	_helper.assert_equal(scenes_root.get_child_count(), 1, "専用ルートには現在のシーンだけを置く")
	if scenes_root.get_child_count() == 1:
		_helper.assert_equal(scenes_root.get_child(0).scene_file_path, scene_path, "期待するシーンを配置する")


## 次の要求を処理できる状態に戻っているか確認する。[br]
## [param controller]: 検証対象
func _assert_idle(controller: SceneController) -> void:
	var blocker := controller._transition_controller._input_blocker
	_helper.assert_false(controller.is_changing, "処理中状態を解除する")
	_helper.assert_false(blocker.visible, "入力遮断を解除する")
	_helper.assert_equal(blocker.get_child_count(), 0, "使用した演出をCanvasLayerから外す")
