#!/usr/bin/env node
// App Store Connect の自動投入を「一気に」実行するランナー。アプリ非依存。
//   1) 掲載文（setup-metadata.mjs）… 説明/キーワード/宣伝文/サブタイトル/カテゴリ/審査メモ/URL
//   2) App内課金（setup-iap.mjs）  … 作成/日本語ローカライズ/円価格
// 既定はドライラン（送信なし）。実際に反映するときだけ --yes。冪等。
//
//   node <path>/setup-all.mjs ./asc.config.json <appId>          # 下見（送信なし）
//   node <path>/setup-all.mjs ./asc.config.json <appId> --yes    # 反映
//
// APIで入らない残り（画面作業）は最後にまとめて表示する。

import { spawnSync } from "node:child_process";
import path from "node:path";
import { fileURLToPath } from "node:url";

const HERE = path.dirname(fileURLToPath(import.meta.url));
const args = process.argv.slice(2);
const EXECUTE = args.includes("--yes");

// iaps が無い config でも動くよう、課金ステップは設定があるときだけ動く（スクリプト側で判定）。
const STEPS = [
  { file: "setup-metadata.mjs", title: "掲載文（説明・キーワード・宣伝文・サブタイトル・カテゴリ・審査メモ）" },
  { file: "setup-iap.mjs", title: "App内課金（作成・日本語ローカライズ・円価格）", optional: true },
];

for (const step of STEPS) {
  console.log(`\n================ ${step.title} ================`);
  const r = spawnSync(process.execPath, [path.join(HERE, step.file), ...args], { stdio: "inherit" });
  if (r.status !== 0) {
    // iaps 未設定など「設定に無いだけ」の失敗は致命ではないので続行（optional のみ）。
    if (step.optional) {
      console.log(`（${step.file} はスキップ／設定なしの可能性。続行します）`);
      continue;
    }
    console.error(`\n[中断] ${step.file} が失敗しました。原因を直して再実行してください（冪等）。`);
    process.exit(r.status || 1);
  }
}

console.log("\n──────────────────────────────────────────");
console.log(EXECUTE ? "✅ 自動投入（掲載文＋課金）完了。" : "ドライラン完了。問題なければ末尾に --yes を付けて再実行。");
console.log("APIで入らない残り（App Store Connect の画面）:");
console.log("  1. スクリーンショット（6.7インチ 必須）");
console.log("  2. 各App内課金の 審査用スクショ を添付し、版の「App内課金」に紐付け");
console.log("  3. Appのプライバシー（データ収集の質問票）");
console.log("  4. App Review Information の 連絡先（氏名・電話 +81… ・メール）");
console.log("  5. ビルドを選択して 審査に提出");
