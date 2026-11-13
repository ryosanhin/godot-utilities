extends SceneTree

const TestHelper := preload("res://tests/supports/test_helper.gd")
const Loader := preload("res://async_resource_load_request/async_resource_load_request.gd")

const SCENE_UID := "uid://cclwwdo81dta1"
const SCENE_PATH := "res://tests/async_resource_load_request/fixtures/example.tscn"
const MISSING_RESOURCE_PATH := "res://tests/async_resource_load_request/fixtures/missing.tres"

const RESOURCE_PATH := "res://tests/async_resource_load_request/fixtures/example.tres"

var _helper := TestHelper.new(true)


## 実行中のSceneTreeを利用してリソースを読み込めることを確認する。
func _initialize() -> void:
	_test_resolve_resource_path()
	await _test_load()
	await _helper.finish(self, "async_resource_loader")


## 同じリソースを指す入力を同じパスへ正規化し、プロジェクト外のパスを拒否する。
func _test_resolve_resource_path() -> void:
	_helper.change_test_name("resolve_resource_path")
	var equivalent_paths: Array[String] = [
		SCENE_UID,
		SCENE_PATH,
		SCENE_PATH.trim_prefix("res://"),
		SCENE_PATH.get_base_dir().path_join("./example.tscn"),
		ProjectSettings.globalize_path(SCENE_PATH),
	]
	for path in equivalent_paths:
		_helper.assert_equal(
				Loader.resolve_resource_path(path),
				SCENE_PATH,
				"同じリソースのパスに解決する (%s)" % path,
		)
	_helper.assert_equal(Loader.resolve_resource_path("user://example.tres"), "", "user:// は対象外")
	_helper.assert_equal(
			Loader.resolve_resource_path("res://fixtures/../../example.tres"),
			"",
			"プロジェクトのルートより上を指すパスは対象外",
	)
	var external_path := ProjectSettings.globalize_path("res://").path_join("../example.tres")
	_helper.assert_equal(
			Loader.resolve_resource_path(external_path),
			"",
			"プロジェクト外の絶対パスは対象外",
	)


## シーンとResourceの読み込み、および失敗時の結果を確認する。
func _test_load() -> void:
	_helper.change_test_name("async_resource_loader")

	# シーンの読み込み
	var scene := Loader.new(SCENE_UID, "PackedScene")
	await _wait_for_request(scene)
	_helper.assert_true(scene.resource is PackedScene, "UIDからPackedSceneを取得できる")
	_helper.assert_true(scene.is_successful(), "読み込み成功を判別できる")
	_helper.assert_equal(scene.error_code, Loader.ErrorCode.OK, "成功コードを返す")
	_helper.assert_equal(scene.resource_path, SCENE_PATH, "解決した res:// パスを保持する")

	# 存在しないUIDを指定したとき
	var invalid := Loader.new("uid://invalid")
	await _wait_for_request(invalid)
	_helper.assert_equal(
			invalid.error_code,
			Loader.ErrorCode.INVALID_REFERENCE,
			"無効なUIDは参照エラーとして返す",
	)
	_helper.assert_equal(invalid.resource_path, "", "解決できない場合はパスを持たない")
	_helper.assert_true(invalid.format_error().contains("uid://invalid"), "エラー説明に元のUIDを含める")

	# 存在しないUIDを指定したとき
	var unknown_uid := ResourceUID.create_id()
	var unknown := Loader.new(ResourceUID.id_to_text(unknown_uid))
	await _wait_for_request(unknown)
	_helper.assert_equal(
			unknown.error_code,
			Loader.ErrorCode.INVALID_REFERENCE,
			"未登録のUIDも参照エラーとして返す",
	)

	# シーン以外のResourceの取得
	var resource := Loader.new(RESOURCE_PATH)
	await _wait_for_request(resource)
	_helper.assert_true(resource.resource is Resource, "シーン以外のResourceも取得できる")

	# 存在しないResouceの取得
	var missing := Loader.new(MISSING_RESOURCE_PATH.trim_prefix("res://"))
	await _wait_for_request(missing)
	_helper.assert_equal(
			missing.error_code,
			Loader.ErrorCode.INVALID_REFERENCE,
			"存在しないパスも参照エラーとして返す",
	)
	_helper.assert_false(missing.is_successful(), "失敗結果を判別できる")
	_helper.assert_null(missing.resource, "失敗時はResourceを持たない")
	_helper.assert_equal(
			missing.resource_path,
			MISSING_RESOURCE_PATH,
			"存在しないリソースも正規化したパスを保持する",
	)
	_helper.assert_true(
			missing.format_error().contains(MISSING_RESOURCE_PATH),
			"エラー説明に正規化したパスを含める",
	)

	# 空の参照もエラーとして扱う
	var empty := Loader.new("")
	await _wait_for_request(empty)
	_helper.assert_true(empty.is_completed(), "即時失敗でも完了状態を保持する")
	_helper.assert_equal(empty.error_code, Loader.ErrorCode.INVALID_REFERENCE, "空の参照も参照エラーとして返す")
	
	# 異なる型ヒントを渡した場合
	var failed := Loader.new(
			"res://tests/async_resource_load_request/fixtures/non_scene.tres",
			"PackedScene",
	)
	await _wait_for_request(failed)
	_helper.assert_equal(failed.error_code, Loader.ErrorCode.LOAD_FAILED, "読み込み開始後の失敗をコードで返す")
	_helper.assert_null(failed.resource, "読み込み失敗時もResourceを持たない")


## 完了済みのリクエストも、シグナルを待ち逃さず受け取る。[br]
## [param request]: 完了を待つリクエスト
func _wait_for_request(request: Loader) -> void:
	if not request.is_completed():
		await request.completed
