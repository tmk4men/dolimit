import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../util/limits.dart';

/// とことんシンプルなオンボーディング。説明より「触って分かる」。
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _controller = PageController();
  int _page = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _next() {
    _controller.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
  }

  Future<void> _finish({bool requestPermission = false}) async {
    final app = context.read<AppState>();
    if (requestPermission) await app.notifier.requestPermission();
    app.updateSettings((s) => s.onboardingDone = true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView(
                controller: _controller,
                onPageChanged: (i) => setState(() => _page = i),
                children: [
                  _concept(),
                  _swipe(),
                  _boxes(),
                  _notify(),
                ],
              ),
            ),
            // ドット
            Padding(
              padding: const EdgeInsets.only(bottom: 24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(4, (i) {
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: i == _page ? 20 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: i == _page ? AppTheme.ink : AppTheme.line,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  );
                }),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 1. 一言コンセプト
  Widget _concept() {
    return _page1Layout(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('タスク、溜めすぎてない？',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900)),
          const SizedBox(height: 12),
          const Text('BOXに入れて、左右に仕分けるだけ。',
              style: TextStyle(fontSize: 15, color: AppTheme.sub)),
          const SizedBox(height: 40),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: AppTheme.ink, padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 14)),
            onPressed: _next,
            child: const Text('試してみる'),
          ),
        ],
      ),
    );
  }

  // 2. スワイプ体験
  Widget _swipe() => const _SwipeExperience();

  // 3. 3つの箱
  Widget _boxes() {
    return _page1Layout(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _boxRow('BOX', Limits.box, AppTheme.boxAccent),
          const SizedBox(height: 12),
          _boxRow('TODAY', Limits.today, AppTheme.todayAccent),
          const SizedBox(height: 12),
          _boxRow('LATER', Limits.later, AppTheme.laterAccent),
          const SizedBox(height: 28),
          const Text('溜めすぎないための上限です。',
              style: TextStyle(fontSize: 14, color: AppTheme.sub)),
          const SizedBox(height: 36),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: AppTheme.ink, padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 14)),
            onPressed: _next,
            child: const Text('次へ'),
          ),
        ],
      ),
    );
  }

  Widget _boxRow(String label, int cap, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SizedBox(
          width: 110,
          child: Text(label,
              textAlign: TextAlign.right,
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: color)),
        ),
        const SizedBox(width: 16),
        Text('$cap', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700)),
      ],
    );
  }

  // 4. 通知とバッジ
  Widget _notify() {
    return _page1Layout(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.notifications_active_outlined, size: 56, color: AppTheme.ink),
          const SizedBox(height: 20),
          const Text('TODAYの数を表示します',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
          const SizedBox(height: 12),
          const Text('忘れないために、バッジと通知を使います。',
              textAlign: TextAlign.center, style: TextStyle(fontSize: 14, color: AppTheme.sub)),
          const SizedBox(height: 36),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: AppTheme.ink, padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 14)),
            onPressed: () => _finish(requestPermission: true),
            child: const Text('通知を許可する'),
          ),
          TextButton(onPressed: () => _finish(), child: const Text('あとで')),
        ],
      ),
    );
  }

  Widget _page1Layout({required Widget child}) {
    return Padding(padding: const EdgeInsets.all(32), child: Center(child: child));
  }
}

/// スワイプ体験ページ。サンプルカードを実際に左右スワイプできる。
class _SwipeExperience extends StatefulWidget {
  const _SwipeExperience();
  @override
  State<_SwipeExperience> createState() => _SwipeExperienceState();
}

class _SwipeExperienceState extends State<_SwipeExperience> {
  final List<String> _samples = ['歯医者を予約する', 'アプリの通知設計を見る', '読書10分'];
  String? _feedback;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        children: [
          const SizedBox(height: 8),
          const Text('左右にスワイプ', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
          const SizedBox(height: 6),
          // ヒント
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              Text('← LATER', style: TextStyle(color: AppTheme.laterAccent, fontWeight: FontWeight.w700)),
              Text('TODAY →', style: TextStyle(color: AppTheme.todayAccent, fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 20),
          Expanded(
            child: _samples.isEmpty
                ? _doneBlock()
                : Center(
                    child: ListView(
                      shrinkWrap: true,
                      children: [
                        for (final s in _samples.take(1))
                          Dismissible(
                            key: ValueKey(s),
                            background: _bg(Alignment.centerLeft, AppTheme.todayAccent, 'TODAY →'),
                            secondaryBackground: _bg(Alignment.centerRight, AppTheme.laterAccent, '← LATER'),
                            onDismissed: (dir) {
                              setState(() {
                                _feedback = dir == DismissDirection.startToEnd ? 'TODAYへ' : 'LATERへ';
                                _samples.remove(s);
                              });
                            },
                            child: _sampleCard(s),
                          ),
                      ],
                    ),
                  ),
          ),
          if (_feedback != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(_feedback!,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            ),
        ],
      ),
    );
  }

  Widget _doneBlock() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.swipe, size: 40, color: AppTheme.sub),
        const SizedBox(height: 12),
        const Text('その調子。', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
        const SizedBox(height: 24),
        FilledButton(
          style: FilledButton.styleFrom(
              backgroundColor: AppTheme.ink, padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 14)),
          onPressed: () {
            // 次のページへスクロール
            final state = context.findAncestorStateOfType<_OnboardingScreenState>();
            state?._next();
          },
          child: const Text('次へ'),
        ),
      ],
    );
  }

  Widget _sampleCard(String title) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.line),
        boxShadow: const [BoxShadow(color: Color(0x14000000), blurRadius: 12, offset: Offset(0, 4))],
      ),
      child: Text(title,
          textAlign: TextAlign.center, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
    );
  }

  Widget _bg(Alignment align, Color color, String label) {
    return Container(
      alignment: align,
      padding: const EdgeInsets.symmetric(horizontal: 28),
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(20)),
      child: Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16)),
    );
  }
}
