import 'package:flutter/widgets.dart';

/// Web / 未対応環境向け。広告は一切扱わない。
Future<void> initAds() async {}

Widget buildAdBanner(BuildContext context) => const SizedBox.shrink();
