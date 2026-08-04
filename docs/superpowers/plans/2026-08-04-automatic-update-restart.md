# Automatic Update Restart Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 自動ダウンロードした通常更新の準備完了直後に、確認画面を表示せずMacClipyをインストール・再起動する。

**Architecture:** Sparkleの`SPUUpdaterDelegate`専用オブジェクトが、終了時インストール予約のcallbackで`immediateInstallationBlock`を直ちに実行する。`AppUpdater`はこのdelegateを強参照して`SPUStandardUpdaterController`へ渡し、ダウンロード、検証、終了、インストール、再起動はSparkleの既存機構へ委ねる。

**Tech Stack:** Swift 6 / macOS 14 / Observation / Sparkle 2.9.3 / XCTest

## Global Constraints

- 「更新を自動でダウンロード/インストール」が有効な場合にSparkleが自動ダウンロードした通常更新だけを対象とする。
- ダウンロード、署名検証、展開が完了し、Sparkleが即時インストール可能と判断した後に再起動する。
- 再起動前の通知、確認画面、カウントダウン、延期操作は追加しない。
- 手動の「アップデートを確認...」と、メジャーアップデートなどユーザー確認が必要な更新の既存挙動は変更しない。
- 独自の終了処理、更新状態監視、タイマー、新しい依存関係は追加しない。

---

### Task 1: 即時インストールdelegate

**Files:**
- Create: `Sources/MacClipy/App/AutomaticUpdateInstaller.swift`
- Create: `Tests/MacClipyTests/AutomaticUpdateInstallerTests.swift`

**Interfaces:**
- Consumes: Sparkleの`SPUUpdaterDelegate`と`immediateInstallationBlock`。
- Produces: `AutomaticUpdateInstaller.installImmediately(using:) -> Bool`。
- Produces: `SPUUpdaterDelegate.updater(_:willInstallUpdateOnQuit:immediateInstallationBlock:) -> Bool`の実装。

- [ ] **Step 1: 即時インストール処理の失敗テストを追加する**

```swift
import Foundation
@testable import MacClipy
import XCTest

@MainActor
final class AutomaticUpdateInstallerTests: XCTestCase {
    func testInstallImmediatelyInvokesHandlerOnceAndClaimsUpdate() {
        let installer = AutomaticUpdateInstaller()
        var invocationCount = 0

        let handled = installer.installImmediately {
            invocationCount += 1
        }

        XCTAssertTrue(handled)
        XCTAssertEqual(invocationCount, 1)
    }
}
```

- [ ] **Step 2: テストを実行してREDを確認する**

Run: `swift test --filter AutomaticUpdateInstallerTests -Xswiftc -warnings-as-errors`

Expected: `AutomaticUpdateInstaller`が未定義のためコンパイルが失敗する。

- [ ] **Step 3: 最小のdelegate実装を追加する**

```swift
import Foundation
import Sparkle

@MainActor
final class AutomaticUpdateInstaller: NSObject, SPUUpdaterDelegate {
    func installImmediately(using installationHandler: () -> Void) -> Bool {
        installationHandler()
        return true
    }

    func updater(
        _: SPUUpdater,
        willInstallUpdateOnQuit _: SUAppcastItem,
        immediateInstallationBlock immediateInstallHandler: @escaping () -> Void
    ) -> Bool {
        installImmediately(using: immediateInstallHandler)
    }
}
```

このcallbackは、Sparkleが自動ダウンロード、署名検証、展開を完了し、通常なら終了時インストールを予約する段階で呼ばれる。`true`を返してMacClipy側が処理を引き受け、渡されたblockを直ちに呼ぶことでSparkleに無通知のインストール・再起動を開始させる。

- [ ] **Step 4: focused testを実行してGREENを確認する**

Run: `swift test --filter AutomaticUpdateInstallerTests -Xswiftc -warnings-as-errors`

Expected: 1 test passes。上記の`SPUUpdaterDelegate` signatureは、固定中のSparkle 2.9.3をSwift 6でtypecheck済み。

- [ ] **Step 5: Task 1をコミットする**

```bash
git add Sources/MacClipy/App/AutomaticUpdateInstaller.swift Tests/MacClipyTests/AutomaticUpdateInstallerTests.swift
git commit -m "feat: 自動更新の即時インストール処理を追加"
```

---

### Task 2: AppUpdaterへのdelegate接続

**Files:**
- Modify: `Sources/MacClipy/App/AppUpdater.swift:7-22`
- Verify: `Tests/MacClipyTests/AppAnalyticsIntegrationTests.swift:102`

**Interfaces:**
- Consumes: `AutomaticUpdateInstaller`。
- Produces: `SPUStandardUpdaterController`が保持する`updaterDelegate`接続。
- Preserves: `AppUpdater(startingUpdater:)`、更新設定property、`checkForUpdates()`の既存interface。

- [ ] **Step 1: AppUpdater初期化の既存テストを実行して基準を確認する**

Run: `swift test --filter AppAnalyticsIntegrationTests -Xswiftc -warnings-as-errors`

Expected: PASS。既存テスト内の`AppUpdater(startingUpdater: false)`が正常に初期化される。

- [ ] **Step 2: AppUpdaterがdelegateを強参照してSparkleへ渡す**

`AppUpdater`のstored propertyとinitializerを次の形に変更する。

```swift
@ObservationIgnored private let updaterDelegate: AutomaticUpdateInstaller
@ObservationIgnored private let updaterController: SPUStandardUpdaterController

init(startingUpdater: Bool) {
    let updaterDelegate = AutomaticUpdateInstaller()
    self.updaterDelegate = updaterDelegate
    updaterController = SPUStandardUpdaterController(
        startingUpdater: startingUpdater,
        updaterDelegate: updaterDelegate,
        userDriverDelegate: nil
    )
    super.init()
}
```

`updaterDelegate`をpropertyとして保持し、controller生成後に解放されないようにする。既存の`automaticallyChecksForUpdates`、`automaticallyDownloadsUpdates`、`checkForUpdates()`は変更しない。

- [ ] **Step 3: focused testと全テストを実行してGREENを確認する**

Run: `swift test --filter AutomaticUpdateInstallerTests -Xswiftc -warnings-as-errors`

Expected: PASS。

Run: `swift test --filter AppAnalyticsIntegrationTests -Xswiftc -warnings-as-errors`

Expected: PASS。

Run: `swift test -Xswiftc -warnings-as-errors`

Expected: すべてPASSし、warningがない。

- [ ] **Step 4: Task 2をコミットする**

```bash
git add Sources/MacClipy/App/AppUpdater.swift
git commit -m "feat: 自動更新完了後に即時再起動する"
```

---

### Task 3: 品質ゲートと差分監査

**Files:**
- Verify: `Sources/MacClipy/App/AutomaticUpdateInstaller.swift`
- Verify: `Sources/MacClipy/App/AppUpdater.swift`
- Verify: `Tests/MacClipyTests/AutomaticUpdateInstallerTests.swift`

**Interfaces:**
- Consumes: Tasks 1-2の完成差分。
- Produces: formatter、test、lint、release build、app bundle作成を通過した実装。

- [ ] **Step 1: formatterを実行する**

Run: `scripts/format.sh`

Expected: 対象Swiftファイルがリポジトリ規約に整形される。

- [ ] **Step 2: authoritative gateを実行する**

Run: `scripts/check.sh`

Expected: tests、SwiftLint、SwiftFormat lint、release build、app bundle作成がすべてPASSする。

- [ ] **Step 3: 最終差分を監査する**

Run: `git diff --check HEAD~2..HEAD`

Expected: 出力なし。

Run: `git diff --check`

Expected: 出力なし。

Run: `git status --short`

Expected: formatterによる未コミット差分がなければ出力なし。差分がある場合は、変更が対象3ファイルだけであることを確認する。

最終確認では、`SPUUpdaterDelegate`接続が自動更新callbackだけを変更していること、手動更新interfaceと設定画面に差分がないこと、通知・確認・タイマーを追加していないことを確認する。

- [ ] **Step 4: formatterによる差分がある場合だけコミットする**

```bash
git add Sources/MacClipy/App/AutomaticUpdateInstaller.swift Sources/MacClipy/App/AppUpdater.swift Tests/MacClipyTests/AutomaticUpdateInstallerTests.swift
git commit -m "style: 自動更新処理の形式を統一"
```
