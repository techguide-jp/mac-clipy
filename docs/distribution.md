# MacClipy 初回配布手順

## 配布の前提

- 配布元は GitHub Releases: https://github.com/techguide-jp/mac-clipy/releases/latest
- 自社 LP は案内ページとして使い、ダウンロードボタンから GitHub Releases へ誘導する。
- GitHub Release 版は Developer ID 署名・公証済み DMG として配布する。
- ローカル実行や手元検証の既定は ad-hoc 署名のままにする。
- Bundle ID は `jp.techguide.macclipy` に固定する。
- 配布用 app binary は Apple Silicon / Intel 両対応の universal binary として生成する。
- 自社配布版のアップデート確認は Sparkle 2 を使う。
- appcast は GitHub Releases の `appcast.xml` を正とする。
- このリポジトリには OSS ライセンスを付与しない。バイナリは無償利用可、ソースコードの複製・改変・再配布は別途許諾が必要。

## DMG 作成

```bash
cd /Users/yuta/works/mac-clipy
APP_VERSION=0.1.0 BUILD_NUMBER=1 scripts/package-release.sh
```

生成物:

- `dist/release/MacClipy-v0.1.0.dmg`
- `dist/release/MacClipy-v0.1.0.dmg.sha256`
- `dist/release/appcast.xml`（GitHub Actions の release workflow で生成）

`scripts/package-release.sh` は `scripts/check.sh` を実行してから、DMG 内に `MacClipy.app` と `/Applications` symlink を配置する。
DMG には背景画像、ウィンドウサイズ、アイコン位置を焼き込み、開いた時にドラッグインストールの導線が見えるようにする。
このスクリプトは release 用の Bundle ID を `jp.techguide.macclipy` に固定し、`x86_64 arm64` の universal binary を検証する。

Developer ID 署名・公証を行う場合は、`SIGNING_MODE=developer-id` で実行する。
このモードでは `DEVELOPER_ID_APPLICATION`、`APPLE_ID`、`APPLE_TEAM_ID`、`APPLE_APP_SPECIFIC_PASSWORD`、`SPARKLE_PUBLIC_ED_KEY` が必須になる。

## GitHub Release 作成

tag push で `.github/workflows/release.yml` が実行される。

```bash
git tag v0.1.0
git push origin v0.1.0
```

手動で出す場合は GitHub Actions の `Release` workflow を `version=0.1.0` で実行する。

release workflow には次の GitHub Secrets が必要:

- `MACOS_CERTIFICATE_P12_BASE64`
- `MACOS_CERTIFICATE_PASSWORD`
- `DEVELOPER_ID_APPLICATION`
- `APPLE_ID`
- `APPLE_TEAM_ID`
- `APPLE_APP_SPECIFIC_PASSWORD`
- `SPARKLE_PUBLIC_ED_KEY`
- `SPARKLE_ED_PRIVATE_KEY`

workflow は一時 keychain に証明書を import し、app bundle と DMG を Developer ID 署名し、`xcrun notarytool` で公証、`xcrun stapler` で ticket を staple する。
その後 `scripts/generate-appcast.sh` で Sparkle appcast を生成し、DMG、checksum、`appcast.xml` を GitHub Release にアップロードする。

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

GitHub Release 版は Developer ID 署名・公証済みのため、通常は Gatekeeper のブロックなしで起動できる。
手元で作った ad-hoc 署名版を案内する場合だけ、README の「未署名アプリの起動手順」へのリンクを含める。

直前のアプリへ自動貼り付けするには、`システム設定 > プライバシーとセキュリティ > アクセシビリティ` で MacClipy を許可してもらう。

## 次フェーズ候補

- フリーミアム化する場合は、課金状態の保存、機能制限、ライセンス検証、サポート導線を別 issue として設計する。
