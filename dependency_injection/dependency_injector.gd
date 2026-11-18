class_name DependencyInjector
extends RefCounted
## 登録したインスタンスを注入対象の引数型に応じて渡す。

enum ErrorCode {
	OK,
	INVALID_SERVICE_TYPE,
	INVALID_INSTANCE,
	INCOMPATIBLE_SERVICE_TYPE,
	DUPLICATE_REGISTRATION,
	INVALID_TARGET,
	MISSING_INJECTION_METHOD,
	UNSUPPORTED_ARGUMENT_TYPE,
	UNREGISTERED_DEPENDENCY,
	FREED_INSTANCE,
}

const MethodReader := preload("method_reader.gd")
const ScriptTypeCompatibility := preload("script_type_compatibility.gd")
const INJECTION_METHOD := &"inject_dependency"

var _instances: Dictionary[Script, Object] = {}
var _method_reader := MethodReader.new(INJECTION_METHOD)
var _error_code: ErrorCode = ErrorCode.OK
var _error_details := ""


## 指定した型にインスタンスを登録する。登録に成功した場合はtrueを返す。[br]
## [param service_type]: class_nameで宣言された登録型[br]
## [param instance]: 登録型と同じ型、または派生型のスクリプトインスタンス
func register(service_type: Script, instance: Variant) -> bool:
	if service_type == null:
		return _fail(ErrorCode.INVALID_SERVICE_TYPE)

	var service_name := service_type.get_global_name()
	if service_name.is_empty():
		return _fail(ErrorCode.INVALID_SERVICE_TYPE, service_type.resource_path)

	if typeof(instance) != TYPE_OBJECT or not is_instance_valid(instance):
		return _fail(ErrorCode.INVALID_INSTANCE, String(service_name))

	var actual_type := instance.get_script() as Script
	if actual_type == null:
		return _fail(ErrorCode.INVALID_INSTANCE, String(service_name))
	if not ScriptTypeCompatibility.is_same_or_derived_from(actual_type, service_type):
		var actual_name := actual_type.get_global_name()
		if actual_name.is_empty():
			actual_name = StringName(actual_type.resource_path)
		return _fail(
				ErrorCode.INCOMPATIBLE_SERVICE_TYPE,
				"登録型 %s、インスタンス型 %s" % [service_name, actual_name],
		)
	if _instances.has(service_type):
		return _fail(ErrorCode.DUPLICATE_REGISTRATION, String(service_name))

	_instances[service_type] = instance
	_reset_error()
	return true


## すべての引数を解決し、宣言順に渡して注入メソッドを一度呼び出す。[br]
## [param target]: inject_dependency()を持つスクリプトインスタンス
func inject(target: Variant) -> bool:
	if typeof(target) != TYPE_OBJECT or not is_instance_valid(target):
		return _fail(ErrorCode.INVALID_TARGET)

	var script := target.get_script() as Script
	var method := Callable(target, INJECTION_METHOD)
	if script == null:
		return _fail(ErrorCode.MISSING_INJECTION_METHOD, target.get_class())

	var method_data := _method_reader.find_injection_method(script)
	if method_data.is_empty() or not method.is_valid():
		return _fail(ErrorCode.MISSING_INJECTION_METHOD, script.resource_path)

	var resolved_arguments: Array[Object] = []
	for argument in _method_reader.get_injection_arguments(method_data):
		var service_type := argument.service_type
		if service_type == null:
			return _fail(ErrorCode.UNSUPPORTED_ARGUMENT_TYPE, String(argument.arg_name))
		if not _instances.has(service_type):
			return _fail(ErrorCode.UNREGISTERED_DEPENDENCY, String(service_type.get_global_name()))

		# 解放済みの値をObject型の変数に代入する前に検証する。
		var instance: Variant = _instances[service_type]
		if not is_instance_valid(instance):
			return _fail(ErrorCode.FREED_INSTANCE, String(service_type.get_global_name()))
		resolved_arguments.append(instance)

	method.callv(resolved_arguments)
	_reset_error()
	return true


## すべての登録参照を手放し、エラー状態を初期化する。
func clear() -> void:
	_instances.clear()
	_reset_error()


## 最後の操作のエラーコードを返す。
func get_error_code() -> ErrorCode:
	return _error_code


## 最後のエラーを日本語で説明する。エラーがなければ空文字列を返す。
func format_error() -> String:
	var message: String
	match _error_code:
		ErrorCode.OK:
			return ""
		ErrorCode.INVALID_SERVICE_TYPE:
			message = "登録型にclass_nameで宣言されたスクリプトを指定してください。"
		ErrorCode.INVALID_INSTANCE:
			message = "登録するインスタンスに有効なスクリプト付きObjectを指定してください。"
		ErrorCode.INCOMPATIBLE_SERVICE_TYPE:
			message = "インスタンスの型が登録型と同じ型でも派生型でもありません。"
		ErrorCode.DUPLICATE_REGISTRATION:
			message = "指定した型は既に登録されています。"
		ErrorCode.INVALID_TARGET:
			message = "注入対象に有効なObjectを指定してください。"
		ErrorCode.MISSING_INJECTION_METHOD:
			message = "注入対象にinject_dependency()がありません。"
		ErrorCode.UNSUPPORTED_ARGUMENT_TYPE:
			message = "inject_dependency()の引数型にはclass_nameで宣言されたスクリプトクラスを指定してください。"
		ErrorCode.UNREGISTERED_DEPENDENCY:
			message = "引数型に対応するインスタンスが登録されていません。"
		ErrorCode.FREED_INSTANCE:
			message = "登録されていたインスタンスは解放済みです。"
		_:
			message = "不明な依存注入エラーです。"

	if _error_details.is_empty():
		return message
	return "%s（%s）" % [message, _error_details]


## 失敗の診断情報を記録してfalseを返す。[br]
## [param error_code]: 失敗を示すエラーコード[br]
## [param details]: 型名や引数名などの補足情報
func _fail(error_code: ErrorCode, details: String = "") -> bool:
	_error_code = error_code
	_error_details = details
	return false


## エラーコードと診断情報を初期化する。
func _reset_error() -> void:
	_error_code = ErrorCode.OK
	_error_details = ""
