import '../models/enums.dart';

/// 登録上限。タスクを無限に溜めさせないためのプロダクト中心思想。
class Limits {
  static const int box = 15;
  static const int today = 10;
  static const int later = 20;
  static const int genre = 5;

  static int? capacityFor(TaskStatus status) => switch (status) {
        TaskStatus.box => box,
        TaskStatus.today => today,
        TaskStatus.later => later,
        _ => null,
      };

  static String fullMessage(TaskStatus status) => switch (status) {
        TaskStatus.box => 'BOXがいっぱいです。先に仕分けてください。',
        TaskStatus.today => 'TODAYがいっぱいです。1件完了するか、LATERへ移動してください。',
        TaskStatus.later => 'LATERがいっぱいです。整理してください。',
        _ => '',
      };
}
