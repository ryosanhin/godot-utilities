extends RefCounted
## スクリプトから注入メソッドを探し、引数情報を取り出す。

const ArgumentEntry := preload("argument_entry.gd")

var _method_name: StringName


## 検索するメソッド名を指定する。[br]
## [param init_method_name]: 注入メソッド名
func _init(init_method_name: StringName) -> void:
	_method_name = init_method_name


## 注入メソッドの情報を返す。見つからない場合は空の辞書を返す。[br]
## [param script]: 注入対象のスクリプト
func find_injection_method(script: Script) -> Dictionary:
	for method_data in script.get_script_method_list():
		if StringName(method_data.get("name", "")) == _method_name:
			return method_data
	return {}


## メソッドの引数情報を宣言順に返す。[br]
## [param method_data]: [method find_injection_method]で取得したメソッド情報
func get_injection_arguments(method_data: Dictionary) -> Array[ArgumentEntry]:
	var arguments: Array[ArgumentEntry] = []

	for argument_data: Dictionary in method_data.get("args", []):
		var arg_name := StringName(argument_data.get("name", ""))
		var arg_class_name := StringName(argument_data.get("class_name", ""))
		var arg_variant_type := int(argument_data.get("type", TYPE_NIL))
		var service_type: Script
		if arg_variant_type == TYPE_OBJECT:
			service_type = _get_global_class_script(arg_class_name)

		arguments.append(ArgumentEntry.new(arg_name, service_type, arg_variant_type))

	return arguments


## グローバルクラス名からスクリプトを取得。[br]
## 存在しない場合は[code]null[/code]を返す。[br]
## [param arg_class_name]: 引数の型情報に含まれるクラス名
func _get_global_class_script(arg_class_name: StringName) -> Script:
	if arg_class_name.is_empty():
		return null

	for class_data in ProjectSettings.get_global_class_list():
		if StringName(class_data["class"]) == arg_class_name:
			return load(class_data["path"]) as Script

	return null
