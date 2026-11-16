# 画面切り替え演出

演出ごとに独立したシーンを用意し、ルートの`Control`に`transition_effect.gd`を割り当てます。`TransitionController`はシーン切り替えごとに演出を非同期で読み込み、同じインスタンスで画面を覆ってから戻します。

## AnimationPlayerで演出を作る

1. 演出シーンのルートを全画面に配置します。配下に`AnimationPlayer`を追加し、ルートの`_animation_player`に設定します。
2. `cover`は画面が見える状態から完全に覆った状態へ、`reveal`は覆った状態から画面が見える状態へ変化するように作ります。終了時の状態を保てるよう、両方をループなし、トランジションにおける次のアニメーションを空に設定します。
3. `AnimationPlayer`の自動再生を空にし、更新モードをIdleまたはPhysicsに設定します。ポーズ中にも再生できるよう、処理モードは演出ルートから継承するか、Alwaysを使用します。

付属の`circle_fade.tscn`を指定すると円形のシェーダーフェードを使えます。色は`ColorRect.color`、マスクは同ノードのマテリアルにある`Texture`で設定し、長さは`cover`と`reveal`のタイムラインと終点のキーで調整します。演出シーンの参照は`res://transition_management/circle_fade.tscn`または`uid://dsa1axpkvfqo0`です。

## コードで演出を作る

`transition_effect.gd`を継承したスクリプトを演出シーンのルートに付け、`cover_async()`と`reveal_async()`を上書きします。たとえばシャッターを子に置き、`cover_async()`でシャッターの`close_async()`の完了を待ち、`reveal_async()`で開く動作の完了を待てます。`is_configured()`も上書きし、ツリーへ追加する前に子ノードなどの依存関係を検証します。子ノードで処理モードを継承すると、ポーズ中も演出ルートと一緒に処理されます。

## SceneControllerと独立して使う

`transition_controller.tscn`を常駐するシーンに配置します。`transition`にはそのインスタンスを渡します。

```gdscript
const TransitionController := preload(
		"res://transition_management/transition_controller.gd"
)


func play_transition_async(transition: TransitionController) -> void:
	if not await transition.prepare_async("uid://dsa1axpkvfqo0"):
		return
	await transition.cover_async()
	# 画面を完全に覆った状態で必要な処理を行います。
	await transition.reveal_async()
	transition.finish()
```

`cover_async()`から`finish()`までは、`CanvasLayer`上の全画面`Control`がゲーム画面へのGUIマウス入力を受け止めます。キーボードや`_input()`で直接読む入力は利用側で制御してください。
