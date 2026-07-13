#!/usr/bin/env bash
#
# やっとこ（DoLimit）iOS セットアップ。Mac のターミナルで一度だけ実行する。
#   1) iOS プロジェクトを生成（ios/ は .gitignore なので毎回生成）
#   2) アプリアイコンを assets/icon/app_icon.png から自動適用
#   3) 表示名「やっとこ」・マイク/音声認識の権限説明を Info.plist に設定
#   4) 通知デリゲートを AppDelegate に設定
#
# 使い方:
#   chmod +x scripts/setup_ios.sh
#   ./scripts/setup_ios.sh
#
# この後は docs/ios-release.md の「3. Xcode」以降へ。
set -euo pipefail

# ===== 設定（必要なら書き換え）=====
ORG="com.tmk4men"          # バンドルID接頭辞 → com.tmk4men.dolimit
PROJECT_NAME="dolimit"     # 内部識別子（表示名ではない。据え置き推奨）
DISPLAY_NAME="やっとこ"    # ホーム画面に出るアプリ名

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

echo "==> [1/5] Flutter 依存を取得"
flutter pub get

echo "==> [2/5] iOS プロジェクトを生成（バンドルID: ${ORG}.${PROJECT_NAME}）"
flutter create . --platforms=ios --org "$ORG" --project-name "$PROJECT_NAME"

echo "==> [3/5] アプリアイコンを生成（assets/icon/app_icon.png → AppIcon.appiconset）"
dart run flutter_launcher_icons

PLIST="ios/Runner/Info.plist"
echo "==> [4/5] Info.plist を設定（表示名・権限説明）"
set_plist() {
  /usr/libexec/PlistBuddy -c "Set :$1 $2" "$PLIST" 2>/dev/null \
    || /usr/libexec/PlistBuddy -c "Add :$1 string $2" "$PLIST"
}
set_plist CFBundleDisplayName "$DISPLAY_NAME"
set_plist NSMicrophoneUsageDescription "音声でタスクを入力するためにマイクを使用します。"
set_plist NSSpeechRecognitionUsageDescription "話した言葉を文字にしてタスクにするため、音声認識を使用します。"

# 輸出コンプライアンス（暗号化）を「非適用」に固定 → 提出時の暗号化の質問が出ない。
# 独自暗号なし・標準HTTPS(Apple/OS)のみ・端末内保存のため false でよい。
/usr/libexec/PlistBuddy -c "Set :ITSAppUsesNonExemptEncryption false" "$PLIST" 2>/dev/null \
  || /usr/libexec/PlistBuddy -c "Add :ITSAppUsesNonExemptEncryption bool false" "$PLIST"

echo "==> [5/5] AppDelegate に通知デリゲートを設定"
cat > ios/Runner/AppDelegate.swift <<'SWIFT'
import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    // フォアグラウンドでもローカル通知を表示できるようにする（flutter_local_notifications）
    if #available(iOS 10.0, *) {
      UNUserNotificationCenter.current().delegate = self as UNUserNotificationCenterDelegate
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
SWIFT

echo ""
echo "✅ セットアップ完了。バンドルID = ${ORG}.${PROJECT_NAME} / 表示名 = ${DISPLAY_NAME}"
echo "   次は docs/ios-release.md の「3. Xcode（署名）」→「4. ビルドとアップロード」へ。"
