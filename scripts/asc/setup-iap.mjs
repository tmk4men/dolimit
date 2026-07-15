#!/usr/bin/env node
// App内課金（IAP）を config から一気に用意する。アプリ非依存・冪等・既定ドライラン。
//   作成 → 日本語ローカライズ（表示名/説明）→ 円価格の設定。
// 既存の productId はそのまま再利用（重複作成しない）。実行は --yes。
//
//   node <path>/setup-iap.mjs ./asc.config.json <appId>          # 下見（送信なし）
//   node <path>/setup-iap.mjs ./asc.config.json <appId> --yes    # 反映
//
// 前提: App Store Connect に App 作成済み。価格設定には「有料App契約」への同意が必要
//       （未同意だと価格スケジュール作成が失敗する）。
// 補足: 各IAPの「審査用スクリーンショット」と、審査提出への添付は画面で行う（APIでは非対応にしている）。

import path from "node:path";
import { fileURLToPath } from "node:url";
import { api, loadAppConfig } from "./lib.mjs";

const BASE = "https://api.appstoreconnect.apple.com";
const HERE = path.dirname(fileURLToPath(import.meta.url));
const argv = process.argv.slice(2);
const EXECUTE = argv.includes("--yes");

const APP = loadAppConfig(argv, HERE);
const appId = APP.appId;
const LOCALE = APP.locale || "ja";
const IAPS = APP.iaps;
if (!IAPS || !IAPS.length) {
  console.error("設定に iaps がありません（asc.config.json の iaps を確認）。");
  process.exit(1);
}

function log(s) {
  console.log(s);
}

// Apple が返す relationship の related リンクをそのまま使う（v1/v2 の差異を吸収）。
function relatedPath(iap, name, fallback) {
  const link = iap && iap.relationships && iap.relationships[name] && iap.relationships[name].links && iap.relationships[name].links.related;
  return link ? link.replace(BASE, "") : fallback;
}

// productId 一致の既存IAPを取得（関係リンク付き）。
async function findIap(productId) {
  const list = await api("GET", `/v1/apps/${appId}/inAppPurchasesV2?limit=200`);
  return (list.data || []).find((p) => p.attributes.productId === productId) || null;
}

// 価格ポイント(JPN)を全ページ探して、指定円に一致する pricePoint id を返す。
async function findPricePointJPN(startPath, yen) {
  const sep = startPath.includes("?") ? "&" : "?";
  let endpoint = `${startPath}${sep}filter[territory]=JPN&limit=200`;
  while (endpoint) {
    const r = await api("GET", endpoint);
    for (const pp of r.data || []) {
      if (Number(pp.attributes.customerPrice) === Number(yen)) return pp.id;
    }
    const next = r.links && r.links.next;
    endpoint = next ? next.replace(BASE, "") : null;
  }
  return null;
}

async function ensureIap(spec) {
  log(`\n■ ${spec.productId}（${spec.name} / ¥${spec.priceYen}）`);

  // 1) 既存を探す（productId 一致）。なければ作成。
  let iap = await findIap(spec.productId);

  if (iap) {
    log(`  ・既存を再利用: ${iap.id}（state=${iap.attributes.state}）`);
  } else if (!EXECUTE) {
    log(`  ＋作成予定: ${spec.type} name="${spec.referenceName || spec.name}"`);
    log(`  ＋ローカライズ予定(${LOCALE}): 表示名="${spec.name}" 説明="${spec.description}"`);
    log(`  ＋価格予定: ¥${spec.priceYen}（JPNの価格ポイントから設定）`);
    return;
  } else {
    await api("POST", "/v2/inAppPurchases", {
      data: {
        type: "inAppPurchases",
        attributes: {
          name: spec.referenceName || spec.name,
          productId: spec.productId,
          inAppPurchaseType: spec.type || "NON_CONSUMABLE",
        },
        relationships: { app: { data: { type: "apps", id: appId } } },
      },
    });
    iap = await findIap(spec.productId); // 関係リンク付きで取り直す
    log(`  ✅ 作成: ${iap.id}`);
  }

  // 2) 日本語ローカライズ（表示名・説明）
  const locsPath = relatedPath(iap, "inAppPurchaseLocalizations", `/v2/inAppPurchases/${iap.id}/inAppPurchaseLocalizations`);
  const sep = locsPath.includes("?") ? "&" : "?";
  const locs = await api("GET", `${locsPath}${sep}limit=50`);
  const loc = (locs.data || []).find((l) => l.attributes.locale === LOCALE);
  const attrs = { name: spec.name, description: spec.description };
  if (!EXECUTE) {
    log(`  ＋ローカライズ${loc ? "更新" : "作成"}予定(${LOCALE}): 表示名="${spec.name}" 説明="${spec.description}"`);
  } else if (loc) {
    await api("PATCH", `/v1/inAppPurchaseLocalizations/${loc.id}`, {
      data: { type: "inAppPurchaseLocalizations", id: loc.id, attributes: attrs },
    });
    log(`  ✅ ローカライズ更新(${LOCALE})`);
  } else {
    await api("POST", "/v1/inAppPurchaseLocalizations", {
      data: {
        type: "inAppPurchaseLocalizations",
        attributes: { ...attrs, locale: LOCALE },
        relationships: { inAppPurchaseV2: { data: { type: "inAppPurchases", id: iap.id } } },
      },
    });
    log(`  ✅ ローカライズ作成(${LOCALE})`);
  }

  // 3) 価格（JPN・¥指定）
  if (!EXECUTE) {
    log(`  ＋価格予定: ¥${spec.priceYen}`);
    return;
  }
  const ppPath = relatedPath(iap, "pricePoints", `/v2/inAppPurchases/${iap.id}/pricePoints`);
  const ppId = await findPricePointJPN(ppPath, spec.priceYen);
  if (!ppId) {
    log(`  ⚠ ¥${spec.priceYen} に一致する価格ポイントが見つからず（画面で価格設定してください）`);
    return;
  }
  try {
    const TMP = "price-1";
    await api("POST", "/v1/inAppPurchasePriceSchedules", {
      data: {
        type: "inAppPurchasePriceSchedules",
        relationships: {
          inAppPurchase: { data: { type: "inAppPurchases", id: iap.id } },
          baseTerritory: { data: { type: "territories", id: "JPN" } },
          manualPrices: { data: [{ type: "inAppPurchasePrices", id: TMP }] },
        },
      },
      included: [
        {
          type: "inAppPurchasePrices",
          id: TMP,
          attributes: { startDate: null },
          relationships: {
            inAppPurchasePricePoint: {
              data: { type: "inAppPurchasePricePoints", id: ppId },
            },
          },
        },
      ],
    });
    log(`  ✅ 価格設定: ¥${spec.priceYen}`);
  } catch (e) {
    const last = (e.message || "").split("\n").slice(-1)[0];
    log(`  ⚠ 価格設定失敗（有料App契約の同意が必要な場合あり）: ${last}`);
  }
}

async function main() {
  log(`設定: ${APP.path}`);
  log(`アプリ ${appId} の App内課金 ${EXECUTE ? "【反映】" : "【ドライラン：変更しません】"}`);
  for (const spec of IAPS) {
    await ensureIap(spec);
  }
  log(`\n${EXECUTE ? "完了。" : "ドライラン完了。問題なければ --yes で反映してください。"}`);
  log("残り(画面): 各IAPの審査用スクショ添付 / 版の「App内課金」に紐付けて審査提出。");
}

main().catch((e) => {
  console.error("\n[エラー] " + (e.message || e));
  console.error("※ 冪等なので、原因を直して再実行すればOKです。");
  process.exit(1);
});
