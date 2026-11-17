extends SceneTree

const TestHelper := preload("res://tests/supports/test_helper.gd")

const SCENE_UID := "uid://cclwwdo81dta1"
const SCENE_PATH := "res://tests/async_resource_load_request/fixtures/example.tscn"
const MISSING_RESOURCE_PATH := "res://tests/async_resource_load_request/fixtures/missing.tres"
const MALFORMED_RESOURCE_PATH := "res://tests/async_resource_load_request/fixtures/malformed.tres"

const RESOURCE_PATH := "res://tests/async_resource_load_request/fixtures/example.tres"

var _helper := TestHelper.new(true)


class PendingResourceLoader extends ResourceFormatLoader:
	const PATH := "res://tests/async_resource_load_request/fixtures/pending_resource.test"

	var load_gate := Semaphore.new()

	## 回帰テスト専用のパスだけを受け付ける。[br]
	## [param path]: 読み込み対象のパス
	func _recognize_path(path: String, _type: StringName) -> bool:
		return path == PATH

	## 専用のパスを仮想リソースとして扱う。[br]
	## [param path]: 確認対象のパス
	func _exists(path: String) -> bool:
		return path == PATH

	## テストが読み込み再開を許可するまでワーカーを待機させる。
	func _load(
			_path: String,
			_original_path: String,
			_use_sub_threads: bool,
			_cache_mode: int,
	) -> Variant:
		load_gate.wait()
		return Resource.new()


class OwnerNode extends Node:
	func wait_for_resource(request: AsyncResourceLoadRequest, resumptions: Array[bool]) -> void:
		await request.get_resource_async()
		resumptions.append(true)


## 実行中のSceneTreeを利用してリソースを読み込めることを確認する。
func _initialize() -> void:
	_test_resolve_resource_path()
	await _test_load()
	await _test_release_pending_request()
	await _test_release_owner_node()
	await _helper.finish(self, "async_resource_load_request")


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
				AsyncResourceLoadRequest.resolve_resource_path(path),
				SCENE_PATH,
				"同じリソースのパスに解決する (%s)" % path,
		)
	_helper.assert_equal(AsyncResourceLoadRequest.resolve_resource_path("user://example.tres"), "", "user:// は対象外")
	_helper.assert_equal(
			AsyncResourceLoadRequest.resolve_resource_path("res://fixtures/../../example.tres"),
			"",
			"プロジェクトのルートより上を指すパスは対象外",
	)
	var external_path := ProjectSettings.globalize_path("res://").path_join("../example.tres")
	_helper.assert_equal(
			AsyncResourceLoadRequest.resolve_resource_path(external_path),
			"",
			"プロジェクト外の絶対パスは対象外",
	)


## シーンとResourceの読み込み、および失敗時の結果を確認する。
func _test_load() -> void:
	_helper.change_test_name("async_resource_load")

	# シーンの読み込み
	var scene := AsyncResourceLoadRequest.new(SCENE_UID)
	var packed_scene := (await scene.get_resource_async()) as PackedScene
	_helper.assert_true(packed_scene != null, "UIDからPackedSceneを取得できる")
	_helper.assert_same(await scene.get_resource_async(), packed_scene, "完了済みなら同じリソースを返す")
	_helper.assert_true(scene.is_successful(), "読み込み成功を判別できる")
	_helper.assert_equal(scene.get_error_code(), AsyncResourceLoadRequest.ErrorCode.OK, "成功コードを返す")
	_helper.assert_equal(scene.resource_path, SCENE_PATH, "解決した res:// パスを保持する")

	# 存在しないUIDを指定したとき
	var invalid := AsyncResourceLoadRequest.new("uid://invalid")
	_helper.assert_equal(
			invalid.get_error_code(),
			AsyncResourceLoadRequest.ErrorCode.INVALID_REFERENCE,
			"無効なUIDは参照エラーとして返す",
	)
	_helper.assert_equal(invalid.resource_path, "", "解決できない場合はパスを持たない")
	_helper.assert_true(invalid.format_error().contains("uid://invalid"), "エラー説明に元のUIDを含める")

	# 存在しないUIDを指定したとき
	var unknown_uid := ResourceUID.create_id()
	var unknown := AsyncResourceLoadRequest.new(ResourceUID.id_to_text(unknown_uid))
	_helper.assert_equal(
			unknown.get_error_code(),
			AsyncResourceLoadRequest.ErrorCode.INVALID_REFERENCE,
			"未登録のUIDも参照エラーとして返す",
	)

	# シーン以外のResourceの取得
	var resource_request := AsyncResourceLoadRequest.new(RESOURCE_PATH)
	var non_scene := await resource_request.get_resource_async()
	_helper.assert_true(non_scene != null, "シーン以外のResourceも取得できる")
	_helper.assert_true(resource_request.is_successful(), "シーン以外のResourceも読み込み成功として扱う")
	_helper.assert_null(non_scene as PackedScene, "シーン以外のResourceはPackedSceneにキャストできない")

	# 存在しないResouceの取得
	var missing := AsyncResourceLoadRequest.new(MISSING_RESOURCE_PATH.trim_prefix("res://"))
	_helper.assert_equal(
			missing.get_error_code(),
			AsyncResourceLoadRequest.ErrorCode.INVALID_REFERENCE,
			"存在しないパスも参照エラーとして返す",
	)
	_helper.assert_false(missing.is_successful(), "失敗結果を判別できる")
	_helper.assert_null(missing.get_loaded_resource(), "失敗時はResourceを持たない")
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
	var empty := AsyncResourceLoadRequest.new("")
	_helper.assert_true(empty.is_completed(), "即時失敗でも完了状態を保持する")
	_helper.assert_null(await empty.get_resource_async(), "即時失敗時はnullを返す")
	_helper.assert_equal(empty.get_error_code(), AsyncResourceLoadRequest.ErrorCode.INVALID_REFERENCE, "空の参照も参照エラーとして返す")

	# 構文が壊れたResourceを指定した場合
	var failed := AsyncResourceLoadRequest.new(MALFORMED_RESOURCE_PATH)
	_helper.assert_null(await failed.get_resource_async(), "読み込み失敗時はnullを返す")
	_helper.assert_equal(failed.get_error_code(), AsyncResourceLoadRequest.ErrorCode.LOAD_FAILED, "読み込み開始後の失敗をコードで返す")
	_helper.assert_null(failed.get_loaded_resource(), "読み込み失敗時もResourceを持たない")
	_helper.assert_equal(
			ResourceLoader.load_threaded_get_status(MALFORMED_RESOURCE_PATH),
			ResourceLoader.THREAD_LOAD_INVALID_RESOURCE,
			"読み込みに失敗した要求もGodotから回収する",
	)


## 外部参照を手放した読み込み中の要求も回収され、リクエストが解放されることを確認する。
func _test_release_pending_request() -> void:
	_helper.change_test_name("release_pending_request")
	var format_loader := PendingResourceLoader.new()
	ResourceLoader.add_resource_format_loader(format_loader)
	var path := PendingResourceLoader.PATH
	var request := AsyncResourceLoadRequest.new(path)
	_helper.assert_false(request.is_completed(), "生成直後のリクエストは未完了")
	_helper.assert_equal(
			ResourceLoader.load_threaded_get_status(path),
			ResourceLoader.THREAD_LOAD_IN_PROGRESS,
			"外部参照を手放す時点でGodotの要求は読み込み中",
	)
	var request_ref: WeakRef = weakref(request)
	var completions: Array[bool] = []
	request.completed.connect(func() -> void: completions.append(true))
	request = null

	# 読み込み中の確認を挟み、次のフレームへ参照を引き継がせる。
	await process_frame
	await process_frame
	format_loader.load_gate.post()

	var deadline := Time.get_ticks_msec() + 5000
	var status := ResourceLoader.load_threaded_get_status(path)
	while status != ResourceLoader.THREAD_LOAD_INVALID_RESOURCE and Time.get_ticks_msec() < deadline:
		await process_frame
		status = ResourceLoader.load_threaded_get_status(path)

	# process_frame の発火が終わり、実行済みのラムダが解放されるまで待つ。
	await process_frame

	# タイムアウトでワーカーが動作中なら、終了処理にローダーの解放を任せる。
	if status != ResourceLoader.THREAD_LOAD_IN_PROGRESS:
		ResourceLoader.remove_resource_format_loader(format_loader)
	_helper.assert_equal(status, ResourceLoader.THREAD_LOAD_INVALID_RESOURCE, "Godotに未回収の要求が残らない")
	_helper.assert_equal(completions.size(), 1, "完了を一度だけ通知する")
	_helper.assert_null(request_ref.get_ref(), "回収後にリクエストを解放する")


## 待機中のノードを破棄し、読み込み結果の回収と解放を確認する。
func _test_release_owner_node() -> void:
	_helper.change_test_name("release_owner_node")
	var format_loader := PendingResourceLoader.new()
	ResourceLoader.add_resource_format_loader(format_loader)

	var path := PendingResourceLoader.PATH
	var request := AsyncResourceLoadRequest.new(path)
	var request_ref: WeakRef = weakref(request)
	var resource_refs: Array[WeakRef] = []
	var resumptions: Array[bool] = []

	request.completed.connect(
			func() -> void:
				var finished := request_ref.get_ref() as AsyncResourceLoadRequest
				if finished != null and finished.get_loaded_resource() != null:
					resource_refs.append(weakref(finished.get_loaded_resource())),
			CONNECT_ONE_SHOT,
	)

	var node := OwnerNode.new()
	root.add_child(node)
	node.wait_for_resource(request, resumptions)
	_helper.assert_equal(
			ResourceLoader.load_threaded_get_status(path),
			ResourceLoader.THREAD_LOAD_IN_PROGRESS,
			"ノードを破棄する前は読み込み中",
	)

	request = null
	node.queue_free()
	while is_instance_valid(node):
		await process_frame

	format_loader.load_gate.post()
	var deadline := Time.get_ticks_msec() + 5000
	var status := ResourceLoader.load_threaded_get_status(path)
	while status != ResourceLoader.THREAD_LOAD_INVALID_RESOURCE and Time.get_ticks_msec() < deadline:
		await process_frame
		status = ResourceLoader.load_threaded_get_status(path)

	# 完了を処理したフレームのコールバックが解放されるまで待つ。
	await process_frame

	if status != ResourceLoader.THREAD_LOAD_IN_PROGRESS:
		ResourceLoader.remove_resource_format_loader(format_loader)

	_helper.assert_equal(
			status,
			ResourceLoader.THREAD_LOAD_INVALID_RESOURCE,
			"Godotの要求を回収する",
	)
	_helper.assert_true(resumptions.is_empty(), "破棄済みノードのawait後の処理は実行しない")
	_helper.assert_null(request_ref.get_ref(), "リクエストを解放する")
	_helper.assert_equal(resource_refs.size(), 1, "読み込み結果のResourceを観測できる")
	if resource_refs.size() == 1:
		_helper.assert_null(resource_refs[0].get_ref(), "読み込んだResourceを解放する")
