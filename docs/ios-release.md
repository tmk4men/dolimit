# iOS リリース手順 — やっとこ（DoLimit）

**ターミナル / Xcode / App Store Connect の3つだけ**で iOS を出すための手順。
アプリアイコンはリポジトリ内 `assets/icon/app_icon.png` から自動適用される（別途ダウンロード不要）。

| 項目 | 値 |
|---|---|
| 表示名 | やっとこ |
| バンドルID | `com.tmk4men.dolimit` |
| App内課金 | `dolimit_pro`（¥500・非消費型）／`dolimit_boost`（¥100・非消費型） |
| プライバシーポリシー | https://accidental-twine-974.notion.site/Privacy-Policy-ToDo-39cea830abd380dea638ea69253209ee |

> バージョン：初回公開なら `pubspec.yaml` の `version:` を `1.0.0+1` に上げておくと自然（任意）。

---

## 1. App Store Connect の下準備（先にやる）

ブラウザで https://appstoreconnect.apple.com

1. **契約・税・口座**（Agreements, Tax, and Banking）で **有料App（Paid Applications）契約に同意**し、税・銀行情報を入力。
   → これが未完了だと **App内課金が作れない／読み込めない**。最重要。
2. **証明書・ID・プロファイル**（developer.apple.com）→ Identifiers で App ID `com.tmk4men.dolimit` を作成（後述の Xcode 自動署名でも自動作成される）。
3. **App を新規作成**：My Apps → ＋ → 新規App。プラットフォーム=iOS、名前=やっとこ、言語=日本語、バンドルID=`com.tmk4men.dolimit`、SKU=任意（例 `dolimit`）。
4. **App内課金を作成**（このApp → 機能 → App内課金）：
   - `dolimit_pro`：非消費型、参照名「Pro」、価格 **¥500**、表示名/説明を日本語で。
   - `dolimit_boost`：非消費型、参照名「ブースト」、価格 **¥100**、表示名/説明を日本語で。
   - 各IAPに**審査用スクリーンショット**を1枚添付（アプリの購入画面でよい）。初回はアプリ本体の審査と一緒に提出する。
5. **App のプライバシー**（App情報 → Appのプライバシー）：データ収集**なし**で回答（端末内保存のみ・アナリティクスなし・広告なし）。プライバシーポリシーURL に上記Notionを設定。

---

## 2. ターミナル（Mac でセットアップ）

```bash
git clone https://github.com/tmk4men/dolimit.git   # 既にあれば git pull
cd dolimit
chmod +x scripts/setup_ios.sh
./scripts/setup_ios.sh
```

このスクリプトが自動でやること：
- `ios/` を生成（バンドルID `com.tmk4men.dolimit`）
- **アイコンを自動適用**（`dart run flutter_launcher_icons`。App Store用1024pxも含む）
- Info.plist に表示名「やっとこ」＋マイク/音声認識の権限説明
- AppDelegate に通知デリゲート

> `ios/` は `.gitignore` 済み。一度生成すればローカルに残るので、以降の署名設定は消えない（再び `flutter create` しない限り）。

---

## 3. Xcode（署名：一度だけ）

```bash
open ios/Runner.xcworkspace   # .xcodeproj ではなく .xcworkspace
```

Xcode で：
1. 左の **Runner** → **Signing & Capabilities**。
2. **Automatically manage signing** にチェック → **Team** に自分の Apple Developer チームを選択。
   → これで署名・プロビジョニングは自動。エラーが消えればOK。
3. （確認）**Display Name = やっとこ**、**Bundle Identifier = com.tmk4men.dolimit**、アイコンが入っていること。
4. **In-App Purchase** は App ID で既定有効なので、通常は capability 追加不要（購入が動かない時だけ ＋Capability → In-App Purchase を追加）。

---

## 4. ビルドとアップロード

### 方法A：ターミナルだけ（おすすめ）
```bash
flutter build ipa --export-method app-store
```
`build/ios/ipa/*.ipa` ができる。これをアップロード：
```bash
# 事前に appleid.apple.com → サインインとセキュリティ → App用パスワード を作成
xcrun altool --upload-app -t ios \
  -f build/ios/ipa/*.ipa \
  -u "あなたのAppleID(メール)" \
  -p "xxxx-xxxx-xxxx-xxxx"   # 上で作ったApp用パスワード
```

### 方法B：Xcode の GUI（確実）
Xcode → メニュー **Product → Archive** → 完了後 **Distribute App → App Store Connect → Upload**。署名は自動。

どちらでも、数分後に App Store Connect の TestFlight/ビルド一覧に現れる（処理に10〜30分かかることあり）。

---

## 5. App Store Connect（審査提出）

1. 対象Appの**バージョン（1.0.0）**画面で：
   - **ビルド**：アップロードしたビルドを選択。
   - **スクリーンショット**：6.7インチ(iPhone)必須。iOSシミュレータでアプリを動かして撮る：
     ```bash
     open -a Simulator
     flutter run   # シミュレータ起動中に。画面を作って↓で保存
     xcrun simctl io booted screenshot ~/Desktop/shot1.png
     ```
     おすすめ画面：①BOXを左右スワイプ ②TODAYの残り時間 ③今日の精算 ④一覧（`docs/store-listing.md` 参照）。
   - **概要・キーワード・サポートURL・プライバシーポリシーURL**：`docs/store-listing.md` の文面を貼る。
   - **App内課金**：この版に `dolimit_pro` / `dolimit_boost` を紐付けて一緒に審査提出。
2. **審査に提出**。初回は1〜3日程度。

---

## 6. よくある詰まり

- **「商品が見つかりません／準備中」**：有料App契約が未同意 or IAPが「審査待ち/未承認」。§1-1 と §1-4 を確認。IAPは初回はアプリと同時審査。
- **署名エラー**：Xcode の Team 未選択。§3-2。`flutter create` し直すと Team 設定が消えるので再設定。
- **通知が前面で出ない**：AppDelegate のデリゲート設定（スクリプトで実施済み）。`flutter create` し直したら `./scripts/setup_ios.sh` を再実行。
- **アイコンが反映されない**：`dart run flutter_launcher_icons` を再実行（スクリプトに含む）。元画像は `assets/icon/app_icon.png`。
- **バージョン/ビルド番号の重複でアップロード拒否**：`pubspec.yaml` の `+ビルド番号` を上げる（例 `1.0.0+2`）。

---

## 更新リリース（2回目以降）

1. コードを更新。
2. `pubspec.yaml` の `version:` を上げる（例 `1.0.1+3`）。
3. `flutter build ipa --export-method app-store` → §4 でアップロード。
4. App Store Connect で新バージョンを作成→ビルド選択→審査提出。

（`./scripts/setup_ios.sh` は `ios/` を作り直すので、通常の更新では**実行しない**。Xcodeのsigningを守るため。）
