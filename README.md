# MacClipy

MacClipy は macOS 用のメニューバー常駐クリップボード管理アプリです。

## 初版の機能

- テキストクリップボード履歴の自動保存
- メニューバーから直近 10 件を即時貼り付け
- `Shift + Command + V` でマウス位置に検索付き履歴ポップオーバーを表示
- 履歴ポップオーバーで選んだ項目をコピーし、アクセシビリティ権限があれば直前のアプリへ即時貼り付け
- メニューバーからショートカットと同じ検索付き履歴ポップオーバーを表示
- 履歴の JSON ローカル保存
- アプリ選択式の「履歴に保存しないアプリ」設定
- コピー履歴保存の一時停止、履歴削除、ショートカット変更、設定画面

## 開発

```bash
cd /Users/yuta/works/mac-clipy
scripts/check.sh
```

`scripts/check.sh` はテスト、warnings-as-errors の release build、`.app` 生成、`Info.plist` 検証をまとめて実行します。
SwiftLint がインストールされている環境では lint も実行します。
品質ゲートの詳細は [docs/quality-gates.md](docs/quality-gates.md) にまとめています。

## 主なディレクトリ構成

- `Sources/MacClipy/App`: アプリ起動、`AppDelegate`、アプリ内パス
- `Sources/MacClipy/Clipboard`: 履歴モデル、保存、監視、貼り付け処理
- `Sources/MacClipy/Favorites`: お気に入りとフォルダの保存
- `Sources/MacClipy/HotKeys`: グローバルショートカットと入力 UI
- `Sources/MacClipy/UI`: 履歴パネル、履歴ポップオーバー、設定画面
- `Sources/MacClipy/Support`: 設定、ローカライズなどの共通処理
- `Sources/MacClipy/Resources`: ローカライズリソース

## ローカル .app の作成

```bash
cd /Users/yuta/works/mac-clipy
scripts/build-app.sh
open dist/MacClipy.app
```

作成される `.app` は署名・公証なしのローカル実行用です。

## データ保存先

- 履歴: `~/Library/Application Support/MacClipy/history.json`
- 設定: `~/Library/Application Support/MacClipy/settings.json`
- お気に入り: `~/Library/Application Support/MacClipy/favorites.json`

## ショートカット

既定値は `Shift + Command + V` です。

設定画面の「履歴メニューのショートカット」で枠をクリックし、使いたいキーの組み合わせを実際に押すと変更できます。
保存すると新しいショートカットが有効になります。

## 初期設定で履歴に保存しないアプリ

- 1Password
- Bitwarden
- KeePassXC
- キーチェーンアクセス
- MacClipy

## アクセシビリティ権限

直前のアプリへ自動貼り付けするには、macOS のシステム設定で MacClipy にアクセシビリティ権限を付与する必要があります。
権限がない場合でも、履歴選択時の再コピーまでは動作します。
