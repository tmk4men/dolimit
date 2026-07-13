import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/task.dart';
import '../models/enums.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import 'ui_kit.dart';

/// LATER 詳細設定：開始日 / 開始時刻 / 事前通知 / 自動移動 ON/OFF
class LaterDetailSheet extends StatefulWidget {
  final TaskItem task;
  const LaterDetailSheet({super.key, required this.task});

  static Future<void> present(BuildContext context, TaskItem task) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.c.card,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => LaterDetailSheet(task: task),
    );
  }

  @override
  State<LaterDetailSheet> createState() => _LaterDetailSheetState();
}

/// 事前通知プリセット
class _Preset {
  final String label;
  final int? value; // null=なし
  final ReminderOffsetUnit? unit;
  final bool custom;
  const _Preset(this.label, this.value, this.unit, {this.custom = false});
}

const _presets = <_Preset>[
  _Preset('なし', null, null),
  _Preset('開始時刻ちょうど', 0, ReminderOffsetUnit.minute),
  _Preset('5分前', 5, ReminderOffsetUnit.minute),
  _Preset('10分前', 10, ReminderOffsetUnit.minute),
  _Preset('30分前', 30, ReminderOffsetUnit.minute),
  _Preset('1時間前', 1, ReminderOffsetUnit.hour),
  _Preset('3時間前', 3, ReminderOffsetUnit.hour),
  _Preset('1日前', 1, ReminderOffsetUnit.day),
  _Preset('カスタム', null, null, custom: true),
];

class _LaterDetailSheetState extends State<LaterDetailSheet> {
  late DateTime? _date = widget.task.startAt;
  late bool _timeSpecified =
      !(widget.task.startDateOnly) && widget.task.startAt != null;
  late TimeOfDay _time = TimeOfDay(
      hour: widget.task.startAt?.hour ?? 9,
      minute: widget.task.startAt?.minute ?? 0);
  late bool _autoMove = widget.task.autoMoveToToday;

  late int _presetIndex = _initialPreset();
  late int _customValue = widget.task.reminderOffsetValue ?? 10;
  late ReminderOffsetUnit _customUnit =
      widget.task.reminderOffsetUnit ?? ReminderOffsetUnit.minute;

  int _initialPreset() {
    if (!widget.task.reminderEnabled) return 0;
    final v = widget.task.reminderOffsetValue;
    final u = widget.task.reminderOffsetUnit;
    for (var i = 0; i < _presets.length; i++) {
      if (!_presets[i].custom &&
          _presets[i].value == v &&
          _presets[i].unit == u) {
        return i;
      }
    }
    return _presets.length - 1; // custom
  }

  @override
  Widget build(BuildContext context) {
    final preset = _presets[_presetIndex];
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        left: 20,
        right: 20,
        top: 16,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SheetHandle(),
            const SizedBox(height: 6),
            const Text('LATER 詳細設定',
                style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900)),
            const SizedBox(height: 12),

            // 開始日：トグルをオンにするとカレンダー→時計の順で設定できる。
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              activeColor: context.c.laterAccent,
              value: _date != null,
              onChanged: (v) async {
                if (v) {
                  await _pickSchedule();
                } else {
                  _date = null;
                  _timeSpecified = false;
                }
                if (mounted) setState(() {});
              },
              title: const Text('開始日を設定'),
            ),
            if (_date != null)
              ListTile(
                contentPadding: const EdgeInsets.only(left: 8),
                leading: Icon(Icons.event, color: context.c.laterAccent),
                title: Text(
                  _timeSpecified
                      ? '${_fmtDate(_date!)}  ${_time.format(context)}'
                      : '${_fmtDate(_date!)}（時刻の指定なし）',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                trailing: const Icon(Icons.edit_calendar_outlined, size: 20),
                onTap: () async {
                  await _pickSchedule();
                  if (mounted) setState(() {});
                },
              ),

            const Divider(height: 24),

            // 事前通知
            const Text('事前通知', style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            DropdownButton<int>(
              isExpanded: true,
              value: _presetIndex,
              items: [
                for (var i = 0; i < _presets.length; i++)
                  DropdownMenuItem(value: i, child: Text(_presets[i].label)),
              ],
              onChanged: (v) => setState(() => _presetIndex = v ?? 0),
            ),
            if (preset.custom)
              Row(
                children: [
                  SizedBox(
                    width: 90,
                    child: TextFormField(
                      initialValue: '$_customValue',
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: '数値'),
                      // 負値は「開始後に通知」になってしまうので受け付けない。
                      onChanged: (s) {
                        final v = int.tryParse(s);
                        if (v != null && v >= 0) _customValue = v;
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  DropdownButton<ReminderOffsetUnit>(
                    value: _customUnit,
                    items: ReminderOffsetUnit.values
                        .map((u) =>
                            DropdownMenuItem(value: u, child: Text(u.label)))
                        .toList(),
                    onChanged: (u) =>
                        setState(() => _customUnit = u ?? _customUnit),
                  ),
                ],
              ),

            const Divider(height: 24),

            // 自動移動
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              activeColor: context.c.laterAccent,
              value: _autoMove,
              onChanged: (v) => setState(() => _autoMove = v),
              title: const Text('開始日にTODAYへ自動移動'),
            ),

            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(backgroundColor: context.c.ink),
                onPressed: _save,
                child: const Text('保存'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// カレンダーで日付 → 時計で時刻、の順に設定する。
  /// 時計の「指定しない」を押したら、日付だけ（時刻の指定なし）にする。
  /// 日付選択をキャンセルしたら何も変更しない。
  ///
  /// 呼び出し側で setState すること（このメソッドはフィールドを書き換えるだけ）。
  Future<void> _pickSchedule() async {
    final now = DateTime.now();
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _date ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 5),
      helpText: '開始日を選ぶ',
    );
    if (pickedDate == null || !mounted) return; // キャンセルなら据え置き
    final pickedTime = await showTimePicker(
      context: context,
      initialTime: _time,
      helpText: '開始時刻を選ぶ',
      cancelText: '指定しない',
      confirmText: '設定',
    );
    _date = pickedDate;
    if (pickedTime != null) {
      _time = pickedTime;
      _timeSpecified = true;
    } else {
      // 「指定しない」= 日付だけ
      _timeSpecified = false;
    }
  }

  void _save() {
    final preset = _presets[_presetIndex];
    DateTime? startAt;
    final bool startDateOnly = !_timeSpecified;
    if (_date != null) {
      if (_timeSpecified) {
        startAt = DateTime(
            _date!.year, _date!.month, _date!.day, _time.hour, _time.minute);
      } else {
        startAt = DateTime(_date!.year, _date!.month, _date!.day);
      }
    }

    final bool reminderEnabled = preset.value != null || preset.custom;
    int? offsetValue;
    ReminderOffsetUnit? offsetUnit;
    if (preset.custom) {
      offsetValue = _customValue;
      offsetUnit = _customUnit;
    } else if (preset.value != null) {
      offsetValue = preset.value;
      offsetUnit = preset.unit;
    }

    context.read<AppState>().configureLater(
          widget.task,
          startAt: startAt,
          startDateOnly: startDateOnly,
          autoMove: _autoMove,
          reminderEnabled: reminderEnabled && startAt != null,
          reminderOffsetValue: offsetValue,
          reminderOffsetUnit: offsetUnit,
        );
    Navigator.pop(context);
  }

  String _fmtDate(DateTime d) => '${d.year}/${d.month}/${d.day}';
}
