# 自社配布リリース Runbook

このドキュメントは、MacClipy を GitHub Releases で自社配布するための証明書、署名、公証、Sparkle appcast、Release workflow の流れをまとめる。

## 目的

- GitHub Releases に置く DMG を Developer ID 署名・公証済みにする。
- macOS Gatekeeper で `Notarized Developer ID` として受け入れられる配布物を作る。
- Sparkle 2 の appcast を GitHub Release asset として置き、アプリ内の「アップデートを確認...」から更新を検出できるようにする。
- ローカル検証と GitHub Actions の本番 release pipeline で同じ前提を使う。

## 全体像

1. Apple Developer Program の membership を有効にする。
2. Developer ID Application certificate を作る。
3. certificate と private key から CI 用 `.p12` を作る。
4. Sparkle EdDSA key を作る。
5. GitHub Secrets に certificate、Apple notarization 認証情報、Sparkle key を登録する。
6. `scripts/package-release.sh` を Developer ID モードで実行し、app bundle と DMG を署名・公証・staple する。
7. `scripts/generate-appcast.sh` で Sparkle appcast を生成する。
8. GitHub Release に DMG、checksum、`appcast.xml` を upload する。

## 現在の状況

2026-07-12 時点:

- PR: https://github.com/techguide-jp/mac-clipy/pull/20
- branch: `codex/issue-8-sparkle-updates`
- Apple Developer membership: 承認済み
- Team ID: `D5J584PC7Z`
- Developer ID Application certificate: 作成済み
- GitHub Secrets: 必要 8 件を登録済み
- ローカル Developer ID packaging: 実行済み
- notarization submission: `Accepted` 確認済み
- DMG staple / Gatekeeper 検証: 通過済み
- Release workflow 本検証: PR merge 後に実行予定
- Sparkle appcast の GitHub Actions 生成確認: Release workflow 本検証で確認予定

ローカルで検証した DMG:

```text
dist/release/MacClipy-v0.1.0.dmg
```

検証結果:

```text
dist/release/MacClipy-v0.1.0.dmg: accepted
source=Notarized Developer ID
origin=Developer ID Application: yuta takahashi (D5J584PC7Z)
```

## Apple Developer Program

Developer ID Application certificate と notarization を使うには Apple Developer Program が必要。
これは Mac App Store 外で配布するアプリを Apple が開発元確認済みとして扱うための前提になる。

今回の membership は個人名義で承認されている。
そのため Gatekeeper 上の配布元は次の identity になる。

```text
Developer ID Application: yuta takahashi (D5J584PC7Z)
```

TechGuide 名義で配布元を出したい場合は、organization 名義の Apple Developer Program team が別途必要。

## Developer ID Application certificate

### 目的

Developer ID Application certificate は、Mac App Store 外で配布する `.app` と `.dmg` を Developer ID 署名するために使う。
GitHub Actions ではこの certificate を `.p12` として一時 keychain に import し、`codesign` に渡す。

### 作成手順

1. CSR を作る。

   ```text
   /private/tmp/macclipy-developer-id/developer-id-application.certSigningRequest
   ```

2. Apple Developer の Certificates 画面で `Developer ID Application` を選ぶ。
3. CSR を upload する。
4. `.cer` を download する。

   ```text
   /Users/yuta/Downloads/developerID_application.cer
   ```

5. certificate の種類を確認する。

   ```bash
   openssl x509 -in /Users/yuta/Downloads/developerID_application.cer -inform DER -noout -subject -issuer -enddate
   ```

確認済み certificate:

```text
subject=UID=D5J584PC7Z, CN=Developer ID Application: yuta takahashi (D5J584PC7Z), OU=D5J584PC7Z, O=yuta takahashi, C=US
issuer=CN=Developer ID Certification Authority, OU=Apple Certification Authority, O=Apple Inc., C=US
notAfter=Feb  1 22:12:15 2027 GMT
```

### 注意点

`Apple Development` や `Development` certificate は今回の release workflow には使わない。
一度誤って Development certificate を作ったが、Developer ID 配布には不要。

## `.p12` 作成

### 目的

GitHub Actions 上ではローカル Keychain の private key を直接使えない。
そのため、Developer ID certificate と private key を `.p12` にまとめて GitHub Secret に登録する。

### 実施内容

CSR 作成時の private key:

```text
/private/tmp/macclipy-developer-id/developer-id-application.key
```

生成した `.p12`:

```text
/private/tmp/macclipy-developer-id/developer-id-application.p12
```

OpenSSL 3 の通常形式だと macOS `security import` で読めない場合があるため、CI 互換性を優先して `-legacy` 付きで作成した。

```bash
openssl pkcs12 \
  -export \
  -legacy \
  -inkey /private/tmp/macclipy-developer-id/developer-id-application.key \
  -in /private/tmp/macclipy-developer-id/developer-id-application.pem \
  -out /private/tmp/macclipy-developer-id/developer-id-application.p12 \
  -passout pass:"<p12 password>" \
  -name "Developer ID Application: yuta takahashi (D5J584PC7Z)"
```

### 検証

一時 keychain に import し、identity が見えることを確認済み。

```text
Developer ID Application: yuta takahashi (D5J584PC7Z)
```

## Sparkle EdDSA key

### 目的

Sparkle は update archive の署名検証に EdDSA key を使う。
アプリ側には public key を `SUPublicEDKey` として入れ、appcast 生成時には private key で署名する。

### GitHub Secrets

次の 2 件は登録済み。

```text
SPARKLE_PUBLIC_ED_KEY
SPARKLE_ED_PRIVATE_KEY
```

`SPARKLE_PUBLIC_ED_KEY` は app の `Info.plist` に入る。
`SPARKLE_ED_PRIVATE_KEY` は GitHub Actions の `scripts/generate-appcast.sh` で使う。

### 現在の注意点

GitHub Secret は読み戻せないため、登録後にローカルから private key を再取得することはできない。
ローカル Keychain からの Sparkle private key export は現時点で確認できていないため、appcast の最終確認は Release workflow 上で行う。

## GitHub Secrets

必要な secrets は 8 件。
2026-07-12 時点ですべて登録済み。

```text
MACOS_CERTIFICATE_P12_BASE64
MACOS_CERTIFICATE_PASSWORD
DEVELOPER_ID_APPLICATION
APPLE_ID
APPLE_TEAM_ID
APPLE_APP_SPECIFIC_PASSWORD
SPARKLE_PUBLIC_ED_KEY
SPARKLE_ED_PRIVATE_KEY
```

用途:

| Secret | 目的 |
| --- | --- |
| `MACOS_CERTIFICATE_P12_BASE64` | Developer ID certificate と private key を含む `.p12` |
| `MACOS_CERTIFICATE_PASSWORD` | `.p12` の import password |
| `DEVELOPER_ID_APPLICATION` | `codesign` の identity |
| `APPLE_ID` | `notarytool` の Apple ID |
| `APPLE_TEAM_ID` | Apple Developer team ID |
| `APPLE_APP_SPECIFIC_PASSWORD` | notarization 用 app-specific password |
| `SPARKLE_PUBLIC_ED_KEY` | `Info.plist` の `SUPublicEDKey` |
| `SPARKLE_ED_PRIVATE_KEY` | `generate_appcast` 用 private key |

## ローカル Developer ID packaging 検証

### 目的

Release workflow を動かす前に、証明書、p12、Apple notarization 認証情報が実際に使えるか確認する。

### 実施内容

1. 一時 keychain を作る。
2. `.p12` を import する。
3. `scripts/package-release.sh` を Developer ID モードで実行する。
4. app bundle を Developer ID 署名する。
5. DMG を作る。
6. DMG を Developer ID 署名する。
7. `xcrun notarytool submit --wait` で notarization に出す。
8. `xcrun stapler staple` で ticket を DMG に埋め込む。
9. `spctl` と `codesign` で配布物を検証する。

### 確認済みコマンド

```bash
xcrun stapler staple dist/release/MacClipy-v0.1.0.dmg
xcrun stapler validate dist/release/MacClipy-v0.1.0.dmg
spctl -a -vv -t open --context context:primary-signature dist/release/MacClipy-v0.1.0.dmg
codesign --verify --verbose=2 dist/release/MacClipy-v0.1.0.dmg
```

### 結果

```text
dist/release/MacClipy-v0.1.0.dmg: accepted
source=Notarized Developer ID
origin=Developer ID Application: yuta takahashi (D5J584PC7Z)
```

これで、手元で作った DMG は署名・公証・staple 済みの配布物として成立している。

## Release workflow

### 目的

ローカルではなく GitHub Actions 上で、配布用成果物を再現可能に作る。

workflow は次を行う。

1. lint / format / test / release build
2. temporary keychain 作成
3. Developer ID `.p12` import
4. app bundle 署名
5. DMG 作成
6. DMG 署名
7. notarization
8. staple
9. `spctl` / `codesign` 検証
10. Sparkle appcast 生成
11. GitHub Release へ upload

### 実行方法

PR #20 merge 後に、次のどちらかで実行する。

tag push:

```bash
git tag v0.1.1
git push origin v0.1.1
```

手動実行:

```bash
gh workflow run Release --repo techguide-jp/mac-clipy --ref main -f version=0.1.1
```

既存の `v0.1.0` release はすでにあるため、検証を兼ねた本番 workflow は `0.1.1` など新しい version で実行する。
同じ version を使うと release asset を `--clobber` で上書きする。

## Release workflow 後に確認すること

1. workflow が成功している。
2. GitHub Release に次の 3 ファイルがある。

   ```text
   MacClipy-v0.1.1.dmg
   MacClipy-v0.1.1.dmg.sha256
   appcast.xml
   ```

3. DMG が notarized Developer ID として受け入れられる。
4. `appcast.xml` に `sparkle:edSignature` が入っている。
5. `appcast.xml` の download URL が対象 release asset を向いている。
6. 旧 build number の MacClipy から「アップデートを確認...」で新 build を検出できる。

## トラブルシュート

### `security import` で p12 password mismatch が出る

OpenSSL 3 のデフォルト PKCS#12 形式が macOS `security import` と噛み合わない場合がある。
`openssl pkcs12 -export -legacy` で `.p12` を作り直す。

### `notarytool --wait` が長時間 `In Progress` のままになる

Apple notary service 側のキュー待ちの可能性がある。
Submission ID を控えて、後から状態確認する。

```bash
xcrun notarytool info <submission-id> \
  --apple-id "$APPLE_ID" \
  --team-id "$APPLE_TEAM_ID" \
  --password "$APPLE_APP_SPECIFIC_PASSWORD"
```

`Accepted` になったら、DMG に staple する。

### Sparkle private key をローカルで export できない

GitHub Secret に入れた値は読み戻せない。
ローカル Keychain に private key が残っていない場合は、Release workflow 上で `SPARKLE_ED_PRIVATE_KEY` を使って appcast 生成を検証する。
新しい key を作り直す場合は、`SPARKLE_PUBLIC_ED_KEY` と `SPARKLE_ED_PRIVATE_KEY` を必ずセットで更新し、古い app に入っている public key との互換性に注意する。
