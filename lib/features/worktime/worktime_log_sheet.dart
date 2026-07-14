import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/db/database.dart';
import '../../core/design/design.dart';
import 'repositories/worktime_repository.dart';
import 'services/rollup_service.dart';

// Shared preferences keys for timer
const _timerContextKey = 'worktime_timer_context_id';
const _timerStartKey = 'worktime_timer_started_at';

class WorktimeLogSheet extends ConsumerStatefulWidget {
  const WorktimeLogSheet({
    this.timerContextId,
    this.timerStartedAt,
    super.key,
  });

  final int? timerContextId;
  final DateTime? timerStartedAt;

  @override
  ConsumerState<WorktimeLogSheet> createState() => _WorktimeLogSheetState();
}

class _WorktimeLogSheetState extends ConsumerState<WorktimeLogSheet> {
  final _formKey = GlobalKey<FormState>();
  final _noteCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();

  int? _contextId;
  late DateTime _selectedDate;
  late TimeOfDay _startTime;
  late TimeOfDay _endTime;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedDate = widget.timerStartedAt ?? now;

    if (widget.timerStartedAt != null) {
      // Stopwatch mode
      _contextId = widget.timerContextId;
      _startTime = TimeOfDay.fromDateTime(widget.timerStartedAt!);
      _endTime = TimeOfDay.fromDateTime(now);
    } else {
      // Manual add mode
      _startTime = TimeOfDay.fromDateTime(now.subtract(const Duration(hours: 1)));
      _endTime = TimeOfDay.fromDateTime(now);
    }
  }

  @override
  void dispose() {
    _noteCtrl.dispose();
    _locationCtrl.dispose();
    super.dispose();
  }

  DateTime _combine(DateTime date, TimeOfDay time) {
    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  DateTime get _startDateTime => _combine(_selectedDate, _startTime);

  DateTime get _endDateTime {
    var end = _combine(_selectedDate, _endTime);
    if (end.isBefore(_startDateTime)) {
      // Handles overnight crossings
      end = end.add(const Duration(days: 1));
    }
    return end;
  }

  int get _calculatedMinutes {
    return _endDateTime.difference(_startDateTime).inMinutes;
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _pickStartTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _startTime,
    );
    if (picked != null) {
      setState(() {
        _startTime = picked;
      });
    }
  }

  Future<void> _pickEndTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _endTime,
    );
    if (picked != null) {
      setState(() {
        _endTime = picked;
      });
    }
  }

  Future<void> _discardTimer() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Discard Timer?'),
        content: const Text('Are you sure you want to discard this timer session? The timed hours will not be saved.'),
        actions: [
          TextButton(
            child: const Text('Cancel'),
            onPressed: () => Navigator.of(ctx).pop(false),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: DesignTokens.danger),
            child: const Text('Discard', style: TextStyle(color: Colors.white)),
            onPressed: () => Navigator.of(ctx).pop(true),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_timerContextKey);
      await prefs.remove(_timerStartKey);
      if (mounted) {
        Navigator.of(context).pop(true); // Return true to indicate timer was discarded
      }
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_calculatedMinutes <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('End time must be after start time.')),
      );
      return;
    }

    final repo = ref.read(worktimeRepositoryProvider);
    final isStopwatch = widget.timerStartedAt != null;

    if (isStopwatch) {
      await repo.stopTimer(
        contextId: _contextId!,
        startedAt: _startDateTime,
        endedAt: _endDateTime,
        location: _locationCtrl.text.trim().isEmpty ? null : _locationCtrl.text.trim(),
        note: _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
      );

      // Clear timer state
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_timerContextKey);
      await prefs.remove(_timerStartKey);
    } else {
      final dateStr =
          '${_selectedDate.year.toString().padLeft(4, '0')}-'
          '${_selectedDate.month.toString().padLeft(2, '0')}-'
          '${_selectedDate.day.toString().padLeft(2, '0')}';

      await repo.createEntry(
        TimeEntriesCompanion.insert(
          contextId: _contextId!,
          date: dateStr,
          minutes: _calculatedMinutes,
          note: Value(_noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim()),
          startTime: Value(DateFormat('HH:mm').format(_startDateTime)),
          endTime: Value(DateFormat('HH:mm').format(_endDateTime)),
          location: Value(_locationCtrl.text.trim().isEmpty ? null : _locationCtrl.text.trim()),
        ),
      );
    }

    if (mounted) Navigator.of(context).pop(false); // Return false to indicate saved successfully
  }

  @override
  Widget build(BuildContext context) {
    final insets = MediaQuery.viewInsetsOf(context);
    final ctxAsync = ref.watch(workContextsProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isStopwatch = widget.timerStartedAt != null;

    return Padding(
      padding: EdgeInsets.fromLTRB(24, 20, 24, 24 + insets.bottom),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  isStopwatch ? 'Complete Session' : 'Log Time',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontFamily: GoogleFonts.fraunces().fontFamily,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (isStopwatch)
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: DesignTokens.danger),
                    onPressed: _discardTimer,
                  )
                else
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
              ],
            ),
            const SizedBox(height: 16),

            // Context Dropdown
            ctxAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Text('$e'),
              data: (contexts) {
                if (contexts.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Text('Please add a Position in Settings first.'),
                  );
                }
                _contextId ??= contexts.first.id;
                return DropdownButtonFormField<int>(
                  value: _contextId,
                  items: contexts
                      .map((c) => DropdownMenuItem(value: c.id, child: Text(c.name)))
                      .toList(),
                  onChanged: (v) => setState(() => _contextId = v),
                  decoration: const InputDecoration(
                    labelText: 'Work Context / Position',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) => v == null ? 'Required' : null,
                );
              },
            ),
            const SizedBox(height: 12),

            // Date and Time Pickers
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.calendar_today, size: 16),
                    label: Text(DateFormat('yyyy-MM-dd').format(_selectedDate)),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(DesignTokens.radiusInput),
                      ),
                    ),
                    onPressed: _pickDate,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.access_time, size: 16),
                    label: Text('Start: ${_startTime.format(context)}'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(DesignTokens.radiusInput),
                      ),
                    ),
                    onPressed: _pickStartTime,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.access_time, size: 16),
                    label: Text('End: ${_endTime.format(context)}'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(DesignTokens.radiusInput),
                      ),
                    ),
                    onPressed: _pickEndTime,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Duration display
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? DesignTokens.surfaceDark : Colors.grey.shade50,
                borderRadius: BorderRadius.circular(DesignTokens.radiusInput),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Calculated Duration:',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: isDark ? DesignTokens.inkSoftDark : DesignTokens.inkSoftLight,
                    ),
                  ),
                  Text(
                    RollupService.formatMinutes(_calculatedMinutes),
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: isDark ? DesignTokens.accentDark : DesignTokens.accentLight,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Location field
            TextFormField(
              controller: _locationCtrl,
              decoration: const InputDecoration(
                labelText: 'Location (e.g. Office, Home, Cafe)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.location_on_outlined, size: 18),
              ),
            ),
            const SizedBox(height: 12),

            // Note field
            TextFormField(
              controller: _noteCtrl,
              decoration: const InputDecoration(
                labelText: 'Note (optional)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.note_alt_outlined, size: 18),
              ),
            ),
            const SizedBox(height: 20),

            // Save / Submit Button
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: isDark ? DesignTokens.accentDark : DesignTokens.accentLight,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(DesignTokens.radiusInput),
                ),
              ),
              onPressed: _submit,
              child: Text(isStopwatch ? 'Save Session' : 'Log'),
            ),
          ],
        ),
      ),
    );
  }
}
