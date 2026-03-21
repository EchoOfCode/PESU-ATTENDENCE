import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/timetable.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';
import '../theme/theme_notifier.dart';

/// Settings screen for configuring the weekly timetable and academic dates.
/// Changes are saved immediately and synced to the homescreen widget.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen>
    with SingleTickerProviderStateMixin {
  List<ClassSlot> _slots = [];
  AcademicDates _dates = AcademicDates();
  late TabController _tabController;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final tt = await StorageService.getTimetable();
    final dates = await StorageService.getAcademicDates();
    if (mounted) {
      setState(() {
        _slots = tt?.slots ?? [];
        _dates = dates ?? AcademicDates();
        _isLoading = false;
      });
    }
  }

  Future<void> _save() async {
    await StorageService.saveTimetable(Timetable(slots: _slots));
    await StorageService.saveAcademicDates(_dates);

    // Re-sync widget with the new timetable/dates data.
    final attendance = await StorageService.getAttendanceData();
    if (attendance != null) {
      await StorageService.syncToWidget(attendance);
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Saved & synced to widget ✓')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeNotifier.instance.value;
    final topPad = MediaQuery.paddingOf(context).top;

    return Scaffold(
      backgroundColor: theme.backgroundColor,
      body: Column(
        children: [
          SizedBox(height: topPad + 8),

          // Title bar
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Icon(Icons.arrow_back_rounded, color: theme.textColor),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    'Settings',
                    style: theme.fontBuilder(
                      color: theme.textColor,
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                _actionBtn(Icons.save_rounded, _save, theme),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Tabs
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 24),
            decoration: BoxDecoration(
              color: theme.cardColor,
              borderRadius: theme.cardRadius,
              border: theme.cardBorder,
            ),
            child: TabBar(
              controller: _tabController,
              labelColor: theme.textColor,
              unselectedLabelColor: theme.secondaryTextColor,
              indicatorColor: theme.safeColor,
              indicatorSize: TabBarIndicatorSize.tab,
              dividerColor: Colors.transparent,
              tabs: const [
                Tab(text: 'TIMETABLE'),
                Tab(text: 'DATES'),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Tab content
          Expanded(
            child: _isLoading
                ? Center(child: CircularProgressIndicator(color: theme.safeColor))
                : TabBarView(
                    controller: _tabController,
                    children: [
                      _TimetableTab(
                        slots: _slots,
                        theme: theme,
                        onSlotsChanged: (s) => setState(() => _slots = s),
                      ),
                      _DatesTab(
                        dates: _dates,
                        theme: theme,
                        onDatesChanged: (d) => setState(() => _dates = d),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _actionBtn(IconData icon, VoidCallback onTap, AppTheme theme) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: BorderRadius.circular(12),
            border: theme.cardBorder,
          ),
          child: Icon(icon, color: theme.safeColor, size: 20),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Timetable tab
// ---------------------------------------------------------------------------

class _TimetableTab extends StatelessWidget {
  final List<ClassSlot> slots;
  final AppTheme theme;
  final ValueChanged<List<ClassSlot>> onSlotsChanged;

  const _TimetableTab({
    required this.slots,
    required this.theme,
    required this.onSlotsChanged,
  });

  static const _dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      children: [
        // Grouped by day
        for (int day = 1; day <= 7; day++) ...[
          _dayHeader(day),
          ..._slotsForDay(day).map((s) => _slotCard(context, s)),
          _addButton(context, day),
          const SizedBox(height: 8),
        ],
        const SizedBox(height: 80),
      ],
    );
  }

  List<ClassSlot> _slotsForDay(int day) {
    return slots.where((s) => s.dayOfWeek == day).toList()
      ..sort((a, b) => a.startTime.compareTo(b.startTime));
  }

  Widget _dayHeader(int day) {
    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 8),
      child: Text(
        _dayNames[day - 1],
        style: theme.fontBuilder(
          color: theme.secondaryTextColor,
          fontSize: 12,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _slotCard(BuildContext context, ClassSlot slot) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: theme.cardRadius,
        border: theme.cardBorder,
        boxShadow: theme.cardShadow,
      ),
      child: Row(
        children: [
          // Time range
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                slot.startTime,
                style: theme.fontBuilder(
                  color: theme.safeColor,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                slot.endTime,
                style: theme.fontBuilder(
                  color: theme.secondaryTextColor,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(width: 16),
          // Subject
          Expanded(
            child: Text(
              slot.subjectTitle,
              style: theme.fontBuilder(
                color: theme.textColor,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          // Delete button
          GestureDetector(
            onTap: () {
              final updated = List<ClassSlot>.from(slots)..remove(slot);
              onSlotsChanged(updated);
            },
            child: Icon(Icons.close_rounded, color: theme.dangerColor, size: 18),
          ),
        ],
      ),
    );
  }

  Widget _addButton(BuildContext context, int day) {
    return GestureDetector(
      onTap: () => _showAddSlotDialog(context, day),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          border: Border.all(color: theme.safeColor.withAlpha(60)),
          borderRadius: theme.cardRadius,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_rounded, color: theme.safeColor, size: 18),
            const SizedBox(width: 6),
            Text(
              'Add class',
              style: theme.fontBuilder(
                color: theme.safeColor,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddSlotDialog(BuildContext context, int day) {
    final subjectCtrl = TextEditingController();
    TimeOfDay start = const TimeOfDay(hour: 9, minute: 0);
    TimeOfDay end = const TimeOfDay(hour: 10, minute: 0);

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setDialogState) {
          return AlertDialog(
            title: Text('Add class — ${_dayNames[day - 1]}'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: subjectCtrl,
                  decoration: const InputDecoration(labelText: 'Subject name'),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _timePicker(ctx, 'Start', start, (t) {
                        setDialogState(() => start = t);
                      }),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _timePicker(ctx, 'End', end, (t) {
                        setDialogState(() => end = t);
                      }),
                    ),
                  ],
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () {
                  if (subjectCtrl.text.trim().isEmpty) return;
                  final slot = ClassSlot(
                    dayOfWeek: day,
                    startTime: _fmtTime(start),
                    endTime: _fmtTime(end),
                    subjectTitle: subjectCtrl.text.trim(),
                  );
                  onSlotsChanged([...slots, slot]);
                  Navigator.pop(ctx);
                },
                child: const Text('Add'),
              ),
            ],
          );
        });
      },
    );
  }

  Widget _timePicker(
      BuildContext context, String label, TimeOfDay time, ValueChanged<TimeOfDay> onPicked) {
    return GestureDetector(
      onTap: () async {
        final picked = await showTimePicker(context: context, initialTime: time);
        if (picked != null) onPicked(picked);
      },
      child: InputDecorator(
        decoration: InputDecoration(labelText: label),
        child: Text(_fmtTime(time)),
      ),
    );
  }

  String _fmtTime(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
}

// ---------------------------------------------------------------------------
// Academic dates tab
// ---------------------------------------------------------------------------

class _DatesTab extends StatelessWidget {
  final AcademicDates dates;
  final AppTheme theme;
  final ValueChanged<AcademicDates> onDatesChanged;

  const _DatesTab({
    required this.dates,
    required this.theme,
    required this.onDatesChanged,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      children: [
        const SizedBox(height: 8),
        _dateRow(context, 'ISA-1', dates.isa1, (d) {
          onDatesChanged(AcademicDates(isa1: d, isa2: dates.isa2, esa: dates.esa, lwd: dates.lwd));
        }),
        _dateRow(context, 'ISA-2', dates.isa2, (d) {
          onDatesChanged(AcademicDates(isa1: dates.isa1, isa2: d, esa: dates.esa, lwd: dates.lwd));
        }),
        _dateRow(context, 'ESA', dates.esa, (d) {
          onDatesChanged(AcademicDates(isa1: dates.isa1, isa2: dates.isa2, esa: d, lwd: dates.lwd));
        }),
        _dateRow(context, 'LWD (Last Working Day)', dates.lwd, (d) {
          onDatesChanged(AcademicDates(isa1: dates.isa1, isa2: dates.isa2, esa: dates.esa, lwd: d));
        }),
        const SizedBox(height: 80),
      ],
    );
  }

  Widget _dateRow(
      BuildContext context, String label, DateTime? value, ValueChanged<DateTime?> onChanged) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: theme.cardRadius,
        border: theme.cardBorder,
        boxShadow: theme.cardShadow,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.fontBuilder(
                    color: theme.textColor,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value != null ? DateFormat('d MMMM yyyy').format(value) : 'Not set',
                  style: theme.fontBuilder(
                    color: value != null ? theme.safeColor : theme.secondaryTextColor,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          if (value != null)
            GestureDetector(
              onTap: () => onChanged(null),
              child: Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Icon(Icons.close_rounded, color: theme.dangerColor, size: 18),
              ),
            ),
          GestureDetector(
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: value ?? DateTime.now(),
                firstDate: DateTime(2024),
                lastDate: DateTime(2030),
              );
              if (picked != null) onChanged(picked);
            },
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: theme.safeColor.withAlpha(20),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.calendar_today_rounded, color: theme.safeColor, size: 18),
            ),
          ),
        ],
      ),
    );
  }
}
