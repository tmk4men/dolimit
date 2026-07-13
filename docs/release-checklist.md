# リリース チェックリスト — やっとこ

`lib/` のアプリ本体はほぼ完成。残るのは **Mac / 実機 / ストア Console 側の設定**が中心。ここに漏れなくまとめる。
（コード上の実装状況は `README.md` も参照。）

## 1. プラットフォーム生成・署名
- [ ] `flutter create . --platforms=android,ios --project-name dolimit` でネイティブプロジェクトを生成（このリポジトリは `android/ios/web` を `.gitignore` 済み）。
- [ ] アプリアイコンを書き出す: `dart run flutter_launcher_icons`（元画像 `assets/icon/app_icon.png`。設定は `pubspec.yaml` の `flutter_launcher_icons:`）。※ Web デモのアイコンは CI が自動で焼き込むので手動不要。
- [ ] Android: 署名鍵を作成し `android/key.properties` と `build.gradle` に設定。
- [ ] iOS: Xcode で署名（Apple Developer Program は課金済み）。Bundle ID を決定。

## 2. Android マニフェスト（`AndroidManifest.xml`）
- [ ] ランチャーの表示名を「やっとこ」に設定（`<application android:label="やっとこ">`）。※ `--project-name dolimit` は内部識別子なので変えなくてよい。
- [ ] `POST_NOTIFICATIONS`（Android 13+）を追加。※ inexact スケジュールなので `SCHEDULE_EXACT_ALARM` は不要。
- [ ] 音声入力: `RECORD_AUDIO` 権限 と `<queries><intent><action android:name="android.speech.RecognitionService"/></intent></queries>`。

## 3. iOS（`Info.plist`）
- [ ] 表示名を「やっとこ」に設定（`CFBundleDisplayName`）。
- [ ] 音声入力: `NSMicrophoneUsageDescription` と `NSSpeechRecognitionUsageDescription`。
- [ ] 通知・バッジ権限は起動時に要求済み（`main.dart`）。実機で許可ダイアログが出ることを確認。

## 4. App 内課金（Pro・ブースト）
- [ ] App Store Connect / Google Play Console で **非消費型**商品を 2 つ作成（未作成だと「商品が見つかりません」）:
  - `dolimit_pro` — Pro（**¥500** の価格帯に設定。上限をまとめて拡張）
  - `dolimit_boost` — ブースト（**¥100** の価格帯に設定。BOX+5 / TODAY+2 / LATER+5 を恒久追加）
- [ ] サンドボックス / テスターで**両商品**の購入・**復元**を実機確認（`StorePurchaseService`。復元は Pro/ブーストの両方が対象）。
- [ ] **中断復帰**を実機確認: 購入の途中でアプリを落として再起動しても、次回起動で権利が付与される（起動時に `PurchaseService.init()` がリスナー常駐＋未処理トランザクションを処理し、`onUnlocked` で AppState に反映される）。
- [ ] Play の「アプリのコンテンツ」で課金の申告。

## 5. 広告
- [ ] **広告は使わない**（`RewardedAdService` は撤去済み）。枠拡張はブースト（§4 の `dolimit_boost`, ¥100 買い切り）に一本化。将来も導入しない方針。

## 6. ホーム画面ウィジェット
- [ ] Dart 側のデータ供給・タップ遷移は実装済み。ネイティブ表示は `native_widget_reference/`（Android AppWidgetProvider+XML / iOS WidgetKit）を各プラットフォームへ組み込み。
- [ ] 実機でウィジェットに TODAY 件数・上位タスクが出ること、タップで該当タブに飛ぶことを確認。

## 7. 実機での動作確認（Web スタブでは確認できない項目）
- [ ] 通知が実際に発火する（朝の確認 / 日中 / 夜の精算 / LATER 事前 / 自動移動 / 満杯 / 自動追放）。
- [ ] 通知タップで該当画面へ遷移（ディープリンク）。
- [ ] アプリアイコンのバッジ = TODAY 未完了数（常時 ON・設定で消せない仕様）。
- [ ] 端末**再起動後**、次回起動で定時・LATER 通知が貼り直される（`AppState.load()`）。
- [ ] 音声入力: 使える端末で書き起こし、使えない端末でキーボードにフォールバック。
- [ ] 今回の UI 変更: 各タブ右上の ≡ メニュー →「設定」で設定ページが開く／起動直後は TODAY タブ／夜の精算時刻を過ぎたらホームに「今日の精算」が出る。

## 8. ストア申請物
- [x] **プライバシーポリシーを公開 URL 化**（本文 `docs/privacy-policy.md`。公開先: https://accidental-twine-974.notion.site/Privacy-Policy-ToDo-39cea830abd380dea638ea69253209ee ）。※連絡先メールの記入と、本文更新時の Notion 反映を忘れずに。
- [ ] アイコン（各サイズ）、スクリーンショット（端末別）、説明文（`docs/store-listing.md`）。
- [ ] **Data Safety（Google Play）/ App Privacy（Apple）** の申告: 音声入力は OS の音声認識を利用（Apple/Google が処理し得る）、課金はストア処理、開発者による個人情報収集・送信なし、を正しく反映。
- [ ] サポート URL / 問い合わせ先。

## 9. 最終ビルド
- [ ] `flutter build appbundle --release`（Android）
- [ ] `flutter build ipa`（iOS）
- [ ] 各ストアへアップロード → 審査提出。
