# Issue 33 Daily Usage Analytics Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** MacClipyの常駐、生存確認、明示的な利用、機能別の日次利用回数を、匿名送信OFFと収集禁止項目を守りながら別イベントとして記録する。

**Architecture:** 既存の匿名インストールIDとfirst-party API senderを再利用し、イベントpayload、永続状態、送信調停をAnalytics配下の小さな型へ分ける。RunningとEngagedはローカル日付ごとに成功時だけ送信済みにし、機能別カウンターは完了日をfeature単位で順次送信して成功した項目だけ削除する。AppModelはライフサイクル通知とUI modelの意味的なcallbackをAnalyticsへ接続し、本文、検索語、項目ID、利用アプリ情報を境界へ渡さない。

**Tech Stack:** Swift 6 / AppKit / SwiftUI / Observation / Defaults / XCTest

## Global Constraints

- 対象は`techguide-jp/mac-clipy#33`のアプリ側だけとし、API・GA4・公開プライバシーページは`techguide-jp/corporate#43`へ残す。
- 新クライアントは`daily_active`を送らず、`daily_running`、`daily_engaged`、`feature_usage`を送る。
- クリップボード本文、検索文字列、お気に入り本文・表示名、項目ID、フォルダ情報、利用アプリ情報をAnalyticsへ渡さない。
- 匿名送信OFF、開発build、テスト、未署名buildでは既存どおり外部送信しない。
- 通信失敗やtimeoutは履歴表示、コピー、貼り付け、終了を妨げない。
- 既存の`lastAnonymousDailyActiveDay`はRunning送信済み日へ一度だけ引き継ぐ。

---

### Task 1: 日次イベントpayloadと永続状態

**Files:**
- Create: `Sources/MacClipy/Analytics/AnalyticsEvent.swift`
- Create: `Sources/MacClipy/Analytics/AnalyticsEventState.swift`
- Modify: `Sources/MacClipy/Analytics/AnonymousAnalytics.swift`
- Modify: `Tests/MacClipyTests/AnonymousAnalyticsTests.swift`
- Create: `Tests/MacClipyTests/DailyUsageAnalyticsTests.swift`

**Interfaces:**
- Produces: `AnalyticsEventName.dailyRunning`, `.dailyEngaged`, `.featureUsage`.
- Produces: `AnalyticsFeature` with the six issue-approved raw values.
- Produces: `AnonymousAnalyticsRecorder.recordRunning(at:) async`, `recordEngagement(at:) async`, and `recordFeatureUsage(_:at:)`.
- Persists: sent Running/Engaged days and `AnalyticsFeatureUsageState` through `AnalyticsEventStateStoring`.

- [x] **Step 1: Write failing tests for event names, payload allowlist, and legacy migration**

```swift
await recorder.recordLaunch(at: fixedDate)
XCTAssertEqual(sender.successfulPayloads.map(\.eventName), [.install, .dailyRunning])

state.lastDailyActiveDay = "2025-07-20"
await recorder.recordRunning(at: fixedDate)
XCTAssertTrue(sender.successfulPayloads.isEmpty)
XCTAssertEqual(state.lastDailyRunningDay, "2025-07-20")
```

- [x] **Step 2: Run `swift test --filter AnonymousAnalyticsTests -Xswiftc -warnings-as-errors` and confirm RED because the new event cases and state are absent**

- [x] **Step 3: Add the minimal event and state types, then change launch recording from legacy Daily Active to Running**

`AnalyticsEventPayload` encodes `feature`, `usage_count`, and `usage_date` only for feature usage. `DefaultsAnalyticsEventStateStore` keeps the legacy key readable and adds separate Running, Engaged, and Codable feature-state keys.

- [x] **Step 4: Write failing tests for dedupe, retry, completed-day flushing, and success-only deletion**

```swift
recorder.recordFeatureUsage(.historyPanel, at: fixedDate)
recorder.recordFeatureUsage(.historyPanel, at: fixedDate)
await recorder.recordRunning(at: nextDay)
XCTAssertEqual(sender.successfulPayloads.last?.usageCount, 2)

sender.failOnceFor = [.featureUsage]
await recorder.recordRunning(at: nextDay)
XCTAssertFalse(state.featureUsageState.countsByDay.isEmpty)
await recorder.recordRunning(at: nextDay)
XCTAssertTrue(state.featureUsageState.countsByDay.isEmpty)
```

- [x] **Step 5: Run `swift test --filter DailyUsageAnalyticsTests -Xswiftc -warnings-as-errors` and confirm RED**

- [x] **Step 6: Implement Running, Engaged, local counters, sequential flush, retry, and in-flight duplicate suppression**

- [x] **Step 7: Run both focused Analytics test suites and confirm GREEN**

---

### Task 2: ライフサイクルと意味的なUI操作の接続

**Files:**
- Modify: `Sources/MacClipy/App/AppDelegateBridge.swift`
- Modify: `Sources/MacClipy/App/AppModel.swift`
- Modify: `Sources/MacClipy/UI/HistoryPopup/HistoryPopupModel.swift`
- Modify: `Sources/MacClipy/Favorites/FavoritesModel.swift`
- Modify: `Tests/MacClipyTests/SwiftUIModelTests.swift`
- Modify: `Tests/MacClipyTests/HistoryPopupKeyActionTests.swift`

**Interfaces:**
- Consumes: `recordRunning`, `recordEngagement`, and `recordFeatureUsage`.
- Produces: popup callbacks containing only `HistoryPopupInitialMode` or `AnalyticsItemSource`; no content or identifier enters Analytics.

- [x] **Step 1: Write failing model tests for one search session per presentation and history/favorite item source classification**

```swift
popupModel.prepare(initialMode: .all)
popupModel.query = "a"
popupModel.query = "ab"
XCTAssertEqual(searchSessionCount, 1)

popupModel.prepare(initialMode: .favorites)
popupModel.chooseSelectedItem()
XCTAssertEqual(usedSources, [.favorite])
```

- [x] **Step 2: Run focused popup tests and confirm RED because semantic callbacks are absent**

- [x] **Step 3: Add popup presentation, search-session, item-source, and favorite-management callbacks**

- [x] **Step 4: Connect launch, `NSCalendarDayChanged`, and `NSWorkspace.didWakeNotification` to the common Running path**

- [x] **Step 5: Connect history/favorites panel opens, popup item use, menu-bar direct history use, search sessions, and favorite add/remove to feature counters and Engaged recording**

- [x] **Step 6: Run popup, App model, and Analytics tests and confirm GREEN**

---

### Task 3: 利用者向け説明とPrivacy Manifest整合

**Files:**
- Modify: `Sources/MacClipy/Resources/ja.lproj/Localizable.strings`
- Modify: `Sources/MacClipy/Resources/en.lproj/Localizable.strings`
- Modify: `README.md`
- Verify: `Sources/MacClipy/Resources/PrivacyInfo.xcprivacy`
- Verify: `scripts/check.sh`

- [x] **Step 1: Update Japanese and English settings copy to name anonymous running, panel use, and daily feature counts**

- [x] **Step 2: Explicitly state that clipboard content, search terms, favorite content, and app names are not sent**

- [x] **Step 3: Update README metrics and local storage descriptions**

- [x] **Step 4: Confirm the existing Product Interaction declaration and bundle checks still match the expanded implementation**

---

### Task 4: Fresh verification

**Files:**
- Review all files changed by Tasks 1-3.

- [x] **Step 1: Run `swift test --filter AnonymousAnalyticsTests -Xswiftc -warnings-as-errors`**

- [x] **Step 2: Run `swift test --filter DailyUsageAnalyticsTests -Xswiftc -warnings-as-errors`**

- [x] **Step 3: Run `swift test -Xswiftc -warnings-as-errors`**

- [x] **Step 4: Run `scripts/format.sh`, then `scripts/check.sh`**

- [x] **Step 5: Run `git diff --check`, inspect `git status --short`, and compare the final diff against every app-side acceptance condition**
