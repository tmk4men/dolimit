import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dolimit/data/store.dart';
import 'package:dolimit/models/enums.dart';
import 'package:dolimit/services/ad_service.dart';
import 'package:dolimit/services/notification_service.dart';
import 'package:dolimit/state/app_state.dart';
import 'package:dolimit/util/limits.dart';

/// 任意の結果を返す広告スタブ。
class FakeAdService implements RewardedAdService {
  FakeAdService(this.result);
  final AdResult result;
  int shown = 0;

  @override
  Future<bool> isAvailable() async => result.outcome != AdOutcome.unavailable;

  @override
  Future<AdResult> showRewardedAd() async {
    shown++;
    return result;
  }
}

Future<AppState> newState() async {
  SharedPreferences.setMockInitialValues({});
  final store = await Store.open();
  final app = AppState(store: store, notifier: StubNotificationService());
  await app.load();
  return app;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('広告ブーストの仕組み', () {
    test('付与すると各箱の実効上限が広がる', () async {
      final app = await newState();
      expect(app.isBoosted, isFalse);
      expect(app.capacityFor(TaskStatus.box), Limits.box);

      app.grantAdBoost();

      expect(app.isBoosted, isTrue);
      expect(app.capacityFor(TaskStatus.box), Limits.box + Limits.adBoostBox);
      expect(app.capacityFor(TaskStatus.today), Limits.today + Limits.adBoostToday);
      expect(app.capacityFor(TaskStatus.later), Limits.later + Limits.adBoostLater);
      expect(app.genreCap, Limits.genre, reason: 'ジャンルはブースト対象外');
    });

    test('Pro とブーストは重ねがけできる', () async {
      final app = await newState();
      app.setPro(true);
      app.grantAdBoost();

      expect(app.capacityFor(TaskStatus.box),
          Limits.box + Limits.proBonusBox + Limits.adBoostBox);
    });

    test('ブースト中は基本上限を超えて追加できる', () async {
      final app = await newState();
      for (var i = 0; i < Limits.box; i++) {
        expect(app.addToBox('t$i'), isTrue);
      }
      expect(app.addToBox('overflow'), isFalse);

      app.grantAdBoost();

      for (var i = 0; i < Limits.adBoostBox; i++) {
        expect(app.addToBox('boost$i'), isTrue);
      }
      expect(app.addToBox('overflow2'), isFalse, reason: '広げた上限も守る');
      expect(app.count(TaskStatus.box), Limits.box + Limits.adBoostBox);
    });

    test('重ねて視聴すると期限が延びる', () async {
      final app = await newState();
      app.grantAdBoost();
      final first = app.settings.boostUntil!;

      app.grantAdBoost();
      final second = app.settings.boostUntil!;

      expect(second.isAfter(first), isTrue);
      expect(second.difference(first), Limits.adBoostDuration);
    });

    test('期限が切れると runMaintenance で基本上限へ戻る', () async {
      final app = await newState();
      app.grantAdBoost();
      expect(app.capacityFor(TaskStatus.box), Limits.box + Limits.adBoostBox);

      // 期限を過去にする
      app.settings.boostUntil = DateTime.now().subtract(const Duration(minutes: 1));
      expect(app.isBoosted, isFalse, reason: '過去の期限は無効');

      app.runMaintenance();

      expect(app.settings.boostUntil, isNull, reason: '失効した期限は片付ける');
      expect(app.capacityFor(TaskStatus.box), Limits.box);
      expect(app.boostRemaining, isNull);
    });

    test('ブーストは保存され、読み直しても続く', () async {
      SharedPreferences.setMockInitialValues({});
      final store = await Store.open();
      final app = AppState(store: store, notifier: StubNotificationService());
      await app.load();
      app.grantAdBoost();

      final reloaded = AppState(store: store, notifier: StubNotificationService());
      await reloaded.load();

      expect(reloaded.isBoosted, isTrue);
      expect(reloaded.capacityFor(TaskStatus.box), Limits.box + Limits.adBoostBox);
    });

    test('ブースト中に上限超過のまま失効しても既存タスクは消えない', () async {
      final app = await newState();
      app.grantAdBoost();
      for (var i = 0; i < Limits.box + Limits.adBoostBox; i++) {
        app.addToBox('t$i');
      }

      app.settings.boostUntil = DateTime.now().subtract(const Duration(minutes: 1));
      app.runMaintenance();

      expect(app.count(TaskStatus.box), Limits.box + Limits.adBoostBox);
      expect(app.isFull(TaskStatus.box), isTrue, reason: '追加はできない');
      expect(app.addToBox('もう入らない'), isFalse);
    });
  });

  group('広告視聴からブースト付与まで', () {
    test('視聴し切ればブーストされ、成功を伝える', () async {
      final app = await newState();
      final ads = FakeAdService(const AdResult(AdOutcome.rewarded));

      final message = await redeemAdBoost(ads, app.grantAdBoost);

      expect(ads.shown, 1);
      expect(app.isBoosted, isTrue);
      expect(message, '枠を24時間ぶん広げました');
    });

    test('途中で閉じたらブーストせず、何も言わない', () async {
      final app = await newState();
      final ads = FakeAdService(const AdResult(AdOutcome.dismissed));

      final message = await redeemAdBoost(ads, app.grantAdBoost);

      expect(app.isBoosted, isFalse);
      expect(message, isNull, reason: '自分で閉じたのだから責めない');
    });

    test('広告が出せなければ理由を伝える', () async {
      final app = await newState();
      final ads = FakeAdService(const AdResult(AdOutcome.unavailable, '広告は準備中です'));

      final message = await redeemAdBoost(ads, app.grantAdBoost);

      expect(app.isBoosted, isFalse);
      expect(message, '広告は準備中です');
    });

    test('失敗時もブーストしない', () async {
      final app = await newState();
      final ads = FakeAdService(const AdResult(AdOutcome.failed));

      final message = await redeemAdBoost(ads, app.grantAdBoost);

      expect(app.isBoosted, isFalse);
      expect(message, '広告を表示できませんでした');
    });
  });

  group('未接続のスタブ', () {
    test('常に利用不可を返す', () async {
      const ads = StubRewardedAdService();
      expect(await ads.isAvailable(), isFalse);
      final r = await ads.showRewardedAd();
      expect(r.earned, isFalse);
      expect(r.message, '広告は準備中です');
    });
  });
}
