# DoLimit / 今日やる枠

タスクを溜めすぎず、**BOX → 左右スワイプで TODAY / LATER に仕分け**て「今日に決着」させるタスク**遂行**アプリ。

- **Flutter (Dart)** — 1 つのコードで **Android / iOS / Web**
- まずは **Android** でリリース（Android Studio でビルド・署名）、その後 iPhone
- ローカル保存のみ（クラウド同期 / ログイン / AI なし）

## 🌐 オンラインデモ

`main` に push すると GitHub Actions が **Flutter Web** をビルドし **GitHub Pages** に公開します。

→ デモURL: `https://<ユーザー名>.github.io/<リポジトリ名>/`

> Web デモでは通知・ホーム画面ウィジェット・アプリバッジは**スタブ（動作しない）**です。
> これらは Android/iOS ビルド時に実装が有効になります。仕分け・上限・精算・自動移動などの中心ロジックはデモで体験できます。

## 箱と表示名

| 内部 | UI 表示 | 上限 |
|----|----|----|
| 未分類 | **BOX** | 15 |
| 今日やる | **TODAY** | 10 |
| あとでやる | **LATER** | 20 |
| ジャンル | ジャンル | 5 |

上限はプロダクト思想の中心（溜めさせない）。満杯時は追加・移動を止めて整理を促す。

## 機能

- ＋（FAB）でタスク名だけ入力 → 必ず BOX へ（端末の音声認識で書き起こし / `source=voice`）
- BOX を **右スワイプ=TODAY（赤）/ 左スワイプ=LATER（青）** で仕分け（削除はスワイプに含めない）
- TODAY: 残り時間（夜に近づくほど赤）、放置日数、ドラッグ並び替え、ジャンルフィルター
- LATER: 開始日グループ表示、開始日/時刻・事前通知・自動移動 ON/OFF
- 開始日到来で LATER → TODAY 自動移動（満杯時は移動待ち）
- 今日の精算（明日もTODAY / LATERへ / 完了 / 削除）
- 3 日連続未完了は LATER へ自動追放
- アプリアイコンバッジ = TODAY 未完了数
- JSON バックアップ / 復元、ジャンル管理、通知時刻設定
- 触って分かるオンボーディング（実際にスワイプ）

## ローカル開発

```bash
flutter --version          # Flutter 3.4+ / Dart 3
flutter create . --platforms=android,ios,web --project-name dolimit  # 初回のみ: 各プラットフォームを生成
flutter pub get
flutter run                # 実機 / エミュレータ
flutter run -d chrome      # Web で確認
```

`lib/` がアプリ本体。`android/ios/web` などのプラットフォームディレクトリは
`flutter create .` で生成されます（このリポジトリでは `.gitignore` 済み・CI で自動生成）。

## Android リリース（Android Studio）

1. `flutter create . --platforms=android` でネイティブプロジェクト生成。
2. Android Studio で `android/` を開く。
3. 署名鍵を作成し `android/key.properties` と `build.gradle` に設定。
4. 通知・バッジは実装済み（`lib/services/native_notification_service.dart`、`flutter_local_notifications` + `app_badge_plus`）。Web では条件付きインポートでスタブに切り替わる。
   - **Android**: `AndroidManifest.xml` に `POST_NOTIFICATIONS`（Android 13+）を追加。inexact スケジュールなので `SCHEDULE_EXACT_ALARM` は不要。再起動で OS 側の予約が消えても、次回起動時に `AppState.load()` が貼り直す。
   - **iOS**: 通知・バッジ権限は起動時に要求（`main.dart`）。
   - ホーム画面ウィジェットは Dart 側のデータ供給のみ実装済み。ネイティブ表示は `native_widget_reference/` を参照。
5. 音声入力（`speech_to_text`）にはネイティブ側の宣言が必要。未設定なら
   `SpeechService.isAvailable` が false になり、キーボードの音声入力へ自動でフォールバックする。
   - **Android**: `AndroidManifest.xml` に `<uses-permission android:name="android.permission.RECORD_AUDIO"/>` と、
     `<queries><intent><action android:name="android.speech.RecognitionService"/></intent></queries>`。
   - **iOS**: `Info.plist` に `NSMicrophoneUsageDescription` と `NSSpeechRecognitionUsageDescription`。
6. `flutter build appbundle --release`（Android）/ `flutter build ipa`（iOS）→ 各ストアへ。

## TODO / プレースホルダー

- **Pro 課金**: 上限拡張ロジック・導線 UI は実装済み（`ProSheet`）。実際のストア購入（`in_app_purchase`）は未接続で、`PurchaseService` のスタブが「準備中」を返す（debug ビルドでは開発用に Pro 解除ボタンあり）。
- **ホーム画面ウィジェット**: Dart 側のデータ供給は実装済み。ネイティブ表示の組み込みは `native_widget_reference/` を参照（Mac 側作業）。
- 広告で一時的に枠拡張（ボタンのみ「今後実装予定」）

`_ios_swiftui_reference/` は最初に検討した iOS ネイティブ(SwiftUI)版の参考実装（不使用）。
