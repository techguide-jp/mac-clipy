# 品質ゲート

MacClipy は常駐アプリなので、クリップボード履歴や貼り付け操作の退行を早めに検出することを優先します。
AI で変更する場合も、完了条件は実装差分だけでなく `scripts/check.sh` の通過までとします。

## ローカルチェック

```bash
scripts/check.sh
```

このスクリプトは次をまとめて実行します。

- SwiftLint がある場合は `swiftlint lint --strict`
- `swift test -Xswiftc -warnings-as-errors`
- `swift build -c release -Xswiftc -warnings-as-errors`
- `scripts/build-app.sh`
- `dist/MacClipy.app/Contents/Info.plist` の検証
- 実行ファイルの存在確認

ローカルに SwiftLint がない場合は lint をスキップします。
CI では `REQUIRE_SWIFTLINT=1` を付けて実行するため、SwiftLint がない状態や lint 違反は失敗として扱います。

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
