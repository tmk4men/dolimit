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
5. **App のプライバシー**（App情報 → Appのプライバシー）：タスク本体は端末内保存のみ・自前のアナリティクスなし。
   ただし **無料版は AdMob バナーを出す**ので、「識別子（デバイスID）／使用状況データ」を**サードパーティ広告目的で収集**と回答する（Proで非表示になる旨は説明に記載済み）。プライバシーポリシーURL に上記Notionを設定。

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
- **暗号化の輸出コンプライアンスを「非適用」に固定**（`ITSAppUsesNonExemptEncryption=false`）
  → 提出時の「暗号化を使用していますか？」が**出なくなる**。本アプリは独自暗号なし・
  標準HTTPS(Apple/OS)のみ・端末内保存なので false でよい（免除対象）。
- AppDelegate に通知デリゲート
- **ホーム画面ウィジェット（DoLimitWidget）を組み込み**（`scripts/add_ios_widget.sh`）
  → Widget Extension ターゲット追加・App Group `group.dolimit.widget` 付与・埋め込みを自動化。
  バンドルID `com.tmk4men.dolimit.DoLimitWidget`。バージョンは Flutter に自動同期。

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
3. **⚠️ ターゲット選択を `DoLimitWidget` に切り替えて、こちらでも同じ Team を選ぶ**。
   → ウィジェット拡張は別ターゲットなので署名が別途必要。ここを忘れるとビルドが
   「requires a development team」で失敗する。App Group は自動署名が自動登録する
   （もし `group.dolimit.widget` で怒られたら、各ターゲットの ＋Capability → App Groups を
   一度開き直すと登録される）。
4. （確認）Runner: **Display Name = やっとこ**、**Bundle Identifier = com.tmk4men.dolimit**、
   両ターゲットの **App Groups** に `group.dolimit.widget` が入っていること。
5. **In-App Purchase** は App ID で既定有効なので、通常は capability 追加不要（購入が動かない時だけ ＋Capability → In-App Purchase を追加）。

---

## 4. ビルドとアップロード

### 方法A：ターミナルだけ（おすすめ・Connect API キー）
```bash
flutter build ipa --export-method app-store
```
`build/ios/ipa/*.ipa` ができる。これを **App Store Connect API キー**でアップロード：

```bash
# 事前準備（Mac で1回だけ）：.p8 を共通置き場に置く。他アプリと共用でよい。
#   mkdir -p ~/.appstoreconnect/private_keys
#   cp /他アプリ/AuthKey_XXXXXXXXXX.p8 ~/.appstoreconnect/private_keys/
xcrun altool --upload-app -t ios \
  -f build/ios/ipa/*.ipa \
  --apiKey  XXXXXXXXXX \                          # Key ID = ファイル名 AuthKey_XXXXXXXXXX.p8 の後半
  --apiIssuer xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx # Issuer ID
```

- **Key ID / Issuer ID はアカウント共通**。他アプリで使ったのと同じ値をそのまま使う。
- **Issuer ID の場所**：App Store Connect → ユーザーとアクセス → Integrations（統合）→ App Store Connect API。
- `.p8` は上記の `~/.appstoreconnect/private_keys/` に置いておけば `--apiKey` が自動で見つける（キー本体のパス指定は不要）。
- ⚠️ `.p8`・Key ID・Issuer ID は**秘密情報**。このリポジトリにコミットしない。

> 旧方式（Apple ID ＋ App 用パスワード）でも可：`-u "AppleID(メール)" -p "xxxx-xxxx-xxxx-xxxx"`。API キーが使えるならそちらが手軽。

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
   - **マーケティングURL（デベロッパWebサイト）**：`https://tmk4men.github.io/dolimit/`。
     **Notion にしてはいけない**（下記 §5.5 の app-ads.txt が通らなくなる）。
   - **App内課金**：この版に `dolimit_pro` / `dolimit_boost` を紐付けて一緒に審査提出。
2. **審査に提出**。初回は1〜3日程度。

---

## 5.5 AdMob の app-ads.txt（無料版の広告）

AdMob は **App Store 掲載の「デベロッパWebサイト」（＝マーケティングURL）のドメイン直下**を
クロールして `app-ads.txt` を探す。ここが Notion のままだと Notion はルート直下にファイルを
置けないため必ず 404 になり、「app-ads.txt ファイルが見つかりませんでした」と表示される。

| 項目 | 値 |
|---|---|
| 配信URL | https://tmk4men.github.io/app-ads.txt |
| 配信元リポジトリ | `tmk4men/tmk4men.github.io` のルート（このリポジトリではない） |
| リポジトリ内の控え | `app-ads.txt`（内容を変えたら両方更新） |
| 必須の行 | `google.com, pub-2783540275927131, DIRECT, f08c47fec0942fa0` |
| マーケティングURL | `https://tmk4men.github.io/dolimit/`（`scripts/asc/asc.config.dolimit.json`） |

- **サブディレクトリは不可**。`/dolimit/app-ads.txt` に置いてもAdMobは見に行かない。
  `github.io` は Public Suffix なので `tmk4men.github.io` がルート扱いになり、そこの直下でOK。
- 反映確認：`curl -I https://tmk4men.github.io/app-ads.txt` が 200、かつ
  `curl -s "https://itunes.apple.com/lookup?id=6791004776&country=jp" | grep sellerUrl` が
  github.io になっていること。**ストア掲載が更新されるまでAdMob側は通らない**（マーケティングURLは
  バージョンのメタデータなので、次バージョンの審査承認と同時にライブへ反映される）。
- 両方OKになってから AdMob →「アプリ」→ 該当アプリ → **app-ads.txt「アップデートを確認」**。
  クロール反映には最大24時間ほどかかることがある。

---

## 6. よくある詰まり

- **「商品が見つかりません／準備中」**：有料App契約が未同意 or IAPが「審査待ち/未承認」。§1-1 と §1-4 を確認。IAPは初回はアプリと同時審査。
- **署名エラー**：Xcode の Team 未選択。§3-2。`flutter create` し直すと Team 設定が消えるので再設定。
- **通知が前面で出ない**：AppDelegate のデリゲート設定（スクリプトで実施済み）。`flutter create` し直したら `./scripts/setup_ios.sh` を再実行。
- **アイコンが反映されない**：`dart run flutter_launcher_icons` を再実行（スクリプトに含む）。元画像は `assets/icon/app_icon.png`。
- **バージョン/ビルド番号の重複でアップロード拒否**：`pubspec.yaml` の `+ビルド番号` を上げる（例 `1.0.0+2`）。
- **ウィジェットが一覧に出ない**：①署名 Team を `DoLimitWidget` ターゲットにも設定したか（§3-3）。
  ②実機にアプリを入れて**一度起動**したか（初回起動でウィジェット用データが書き込まれる）。
  ③ホーム画面を長押し → ＋ → 「DoLimit」を検索。数字が0でも「🎉 今日は決着！」が出れば連携OK。
- **ウィジェットの数字が更新されない**：App Group 不一致。両ターゲットの App Groups と
  `lib/services/native_widget_service.dart` の `_iosAppGroupId` が全て `group.dolimit.widget` か確認。
- **`add_ios_widget.sh` が「xcodeproj が無い」**：`sudo gem install xcodeproj`（CocoaPods 導入済みなら通常は入っている）。

---

## 更新リリース（2回目以降）

1. コードを更新。
2. `pubspec.yaml` の `version:` を上げる（例 `1.0.1+3`）。
3. **`./scripts/add_ios_widget.sh` を実行**（ウィジェットの版数を pubspec に合わせて焼き直す。
   これを忘れると appex とアプリの版数がズレて「Invalid Version / Pre-Release Train」で弾かれる）。
   ※ `setup_ios.sh` は署名が消えるので**実行しない**。`add_ios_widget.sh` だけでよい。
4. `flutter build ipa --export-method app-store` → §4 でアップロード。
5. App Store Connect で新バージョンを作成→ビルド選択→審査提出。

> ⚠️ 一度でも版数のズレたビルドをアップすると、その版数の「train」が閉じられ、**以後それ以下の
> 版数は全て弾かれる**。必ず過去に使った最大版数より上げること（例: 1.0.0 が閉じたら 1.0.1 以上）。

（`./scripts/setup_ios.sh` は `ios/` を作り直すので、通常の更新では**実行しない**。Xcodeのsigningを守るため。）
