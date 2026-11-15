# シーン切り替え

`SceneController`は、専用ルートの子シーンを画面演出付きで交換します。切り替え先のシーンと演出の読み込みには[非同期リソース読み込み](../async_resource_load_request/README.md)を使います。

## 設定

1. `scene_management/`と`async_resource_load_request/`をプロジェクト直下へ配置します。
2. `scene_controller.tscn`を、切り替え時にも残るシーンにインスタンス化します。子の`TransitionController`は付属シーンで設定済みです。
3. 交換対象のシーンを子に持つNodeを用意し、`_main_scenes_root`へ設定します。コントローラーは交換対象の配下から外して配置します。
4. 初期シーンがある場合は、起動前に専用ルートの子としてシーンをインスタンス化します。コントローラーは`_ready()`でその`scene_file_path`を取得します。

## 使い方

ゲーム側で参照を定数にまとめると、エディターの補完から指定できます。どちらの引数にも`res://`パスと`uid://`を使えます。

```gdscript
class ScenePaths:
	const MAIN := "res://scenes/main.tscn"


class TransitionPaths:
	const CIRCLE := "uid://dsa1axpkvfqo0"


func open_main_async(controller: SceneController) -> void:
	var result := await controller.change_main_scene_async(
			ScenePaths.MAIN,
			TransitionPaths.CIRCLE,
	)
	if result != SceneController.ChangeResult.SUCCESS:
		print("シーン切り替え結果: ", result)
```

`current_main_scene_path`は現在のシーンの正規化した`res://`パスです。初期シーンを置いていない場合は、最初のシーンを追加するまで空文字列です。`is_loaded(scene_reference)`はUIDまたはパスを受け取り、該当シーンが専用ルートにあるか調べます。

| 戻り値 | 条件 |
| --- | --- |
| `SUCCESS` | 新シーンを追加し、画面を戻し終えた |
| `BUSY` | 別の切り替えを処理中 |
| `ALREADY_CURRENT` | 正規化したパスが現在のシーンと同じ |
| `INVALID_SCENE` | シーン参照をプロジェクト内のパスに解決できないか、専用ルートが未設定 |
| `TRANSITION_PREPARATION_FAILED` | 演出を読み込めないか、演出シーンの型・構成が不正。画面を覆う前に終了する |
| `LOAD_FAILED` | 切り替え先の`PackedScene`を読み込めないか、生成できない。旧シーンを維持し、同じ演出で画面を戻してから結果を返す |

## 通知

すべての通知は、切り替え先の正規化した`res://`パスを引数に取ります。

- `scene_change_started` は演出の準備が完了し、画面を覆う直前に通知します。
- `scene_replaced` は画面を覆った状態で新シーンを追加した後に通知します。シーン独自の非同期初期化や受信側の非同期処理の完了は、必要に応じて利用側で待ちます。
- `scene_changed` は画面を戻し、演出と入力遮断を片付けた後に通知します。

## 演出の作成

付属の円形フェードの調整や独自の演出の作成方法は[画面切り替え演出](transition_management/README.md)を参照してください。
