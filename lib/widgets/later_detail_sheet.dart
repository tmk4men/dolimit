import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/task.dart';
import '../models/enums.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';

/// LATER 詳細設定：開始日 / 開始時刻 / 事前通知 / 自動移動 ON/OFF
class LaterDetailSheet extends StatefulWidget {
  final TaskItem task;
  const LaterDetailSheet({super.key, required this.task});

  static Future<void> present(BuildContext context, TaskItem task) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
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
  late bool _timeSpecified = !(widget.task.startDateOnly) && widget.task.startAt != null;
  late TimeOfDay _time = TimeOfDay(
      hour: widget.task.startAt?.hour ?? 9, minute: widget.task.startAt?.minute ?? 0);
  late bool _autoMove = widget.task.autoMoveToToday;

  late int _presetIndex = _initialPreset();
  late int _customValue = widget.task.reminderOffsetValue ?? 10;
  late ReminderOffsetUnit _customUnit = widget.task.reminderOffsetUnit ?? ReminderOffsetUnit.minute;

  int _initialPreset() {
    if (!widget.task.reminderEnabled) return 0;
    final v = widget.task.reminderOffsetValue;
    final u = widget.task.reminderOffsetUnit;
    for (var i = 0; i < _presets.length; i++) {
      if (!_presets[i].custom && _presets[i].value == v && _presets[i].unit == u) return i;
    }
    return _presets.length - 1; // custom
  }

  @override
  Widget build(BuildContext context) {
    final preset = _presets[_presetIndex];
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        left: 20, right: 20, top: 16,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('LATER 詳細設定', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            const Text('LATERは墓場じゃない。未来のTODAY。',
                style: TextStyle(fontSize: 12, color: AppTheme.sub)),
            const SizedBox(height: 12),

            // 開始日
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.calendar_today, color: AppTheme.laterAccent),
              title: const Text('開始日'),
              trailing: Text(_date == null ? '未設定' : _fmtDate(_date!),
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              onTap: _pickDate,
            ),
            if (_date != null)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(onPressed: () => setState(() => _date = null), child: const Text('クリア')),
              ),

            // 開始時刻
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              activeColor: AppTheme.laterAccent,
              value: _timeSpecified,
              onChanged: _date == null ? null : (v) => setState(() => _timeSpecified = v),
              title: const Text('開始時刻も指定'),
              subtitle: Text(_timeSpecified
                  ? _time.format(context)
                  : '未指定なら自動移動時刻に移動'),
            ),
            if (_timeSpecified && _date != null)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: _pickTime,
                  icon: const Icon(Icons.schedule, size: 18),
                  label: Text('時刻を選ぶ（${_time.format(context)}）'),
                ),
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
                      onChanged: (s) => _customValue = int.tryParse(s) ?? _customValue,
                    ),
                  ),
                  const SizedBox(width: 12),
                  DropdownButton<ReminderOffsetUnit>(
                    value: _customUnit,
                    items: ReminderOffsetUnit.values
                        .map((u) => DropdownMenuItem(value: u, child: Text(u.label)))
                        .toList(),
                    onChanged: (u) => setState(() => _customUnit = u ?? _customUnit),
                  ),
                ],
              ),

            const Divider(height: 24),

            // 自動移動
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              activeColor: AppTheme.laterAccent,
              value: _autoMove,
              onChanged: (v) => setState(() => _autoMove = v),
              title: const Text('開始日にTODAYへ自動移動'),
            ),

            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(backgroundColor: AppTheme.ink),
                onPressed: _save,
                child: const Text('保存'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 5),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(context: context, initialTime: _time);
    if (picked != null) setState(() => _time = picked);
  }

  void _save() {
    final preset = _presets[_presetIndex];
    DateTime? startAt;
    final bool startDateOnly = !_timeSpecified;
    if (_date != null) {
      if (_timeSpecified) {
        startAt = DateTime(_date!.year, _date!.month, _date!.day, _time.hour, _time.minute);
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
