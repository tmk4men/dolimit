import '../models/enums.dart';

/// 登録上限。タスクを無限に溜めさせないためのプロダクト中心思想。
class Limits {
  static const int box = 5;
  static const int today = 10;
  static const int later = 10;
  static const int genre = 3;

  // Pro 購入時に各枠へ加算される拡張ぶん。
  static const int proBonusBox = 10;
  static const int proBonusToday = 5;
  static const int proBonusLater = 15;
  static const int proBonusGenre = 5;

  // ブースト（¥100 の買い切り）で恒久的に加算される拡張ぶん。Pro と重ねがけできる。
  static const int boostBonusBox = 5;
  static const int boostBonusToday = 2;
  static const int boostBonusLater = 5;

  static int boostBonusFor(TaskStatus status) => switch (status) {
        TaskStatus.box => boostBonusBox,
        TaskStatus.today => boostBonusToday,
        TaskStatus.later => boostBonusLater,
        _ => 0,
      };

  static int? capacityFor(TaskStatus status) => switch (status) {
        TaskStatus.box => box,
        TaskStatus.today => today,
        TaskStatus.later => later,
        _ => null,
      };

  static int proBonusFor(TaskStatus status) => switch (status) {
        TaskStatus.box => proBonusBox,
        TaskStatus.today => proBonusToday,
        TaskStatus.later => proBonusLater,
        _ => 0,
      };

  static String fullMessage(TaskStatus status) => switch (status) {
        TaskStatus.box => 'BOX、そろそろいっぱい',
        TaskStatus.today => 'TODAY、そろそろいっぱい',
        TaskStatus.later => 'LATER、そろそろいっぱい',
        _ => '',
      };
}
