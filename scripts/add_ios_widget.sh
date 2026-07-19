#!/usr/bin/env bash
#
# iOS ホーム画面ウィジェット（DoLimitWidget）を ios/ プロジェクトへ組み込む。
# setup_ios.sh から自動で呼ばれる。単体でも再実行できる（冪等）。
#
#   ./scripts/add_ios_widget.sh
#
# 前提: 先に flutter create（= setup_ios.sh）で ios/ が生成済みであること。
# 任意: TEAM_ID=XXXXXXXXXX ./scripts/add_ios_widget.sh で Widget にも署名チームを設定。
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

WIDGET_NAME="DoLimitWidget"
APP_GROUP="group.dolimit.widget"
SRC="scripts/ios_widget"
DEST="ios/${WIDGET_NAME}"

[ -d ios ] || { echo "❌ ios/ がありません。先に ./scripts/setup_ios.sh を実行してください。"; exit 1; }

echo "==> [1/3] ウィジェットのソースを配置 → ${DEST}/"
mkdir -p "$DEST"
cp "native_widget_reference/ios/DoLimitWidget.swift" "${DEST}/DoLimitWidget.swift"
cp "${SRC}/Info.plist"                                "${DEST}/Info.plist"
cp "${SRC}/DoLimitWidget.entitlements"                "${DEST}/DoLimitWidget.entitlements"

echo "==> [2/3] Runner に App Group(${APP_GROUP}) を付与"
RUNNER_ENT="ios/Runner/Runner.entitlements"
if [ -f "$RUNNER_ENT" ]; then
  # 既存 entitlements があれば App Group だけ追記（重複時は入れない）
  /usr/libexec/PlistBuddy -c "Add :com.apple.security.application-groups array" "$RUNNER_ENT" 2>/dev/null || true
  if ! /usr/libexec/PlistBuddy -c "Print :com.apple.security.application-groups" "$RUNNER_ENT" 2>/dev/null | grep -q "$APP_GROUP"; then
    /usr/libexec/PlistBuddy -c "Add :com.apple.security.application-groups: string ${APP_GROUP}" "$RUNNER_ENT"
  fi
else
  cp "${SRC}/Runner.entitlements" "$RUNNER_ENT"
fi

echo "==> [3/3] Xcode プロジェクトへターゲット追加（xcodeproj）"
if ! ruby -e "require 'xcodeproj'" >/dev/null 2>&1; then
  echo "    xcodeproj gem を導入します..."
  gem install xcodeproj >/dev/null 2>&1 || sudo gem install xcodeproj
fi
ruby scripts/add_ios_widget.rb

echo ""
echo "✅ DoLimitWidget を iOS プロジェクトに統合しました。"
echo "   次にやること:"
echo "     open ios/Runner.xcworkspace"
echo "     → Runner と DoLimitWidget の【両ターゲット】で Signing の Team を選択（自動署名）。"
echo "     → flutter build ipa --export-method app-store でビルド。"
