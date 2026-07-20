# Issue 31 Anonymous Analytics Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** MacClipyの初回起動・日次利用を匿名インストール単位で計測し、利用者が設定から送信を停止できる状態を、アプリ・公式API・プライバシー説明まで一貫して提供する。

**Architecture:** MacClipyはKeychainにランダムUUIDを保存し、Defaultsに送信済み状態だけを保持する。release bundleでのみ有効な非同期クライアントがfirst-party endpointへ最小payloadを送り、公式サイトのSvelteKit `+server.ts`が厳格に検証してGA4 Measurement Protocolへ転送する。API secretはサーバー環境だけで保持し、画面・ログ・レスポンスへ出さない。

**Tech Stack:** Swift 6 / AppKit / SwiftUI / Security / Defaults / XCTest、SvelteKit 2 / Svelte 5 / TypeScript / Node test runner / GA4 Measurement Protocol / AWS Amplify

## Global Constraints

- 匿名計測は初期ONとし、設定でOFFにした場合は以後の外部送信を行わない。
- 送信対象はランダムなインストールUUID、イベント名、アプリ版、build番号、macOSメジャー版、CPU種別、発生日時だけに限定する。
- クリップボード履歴、お気に入り、利用アプリ名、ウィンドウ名、氏名、メールアドレス、ハードウェア識別子を送らない。
- 開発build、テスト、`make run`では本番endpointへ送信しない。
- 計測失敗、timeout、4xx、5xxは起動・履歴保存・貼り付け・終了を妨げない。
- GA4 API secretはMacClipy、HTML、JavaScript、API responseへ含めない。
- Privacy ManifestではDevice IDとProduct InteractionをAnalytics目的、user非紐付け、trackingなしとして宣言する。
- 対応版以前の利用数は復元できず、KeychainのID消失後は新しいインストールとして数える。

---

### Task 1: MacClipyの匿名IDと送信スケジュール

**Files:**
- Create: `Sources/MacClipy/Analytics/InstallationIdentifier.swift`
- Create: `Sources/MacClipy/Analytics/AnonymousAnalytics.swift`
- Create: `Sources/MacClipy/Analytics/AnalyticsHTTPClient.swift`
- Create: `Tests/MacClipyTests/AnonymousAnalyticsTests.swift`

**Interfaces:**
- Produces: `InstallationIdentifierProviding.installationIdentifier() throws -> UUID`
- Produces: `AnonymousAnalyticsRecorder.recordLaunch(at:) async`
- Produces: `AnalyticsEventPayload` with only the approved fields.

- [x] **Step 1: Write failing XCTest cases**

```swift
func testInstallationIdentifierIsCreatedOnceAndReused() throws {
    let store = InMemoryInstallationIdentifierStore()
    let provider = InstallationIdentifierProvider(store: store)
    XCTAssertEqual(try provider.installationIdentifier(), try provider.installationIdentifier())
}

func testFirstLaunchSendsInstallAndDailyActive() async {
    let recorder = makeRecorder()
    await recorder.recordLaunch(at: fixedDate)
    XCTAssertEqual(sender.payloads.map(\.eventName), [.install, .dailyActive])
}

func testSameDayLaunchDoesNotSendAgain() async {
    await recorder.recordLaunch(at: fixedDate)
    await recorder.recordLaunch(at: fixedDate.addingTimeInterval(3600))
    XCTAssertEqual(sender.payloads.count, 2)
}

func testDisabledAndRuntimeGuardedRecordersDoNotSend() async {
    await disabledRecorder.recordLaunch(at: fixedDate)
    await developmentRecorder.recordLaunch(at: fixedDate)
    XCTAssertTrue(sender.payloads.isEmpty)
}
```

- [x] **Step 2: Run the focused test and verify RED**

Run: `swift test --filter AnonymousAnalyticsTests -Xswiftc -warnings-as-errors`
Expected: FAIL because the analytics types do not exist.

- [x] **Step 3: Implement the minimal analytics domain and Keychain adapter**

```swift
protocol InstallationIdentifierStoring {
    func load() throws -> String?
    func save(_ value: String) throws
}

enum AnalyticsEventName: String, Codable {
    case install
    case dailyActive = "daily_active"
}

struct AnalyticsEventPayload: Codable, Equatable {
    let schemaVersion: Int
    let installationID: UUID
    let eventName: AnalyticsEventName
    let appVersion: String
    let buildNumber: String
    let macOSMajorVersion: Int
    let architecture: String
    let occurredAt: Date
}
```

`KeychainInstallationIdentifierStore` uses `kSecClassGenericPassword`, service `jp.techguide.macclipy.analytics`, account `installation-id`. `AnonymousAnalyticsRecorder` marks each event sent only after a successful 2xx response and evaluates the day with an injected `Calendar`.

- [x] **Step 4: Run the focused test and verify GREEN**

Run: `swift test --filter AnonymousAnalyticsTests -Xswiftc -warnings-as-errors`
Expected: all anonymous analytics tests pass.

---

### Task 2: MacClipyの起動統合・設定・bundle構成

**Files:**
- Modify: `Sources/MacClipy/App/AppModel.swift`
- Modify: `Sources/MacClipy/Support/AppSettings.swift`
- Modify: `Sources/MacClipy/Support/AppConstants.swift`
- Modify: `Sources/MacClipy/UI/Settings/SettingsView.swift`
- Modify: `Sources/MacClipy/Resources/ja.lproj/Localizable.strings`
- Modify: `Sources/MacClipy/Resources/en.lproj/Localizable.strings`
- Create: `Sources/MacClipy/Resources/PrivacyInfo.xcprivacy`
- Modify: `Package.swift`
- Modify: `scripts/build-app.sh`
- Modify: `scripts/check.sh`
- Modify: `README.md`
- Test: `Tests/MacClipyTests/AnonymousAnalyticsTests.swift`
- Test: `Tests/MacClipyTests/SwiftUIModelTests.swift`

**Interfaces:**
- Consumes: `AnonymousAnalyticsRecorder.recordLaunch(at:) async`
- Produces: `SettingsModel.isAnonymousAnalyticsEnabled` persisted in Defaults.
- Produces: Info.plist Boolean `MacClipyAnalyticsEnabled` and URL `MacClipyAnalyticsEndpoint`.

- [x] **Step 1: Add failing tests for default ON, opt-out, URL, payload privacy, and Privacy Manifest bundle checks**

```swift
func testAnonymousAnalyticsDefaultsToEnabled() {
    Defaults.remove(.anonymousAnalyticsEnabled)
    XCTAssertTrue(SettingsModel().isAnonymousAnalyticsEnabled)
}

func testPayloadContainsNoClipboardOrApplicationFields() throws {
    let keys = Set(try JSONSerialization.jsonObject(with: encodedPayload) as! [String: Any].keys)
    XCTAssertEqual(keys, approvedPayloadKeys)
}

func testPrivacyURLPointsToOfficialMacClipyPolicy() {
    XCTAssertEqual(AppConstants.Support.privacyURL.absoluteString,
                   "https://techguide.jp/macclipy/privacy/")
}
```

- [x] **Step 2: Run focused tests and verify RED**

Run: `swift test --filter AnonymousAnalyticsTests -Xswiftc -warnings-as-errors`
Expected: FAIL because settings and bundle configuration are absent.

- [x] **Step 3: Integrate launch recording and visible settings**

`AppModel.applicationDidFinishLaunching()` starts a cancelable `Task` after local models are loaded. The General tab adds one Analytics section with an enabled toggle, a concise list of collected data, and a link to `https://techguide.jp/macclipy/privacy/`. Turning the toggle off updates Defaults immediately; the recorder checks the setting before every event.

- [x] **Step 4: Add release-only bundle configuration and privacy manifest**

`scripts/build-app.sh` writes:

```xml
<key>MacClipyAnalyticsEnabled</key>
<true/><!-- release signing時。通常buildはfalse -->
<key>MacClipyAnalyticsEndpoint</key>
<string>https://techguide.jp/api/macclipy/analytics</string>
```

The build defaults analytics to disabled and `scripts/package-release.sh` enables it only in the signed release path. `scripts/check.sh` confirms `PrivacyInfo.xcprivacy` is at `Contents/Resources/PrivacyInfo.xcprivacy` and validates its declarations with `plutil`.

- [x] **Step 5: Run focused and full MacClipy gates**

Run: `swift test --filter AnonymousAnalyticsTests -Xswiftc -warnings-as-errors`
Expected: PASS.

Run: `scripts/check.sh`
Expected: tests, lint/format when installed, release build, app bundle, manifest, and codesign checks pass.

---

### Task 3: first-party analytics endpoint

**Files in `techguide-jp/corporate`:**
- Create: `techguide/src/lib/server/macclipy/analyticsValidation.ts`
- Create: `techguide/src/lib/server/macclipy/analyticsValidation.test.ts`
- Create: `techguide/src/lib/server/macclipy/analyticsRateLimit.ts`
- Create: `techguide/src/lib/server/macclipy/analyticsRateLimit.test.ts`
- Create: `techguide/src/lib/server/macclipy/gaMeasurementClient.ts`
- Create: `techguide/src/lib/server/macclipy/gaMeasurementClient.test.ts`
- Create: `techguide/src/lib/server/macclipy/analyticsEndpoint.ts`
- Create: `techguide/src/lib/server/macclipy/analyticsEndpoint.test.ts`
- Create: `techguide/src/routes/api/macclipy/analytics/+server.ts`
- Modify: `techguide/src/lib/server/env.ts`
- Modify: `techguide/package.json`
- Modify: `techguide/.env.example`

**Interfaces:**
- Produces: `parseMacClipyAnalyticsPayload(value: unknown): ValidationResult`.
- Produces: `sendMacClipyAnalyticsEvent(payload, fetcher): Promise<void>`.
- Produces: `handleMacClipyAnalyticsRequest(input, dependencies): Promise<EndpointResult>` so the route stays transport-only.
- Produces: `POST /api/macclipy/analytics` returning 202, 400, 413, 415, 429, or 503 without echoing payloads.

- [x] **Step 1: Write failing Node tests**

```ts
test('accepts the exact analytics schema', () => {
  assert.equal(parseMacClipyAnalyticsPayload(validPayload).ok, true);
});

test('rejects unknown and clipboard fields', () => {
  assert.equal(parseMacClipyAnalyticsPayload({ ...validPayload, clipboard_text: 'secret' }).ok, false);
});

test('maps the installation id to GA client_id and denies ad consent', async () => {
  await sendMacClipyAnalyticsEvent(validPayload, fakeFetch);
  assert.deepEqual(body.consent, { ad_user_data: 'DENIED', ad_personalization: 'DENIED' });
});

test('rejects oversized and rate-limited requests without calling GA', async () => {
  const result = await handleMacClipyAnalyticsRequest(input, dependencies);
  assert.equal(result.status, 429);
  assert.equal(forwardCalls, 0);
});
```

- [x] **Step 2: Run the server tests and verify RED**

Run: `pnpm test`
Expected: FAIL because the endpoint modules do not exist.

- [x] **Step 3: Implement validation, bounded in-memory rate limiting, and GA forwarding**

The route rejects bodies above 4 KiB, only accepts JSON, validates exact keys and formats, and rate-limits by client address for a short in-memory window without logging addresses or IDs. `gaMeasurementClient.ts` reads `PUBLIC_GA_MEASUREMENT_ID` and server-only `MACCLIPY_GA_API_SECRET`, sends `macclipy_install` or `macclipy_daily_active`, includes `session_id` and `engagement_time_msec`, denies advertising consent, and never forwards IP or free text.

- [x] **Step 4: Run tests and verify GREEN**

Run: `pnpm test`
Expected: all endpoint unit tests pass.

---

### Task 4: Privacy page and GA4 operations

**Files in `techguide-jp/corporate`:**
- Create: `techguide/src/routes/macclipy/privacy/+page.svelte`
- Modify: `techguide/src/routes/macclipy/+page.svelte`
- Modify: `techguide/src/lib/data/site.ts`
- Modify: `techguide/src/routes/sitemap.xml/+server.ts`
- Modify: `techguide/scripts/ga-admin.mjs`
- Create: `techguide/docs/macclipy-analytics.md`
- Modify: `techguide/README.md`

**Interfaces:**
- Produces: public privacy URL `https://techguide.jp/macclipy/privacy/`.
- Produces: GA4 custom dimensions `app_version`, `build_number`, `macos_major_version`, and `architecture` through existing `ga:sync` / `ga:sync:dry` commands.

- [x] **Step 1: Add the privacy page and link it from the product page**

The page states collection fields, analytics purpose, Google Analytics as a processor, 14-month target retention, opt-out steps, Keychain reset behavior, pre-feature history limitations, security-log IP processing, and contact route. It explicitly distinguishes local clipboard content from anonymous usage metadata.

- [x] **Step 2: Extend GA4 configuration and operating instructions**

Add the four event-scoped custom dimensions to `DEFAULT_CUSTOM_DIMENSIONS`. Document secret provisioning, validation endpoint use, `ga:sync:dry`, `ga:sync`, Realtime checks, period comparisons, active-user metrics, version distribution, and the rule that failed data acquisition is never reported as zero.

- [x] **Step 3: Run the full official-site gate**

Run: `pnpm validate`
Expected: format, lint, Svelte typecheck, and production build pass.

---

### Task 5: Cross-repository release handoff

**Files:**
- Review all changed files in both repositories.
- Update: GitHub PR descriptions and Issue #31 comment.

**Interfaces:**
- Consumes: verified MacClipy and corporate branches.
- Produces: two reviewable PRs linked to Issue #31.

- [x] **Step 1: Re-run fresh verification**

Run in MacClipy: `scripts/check.sh`

Run in corporate/techguide: `pnpm test && pnpm validate`

Expected: every command exits 0 with no test, lint, typecheck, or build failures.

- [x] **Step 2: Review exact diffs and selectively stage only Issue #31 files**

Run: `git diff --check`, `git status --short`, and `git diff --stat` in both repositories.

- [ ] **Step 3: Commit with Japanese prefixed messages**

MacClipy: `feat: 匿名インストール計測と送信停止設定を追加`

Corporate: `feat: MacClipy匿名計測APIとプライバシー説明を追加`

- [ ] **Step 4: Push and create PRs with intent documentation**

Each PR body contains `概要`, `既存実装の調整意図`, `プライバシー上の判断`, and `検証`. The corporate PR is merged/deployed before the MacClipy release because the endpoint and privacy URL must exist first.

- [ ] **Step 5: Update Issue #31 without closing it prematurely**

Comment with both PR URLs, rollout order, required production secret `MACCLIPY_GA_API_SECRET`, GA4 sync commands, and remaining live confirmation steps. Close only after endpoint deployment, GA4 event confirmation, and the corresponding MacClipy release.
