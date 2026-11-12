extends SceneTree

const TestHelper := preload("res://tests/supports/test_helper.gd")


## ツリーの初期化後に終了処理を検証する。
func _initialize() -> void:
	_run.call_deferred()


## 引数に応じて失敗の有無を切り替え、実際のfinishで終了する。
func _run() -> void:
	var subject := TestHelper.new(false)
	subject.change_test_name("finish_fixture")
	if "failure" in OS.get_cmdline_user_args():
		subject.assert_equal(1, "1", "incompatible")
	subject.assert_not_equal(1, "1", "incompatible_not_equal")
	subject.assert_equal(2, 2, "continue")
	print("after_assertions")
	await subject.finish(self, "finish_fixture")
