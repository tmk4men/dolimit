# ホーム画面ウィジェット — ネイティブ組み込み手順

Dart 側（`lib/services/widget_service.dart` ほか）は実装済みで、タスク変更時に
`today_count` / `today_titles` を `home_widget` 経由で共有ストレージへ書き込みます。
**表示部分はネイティブ実装が必要**で、`android/` `ios/` は `.gitignore`＆CI生成のため
ここに参考実装を置いています。Mac 側で以下を組み込んでください。

前提: `flutter create . --platforms=android,ios` 済み。`flutter pub get` 済み。

## Android
1. `android/app/src/main/kotlin/<applicationId のパス>/DoLimitWidgetProvider.kt` を
   `android/DoLimitWidgetProvider.kt` の内容で作成（package 行を実際の applicationId に合わせる）。
2. `android/app/src/main/res/layout/dolimit_widget.xml` を `android/dolimit_widget.xml` から作成。
3. `android/app/src/main/res/xml/dolimit_widget_info.xml` を `android/dolimit_widget_info.xml` から作成。
4. `android/app/src/main/res/drawable/widget_background.xml` を `android/widget_background.xml` から作成（角丸カード背景）。
5. 色定義を追加（ダークモード対応）:
   - `android/app/src/main/res/values/colors.xml` に `android/colors.xml` の `<color>` を追記。
   - `android/app/src/main/res/values-night/colors.xml` に `android/colors-night.xml` を作成。
6. `android/app/src/main/AndroidManifest.xml` の `<application>` 内に
   `android/manifest_receiver.xml` の `<receiver>` を追加（`android:name` を applicationId に合わせる）。
7. `NativeWidgetService._androidProvider`（`DoLimitWidgetProvider`）とクラス名を一致させる。

## iOS
1. Xcode で `ios/Runner.xcworkspace` を開く。
2. **App Group** を作成（例: `group.dolimit.widget`）。Runner と Widget Extension の両方に付与。
   `NativeWidgetService._iosAppGroupId` を同じ値にする。
3. File > New > Target > **Widget Extension**（名前を `DoLimitWidget` に）。
   生成された Swift を `ios/DoLimitWidget.swift` の内容で置き換える。
4. `NativeWidgetService._iosWidget`（`DoLimitWidget`）と Widget の `kind` を一致させる。

## 共有キー（Dart と一致させる）
- `today_count`: Int — TODAY 未完了数
- `today_titles`: String — 上位3件のタスク名（改行区切り）
- `updated_at`: String（ISO8601）

## タップで TODAY を開く
Dart 側（`lib/app.dart`）は `dolimit://today` を受け取って TODAY タブへ遷移する。
ネイティブ側は widget のタップでこの URI を投げる必要がある。参考実装では組込済み：
- Android: `DoLimitWidgetProvider.kt` が `HomeWidgetLaunchIntent` で
  ルート(`@id/widget_root`)に `setOnClickPendingIntent` を設定。
- iOS: `DoLimitWidget.swift` のビューに `.widgetURL(URL(string: "dolimit://today"))`。

これらが無いと数字は更新されてもタップしても TODAY に飛ばないので注意。

## デザイン仕様（アプリ本体と統一）
- **配色**: `todayAccent`（残り件数）/ `card`（背景）/ `ink`・`sub` を本体の色トークンに合わせる。
  ライト/ダークで自動切替（Android=`values`/`values-night`、iOS=`UITraitCollection`）。
- **背景**: 角丸（Android=`widget_background.xml` の 24dp、iOS 17+=`containerBackground`）。
- **残り件数はアクセント色（赤系）**で強調し、TODAY の"急ぎ感"を出す。
- **決着状態**: TODAY が空（`count==0` かつタスク名なし）のときは「🎉 今日は決着！」を表示し、
  本体の達成演出と体験を揃える。
- **表示件数**: iOS は small=2件 / medium=3件で出し分け（Android は最大3行）。

## 動作確認
実機/エミュレータでアプリを起動 → タスクを追加/完了 → ホーム画面にウィジェットを配置し、
数字とタスク名が更新されることを確認。あわせて次も確認する:
- **タップ** → アプリが起動して TODAY タブが開く。
- **ダークモード**（端末をダークに）→ 背景・文字色が暗色に切り替わる。
- **決着表示** → TODAY を全部片づけると「🎉 今日は決着！」になる。
