# 品質ゲート

MacClipy は常駐アプリなので、クリップボード履歴や貼り付け操作の退行を早めに検出することを優先します。
AI で変更する場合も、完了条件は実装差分だけでなく `scripts/check.sh` の通過までとします。

## ローカルチェック

```bash
scripts/check.sh
```

このスクリプトは次をまとめて実行します。

- SwiftLint がある場合は `swiftlint lint --strict`
- SwiftFormat がある場合は `swiftformat --lint Sources Tests Package.swift`
- `swift test -Xswiftc -warnings-as-errors`
- `swift build -c release -Xswiftc -warnings-as-errors`
- `scripts/build-app.sh`
- `dist/MacClipy.app/Contents/Info.plist` の検証
- 実行ファイルの存在確認
- `ja.lproj` / `en.lproj` の localization resource 存在確認
- `Info.plist` の `LSMinimumSystemVersion` が `14.0` であること

ローカルに SwiftLint / SwiftFormat がない場合は lint をスキップします。
CI では `REQUIRE_SWIFTLINT=1 REQUIRE_SWIFTFORMAT=1` を付けて実行するため、lint tool がない状態や lint 違反は失敗として扱います。

## 多言語対応ルール

UI 文言は Swift ソースに直接書かず、`Localizable.strings` に移して `L10n.tr(...)` 経由で参照します。
`swift test` の `LocalizationTests` で次を検出します。

- `ja` と `en` の key 集合が一致しない
- 空の翻訳がある
- `String(format:)` の placeholder が日英でずれている
- `L10n.tr("...")` で参照している key が resource にない
- Swift ソースに日本語の文字列リテラルが直接残っている
- SwiftUI の `Text("...")`、`Button("...")`、`Toggle("...")`、`Picker("...")` などに表示文言を直書きしている

## CI

GitHub Actions では macOS runner で `scripts/check.sh` を実行します。
PR と `main` への push の両方で、テスト、lint、release build、`.app` 生成が通ることを必須条件にします。

## SwiftLint 方針

`.swiftlint.yml` は、AI 実装で混入しやすいリスクを強めに制限します。

- `try!`、`as!`、強制アンラップは禁止
- 暗黙の optional unwrap は禁止
- `TODO` はエラー
- 長すぎる行、長すぎる関数、長すぎる型、複雑すぎる分岐は段階的に失敗させる

必要な例外がある場合は、ルールを弱める前に実装を分割できないか確認します。

## SwiftFormat 方針

`.swiftformat` を repo に置き、ローカル整形は次で実行します。

```bash
scripts/format.sh
```

CI と `scripts/check.sh` では `--lint` で差分のみ検出し、整形の書き換えは行いません。
