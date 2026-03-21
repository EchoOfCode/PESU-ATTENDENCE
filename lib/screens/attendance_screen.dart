import 'dart:math';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/attendance.dart';
import '../services/background_service.dart';
import '../services/pesu_scraper.dart';
import '../services/storage_service.dart';
import 'login_screen.dart';

import '../theme/app_theme.dart';
import '../theme/theme_notifier.dart';

class AttendanceScreen extends StatefulWidget {
  final AttendanceData? initialData;

  const AttendanceScreen({super.key, this.initialData});

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen>
    with SingleTickerProviderStateMixin {
  AttendanceData? _data;
  bool _isRefreshing = false;
  double _targetPercentage = 75.0;
  late AnimationController _animController;

  @override
  void initState() {
    super.initState();
    _data = widget.initialData;
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..forward();

    _loadStoredData();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _loadStoredData() async {
    final stored = await StorageService.getAttendanceData();
    final prefs = await SharedPreferences.getInstance();
    final target = prefs.getDouble('bunk_target') ?? 75.0;
    
    if (mounted) {
      setState(() {
        if (stored != null) _data = stored;
        _targetPercentage = target;
      });
    }
  }

  Future<void> _updateTarget(double newTarget) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('bunk_target', newTarget);
    setState(() => _targetPercentage = newTarget);
  }

  Future<void> _refresh() async {
    if (_isRefreshing) return;
    setState(() => _isRefreshing = true);

    try {
      final creds = await StorageService.getCredentials();
      if (creds.username == null || creds.password == null) return;

      final scraper = PesuScraper();
      final data = await scraper.fetchAttendance(
        username: creds.username!,
        password: creds.password!,
      );

      if (mounted) {
        setState(() => _data = data);
        await StorageService.saveAttendanceData(data);
        await StorageService.syncToWidget(data);
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to refresh attendance. Check connection.')),
        );
      }
    } finally {
      if (mounted) setState(() => _isRefreshing = false);
    }
  }

  void _showThemePicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) {
        final theme = ThemeNotifier.instance.value;
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 20),
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: theme.cardBorder,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: AppThemeType.values.map((type) {
              final isSelected = theme.type == type;
              return ListTile(
                title: Text(
                  const {
                    AppThemeType.defaultTheme: '(Default)',
                    AppThemeType.funny: 'Procrastinator (Funny)',
                    AppThemeType.cute: 'UwU (Cute)',
                  }[type]!,
                  style: theme.fontBuilder(
                    color: theme.textColor,
                    fontSize: 16,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
                trailing: isSelected 
                    ? Icon(Icons.check_circle, color: theme.safeColor)
                    : null,
                onTap: () {
                  ThemeNotifier.instance.setTheme(type);
                  Navigator.pop(context);
                },
              );
            }).toList(),
          ),
        );
      },
    );
  }

  Future<void> _logout() async {
    await StorageService.clearCredentials();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('attendance_data');
    await prefs.remove('pesu_username');
    await prefs.remove('pesu_password');
    await cancelBackgroundTask();
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (_) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppTheme>(
      valueListenable: ThemeNotifier.instance,
      builder: (context, theme, child) {
        return Scaffold(
          backgroundColor: theme.backgroundColor,
          body: SafeArea(
            child: _data == null
                ? Center(
                    child: CircularProgressIndicator(color: theme.safeColor))
                : RefreshIndicator(
                    onRefresh: _refresh,
                    color: theme.safeColor,
                    backgroundColor: theme.cardColor,
                    child: CustomScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      slivers: [
                        // App bar
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    'Attendance',
                                    style: theme.fontBuilder(
                                      color: theme.textColor,
                                      fontSize: 28,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: -0.5,
                                    ),
                                  ),
                                ),
                                _buildIconButton(
                                  icon: Icons.palette_outlined,
                                  onTap: _showThemePicker,
                                  theme: theme,
                                ),
                                const SizedBox(width: 8),
                                _buildIconButton(
                                  icon: _isRefreshing
                                      ? Icons.hourglass_top_rounded
                                      : Icons.refresh_rounded,
                                  onTap: _refresh,
                                  theme: theme,
                                ),
                                const SizedBox(width: 8),
                                _buildIconButton(
                                  icon: Icons.logout_rounded,
                                  onTap: _logout,
                                  theme: theme,
                                ),
                              ],
                            ),
                          ),
                        ),

                        // Overall percentage ring
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
                            child: _OverallCard(data: _data!),
                          ),
                        ),

                        // Last updated
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                            child: Text(
                              'Updated ${_formatTimestamp(_data!.lastUpdated)}',
                              style: theme.fontBuilder(
                                color: theme.secondaryTextColor,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ),

                        // Bunk Calculator Card
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
                            child: _BunkSummaryCard(
                              subjects: _data!.subjects,
                              targetPercentage: _targetPercentage,
                              onTargetChanged: _updateTarget,
                            ),
                          ),
                        ),

                        // Subjects header
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
                            child: Text(
                              'SUBJECT WISE',
                              style: theme.fontBuilder(
                                color: theme.secondaryTextColor,
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.2,
                              ),
                            ),
                          ),
                        ),

                        // Subject cards
                        SliverPadding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          sliver: SliverList(
                            delegate: SliverChildBuilderDelegate(
                              (context, index) {
                                final subject = _data!.subjects[index];
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 10),
                                  child: _SubjectCard(
                                    subject: subject,
                                    index: index,
                                    targetPercentage: _targetPercentage,
                                  ),
                                );
                              },
                              childCount: _data!.subjects.length,
                            ),
                          ),
                        ),

                        const SliverToBoxAdapter(child: SizedBox(height: 32)),
                      ],
                    ),
                  ),
          ),
        );
      },
    );
  }

  Widget _buildIconButton({
    required IconData icon,
    required VoidCallback onTap,
    required AppTheme theme,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        splashColor: theme.textColor.withAlpha(20),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: BorderRadius.circular(12),
            border: theme.cardBorder,
          ),
          child: Icon(icon, color: theme.textColor, size: 20),
        ),
      ),
    );
  }

  String _formatTimestamp(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${dt.day}/${dt.month} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  Widget _buildLegendRow(String range, Color color, String label, AppTheme theme) {
    return Padding(
      padding: const EdgeInsets.only(top: 3),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Text(
            '$range · $label',
            style: theme.fontBuilder(color: theme.textColor.withAlpha(150), fontSize: 11),
          ),
        ],
      ),
    );
  }
}

// ────────────────────────────────────────────────
//  OVERALL PERCENTAGE CARD WITH RING
// ────────────────────────────────────────────────

class _OverallCard extends StatelessWidget {
  final AttendanceData data;

  const _OverallCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final theme = ThemeNotifier.instance.value;
    final pct = data.overallPercentage ?? 0;

    Color color;
    String statusMessage;
    if (pct >= 85) {
      color = theme.safeColor;
      statusMessage = theme.msgSafe;
    } else if (pct >= 75) {
      color = theme.warningColor;
      statusMessage = theme.msgWarning;
    } else {
      color = theme.dangerColor;
      statusMessage = theme.msgDanger;
    }

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: theme.cardRadius,
        border: theme.cardBorder,
        boxShadow: theme.cardShadow,
      ),
      child: Row(
        children: [
          // Percentage ring
          SizedBox(
            width: 100,
            height: 100,
            child: CustomPaint(
              painter: _RingPainter(
                percentage: pct,
                color: color,
                theme: theme,
              ),
              child: Center(
                child: Text(
                  data.overallPercentage != null
                      ? '${pct.toStringAsFixed(1)}%'
                      : 'N/A',
                  style: theme.fontBuilder(
                    color: color,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 24),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Overall Attendance',
                  style: theme.fontBuilder(
                    color: theme.textColor,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  statusMessage,
                  style: theme.fontBuilder(
                    color: color.withAlpha(200),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                _buildLegendRow('> 85%', theme.safeColor, 'Safe', theme),
                _buildLegendRow('75-85%', theme.warningColor, 'Warning', theme),
                _buildLegendRow('< 75%', theme.dangerColor, 'Danger', theme),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegendRow(String range, Color color, String label, AppTheme theme) {
    return Padding(
      padding: const EdgeInsets.only(top: 3),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Text(
            '$range · $label',
            style: theme.fontBuilder(color: theme.textColor.withAlpha(150), fontSize: 11),
          ),
        ],
      ),
    );
  }
}

// ────────────────────────────────────────────────
//  RING PAINTER
// ────────────────────────────────────────────────

class _RingPainter extends CustomPainter {
  final double percentage;
  final Color color;
  final AppTheme theme;

  _RingPainter({required this.percentage, required this.color, required this.theme});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 6;

    // Background ring.
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 8
        ..color = theme.textColor.withAlpha(20),
    );

    // Progress arc.
    final sweepAngle = (percentage / 100) * 2 * pi;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -pi / 2,
      sweepAngle,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 8
        ..strokeCap = StrokeCap.round
        ..color = color,
    );
  }

  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) =>
      oldDelegate.percentage != percentage || oldDelegate.color != color || oldDelegate.theme != theme;
}

// ────────────────────────────────────────────────
//  SUBJECT CARD
// ────────────────────────────────────────────────

class _SubjectCard extends StatelessWidget {
  final SubjectAttendance subject;
  final int index;
  final double targetPercentage;

  const _SubjectCard({
    required this.subject,
    required this.index,
    required this.targetPercentage,
  });

  @override
  Widget build(BuildContext context) {
    final theme = ThemeNotifier.instance.value;
    final pct = subject.percentage ?? 0;
    
    Color color;
    switch (subject.level) {
      case AttendanceLevel.good:
        color = theme.safeColor;
        break;
      case AttendanceLevel.warning:
        color = theme.warningColor;
        break;
      case AttendanceLevel.danger:
        color = theme.dangerColor;
        break;
      case AttendanceLevel.unknown:
      default:
        color = theme.secondaryTextColor;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: theme.cardRadius,
        border: theme.cardBorder,
        boxShadow: theme.cardShadow,
      ),
      child: Row(
        children: [
          // Color indicator
          Container(
            width: 4,
            height: 56,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 14),
          // Subject info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  subject.title,
                  style: theme.fontBuilder(
                    color: theme.textColor,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  '${subject.code}  ·  ${subject.attended ?? '-'}/${subject.total ?? '-'} classes',
                  style: theme.fontBuilder(
                    color: theme.secondaryTextColor,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 8),
                // Bunk calculator info
                _buildBunkInfo(theme),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // Percentage badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: color.withAlpha(25),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: color.withAlpha(70)),
            ),
            child: Text(
              subject.percentage != null
                  ? '${pct.toStringAsFixed(1)}%'
                  : 'N/A',
              style: theme.fontBuilder(
                color: color,
                fontSize: 14,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBunkInfo(AppTheme theme) {
    if (subject.attended == null || subject.total == null) {
      return const SizedBox.shrink();
    }

    final canBunk = subject.canBunk(targetPercentage);
    final mustAttend = subject.mustAttend(targetPercentage);

    if (canBunk > 0) {
      return Row(
        children: [
          Icon(Icons.sentiment_satisfied_rounded,
              size: 14, color: theme.safeColor),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              theme.msgCanSkip(canBunk),
              style: theme.fontBuilder(
                color: theme.safeColor,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 2,
            ),
          ),
        ],
      );
    } else if (mustAttend == -1) {
      return Row(
        children: [
          Icon(Icons.cancel_rounded,
              size: 14, color: theme.dangerColor),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              theme.msgImpossible,
              style: theme.fontBuilder(
                color: theme.dangerColor,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 2,
            ),
          ),
        ],
      );
    } else if (mustAttend > 0) {
      return Row(
        children: [
          Icon(Icons.warning_amber_rounded,
              size: 14, color: theme.dangerColor),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              theme.msgMustAttend(mustAttend),
              style: theme.fontBuilder(
                color: theme.dangerColor,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 2,
            ),
          ),
        ],
      );
    } else {
      return Row(
        children: [
          Icon(Icons.check_circle_outline_rounded,
              size: 14, color: theme.warningColor),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              theme.msgExactlyTarget,
              style: theme.fontBuilder(
                color: theme.warningColor,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 2,
            ),
          ),
        ],
      );
    }
  }
}

// ────────────────────────────────────────────────
//  BUNK CALCULATOR SUMMARY CARD
// ────────────────────────────────────────────────

class _BunkSummaryCard extends StatefulWidget {
  final List<SubjectAttendance> subjects;
  final double targetPercentage;
  final ValueChanged<double> onTargetChanged;

  const _BunkSummaryCard({
    required this.subjects,
    required this.targetPercentage,
    required this.onTargetChanged,
  });

  @override
  State<_BunkSummaryCard> createState() => _BunkSummaryCardState();
}

class _BunkSummaryCardState extends State<_BunkSummaryCard> {
  DateTime? _selectedEndDate;

  Future<void> _pickEndDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedEndDate ?? now.add(const Duration(days: 90)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
      builder: (context, child) {
        final theme = ThemeNotifier.instance.value;
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: ColorScheme.dark(
              primary: theme.safeColor,
              onPrimary: theme.cardColor,
              surface: theme.backgroundColor,
              onSurface: theme.textColor,
            ),
          ),
          child: child!,
        );
      },
    );
    
    if (picked != null && mounted) {
      setState(() => _selectedEndDate = picked);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Timetable sync required to calculate future attendance based on ${picked.day}/${picked.month}/${picked.year}'),
          action: SnackBarAction(label: 'OK', onPressed: () {}),
        )
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeNotifier.instance.value;
    final bunkable = widget.subjects.where((s) => s.canBunk(widget.targetPercentage) > 0).toList();
    final needAttend = widget.subjects.where((s) => s.mustAttend(widget.targetPercentage) > 0 || s.mustAttend(widget.targetPercentage) == -1).toList();
    final totalBunkable = bunkable.fold<int>(0, (sum, s) => sum + s.canBunk(widget.targetPercentage));

    final isAllSafe = needAttend.isEmpty;
    final bannerColor = isAllSafe ? theme.safeColor : theme.dangerColor;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: theme.cardRadius,
        border: theme.cardBorder ?? Border.all(
          color: bannerColor.withAlpha(80),
          width: 2,
        ),
        boxShadow: theme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Icon(
                isAllSafe ? Icons.celebration_rounded : Icons.warning_amber_rounded,
                color: bannerColor,
                size: 22,
              ),
              const SizedBox(width: 10),
              Text(
                'BUNK CALCULATOR',
                style: theme.fontBuilder(
                  color: theme.textColor,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.5,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Advanced Bunk Planner UI (Screenshot Style)
          Row(
            children: [
              Expanded(
                child: Text(
                  'SEMESTER END DATE',
                  style: theme.fontBuilder(
                    color: theme.secondaryTextColor,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.0,
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  'PLANNED BUNK DAYS',
                  style: theme.fontBuilder(
                    color: theme.secondaryTextColor,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.0,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: _pickEndDate,
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: theme.backgroundColor,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: theme.textColor.withAlpha(20)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _selectedEndDate != null 
                              ? '${_selectedEndDate!.day}/${_selectedEndDate!.month}/${_selectedEndDate!.year}'
                              : 'Select Date',
                          style: theme.fontBuilder(color: theme.textColor, fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                        Icon(Icons.calendar_month, size: 16, color: theme.secondaryTextColor),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: InkWell(
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Timetable sync required to omit specific working days.'))
                    );
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: theme.backgroundColor,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: theme.textColor.withAlpha(20)),
                    ),
                    child: Text(
                      'Select days',
                      style: theme.fontBuilder(color: theme.textColor, fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Target Percentage Selector
          Text(
            'TARGET ATTENDANCE',
            style: theme.fontBuilder(
              color: theme.secondaryTextColor,
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: SliderTheme(
                  data: SliderThemeData(
                    trackHeight: 6,
                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10),
                    overlayShape: const RoundSliderOverlayShape(overlayRadius: 20),
                    activeTrackColor: theme.safeColor,
                    inactiveTrackColor: theme.textColor.withAlpha(20),
                    thumbColor: theme.textColor,
                  ),
                  child: Slider(
                    value: widget.targetPercentage,
                    min: 50,
                    max: 100,
                    divisions: 50,
                    onChanged: widget.onTargetChanged,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '${widget.targetPercentage.toInt()}%',
                style: theme.fontBuilder(
                  color: theme.textColor,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Big summary line
          if (isAllSafe && totalBunkable > 0) ...[
            RichText(
              text: TextSpan(
                children: [
                  TextSpan(
                    text: 'You can bunk ',
                    style: theme.fontBuilder(color: theme.textColor, fontSize: 15),
                  ),
                  TextSpan(
                    text: '$totalBunkable',
                    style: theme.fontBuilder(
                      color: theme.safeColor,
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  TextSpan(
                    text: ' class${totalBunkable == 1 ? '' : 'es'}',
                    style: theme.fontBuilder(color: theme.textColor, fontSize: 15),
                  ),
                  TextSpan(
                    text: ' total across all subjects and still stay above ${widget.targetPercentage.toInt()}%',
                    style: theme.fontBuilder(color: theme.secondaryTextColor, fontSize: 13),
                  ),
                ],
              ),
            ),
          ] else if (!isAllSafe) ...[
            Text(
              'Some subjects need attention!',
              style: theme.fontBuilder(
                color: theme.dangerColor,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
          ] else ...[
            Text(
              'No attendance data to calculate.',
              style: theme.fontBuilder(color: theme.secondaryTextColor, fontSize: 14),
            ),
          ],

          const SizedBox(height: 16),
          Container(height: 1, color: theme.textColor.withAlpha(20)),
          const SizedBox(height: 16),

          // Per-subject breakdown
          ...widget.subjects.where((s) => s.attended != null && s.total != null).map(
            (s) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  // Subject name
                  Expanded(
                    child: Text(
                      s.title,
                      style: theme.fontBuilder(
                        color: theme.textColor.withAlpha(200),
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Bunk badge
                  if (s.canBunk(widget.targetPercentage) > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: theme.safeColor.withAlpha(30),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '✓ Can skip ${s.canBunk(widget.targetPercentage)}',
                        style: theme.fontBuilder(
                          color: theme.safeColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    )
                  else if (s.mustAttend(widget.targetPercentage) == -1)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: theme.dangerColor.withAlpha(30),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '✗ Impossible',
                        style: theme.fontBuilder(
                          color: theme.dangerColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    )
                  else if (s.mustAttend(widget.targetPercentage) > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: theme.dangerColor.withAlpha(30),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '✗ Attend ${s.mustAttend(widget.targetPercentage)}',
                        style: theme.fontBuilder(
                          color: theme.dangerColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    )
                  else
                    Container(
                      child: const Text(
                        '⚠ At limit',
                        style: TextStyle(
                          color: Color(0xFFFACC15),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
