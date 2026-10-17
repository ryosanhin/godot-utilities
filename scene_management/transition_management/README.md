# 画面切り替え演出

`TransitionController`は、CanvasLayer上のColorRectとシェーダーで画面を覆う・戻す演出を行います。シーン交換処理とは独立して使用できます。

## 設定

1. `transition_controller.tscn`をシーンに配置します。`scene_controller.tscn`を使う場合は、すでに子として配置されています。
2. `TransitionRegistry`を作成し、`_entries`へ演出IDと`TransitionEntry`を登録します。
3. 各Entryの`transition_texture`へマスク画像、`color`へ画面を覆う色を設定します。
4. Registryをコントローラーの`_transition_registry`に設定します。

`_transition_rect`とマテリアルは付属シーンで設定済みです。`assets/`に円形マスク画像`circle_fade.png`と、マテリアル・VisualShaderを配置しています。

## 使い方

以下はNodeのメソッド内での使用例です。`transition`には配置済みのコントローラーを渡します。

```gdscript
const TransitionController := preload(
	"res://scene_management/transition_management/transition_controller.gd"
)


func play_transition_async(transition: TransitionController) -> void:
	await transition.fade_in(&"circle", 0.5)
	# 画面が覆われている間に、シーン交換などを行います。
	await transition.fade_out(&"circle", 0.5)
```

`circle`はRegistryへ事前に登録したIDです。このモジュールでは`fade_in()`が画面を覆う処理、`fade_out()`が画面を戻す処理です。

- 時間が0以下の場合は、アニメーションせず終了状態へ切り替えます。
- 演出中はColorRectでマウス入力を受け止めます。キーボードなども含めた入力制御は利用側で行います。
- 演出IDは事前に登録してください。未登録の場合、エラーを出力してその呼び出しを終了します。
