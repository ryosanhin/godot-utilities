extends SceneTree

const TestHelper := preload("res://tests/supports/test_helper.gd")
const Loader := preload("res://async_resource_loading/async_resource_loader.gd")

const SCENE_UID := "uid://cclwwdo81dta1"
const SCENE_PATH := "res://tests/async_resource_loading/async_resource_loader/fixtures/example.tscn"

const RESOURCE_PATH := "res://tests/async_resource_loading/async_resource_loader/fixtures/example.tres"

var _runner := TestHelper.new(true)


## フレーム通知を受け取るリクエストで読み込みを確認する。
func _initialize() -> void:
	await _test_load()
	await _runner.finish(self, "async_resource_loader")


## シーンとResourceの読み込み、および失敗時の結果を確認する。
func _test_load() -> void:
	_runner.change_test_name("async_resource_loader")

	# シーンの読み込み
	var scene := Loader.new(SCENE_UID, process_frame, "PackedScene")
	await _wait_for_request(scene)
	_runner.assert_true(scene.resource is PackedScene, "UIDからPackedSceneを取得できる")
	_runner.assert_true(scene.is_successful(), "読み込み成功を判別できる")
	_runner.assert_equal(scene.error_code, Loader.ErrorCode.OK, "成功コードを返す")
	_runner.assert_equal(
			Loader.resolve_resource_path(SCENE_UID),
			SCENE_PATH,
			"UIDを現在のパスへ解決できる",
	)
	_runner.assert_equal(
			Loader.resolve_resource_path(SCENE_PATH), 
			SCENE_PATH,
			"UIDと通常のパスを同じパスへ統一する",
	)

	# 存在しないUIDを指定したとき
	var invalid := Loader.new("uid://invalid", process_frame)
	await _wait_for_request(invalid)
	_runner.assert_equal(
			invalid.error_code,
			Loader.ErrorCode.INVALID_REFERENCE,
			"無効なUIDは参照エラーとして返す",
	)
	_runner.assert_equal(invalid.resource_reference, "uid://invalid", "失敗したUIDを保持する")

	# 存在しないUIDを指定したとき
	var unknown_uid := ResourceUID.create_id()
	var unknown := Loader.new(ResourceUID.id_to_text(unknown_uid), process_frame)
	await _wait_for_request(unknown)
	_runner.assert_equal(
			unknown.error_code,
			Loader.ErrorCode.INVALID_REFERENCE,
			"未登録のUIDも参照エラーとして返す",
	)

	# シーン以外のResourceの取得
	var resource := Loader.new(RESOURCE_PATH, process_frame)
	await _wait_for_request(resource)
	_runner.assert_true(resource.resource is Resource, "シーン以外のResourceも取得できる")

	# 存在しないResouceの取得
	var missing := Loader.new(
			"res://tests/async_resource_loading/async_resource_loader/fixtures/missing.tres",
			process_frame,
	)
	await _wait_for_request(missing)
	_runner.assert_equal(
			missing.error_code,
			Loader.ErrorCode.INVALID_REFERENCE, 
			"存在しないパスも参照エラーとして返す",
	)
	_runner.assert_false(missing.is_successful(), "失敗結果を判別できる")
	_runner.assert_null(missing.resource, "失敗時はResourceを持たない")
	_runner.assert_equal(
			missing.resource_reference,
			"res://tests/async_resource_loading/async_resource_loader/fixtures/missing.tres",
			"失敗したパスを保持する",
	)

	# 空の参照もエラーとして扱う
	var empty := Loader.new("", process_frame)
	await _wait_for_request(empty)
	_runner.assert_true(empty.is_completed(), "即時失敗でも完了状態を保持する")
	_runner.assert_equal(empty.error_code, Loader.ErrorCode.INVALID_REFERENCE, "空の参照も参照エラーとして返す")
	
	# 異なる型ヒントを渡した場合
	var failed := Loader.new(
			"res://tests/async_resource_loading/async_resource_loader/fixtures/non_scene.tres",
			process_frame,
			"PackedScene",
	)
	await _wait_for_request(failed)
	_runner.assert_equal(failed.error_code, Loader.ErrorCode.LOAD_FAILED, "読み込み開始後の失敗をコードで返す")
	_runner.assert_null(failed.resource, "読み込み失敗時もResourceを持たない")


## 完了済みのリクエストも、シグナルを待ち逃さず受け取る。[br]
## [param request]: 完了を待つリクエスト
func _wait_for_request(request: Loader) -> void:
	if not request.is_completed():
		await request.completed
