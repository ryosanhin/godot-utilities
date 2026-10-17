extends SceneTree

const TestHelper := preload("res://tests/supports/test_helper.gd")
const Loader := preload("res://async_resource_loading/async_resource_loader.gd")

const SCENE_UID := "uid://cclwwdo81dta1"
const SCENE_PATH := "res://tests/async_resource_loading/async_resource_loader/fixtures/example.tscn"

const RESOURCE_PATH := "res://tests/async_resource_loading/async_resource_loader/fixtures/example.tres"

var _runner := TestHelper.new(true)


## フレーム通知を受け取るリクエストで読み込みを確認する。
func _initialize() -> void:
	await _test_parallel_requests()
	await _run_tests()
	await _runner.finish(self, "async_resource_loader")


## シーン以外も読み込めることと、失敗後も新しいリクエストで読み込めることを確認する。
func _run_tests() -> void:
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
			Loader.ErrorCode.RESOURCE_NOT_FOUND,
			"無効なUIDはリソース未検出として返す",
	)
	_runner.assert_equal(invalid.resource_reference, "uid://invalid", "失敗したUIDを保持する")

	# 存在しないUIDを指定したとき
	var unknown_uid := ResourceUID.create_id()
	var unknown := Loader.new(ResourceUID.id_to_text(unknown_uid), process_frame)
	await _wait_for_request(unknown)
	_runner.assert_equal(
			unknown.error_code,
			Loader.ErrorCode.RESOURCE_NOT_FOUND,
			"未登録のUIDも安全に失敗する",
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
			Loader.ErrorCode.RESOURCE_NOT_FOUND, 
			"存在しないパスのエラーコードを返す",
	)
	_runner.assert_false(missing.is_successful(), "失敗結果を判別できる")
	_runner.assert_null(missing.resource, "失敗時はResourceを持たない")
	_runner.assert_equal(
			missing.resource_reference,
			"res://tests/async_resource_loading/async_resource_loader/fixtures/missing.tres",
			"失敗したパスを保持する",
	)

	# 空のパスを区別
	var empty := Loader.new("", process_frame)
	await _wait_for_request(empty)
	_runner.assert_true(empty.is_completed(), "即時失敗でも完了状態を保持する")
	_runner.assert_equal(empty.error_code, Loader.ErrorCode.EMPTY_PATH, "空のパスは未指定として区別する")
	
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


## 同じリソースへの複数要求も、それぞれのリクエストで結果を受け取れる。
func _test_parallel_requests() -> void:
	_runner.change_test_name("parallel_requests")
	var first := Loader.new(SCENE_UID, process_frame, "PackedScene")
	var second := Loader.new(SCENE_PATH, process_frame, "PackedScene")
	var other := Loader.new(RESOURCE_PATH, process_frame)
	_runner.assert_false(is_same(first, second), "同じリソースでも別のリクエストを生成する")
	await _wait_for_request(first)
	await _wait_for_request(second)
	await _wait_for_request(other)
	_runner.assert_true(first.is_successful() and second.is_successful(), "同じリソースへの要求を両方受け取れる")
	_runner.assert_same(first.resource, second.resource, "標準キャッシュの同じResourceを受け取る")
	_runner.assert_true(other.is_successful(), "別リソースへの要求も並行して受け取れる")
	_runner.assert_true(first.is_completed() and second.is_completed() and other.is_completed(), "各リクエストの完了を確認できる")
	_runner.assert_true(first.resource is PackedScene, "リクエスト自身が結果を保持する")
