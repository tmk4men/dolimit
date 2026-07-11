/// 報酬型広告（視聴すると一時的に枠が増える）の抽象。
///
/// 通知や UI に広告は出さない。報酬型広告だけを、ユーザーが自分から
/// 押したときにのみ表示する。
///
/// ## 実装が未接続な理由
///
/// `google_mobile_ads` は `AndroidManifest.xml` の
/// `com.google.android.gms.ads.APPLICATION_ID`（と iOS の `GADApplicationIdentifier`）が
/// 無いと**起動時にクラッシュする**。このリポジトリは `android/` `ios/` を
/// `.gitignore` して CI が `flutter create` で毎回生成するため、そのアプリ ID を
/// 置く場所が無い。SDK を入れた時点で Android ビルドが確実に落ちる。
///
/// そこで枠拡張の仕組み（[AppState.grantAdBoost]）だけ先に実装し、
/// 広告の表示はこの差し込み口に閉じ込めてある。AdMob アカウントを用意して
/// プラットフォームディレクトリを固定できるようになったら、
/// [StubRewardedAdService] を実装に差し替えるだけで動く。
library;

enum AdOutcome {
  /// 最後まで視聴した。報酬を与えてよい。
  rewarded,

  /// 途中で閉じた。報酬なし。
  dismissed,

  /// 在庫なし・未設定・オフラインなど。
  unavailable,

  failed,
}

class AdResult {
  final AdOutcome outcome;
  final String? message;
  const AdResult(this.outcome, [this.message]);

  bool get earned => outcome == AdOutcome.rewarded;
}

abstract class RewardedAdService {
  /// 広告を配信できる状態か（＝広告実装が接続済みか）。
  ///
  /// これが false の間は、広告関連の導線を UI に**一切出さない**
  /// （「準備中」ではなく、そもそも広告が無い体験にする）。
  /// AdMob のアプリ ID を入れて実装（`StubRewardedAdService` の差し替え）を
  /// 接続したら true を返すようにすれば、広告の導線が自動的に現れる。
  bool get isConfigured;

  /// 広告を出せる見込みがあるか。
  Future<bool> isAvailable();

  /// 報酬型広告を表示し、視聴完了を待つ。
  Future<AdResult> showRewardedAd();

  static RewardedAdService create() => const StubRewardedAdService();
}

/// 広告 SDK が未接続の環境。広告の導線は出さない。
class StubRewardedAdService implements RewardedAdService {
  const StubRewardedAdService();

  @override
  bool get isConfigured => false;

  @override
  Future<bool> isAvailable() async => false;

  @override
  Future<AdResult> showRewardedAd() async =>
      const AdResult(AdOutcome.unavailable, '広告は準備中です');
}

/// 広告を見せて、視聴し切ったらブーストを与える。
/// 呼び出し側に見せるメッセージを返す（null=何も出さない）。
Future<String?> redeemAdBoost(RewardedAdService ads, void Function() grant) async {
  final result = await ads.showRewardedAd();
  if (result.earned) {
    grant();
    return '枠を24時間ぶん広げました';
  }
  return switch (result.outcome) {
    // 自分で閉じたのだから、失敗として責めない。
    AdOutcome.dismissed => null,
    _ => result.message ?? '広告を表示できませんでした',
  };
}
