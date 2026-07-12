# macOS の LSUIElement と regular アプリの違い

MacClipy は Dock に出ないメニューバー常駐アプリとして動かす。macOS 26.5 環境でステータス項目が見えないように見えたが、実際にはメニューバー項目が多く隠れていただけだったため、現在は `LSUIElement=true` と `.accessory` を使う方針に戻している。

## 用語

### LSUIElement

`Info.plist` の `LSUIElement` は、アプリを agent app として起動するための Launch Services key。

Apple の説明では、`LSUIElement` はアプリがバックグラウンドで動作し、Dock に表示されない agent app かどうかを示す Boolean key とされている。

MacClipy のようなメニューバー常駐アプリではよく使われるが、ユーザーから見ると Dock、Command+Tab、通常のアプリ一覧に出ないため、起動しているのに見つけづらい。

### NSApplication.ActivationPolicy.regular

`NSApplication.ActivationPolicy.regular` は通常の macOS アプリとして振る舞う activation policy。

Dock に出て、Command+Tab の対象になり、通常ウィンドウを前面に出しやすい。ユーザーが「起動したのに何も起きない」と感じにくい。

## 挙動の違い

| 項目 | LSUIElement=true / accessory 系 | regular |
| --- | --- | --- |
| Dock 表示 | 出ない | 出る |
| Command+Tab | 基本的に出ない | 出る |
| 起動確認 | メニューバー項目を見つける必要がある | Dock とウィンドウで確認できる |
| メニューバー常駐感 | 強い | 弱い |
| 初回ユーザーの分かりやすさ | 低い | 高い |
| MacClipy 初版との相性 | 現在の採用方針 | デバッグ時には便利だが常用では Dock が邪魔 |

## MacClipy の現在の方針

現在の MacClipy は以下の方針にしている。

- `Info.plist` に `LSUIElement=true` を入れる。
- `AppDelegateBridge.applicationDidFinishLaunching` で `NSApp.setActivationPolicy(.accessory)` を呼ぶ。
- Dock には表示しない。
- 通常起動時に検索ウィンドウは自動表示しない。新規インストールの初回起動時だけ使い方ガイドを表示する。
- `NSStatusBar.system.statusItem` のメニューバー項目、`Shift + Command + V` の履歴ショートカット、`Option + Command + V` のお気に入りショートカットを入口にする。
- 使い方ガイドはメニューバーの「使い方...」から再表示できる。

この構成なら、Clipy 系アプリらしく常駐でき、Dock を占有しない。メニューバー項目が多い環境では隠れることがあるため、必要に応じて macOS 側でメニューバー項目を整理する。

## regular に切り替える条件

以下のような場合だけ、`regular` へ切り替える選択肢がある。

- 初回利用者向けに Dock 表示や起動時ウィンドウを優先したい。
- メニューバー項目が多い環境でも必ず視認できる入口が必要。
- デバッグ中にウィンドウやプロセスを見つけやすくしたい。

`regular` にする場合は、`scripts/build-app.sh` の `Info.plist` 生成から以下を削除する。

```xml
<key>LSUIElement</key>
<true/>
```

また runtime では `.regular` を使う。

```swift
NSApp.setActivationPolicy(.regular)
```

ただし MacClipy では、常駐アプリとして Dock に出ない体験を優先し、当面は `LSUIElement=true` と `.accessory` を既定にする。

## 参考

- Apple Developer Documentation: [LSUIElement](https://developer.apple.com/documentation/bundleresources/information-property-list/lsuielement)
- Apple Developer Documentation: [NSApplication.ActivationPolicy](https://developer.apple.com/documentation/appkit/nsapplication/activationpolicy-swift.enum)
- Apple Developer Documentation: [setActivationPolicy:](https://developer.apple.com/documentation/appkit/nsapplication/1428621-setactivationpolicy)
