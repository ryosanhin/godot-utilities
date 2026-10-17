# テスト補助

`test_helper.gd`は、ヘッドレステスト用のアサーション・失敗記録・終了処理をまとめた補助クラスです。テストの自動検出や実行順の管理は行いません。

## 使い方

例として、次のスクリプトを`tests/example_test.gd`に配置します。

```gdscript
extends SceneTree

const TestHelper := preload("res://tests/supports/test_helper.gd")

var _helper := TestHelper.new(true)


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_helper.change_test_name("加算")
	_helper.assert_equal(1 + 1, 2, "加算結果が一致する")
	await _helper.finish(self, "Example")
```

プロジェクト直下で実行します。

```sh
godot --headless --path . --editor --import
godot --headless --path . --script tests/example_test.gd
```

`godot`は使用環境の実行ファイル名に置き換えてください。

- `TestHelper.new(true)`で成功ログも表示します。`false`では成功ログを省略します。
- 各テストの開始時に`change_test_name()`を呼びます。
- 真偽・等値・非等値・同一性・null・配列・エラー文字列の確認に対応しています。
- `assert_expected_error()`は、渡した文字列または文字列の配列に期待する部分文字列が含まれるかを確認します。Godotのエラーログを自動収集する機能ではありません。
- アサーション失敗は`failures`へ記録し、後続の処理を継続します。
- 最後に`await finish()`を呼びます。1フレーム待機後、記録された失敗がなければ終了コード0、あれば1で終了します。必要な非同期処理は利用側で待機してください。
