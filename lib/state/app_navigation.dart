import 'package:flutter/foundation.dart';

/// 下部タブの選択状態。通知タップなど画面ツリーの外から
/// タブを切り替えたいので、RootTab の内部状態ではなく共有状態に置く。
class AppNavigation extends ChangeNotifier {
  static const int homeTab = 0;
  static const int boxTab = 1;
  static const int todayTab = 2;
  static const int laterTab = 3;
  static const int settingsTab = 4;

  int _tab = homeTab;
  int get tab => _tab;

  void goTo(int index) {
    if (_tab == index) return;
    _tab = index;
    notifyListeners();
  }
}
