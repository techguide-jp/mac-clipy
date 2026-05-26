# MacClipy

MacClipy は macOS 用のメニューバー常駐クリップボード管理アプリです。

## 初版の機能

- テキストクリップボード履歴の自動保存
- メニューバーから直近 10 件を再コピー
- `Control + Option + V` でマウス位置に履歴メニューを表示
- 履歴メニューで選んだ項目をコピーし、アクセシビリティ権限があれば直前のアプリへ即時貼り付け
- メニューバーから詳細検索パネルを表示
- 履歴の JSON ローカル保存
- bundle id ベースの除外アプリ設定
- 監視の一時停止、履歴削除、設定画面

## 開発

```bash
cd /Users/yuta/works/mac-clipy
swift test
swift build -c release
```

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

## 初期除外アプリ

- `com.1password.1password`
- `com.agilebits.onepassword7`
- `com.bitwarden.desktop`
- `org.keepassxc.keepassxc`
- `com.apple.keychainaccess`
- `com.local.MacClipy`

## アクセシビリティ権限

直前のアプリへ自動貼り付けするには、macOS のシステム設定で MacClipy にアクセシビリティ権限を付与する必要があります。
権限がない場合でも、履歴選択時の再コピーまでは動作します。
