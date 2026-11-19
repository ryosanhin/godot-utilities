# DependencyInjector

`DependencyInjector` は、登録したサービスインスタンスを、対象の `inject_dependency()` に引数の宣言順で渡す補助クラスです。必要な場所で `DependencyInjector.new()` を呼び出し、ゲーム用やテスト用の登録表を作れます。

## 基本的な使い方

サービスを `class_name` で宣言します。

```gdscript
# game_clock.gd
class_name GameClock
extends RefCounted


## 起動後の経過時間をミリ秒で返す。
func now_msec() -> int:
	return Time.get_ticks_msec()
```

対象は `inject_dependency()` の引数型で必要な依存を宣言します。

```gdscript
# battle_hud.gd
class_name BattleHud
extends Control

var _clock: GameClock


## 時刻の取得に使うサービスを受け取る。[br]
## [param clock]: ゲーム用またはテスト用の時計
func inject_dependency(clock: GameClock) -> void:
	_clock = clock
```

呼び出し側でサービスを登録し、対象に注入します。以下の例では `BattleHud` をルートに持つシーンを生成し、その `_ready()` より前に依存を渡しています。

```gdscript
## 依存を注入してからHUDをツリーに追加する。[br]
## [param hud_scene]: BattleHudをルートに持つシーン
func add_battle_hud(hud_scene: PackedScene) -> void:
	var injector := DependencyInjector.new()
	if not injector.register(GameClock, GameClock.new()):
		push_error(injector.format_error())
		return

	var hud := hud_scene.instantiate()
	if not injector.inject(hud):
		push_error(injector.format_error())
		hud.free()
		return
	add_child(hud)
```

注入のタイミングは呼び出し側が決めます。`inject()` は必要な依存をすべて解決できたときに `inject_dependency()` を一度呼び出します。引数が0個の場合も呼び出します。メソッドが見つからない場合は `false` を返し、エラーコードが `MISSING_INJECTION_METHOD` になります。

## テスト用のモック

基底型を継承したモックを用意します。

```gdscript
# mock_game_clock.gd
class_name MockGameClock
extends GameClock


## テスト用の固定時刻をミリ秒で返す。
func now_msec() -> int:
	return 2500
```

テストごとに Injector を作り、同じ `GameClock` 型にモックを登録します。`BattleHud` の引数宣言はゲーム実行時と共通です。

```gdscript
## HUDにテスト用の時計を注入する。[br]
## [param hud]: テスト対象のHUD
func inject_mock_clock(hud: BattleHud) -> bool:
	var injector := DependencyInjector.new()
	if not injector.register(GameClock, MockGameClock.new()) or not injector.inject(hud):
		push_error(injector.format_error())
		return false
	return true
```

## 登録とインスタンスの寿命

- 1つの登録型につき1インスタンスを登録できます。重複はエラーになります。
- `register(GameClock, MockGameClock.new())` で解決できるのは `GameClock` 型の引数です。`MockGameClock` 型の引数を解決するには、その型で明示的に登録します。引数名は診断に使います。
- `Node` や `RefCounted` など、登録型と同じ型か派生型のスクリプトインスタンスを登録できます。生成と寿命の管理は呼び出し側が担当します。
- `clear()` や Injector 自体の解放で、登録表が保持する参照を手放します。`Node` の破棄は呼び出し側が行い、`RefCounted` は通常の参照カウントに従います。対象が受け取った参照は対象側で管理します。

## エラーの確認

`register()` と `inject()` は成功時に `true`、失敗時に `false` を返します。分岐やテストでは `get_error_code()` が返す `DependencyInjector.ErrorCode` を比較し、ログには `format_error()` を使えます。成功時と `clear()` の直後は `OK` になり、`format_error()` は空文字列を返します。

登録インスタンスと注入対象の引数は、解放済みのオブジェクトを関数内で検出できるように `Variant` 型で受け取ります。登録や注入には有効なスクリプトインスタンスが必要です。

| エラーコード | 発生する条件 |
| --- | --- |
| `INVALID_SERVICE_TYPE` | 登録型が `null`、または `class_name` を持たない |
| `INVALID_INSTANCE` | 登録インスタンスが無効、またはスクリプトを持たない |
| `INCOMPATIBLE_SERVICE_TYPE` | 登録型とインスタンス型に互換性がない |
| `DUPLICATE_REGISTRATION` | 登録型が既に登録されている |
| `INVALID_TARGET` | 注入対象が無効 |
| `MISSING_INJECTION_METHOD` | 対象に `inject_dependency()` がない |
| `UNSUPPORTED_ARGUMENT_TYPE` | 引数型が注入に対応していない |
| `UNREGISTERED_DEPENDENCY` | 引数型の登録がない |
| `FREED_INSTANCE` | 対応する登録インスタンスが解放されている |

## 対応範囲

型解決は `class_name` で宣言されたスクリプトクラスに対応します。型指定のない引数、`Variant`、組み込み型、ネイティブクラス、`class_name` を持たないスクリプトクラスは非対応です。

登録表は Injector ごとに独立します。親子スコープやスコープID、キーや引数名による解決、候補の優先順位解決、AutoLoad 連携、グローバルなサービスロケーター、シーンツリーの走査、対象やサービスの自動検索、エディター拡張、コンストラクタ注入、注釈による指定、自動生成・破棄は対象外です。

## CLIテスト

```sh
godot --headless --path . --import
godot --headless --path . --script tests/dependency_injection/dependency_injector_test.gd
```
