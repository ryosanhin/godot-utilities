extends RefCounted
## テストヘルパースクリプト

## falseにすると成功したアサーションの表示を省略します。
var _is_verbose := true
## 全テストの終了時にまとめて表示する失敗一覧です。
var failures: PackedStringArray = []

var _current_test_name := "(テスト名未設定)"

## コンストラクタ
## [param init_is_verbose]: 詳細ログを表示するか
func _init(init_is_verbose: bool) -> void:
	_is_verbose = init_is_verbose

func change_test_name(test_name: String) -> void:
	_current_test_name = test_name
	if _is_verbose:
		print(
				"---------------\nStart Test [%s]\n"
				% _current_test_name
		)

## 真であるか。[br]
## [param boolean]: 実際の値[br]
## [param message]: 成功時に表示するメッセージ
func assert_true(
	condition: bool,
	message: String,
) -> void:
	_record(condition, message, true, condition)


## 偽であるか。[br]
## [param boolean]: 実際の値[br]
## [param message]: 成功時に表示するメッセージ
func assert_false(
	condition: bool,
	message: String,
) -> void:
	_record(not condition, message, false, condition)


## 等値であるか。[br]
## [param actual]: 実際の値[br]
## [param expected]: 等しくなって欲しい値[br]
## [param message]: 成功時に表示するメッセージ
func assert_equal(
	actual: Variant,
	expected: Variant,
	message: String,
) -> void:
	_record(actual == expected, message, expected, actual)


## 非等値であるか。[br]
## [param actual]: 実際の値[br]
## [param expected]: 等しくなって欲しくない値[br]
## [param message]: 成功時に表示するメッセージ
func assert_not_equal(
	actual: Variant,
	unexpected: Variant,
	message: String,
) -> void:
	_record(actual != unexpected, message, "not %s" % _inspect(unexpected), actual)


## 同一インスタンスであるか。[br]
## [param actual]: 実際の値[br]
## [param expected]: 想定される値[br]
## [param message]: 成功時に表示するメッセージ
func assert_same(
	actual: Variant,
	expected: Variant,
	message: String,
) -> void:
	_record(is_same(actual, expected), message, expected, actual)

## [param variant] がnullであるか。[br]
## [param variant]: 対象[br]
## [param message]: 成功時に表示するメッセージ
func assert_null(
	variant: Variant,
	message: String,
) -> void:
	_record(variant == null, message, null, variant)


## 指定した配列であるか。[br]
## [param actual]: 実際の値[br]
## [param expected]: 想定される値[br]
## [param message]: 成功時に表示するメッセージ
func assert_array(
	actual: Variant,
	expected: Array,
	message: String,
) -> void:
	var is_array := (
			actual is Array
			or actual is PackedByteArray
			or actual is PackedInt32Array
			or actual is PackedInt64Array
			or actual is PackedFloat32Array
			or actual is PackedFloat64Array
			or actual is PackedStringArray
			or actual is PackedVector2Array
			or actual is PackedVector3Array
			or actual is PackedVector4Array
			or actual is PackedColorArray
	)
	_record(is_array and Array(actual) == expected, message, expected, actual)


## 想定したエラーであるか。[br]
## [param actual]: 実際の値[br]
## [param expected]: 想定される値[br]
## [param message]: 成功時に表示するメッセージ
func assert_expected_error(
	actual_errors: Variant,
	expected_error: String,
	message: String,
) -> void:
	var errors: Array[String] = []

	if actual_errors is String or actual_errors is StringName:
		# 単一の場合
		errors.append(str(actual_errors))
	elif actual_errors is Array or actual_errors is PackedStringArray:
		# 文字などの配列の場合
		for error in actual_errors:
			errors.append(str(error))
	
	# 実際のエラーの中に想定されるエラーが一つでも含まれているか
	var found := errors.any(func(error: String) -> bool: return expected_error in error)

	_record(found, message, expected_error, errors)


func finish(tree: SceneTree, suite_name: String) -> void:
	# 非同期処理が予約した最終フレームまで完了してから結果を集計します。
	await tree.process_frame
	if failures.is_empty():
		print("%s tests passed" % suite_name)
		tree.quit()
		return

	for failure in failures:
		push_error(failure)
	tree.quit(1)


## 記録する。[br]
## [param passed]: 成功したか[br]
## [param message]: 表示メッセージ[br]
## [param expected]: 想定される値[br]
## [param actual]: 実際の値
func _record(passed: bool, message: String, expected: Variant, actual: Variant) -> void:
	if passed:
		if _is_verbose:
			print("[PASS] %s: %s" % [_current_test_name, message])
		return

	failures.append(
			"[FAIL] %s: %s\n  expected: %s\n  actual: %s"
			% [
					_current_test_name,
					message,
					_inspect(expected),
					_inspect(actual)
			],
	)


func _inspect(value: Variant) -> String:
	return var_to_str(value)
