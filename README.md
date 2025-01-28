# 【macOS/iOS/Flutter】環境構築＆Share Extension導入手順まとめ

- 本ドキュメントは、FlutterアプリにiOS用Share Extensionを導入し、他アプリからファイルを共有できるようにするための手順を網羅的にまとめたものです。
- 新規開発者が迷わないよう、**順序立てて**整理しています。

---

## 1. macOS環境の準備

1. macOSのバージョン確認  
   - Apple公式がサポートする最新のmacOSを使用してください。  
   - 古すぎるバージョンの場合、XcodeやFlutterの対応が切れていることがあるため注意が必要です。

2. Xcodeインストール  
   - [Mac App Store](https://apps.apple.com/jp/app/xcode/id497799835?mt=12)から最新版のXcodeをインストール。
   - Xcodeを起動し、追加のコンポーネント(シミュレータなど)がある場合はインストールを完了させます。
   - `xcode-select --install` をターミナルで実行し、Command Line Toolsも忘れずに導入してください。

3. Homebrewのインストール（任意）  
   - パッケージ管理システムとしてHomebrewを導入しておくと、SDKやツールなどのインストールが容易になります。  
   - [公式サイト](https://brew.sh/)の手順に従って導入し、`brew update`で常に最新状態に保ちます。

4. CocoaPodsのインストール  
   - FlutterプロジェクトのiOS依存関係を管理するために必要です。  
   - `sudo gem install cocoapods` でインストールします。  
   - インストール後、`pod setup` や `pod repo update` を実行し、初期設定を済ませておきます。

5. Xcodeのライセンス確認・Apple Developerアカウント  
   - 実機デバッグやTestFlightで配布する場合には、Apple Developerアカウントが必要です。  
   - 年間11,800円(2025年1月現在)程度かかるので注意してください。  

---

## 2. Flutterのセットアップ

1. Flutter SDKのインストール  
   - [公式ドキュメント](https://docs.flutter.dev/get-started/install/macos)に従って、Flutter SDKをダウンロードします。  
   - **Path設定**: `.zshrc` や `.bashrc` 等に `export PATH="$PATH:[flutter/bin のパス]"` を追記。  
   - `flutter doctor` を実行し、エラーがないかを確認してください。

2. Android Studio / VSCode 等のIDE設定（任意）  
   - Flutterアプリを開発する際のIDEを準備します。  
   - VSCodeの場合、`Dart` / `Flutter`拡張機能を入れて、必要に応じた設定を行います。

3. Flutterプロジェクトの作成  
   - `flutter create <プロジェクト名>` でプロジェクトを新規作成。  
   - デフォルトで iOS / Android / web などの設定が生成されるため、基本的にそのまま利用します。

4. iOS実機デバッグ・シミュレータ確認  
   - Xcodeから実機デバッグをする場合、デバイスをMacに接続し `Trust` 設定を済ませます。  
   - iPhoneシミュレータでテストする場合、`flutter run` コマンドでターゲットを指定可能。  
   - **注意事項**: シミュレータでは拡張機能(Share Extension)の一部が正しくテストできない場合があります。実機確認が必要です。

---

## 3. iOS向けShare Extensionの導入

以下の手順は、**FlutterアプリにiOS用のShare Extensionを追加して、他のアプリからファイルを共有できるようにする**ためのものです。

### 3.1. 基本的なフォルダ構成

Flutterプロジェクトを作成すると、iOS用に `ios/Runner/` ディレクトリが生成されます。Share Extensionを追加するときは、以下のような構成になります:

```shell
your_flutter_app/
 ┣ android/
 ┣ ios/
 ┃ ┣ Runner/
 ┃ ┣ RunnerTests/
 ┃ ┣ Share Extension/ ← ここにShare Extensionのファイル一式が入る
 ┃ ┗ Podfile
 ┣ lib/
 ┣ pubspec.yaml
 ┗ ...
```

1. Xcodeを開き、`Runner.xcworkspace` or `Runner.xcodeproj` を開く。
2. 左ペインで `Runner`プロジェクトを選択し、`Target`を追加 (`+` ボタンなど)。
3. **iOS > Application Extension > Share Extension** を選び、Share Extension のバンドルID等を設定。

---

### 3.2. Share Extensionのファイル構成

Share Extension用に、一般的には以下のファイルを用意します。

1. **Info.plist**  
   - Share Extension固有の設定。対応する `NSExtension` や `NSExtensionAttributes` を定義。  
   - 例:

     ```xml
     <key>NSExtension</key>
     <dict>
       <key>NSExtensionAttributes</key>
       <dict>
         <key>NSExtensionActivationRule</key>
         <dict>
           <key>NSExtensionActivationSupportsFileWithMaxCount</key>
           <integer>10</integer>
         </dict>
         <key>PHSupportedMediaTypes</key>
         <array>
           <string>Image</string>
           <string>Video</string>
         </array>
       </dict>
       <key>NSExtensionMainStoryboard</key>
       <string>MainInterface</string>
       <key>NSExtensionPointIdentifier</key>
       <string>com.apple.share-services</string>
     </dict>
     ```

   - **注意事項**: `NSExtensionMainStoryboard` が不要な場合は削除し、プログラムのみで画面を組み立てることも可能です。

2. **ShareViewController.swift**  
   - 実際の共有処理(ファイル取得、UserDefaultsを介したデータ保存、ホストアプリへのリダイレクト)を実装。
   - **注意事項**: Extensionのライフサイクルは通常のアプリと異なるため、`viewDidAppear` や `didSelectPost` など、どのメソッドが呼ばれるかをよく理解しておく。

3. **Share Extension.entitlements**  
   - App Groupsの設定を追記。メインアプリと同じApp Group IDを設定することで、UserDefaultsなどを共有できるようにする。  
   - 例:

     ```xml
     <?xml version="1.0" encoding="UTF-8"?>
     <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
     <plist version="1.0">
     <dict>
       <key>com.apple.security.application-groups</key>
       <array>
         <string>group.com.example.receiveSharingFiles</string>
       </array>
     </dict>
     </plist>
     ```

---

### 3.3. アプリグループ (App Groups) の設定

1. **メインアプリの`Runner.entitlements`にApp Groupsを追加**

   ```xml
   <?xml version="1.0" encoding="UTF-8"?>
   <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
   <plist version="1.0">
   <dict>
     <key>com.apple.security.application-groups</key>
     <array>
       <string>group.com.example.receiveSharingFiles</string>
     </array>
   </dict>
   </plist>

### 3.4. バンドルIDの整合性

- メインアプリ: com.example.receiveSharingFiles
- Share Extension: com.example.receiveSharingFiles.Share-Extension
- Info.plist 内で $(PRODUCT_BUNDLE_IDENTIFIER) がこのバンドルIDと一致するように設定。
- project.pbxproj の PRODUCT_BUNDLE_IDENTIFIER も一致させます。

### 3.5. URLスキームの設定 (メインアプリ側)

Share Extensionからホストアプリへ戻るために、カスタムURLスキームを設定するのが一般的です。

1. メインアプリの Info.plist に以下のようなエントリを追加:

    ```xml
    <key>CFBundleURLTypes</key>
    <array>
    <dict>
        <key>CFBundleURLSchemes</key>
        <array>
        <string>ShareMedia-$(PRODUCT_BUNDLE_IDENTIFIER)</string>
        </array>
        <key>CFBundleURLName</key>
        <string>$(PRODUCT_BUNDLE_IDENTIFIER)</string>
        <key>CFBundleTypeRole</key>
        <string>Editor</string>
    </dict>
    </array>
    ```

2. Share Extension内で openURL: などを用いて以下の形式で呼び出せるようにする:

    `ShareMedia-com.example.receiveSharingFiles://dataUrl=ShareKey#file`

**注意事項**: iOSバージョンによっては非推奨メソッド（openURL: vs openURL:options:completionHandler:）があるため、代替APIの利用検討が必要。

### 3.6. ShareViewControllerの概要

#### 3.6.1. 全体の流れ

- SLComposeServiceViewControllerを継承
- didSelectPost()などでNSExtensionContextのinputItemsを解析
- NSItemProviderからファイルURLなどを取得 (hasItemConformingToTypeIdentifier("public.file-url"))
- アプリグループのディレクトリへファイルをコピー
- UserDefaults(suiteName: appGroupId) にエンコード済みデータを保存
- カスタムURLスキームを使いホストアプリへ戻る

### 3.6.2. 実装内容のポイントと注意事項

1. Share Extensionのライフサイクル
    - SLComposeServiceViewControllerを継承することで、システムの共有UIに対して挙動を定義します。
    - ユーザーが「投稿(Share)」ボタンを押したらdidSelectPost()が呼ばれ、extensionContext?.inputItemsから共有データを取得します。
    - キャンセル（取り消し）を押すとdidSelectCancel()が呼ばれます。
2. 共有対象(attachments)の取得と判定
    - NSExtensionItemのattachmentsにはNSItemProviderが配列で含まれています。
    - hasItemConformingToTypeIdentifier(...)を使い、画像やファイルなど、どのタイプに一致するかを判定します。
    - 上記例では kUTTypeFileURLをメインに取り、動画・画像・テキストなど他のメソッドに分けて処理しています。
3. App Groupsを利用したデータ共有
    - appGroupId = "group.com.example.receiveSharingFiles"のように明示的に設定し、UserDefaults(suiteName: appGroupId)を介してホストアプリ側とデータを共有します。
    - 注意点
        - メインアプリ側でも同じApp Group ID (group.com.example.receiveSharingFiles)をSigning & Capabilitiesで設定し、Runner.entitlementsに追加する必要があります。
        - プロビジョニングプロファイルやApple Developerサイトでの設定も一致させておく必要があります。
4. ファイルのコピーとMIMEタイプ
    - 受け取ったURLをそのまま扱うのではなく、containerURL(forSecurityApplicationGroupIdentifier:)で取得したApp Group領域にファイルをコピーしています。
    - URL.mimeType()の拡張を利用し、単純に拡張子からMIMEタイプを推定しています。
    - 必要に応じて動画のDurationやサムネイル画像を生成して保存しています。
5. ホストアプリへのリダイレクト
    - redirectToHostApp(type:)メソッドでは、ShareMedia-<バンドルID>://... といったカスタムURLスキームでホストアプリを呼び出しています。
    - iOS 13以降で推奨される open(_:options:completionHandler:) を活用してリダイレクトと完了通知を行っています。
    - 注意点:
        - ホストアプリのInfo.plistでもCFBundleURLTypesを設定し、同じスキーム(ShareMedia-com.example.receiveSharingFiles など)を登録する必要があります。
        - シミュレータではShare Extensionからアプリを呼び出すフローが制限される可能性があるため、実機テストが望ましいです。
6. 非同期処理とタイムアウト
    - NSItemProvider.loadItemは非同期でファイルの読み込みを行います。
    - Share Extensionには実行時間の制限があるため、大きなファイルをコピーしている最中にエクステンションが終了する可能性があります。大容量ファイルの場合は注意が必要です。
7. デバッグとログ
    - 本文中でprintを多用し、いつどのように処理が進んでいるかをログ出力するようにしています。
    - 実際のアプリではユーザに見せるUIは最低限で、代わりにログやアラート等でエラーメッセージを出す実装になることが多いです。
8. メインアプリ側（Flutterなど）での受け取り
    - このShare Extensionが保存したデータUserDefaults内のShareKey）は、メインアプリが起動したときに同じappGroupIdのUserDefaultsから読み取りが可能です。
    - Flutterの場合、receive_sharing_intentなどのプラグインを利用するか、ネイティブコード（Swift/Objective-C）でUserDefaultsを読み取ってDart側に渡す仕組みを実装するとよいでしょう。

#### ShareViewController実装時のまとめ

- Share Extensionのメインポイントは、SLComposeServiceViewControllerのライフサイクルを把握し、inputItemsに含まれるNSItemProviderを正しいType Identifierで解析することです。
- App Groupを設定し、UserDefaults(suiteName:)を通じてメインアプリにデータを受け渡すのが一般的です。
- ファイルはApp GroupのディレクトリにコピーしてからMIMEタイプやサイズ・サムネイル等を付与して保存することが望ましいです。
- カスタムURLスキームを使ってメインアプリへリダイレクトし、ユーザにスムーズなフローを提供します。
- 実機テストが必須となるケースも多いので、デバッグログをしっかり出しながら挙動を確認することが重要です。

#### 3.6.3. 問題になりそうな注意事項

- 非同期処理中にExtensionの時間切れが発生する
    - Share Extensionはバックグラウンドで動作できる時間が短い場合があります。ファイルが大きいと処理が終わる前にExtensionが終了してしまうことがあるため、必要最小限の処理に留めるか、ファイルコピー中のタイムアウトが起きないよう留意してください。
- UserDefaultsのデータ衝突
    - UserDefaults(suiteName:)を使って、メインアプリと同じApp Group IDを指定しているか要確認。
    - 文字列(UTF-8)のエンコード/デコードで意図しない文字化けが起きないように注意。
    - バンドルIDやApp Group IDが1文字でも間違っていると動作しない
    - XcodeのGUIとproject.pbxprojの手動編集が混在していると、誤りが生じやすい。

## 4. Flutter側で受け取る実装

### 4.1. プラグイン: receive_sharing_intent

pubspec.yaml に追記し、flutter pub get を実行

```yaml
dependencies:
  receive_sharing_intent: ^1.8.1
```

Dartコード例

```dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';

void main() => runApp(MyApp());

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  StreamSubscription? _intentDataStreamSubscription;
  List<SharedMediaFile> _sharedFiles = [];

  @override
  void initState() {
    super.initState();

    // アプリが起動している間のストリームを購読
    _intentDataStreamSubscription =
        ReceiveSharingIntent.getMediaStream().listen((List<SharedMediaFile> value) {
      setState(() {
        _sharedFiles = value;
      });
    }, onError: (err) {
      print("getMediaStream error: $err");
    });

    // アプリが起動される前に受け取った共有データ
    ReceiveSharingIntent.getInitialMedia().then((List<SharedMediaFile> value) {
      setState(() {
        _sharedFiles = value;
      });
    });
  }

  @override
  void dispose() {
    _intentDataStreamSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: Text("Share Extension Demo")),
        body: ListView.builder(
          itemCount: _sharedFiles.length,
          itemBuilder: (context, index) {
            final file = _sharedFiles[index];
            return ListTile(
              title: Text(file.path.split('/').last),
              subtitle: Text("Type: ${file.type}"),
            );
          },
        ),
      ),
    );
  }
}
```

### 注意事項

- Flutterで複数ファイルを取り扱う場合、メモリ消費やスレッド周りに注意が必要。
- デバッグログが不足すると原因が追えないため、Loggerなどで適切にログを出力して追跡するのがおすすめ。

## 5. トラブルシューティング注意事項

ビルドエラー自体の解消手順はここでは詳述しませんが、開発時にハマりがちな問題の注意事項のみを記載します。

1. プロビジョニングプロファイル不一致
    - メインターゲット、Extensionターゲットそれぞれで「Signing & Capabilities」→「Team」「Profile」を確認。
    - アプリグループが正しく有効化されたプロファイルを指定していないとビルドが通りません。
2. バンドルIDのスペルミス / ドットの数
    - 例: com.example.app / com.example.app.ShareExtension など、正確に一致させること。
3. Share Extensionがシミュレータで正しく動作しない
    - シミュレータ特有の制限により、共有フローが試せない場合があります。なるべく実機テストを実施してください。
4. UserDefaultsの読み書きに失敗
    - suiteName がApp Groupsと一致しないと値が保存されない。
    - デバッグログを出力して、どの段階で値が保存され、読み出せていないのかを確認してください。
5. iOS版のフォアグラウンド/バックグラウンド実行時間
    - Extensionがバックグラウンドに移行する際、処理が早期終了するケースがあります。大きなファイルコピーを行う場合は注意。

## 6. まとめ

- Flutterの一般的なプロジェクト構成を理解した上で、iOS固有のShare Extensionを追加する。
- App GroupsをメインアプリとExtensionの両方で設定し、UserDefaultsを経由してデータを受け渡す。
- バンドルID、プロビジョニングプロファイル、URLスキーム、entitlementsなど、iOS特有の設定項目が多岐にわたるため、整合性に注意。
- 実装の確認は実機デバッグが必須となるケースが多い（シミュレータではテストできない部分がある）。
- テストの際にはデバッグログを充実させ、値の受け渡しやファイルパス・UserDefaultsの動作を丁寧に検証する。
