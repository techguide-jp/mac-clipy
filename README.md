# MacClipy

MacClipy は macOS 用のメニューバー常駐クリップボード管理アプリです。

## ダウンロード

最新版は [GitHub Releases](https://github.com/techguide-jp/mac-clipy/releases/latest) からダウンロードできます。

初回配布版は Developer ID 署名・公証前の暫定 DMG です。macOS の Gatekeeper 警告が出る場合は、下の「未署名アプリの起動手順」を確認してください。

## 初版の機能

- テキストクリップボード履歴の自動保存
- メニューバーから直近 10 件を即時貼り付け
- `Shift + Command + V` でマウス位置に検索付き履歴ポップオーバーを表示
- 履歴ポップオーバーで選んだ項目をコピーし、アクセシビリティ権限があれば直前のアプリへ即時貼り付け
- メニューバーからショートカットと同じ検索付き履歴ポップオーバーを表示
- `Option + Command + V` でお気に入りだけを表示
- ログイン時に起動する設定
- 履歴の JSON ローカル保存
- アプリ選択式の「履歴に保存しないアプリ」設定
- コピー履歴保存の一時停止、履歴削除、ショートカット変更、SwiftUI 設定画面

## 開発

```bash
cd /Users/yuta/works/mac-clipy
scripts/check.sh
```

`scripts/check.sh` はテスト、warnings-as-errors の release build、`.app` 生成、`Info.plist` 検証をまとめて実行します。
SwiftLint / SwiftFormat がインストールされている環境では lint も実行します。
品質ゲートの詳細は [docs/quality-gates.md](docs/quality-gates.md) にまとめています。
初回配布の作業手順は [docs/distribution.md](docs/distribution.md) にまとめています。

## 主なディレクトリ構成

- `Sources/MacClipy/App`: SwiftUI lifecycle、AppKit bridge、status item、floating panel
- `Sources/MacClipy/Clipboard`: 履歴モデル、保存、監視、貼り付け処理
- `Sources/MacClipy/Favorites`: お気に入りとフォルダの保存、SwiftUI 向け model
- `Sources/MacClipy/HotKeys`: `KeyboardShortcuts` の name 定義と旧設定移行 helper
- `Sources/MacClipy/UI`: SwiftUI の履歴ポップアップ、設定画面、key event bridge
- `Sources/MacClipy/Support`: Defaults 設定、旧設定移行、ローカライズなどの共通処理
- `Sources/MacClipy/Resources`: ローカライズリソース

## ローカル .app の作成

```bash
cd /Users/yuta/works/mac-clipy
make reapply-local
```

作成される `.app` は Developer ID 署名・公証なしのローカル実行用です。app bundle は ad-hoc 署名されます。
`make reapply-local` は `dist/MacClipy.app` を作り直し、起動中の MacClipy を終了してから再起動します。
短い alias として `make run` も使えます。

## 配布用 DMG の作成

```bash
cd /Users/yuta/works/mac-clipy
APP_VERSION=0.1.0 BUILD_NUMBER=1 scripts/package-release.sh
```

作成されるファイルは `dist/release/MacClipy-v0.1.0.dmg` と `dist/release/MacClipy-v0.1.0.dmg.sha256` です。
配布用 DMG の app binary は Apple Silicon / Intel 両対応の universal binary です。
Bundle ID は `jp.techguide.macclipy` です。将来の Developer ID 署名、公証、自動更新、フリーミアム対応でもこの Bundle ID を継続利用します。

## 未署名アプリの起動手順

初回配布版は Developer ID 署名・公証前のため、通常のダブルクリックでは macOS にブロックされる場合があります。

1. GitHub Releases から DMG をダウンロードします。
2. DMG を開き、`MacClipy.app` を `Applications` にドラッグします。
3. `Applications` 内の `MacClipy.app` を Control キーを押しながらクリックし、`開く` を選びます。
4. 確認ダイアログが出たら、もう一度 `開く` を選びます。
5. それでもブロックされる場合は、`システム設定 > プライバシーとセキュリティ` で `このまま開く` を選びます。

## データ保存先

- 履歴: `~/Library/Application Support/MacClipy/history.json`
- 設定: `UserDefaults` / `KeyboardShortcuts`
- お気に入り: `~/Library/Application Support/MacClipy/favorites.json`

旧バージョンの `~/Library/Application Support/MacClipy/settings.json` は、初回起動時に新しい設定へ一回だけ移行されます。

## ショートカット

履歴メニューの既定値は `Shift + Command + V`、お気に入りメニューの既定値は `Option + Command + V` です。

設定画面のショートカット recorder で、使いたいキーの組み合わせを実際に押すと即時反映されます。

## 初期設定で履歴に保存しないアプリ

- 1Password
- Bitwarden
- KeePassXC
- キーチェーンアクセス
- MacClipy

## アクセシビリティ権限

直前のアプリへ自動貼り付けするには、macOS のシステム設定で MacClipy にアクセシビリティ権限を付与する必要があります。
権限がない場合でも、履歴選択時の再コピーまでは動作します。

設定場所は `システム設定 > プライバシーとセキュリティ > アクセシビリティ` です。

## ライセンスと利用条件

GitHub Releases で配布する MacClipy のバイナリは無償で利用できます。

このリポジトリには OSS ライセンスを付与していません。ソースコードは閲覧できますが、明示的な許諾なく複製、改変、再配布することはできません。
