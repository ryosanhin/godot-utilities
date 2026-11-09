extends SceneTree

const TestHelper := preload("res://tests/supports/test_helper.gd")
const FINISH_FIXTURE := "res://tests/supports/test_helper/fixtures/finish.gd"

var _helper := TestHelper.new(true)


## 検査対象と合否判定用のヘルパーを分けて検証を開始する。
func _initialize() -> void:
	_run_tests.call_deferred()


## 比較・失敗記録・終了コードを確認する。
func _run_tests() -> void:
	_test_incompatible_types()
	_test_comparison_rules()
	_test_identity()
	_test_finish()
	await _helper.finish(self, "test_helper")


## 比較不能な型の失敗を記録し、次のアサーションへ進める。
func _test_incompatible_types() -> void:
	_helper.change_test_name("incompatible_types")
	var subject := TestHelper.new(false)
	subject.change_test_name("比較不能")
	subject.assert_equal(1, "1", "数値と文字列")
	_helper.assert_equal(subject.failures.size(), 1, "比較不能な等値比較は1件だけ失敗する")
	if subject.failures.size() == 1:
		_helper.assert_equal(
				subject.failures[0],
				'[FAIL] 比較不能: 数値と文字列\n  expected: "1"\n  actual: 1',
				"テスト名・メッセージ・期待値・実際の値を記録する",
		)
	subject.assert_not_equal(1, "1", "比較不能な非等値比較は成功する")
	subject.assert_equal(2, 2, "失敗後も比較を続ける")
	_helper.assert_equal(subject.failures.size(), 1, "後続のアサーションへ進める")


## 通常の比較、異なる型の許可範囲、コンテナーの内容比較を確認する。
func _test_comparison_rules() -> void:
	_helper.change_test_name("comparison_rules")
	var subject := TestHelper.new(false)
	var equal_pairs: Array = [
		[1, 1], ["value", "value"], [true, true],
		[1, 1.0], [1.0, 1], ["value", &"value"], [&"value", "value"],
		[null, null], [Vector2.ONE, Vector2.ONE],
		[[1, {"value": 2}], [1, {"value": 2}]],
		[{"value": [1]}, {"value": [1]}],
		[PackedInt32Array([1, 2]), PackedInt32Array([1, 2])],
	]
	var unequal_pairs: Array = [
		[1, 2], ["a", "b"], [true, false], [1, 2.0],
		["a", &"b"], [&"a", "b"], ["1", 1], [true, 1],
		[null, 0], ["", null], [null, []], [{}, null],
		[[1], [2]], [[1], ["1"]], [{"a": 1}, {"a": "1"}],
		[[1], PackedInt32Array([1])],
	]
	for pair: Array in equal_pairs:
		subject.assert_equal(pair[0], pair[1], "等しい値")
	for pair: Array in unequal_pairs:
		subject.assert_not_equal(pair[0], pair[1], "異なる値")
	_helper.assert_array(subject.failures, [], "既存の値比較と型の区別を維持する")

	# 同じ型でも、期待と逆の結果なら失敗を記録する。
	subject.assert_equal(1, 2, "通常の等値比較の失敗")
	subject.assert_not_equal(1, 1, "通常の非等値比較の失敗")
	_helper.assert_equal(subject.failures.size(), 2, "通常の比較失敗も記録する")

	# assert_arrayは配列型の確認後に内容比較し、assert_nullはnullと比較する。
	var related := TestHelper.new(false)
	related.assert_array(PackedInt32Array([1]), [1], "PackedArrayを配列として比較する")
	related.assert_null(null, "nullを比較する")
	related.assert_array(1, [1], "配列以外は失敗する")
	related.assert_array([1], ["1"], "要素の型が異なる配列は失敗する")
	related.assert_null(1, "null以外は失敗する")
	_helper.assert_equal(related.failures.size(), 3, "関連アサーションも中断せず記録する")


## 値が等しい別の配列・辞書と、同じ参照を区別する。
func _test_identity() -> void:
	_helper.change_test_name("identity")
	var subject := TestHelper.new(false)
	var array: Array = [1]
	var dictionary: Dictionary = {"value": 1}
	subject.assert_equal(array, array.duplicate(), "別配列の内容は等しい")
	subject.assert_equal(dictionary, dictionary.duplicate(), "別辞書の内容は等しい")
	subject.assert_same(array, array, "同じ配列の参照")
	subject.assert_same(dictionary, dictionary, "同じ辞書の参照")
	var object := RefCounted.new()
	var other_object := RefCounted.new()
	subject.assert_equal(object, object, "同じObjectは等しい")
	subject.assert_same(object, object, "同じObjectの参照")
	subject.assert_not_equal(object, other_object, "別Objectは等しくない")
	subject.assert_not_equal(object, null, "Objectはnullと異なる")
	subject.assert_not_equal(null, object, "nullはObjectと異なる")
	_helper.assert_array(subject.failures, [], "値の等値と同一参照の成功を維持する")
	subject.assert_same(array, array.duplicate(), "内容が同じでも別配列")
	subject.assert_same(dictionary, dictionary.duplicate(), "内容が同じでも別辞書")
	subject.assert_same(object, other_object, "別Object")
	_helper.assert_equal(subject.failures.size(), 3, "assert_sameは別の参照を拒否する")


## 小さなfixtureを別プロセスで実行し、終了コードとログを個別に確認する。
func _test_finish() -> void:
	_helper.change_test_name("finish")
	for mode: String in ["success", "failure"]:
		var output: Array = []
		var exit_code := OS.execute(
				OS.get_executable_path(),
				["--headless", "--path", ProjectSettings.globalize_path("res://"),
				"--script", FINISH_FIXTURE, "--", mode],
				output,
				true,
		)
		var log_text := "\n".join(output)
		var expected_code := 1 if mode == "failure" else 0
		_helper.assert_equal(exit_code, expected_code, "%sの終了コード" % mode)
		_helper.assert_false("SCRIPT ERROR" in log_text, "%sで実行時エラーが出ない" % mode)
		_helper.assert_true("after_assertions" in log_text, "%sで後続処理へ進む" % mode)
		if mode == "failure":
			_helper.assert_true('[FAIL] finish_fixture: incompatible' in log_text, "失敗内容を出力する")
			_helper.assert_false("tests passed" in log_text, "失敗を成功と表示しない")
		else:
			_helper.assert_true("finish_fixture tests passed" in log_text, "成功を表示する")
