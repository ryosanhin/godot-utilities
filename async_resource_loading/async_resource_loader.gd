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
## 呼び出し元が指定したUIDまたはパス。エラー説明に利用する。
var resource_reference: String
var request_error: Error = OK

var _is_completed := false


## 1件のリクエストを生成し、読み込みを開始する。[br]
## すでに完了している場合もあるため、待機前にis_completed()を確認する。[br]
## [param init_resource_reference]: 読み込むリソースのUID。通常のリソースパスも指定できる[br]
## [param check_requested]: 読み込み中も繰り返し発火する有効なシグナル。
## シグナルの発行元は、読み込みが完了するまで維持すること。[br]
## [param type_hint]: ResourceLoaderへ渡す型のヒント。結果の型を保証するものではない
func _init(
		init_resource_reference: String,
		check_requested: Signal,
		type_hint: String = "",
) -> void:
	resource_reference = init_resource_reference
	_load_resource_async(
			resolve_resource_path(resource_reference),
			type_hint,
			check_requested,
	)


## UIDを現在のリソースパスへ解決する。通常のパスは整理して返す。[br]
## 解決できないUIDでは空文字列を返し、リソース自体は読み込まない。[br]
## [param uid_or_path]: リソースのUIDまたはパス
static func resolve_resource_path(uid_or_path: String) -> String:
	if uid_or_path.is_empty():
		return ""
	if uid_or_path.begins_with("uid://"):
		var id := ResourceUID.text_to_id(uid_or_path)
		if id == ResourceUID.INVALID_ID or not ResourceUID.has_id(id):
			return ""
		return ResourceUID.get_id_path(id).simplify_path()

	if uid_or_path.is_relative_path():
		return ("res://" + uid_or_path).simplify_path()
	return uid_or_path.simplify_path()


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
			return 'リソース参照が無効、またはリソースが存在しません: "%s"' % resource_reference
		ErrorCode.REQUEST_FAILED:
			return "読み込み要求に失敗しました: %s (%s)" % [resource_reference, request_error]
		ErrorCode.LOAD_FAILED:
			return "リソースの読み込みに失敗しました: %s" % resource_reference
		ErrorCode.INVALID_REQUEST:
			return "読み込み要求が無効です: %s" % resource_reference

	return "不明なリソース読み込みエラーです。"


## Resourceをバックグラウンドで読み込み、結果を確定する。[br]
## リクエスト生成時に一度だけ呼び出す。[br]
## [param resolved_path]: UIDまたはパスから解決した読み込み先[br]
## [param type_hint]: ResourceLoaderへ渡す型のヒント[br]
## [param check_requested]: 読み込み状況の再確認を知らせるシグナル
func _load_resource_async(
	path: String,
	type_hint: String,
	check_requested: Signal
) -> void:
	if path.is_empty() or not ResourceLoader.exists(path):
		error_code = ErrorCode.INVALID_REFERENCE
		_complete()
		return

	request_error = ResourceLoader.load_threaded_request(path, type_hint)
	if request_error != OK:
		error_code = ErrorCode.REQUEST_FAILED
		_complete()
		return

	while true:
		var status := ResourceLoader.load_threaded_get_status(path)
		match status:
			ResourceLoader.THREAD_LOAD_LOADED:
				resource = ResourceLoader.load_threaded_get(path)
				if resource == null:
					error_code = ErrorCode.LOAD_FAILED
				_complete()
				return
			ResourceLoader.THREAD_LOAD_IN_PROGRESS:
				await check_requested
			_:
				if status == ResourceLoader.THREAD_LOAD_FAILED:
					# 完了済みの失敗要求も回収し、ローダー内部の参照を残さない。
					ResourceLoader.load_threaded_get(path)
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
