extends RefCounted
## 1件の非同期読み込み処理と、その完了状態・結果。

## 成功・失敗にかかわらず、結果を確定した後に一度だけ通知する。
signal completed

enum ErrorCode {
	OK,
	INVALID_REFERENCE,
	REQUEST_FAILED,
	LOAD_FAILED,
	INVALID_REQUEST,
}

var error_code: ErrorCode = ErrorCode.OK
var resource: Resource
## 正規化した res:// パス。入力をパスに解決できなかった場合は空文字列。
var resource_path: String:
	get:
		return _resource_path
var request_error: Error = OK

var _resource_path: String
var _unresolved_reference_error: String
var _is_completed := false


## 1件のリクエストを生成し、読み込みを開始する。[br]
## すでに完了している場合もあるため、待機前にis_completed()を確認する。[br]
## [param init_resource_reference]: プロジェクト内のリソースのUID、res:// パス、相対パス、絶対パス[br]
## [param check_requested]: 読み込み中も繰り返し発火する有効なシグナル。
## シグナルの発行元は、読み込みが完了するまで維持すること。[br]
## [param type_hint]: ResourceLoaderへ渡す型のヒント。結果の型を保証するものではない
func _init(
		init_resource_reference: String,
		check_requested: Signal,
		type_hint: String = "",
) -> void:
	_resource_path = resolve_resource_path(init_resource_reference)
	if _resource_path.is_empty():
		error_code = ErrorCode.INVALID_REFERENCE
		_unresolved_reference_error = (
				'リソース参照をプロジェクト内のパスに解決できませんでした: "%s"'
				% init_resource_reference
		)
		_complete()
		return
	_load_resource_async(type_hint, check_requested)


## UIDまたはパスを正規化した res:// パスに変換する。[br]
## プロジェクト内のパスに解決できない場合は空文字列を返す。リソースの存在は確認しない。[br]
## [param uid_or_path]: リソースのUIDまたはパス
static func resolve_resource_path(uid_or_path: String) -> String:
	var path := uid_or_path
	if path.begins_with("uid://"):
		var id := ResourceUID.text_to_id(path)
		if id == ResourceUID.INVALID_ID or not ResourceUID.has_id(id):
			return ""
		path = ResourceUID.get_id_path(id)

	if path.is_empty():
		return ""
	if path.is_relative_path():
		path = "res://" + path

	path = ProjectSettings.localize_path(path.simplify_path())
	if not path.begins_with("res://") or path.trim_prefix("res://").get_slice("/", 0) == "..":
		return ""
	return path


## 読み込みが成功または失敗で完了したか。
func is_completed() -> bool:
	return _is_completed


## 読み込みが完了し、成功したか。
func is_successful() -> bool:
	return _is_completed and error_code == ErrorCode.OK


## 読み込み結果を人間向けの説明文へ変換する。
func format_error() -> String:
	match error_code:
		ErrorCode.OK:
			return ""
		ErrorCode.INVALID_REFERENCE:
			if _resource_path.is_empty():
				return _unresolved_reference_error
			return 'リソースが存在しません: "%s"' % _resource_path
		ErrorCode.REQUEST_FAILED:
			return "読み込み要求に失敗しました: %s (%s)" % [_resource_path, request_error]
		ErrorCode.LOAD_FAILED:
			return "リソースの読み込みに失敗しました: %s" % _resource_path
		ErrorCode.INVALID_REQUEST:
			return "読み込み要求が無効です: %s" % _resource_path

	return "不明なリソース読み込みエラーです。"


## Resourceをバックグラウンドで読み込み、結果を確定する。[br]
## リクエスト生成時に一度だけ呼び出す。[br]
## [param type_hint]: ResourceLoaderへ渡す型のヒント[br]
## [param check_requested]: 読み込み状況の再確認を知らせるシグナル
func _load_resource_async(type_hint: String, check_requested: Signal) -> void:
	if not ResourceLoader.exists(_resource_path):
		error_code = ErrorCode.INVALID_REFERENCE
		_complete()
		return

	request_error = ResourceLoader.load_threaded_request(_resource_path, type_hint)
	if request_error != OK:
		error_code = ErrorCode.REQUEST_FAILED
		_complete()
		return

	while true:
		var status := ResourceLoader.load_threaded_get_status(_resource_path)
		match status:
			ResourceLoader.THREAD_LOAD_LOADED:
				resource = ResourceLoader.load_threaded_get(_resource_path)
				if resource == null:
					error_code = ErrorCode.LOAD_FAILED
				_complete()
				return
			ResourceLoader.THREAD_LOAD_IN_PROGRESS:
				await check_requested
			_:
				if status == ResourceLoader.THREAD_LOAD_FAILED:
					# 完了済みの失敗要求も回収し、ローダー内部の参照を残さない。
					ResourceLoader.load_threaded_get(_resource_path)
				error_code = (
					ErrorCode.LOAD_FAILED
					if status == ResourceLoader.THREAD_LOAD_FAILED
					else ErrorCode.INVALID_REQUEST
				)
				_complete()
				return


## 結果を確定し、完了を通知する。
func _complete() -> void:
	_is_completed = true
	completed.emit()
