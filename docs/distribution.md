# MacClipy 初回配布手順

## 配布の前提

- 配布元は GitHub Releases: https://github.com/techguide-jp/mac-clipy/releases/latest
- 自社 LP は案内ページとして使い、ダウンロードボタンから GitHub Releases へ誘導する。
- 初回配布版は Developer ID 署名・公証なし。app bundle は ad-hoc 署名のみ。
- Bundle ID は `jp.techguide.macclipy` に固定する。
- このリポジトリには OSS ライセンスを付与しない。バイナリは無償利用可、ソースコードの複製・改変・再配布は別途許諾が必要。

## DMG 作成

```bash
cd /Users/yuta/works/mac-clipy
APP_VERSION=0.1.0 BUILD_NUMBER=1 scripts/package-release.sh
```

生成物:

- `dist/release/MacClipy-v0.1.0.dmg`
- `dist/release/MacClipy-v0.1.0.dmg.sha256`

`scripts/package-release.sh` は `scripts/check.sh` を実行してから、DMG 内に `MacClipy.app` と `/Applications` symlink を配置する。
DMG には背景画像、ウィンドウサイズ、アイコン位置を焼き込み、開いた時にドラッグインストールの導線が見えるようにする。

## GitHub Release 作成

tag push で `.github/workflows/release.yml` が実行される。

```bash
git tag v0.1.0
git push origin v0.1.0
```

手動で出す場合は GitHub Actions の `Release` workflow を `version=0.1.0` で実行する。

## 自社 LP 掲載文面

```text
MacClipy は macOS 用のメニューバー常駐クリップボード管理アプリです。
コピーしたテキスト履歴を自動保存し、メニューバーやショートカットからすぐに呼び出せます。

無料でダウンロード:
https://github.com/techguide-jp/mac-clipy/releases/latest
```

ボタン文言:

```text
MacClipy を無料でダウンロード
```

## 利用者向け注意

初回配布版は Developer ID 署名・公証前のため、macOS の Gatekeeper 警告が出る場合がある。
案内には README の「未署名アプリの起動手順」へのリンクを含める。

直前のアプリへ自動貼り付けするには、`システム設定 > プライバシーとセキュリティ > アクセシビリティ` で MacClipy を許可してもらう。

## 次フェーズ候補

- Apple Developer Program 登録後、Developer ID Application 証明書で署名し、公証済み DMG に切り替える。
- Sparkle などで自動更新を追加する。
- フリーミアム化する場合は、課金状態の保存、機能制限、ライセンス検証、サポート導線を別 issue として設計する。
