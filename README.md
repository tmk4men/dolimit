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

- ＋（FAB）でタスク名だけ入力 → 必ず BOX へ（音声入力導線あり / `source=voice`）
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
4. ネイティブ機能を有効化（`pubspec.yaml` のコメントを解除）:
   - 通知: `flutter_local_notifications`
   - ホーム画面ウィジェット: `home_widget`（Android は Glance / XML、iOS は WidgetKit）
   - バッジ: `flutter_app_badger`
   - 実装は `lib/services/notification_service.dart` の `NativeNotificationService`（TODO）に追加。
5. `flutter build appbundle --release` → Play Console へ。

## TODO / プレースホルダー

- 広告 / Pro 課金（ボタンのみ「今後実装予定」）
- ホーム画面ウィジェット（小/中）と通知のネイティブ実装
- 音声認識のフル実装（現状は端末の音声入力キーボード導線）

`_ios_swiftui_reference/` は最初に検討した iOS ネイティブ(SwiftUI)版の参考実装（不使用）。
