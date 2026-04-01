import 'dart:math';
import 'package:flutter/material.dart';
import 'package:home_widget/home_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/attendance.dart';
import '../services/pesu_scraper.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';
import '../theme/theme_notifier.dart';
import 'settings_screen.dart';

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
  double _targetPercentage = 85.0;
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
    final target = prefs.getDouble('bunk_target') ?? 85.0;
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

      final data = await PesuScraper().fetchAttendance(
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
          const SnackBar(content: Text('Failed to refresh. Check connection.')),
        );
      }
    } finally {
      if (mounted) setState(() => _isRefreshing = false);
    }
  }

  /// Shows the bunk calculator as a bottom sheet instead of inline,
  /// keeping the main feed clean and spacious.
  void _showBunkCalculator() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _BunkBottomSheet(
        subjects: _data!.subjects,
        targetPercentage: _targetPercentage,
        onTargetChanged: (v) {
          _updateTarget(v);
          // Force the bottom sheet to rebuild with new values.
          (context as Element).markNeedsBuild();
        },
      ),
    );
  }

  Future<void> _pinWidget() async {
    try {
      await HomeWidget.requestPinWidget(
        name: 'AttendanceWidgetProvider',
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Widget pinning not supported on this device.')),
        );
      }
    }
  }



  @override
  Widget build(BuildContext context) {
    // Edge-to-edge: grab the real system insets so we can pad manually.
    final topPad = MediaQuery.paddingOf(context).top;
    final bottomPad = MediaQuery.paddingOf(context).bottom;

    return ValueListenableBuilder<AppTheme>(
      valueListenable: ThemeNotifier.instance,
      builder: (context, theme, _) {
        return Scaffold(
          backgroundColor: theme.backgroundColor,
          body: _data == null
              ? Center(child: CircularProgressIndicator(color: theme.safeColor))
              : RefreshIndicator(
                  onRefresh: _refresh,
                  color: theme.safeColor,
                  backgroundColor: theme.cardColor,
                  child: CustomScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    slivers: [
                      // Status bar spacing
                      SliverToBoxAdapter(child: SizedBox(height: topPad + 8)),

                      // Header row
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
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
                              _iconBtn(Icons.settings_outlined, () {
                                Navigator.push(context, MaterialPageRoute(
                                  builder: (_) => const SettingsScreen(),
                                ));
                              }, theme),
                              const SizedBox(width: 8),
                              _iconBtn(Icons.widgets_outlined, _pinWidget, theme),
                            ],
                          ),
                        ),
                      ),

                      // Overall attendance card
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(24, 28, 24, 8),
                          child: _OverallCard(data: _data!, theme: theme),
                        ),
                      ),

                      // Last updated timestamp
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: Text(
                            'Updated ${_fmtTimestamp(_data!.lastUpdated)}',
                            style: theme.fontBuilder(
                              color: theme.secondaryTextColor,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),

                      // Bunk calculator quick-access button
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
                          child: _BunkQuickBar(
                            theme: theme,
                            subjects: _data!.subjects,
                            targetPercentage: _targetPercentage,
                            onTap: _showBunkCalculator,
                          ),
                        ),
                      ),

                      // Section label
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(24, 28, 24, 14),
                          child: Text(
                            'SUBJECT WISE',
                            style: theme.fontBuilder(
                              color: theme.secondaryTextColor,
                              fontSize: 11,
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
                                padding: const EdgeInsets.only(bottom: 12),
                                child: _SubjectCard(
                                  subject: subject,
                                  targetPercentage: _targetPercentage,
                                  theme: theme,
                                ),
                              );
                            },
                            childCount: _data!.subjects.length,
                          ),
                        ),
                      ),

                      // Bottom nav bar padding so nothing is hidden
                      SliverToBoxAdapter(
                        child: SizedBox(height: bottomPad + 24),
                      ),
                    ],
                  ),
                ),
        );
      },
    );
  }

  Widget _iconBtn(IconData icon, VoidCallback onTap, AppTheme theme) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        splashColor: theme.textColor.withAlpha(20),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: BorderRadius.circular(10),
            border: theme.cardBorder,
          ),
          child: Icon(icon, color: theme.textColor, size: 20),
        ),
      ),
    );
  }

  String _fmtTimestamp(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${dt.day}/${dt.month} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}

/// A slim summary bar that shows the bunk headline and opens the full
/// calculator bottom sheet on tap. Keeps the main feed clean.
class _BunkQuickBar extends StatelessWidget {
  final AppTheme theme;
  final List<SubjectAttendance> subjects;
  final double targetPercentage;
  final VoidCallback onTap;

  const _BunkQuickBar({
    required this.theme,
    required this.subjects,
    required this.targetPercentage,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bunkable = subjects.where((s) => s.canBunk(targetPercentage) > 0);
    final needAttend = subjects.where(
      (s) => s.mustAttend(targetPercentage) > 0 || s.mustAttend(targetPercentage) == -1,
    );
    final allSafe = needAttend.isEmpty;
    final accent = allSafe ? theme.safeColor : theme.dangerColor;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: theme.cardRadius,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: theme.cardRadius,
            border: theme.cardBorder,
            boxShadow: theme.cardShadow,
          ),
          child: Row(
            children: [
              Icon(
                allSafe ? Icons.celebration_rounded : Icons.warning_amber_rounded,
                color: accent,
                size: 22,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  allSafe
                      ? 'Safe in ${bunkable.length} subject${bunkable.length == 1 ? '' : 's'} above ${targetPercentage.toInt()}%'
                      : '${needAttend.length} subject${needAttend.length == 1 ? '' : 's'} need attention',
                  style: theme.fontBuilder(
                    color: theme.textColor,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Icon(Icons.arrow_forward_ios_rounded, color: theme.secondaryTextColor, size: 14),
            ],
          ),
        ),
      ),
    );
  }
}

/// The overall attendance percentage ring card.
class _OverallCard extends StatelessWidget {
  final AttendanceData data;
  final AppTheme theme;

  const _OverallCard({required this.data, required this.theme});

  @override
  Widget build(BuildContext context) {
    final pct = data.overallPercentage ?? 0;

    Color color;
    String msg;
    if (pct >= 85) {
      color = theme.safeColor;
      msg = theme.msgSafe;
    } else if (pct >= 75) {
      color = theme.warningColor;
      msg = theme.msgWarning;
    } else {
      color = theme.dangerColor;
      msg = theme.msgDanger;
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
          SizedBox(
            width: 100,
            height: 100,
            child: CustomPaint(
              painter: _RingPainter(percentage: pct, color: color, bgColor: theme.textColor.withAlpha(20)),
              child: Center(
                child: Text(
                  data.overallPercentage != null ? '${pct.toStringAsFixed(1)}%' : 'N/A',
                  style: theme.fontBuilder(color: color, fontSize: 20, fontWeight: FontWeight.w800),
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
                  style: theme.fontBuilder(color: theme.textColor, fontSize: 18, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 6),
                Text(
                  msg,
                  style: theme.fontBuilder(color: color.withAlpha(200), fontSize: 13, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 12),
                _legendDot('> 85%', theme.safeColor, 'Safe'),
                _legendDot('75-85%', theme.warningColor, 'Warning'),
                _legendDot('< 75%', theme.dangerColor, 'Danger'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _legendDot(String range, Color color, String label) {
    return Padding(
      padding: const EdgeInsets.only(top: 3),
      child: Row(
        children: [
          Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
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

/// Draws the percentage ring arc on the Overall card.
class _RingPainter extends CustomPainter {
  final double percentage;
  final Color color;
  final Color bgColor;

  _RingPainter({required this.percentage, required this.color, required this.bgColor});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 6;

    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 8
        ..color = bgColor,
    );

    final sweep = (percentage / 100) * 2 * pi;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -pi / 2,
      sweep,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 8
        ..strokeCap = StrokeCap.round
        ..color = color,
    );
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) =>
      old.percentage != percentage || old.color != color;
}

/// Individual subject attendance card.
class _SubjectCard extends StatelessWidget {
  final SubjectAttendance subject;
  final double targetPercentage;
  final AppTheme theme;

  const _SubjectCard({
    required this.subject,
    required this.targetPercentage,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    final pct = subject.percentage ?? 0;

    Color color;
    switch (subject.level) {
      case AttendanceLevel.good:
        color = theme.safeColor;
      case AttendanceLevel.warning:
        color = theme.warningColor;
      case AttendanceLevel.danger:
        color = theme.dangerColor;
      case AttendanceLevel.unknown:
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
          // Thin coloured indicator strip
          Container(
            width: 4,
            height: 56,
            decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  subject.title,
                  style: theme.fontBuilder(color: theme.textColor, fontSize: 14, fontWeight: FontWeight.w700),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  '${subject.code}  ·  ${subject.attended ?? '-'}/${subject.total ?? '-'} classes',
                  style: theme.fontBuilder(color: theme.secondaryTextColor, fontSize: 12),
                ),
                const SizedBox(height: 8),
                _bunkHint(theme),
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
              subject.percentage != null ? '${pct.toStringAsFixed(1)}%' : 'N/A',
              style: theme.fontBuilder(color: color, fontSize: 14, fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }

  Widget _bunkHint(AppTheme theme) {
    if (subject.attended == null || subject.total == null) return const SizedBox.shrink();

    final canBunk = subject.canBunk(targetPercentage);
    final mustAttend = subject.mustAttend(targetPercentage);

    late IconData icon;
    late Color c;
    late String text;

    if (canBunk > 0) {
      icon = Icons.sentiment_satisfied_rounded;
      c = theme.safeColor;
      text = theme.msgCanSkip(canBunk);
    } else if (mustAttend == -1) {
      icon = Icons.cancel_rounded;
      c = theme.dangerColor;
      text = theme.msgImpossible;
    } else if (mustAttend > 0) {
      icon = Icons.warning_amber_rounded;
      c = theme.dangerColor;
      text = theme.msgMustAttend(mustAttend);
    } else {
      icon = Icons.check_circle_outline_rounded;
      c = theme.warningColor;
      text = theme.msgExactlyTarget;
    }

    return Row(
      children: [
        Icon(icon, size: 14, color: c),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: theme.fontBuilder(color: c, fontSize: 12, fontWeight: FontWeight.w600),
            maxLines: 2,
          ),
        ),
      ],
    );
  }
}

// //// Full Bunk Cal 
// class _BunkBottomSheet extends StateFulWidget
//   final List<SubjectAttendance> subjects;
//   final double targetPercentage;
//   final ValueChanged<double> onTargetChanged;

/* const _BUnkBottomSheet({
  
  
  
  
  
  */

/// Full bunk calculator shown as a draggable bottom sheet.
class _BunkBottomSheet extends StatefulWidget {
  final List<SubjectAttendance> subjects;
  final double targetPercentage;
  final ValueChanged<double> onTargetChanged;

  const _BunkBottomSheet({
    required this.subjects,
    required this.targetPercentage,
    required this.onTargetChanged,
  });

  @override
  State<_BunkBottomSheet> createState() => _BunkBottomSheetState();
}

class _BunkBottomSheetState extends State<_BunkBottomSheet> {
  late double _target;

  @override
  void initState() {
    super.initState();
    _target = widget.targetPercentage;
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeNotifier.instance.value;
    final bottomPad = MediaQuery.paddingOf(context).bottom;
    final bunkable = widget.subjects.where((s) => s.canBunk(_target) > 0).toList();
    final needAttend = widget.subjects.where(
      (s) => s.mustAttend(_target) > 0 || s.mustAttend(_target) == -1,
    ).toList();
    final allSafe = needAttend.isEmpty;
    final accent = allSafe ? theme.safeColor : theme.dangerColor;

    return Container(
      padding: EdgeInsets.fromLTRB(24, 20, 24, bottomPad + 16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: theme.cardBorder,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: theme.textColor.withAlpha(40),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Title
            Row(
              children: [
                Icon(
                  allSafe ? Icons.celebration_rounded : Icons.warning_amber_rounded,
                  color: accent,
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

            const SizedBox(height: 24),

            // Target slider
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
                      value: _target,
                      min: 60,
                      max: 100,
                      divisions: 8,
                      onChanged: (v) {
                        setState(() => _target = v);
                        widget.onTargetChanged(v);
                      },
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  '${_target.toInt()}%',
                  style: theme.fontBuilder(color: theme.textColor, fontSize: 20, fontWeight: FontWeight.w800),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Summary
            if (allSafe && bunkable.isNotEmpty)
              RichText(
                text: TextSpan(children: [
                  TextSpan(
                    text: 'Safe in ',
                    style: theme.fontBuilder(color: theme.textColor, fontSize: 16),
                  ),
                  TextSpan(
                    text: '${bunkable.length}',
                    style: theme.fontBuilder(color: theme.safeColor, fontSize: 24, fontWeight: FontWeight.w900),
                  ),
                  TextSpan(
                    text: ' subject${bunkable.length == 1 ? '' : 's'}',
                    style: theme.fontBuilder(color: theme.textColor, fontSize: 16),
                  ),
                  TextSpan(
                    text: '\nScroll down to view details.',
                    style: theme.fontBuilder(color: theme.secondaryTextColor, fontSize: 13),
                  ),
                ]),
              )
            else if (!allSafe)
              Text(
                'Some subjects need attention!',
                style: theme.fontBuilder(color: theme.dangerColor, fontSize: 16, fontWeight: FontWeight.w800),
              )
            else
              Text(
                'No attendance data to calculate.',
                style: theme.fontBuilder(color: theme.secondaryTextColor, fontSize: 14),
              ),

            const SizedBox(height: 20),
            Container(height: 1, color: theme.textColor.withAlpha(15)),
            const SizedBox(height: 20),

            // Per-subject breakdown
            ...widget.subjects
                .where((s) => s.attended != null && s.total != null)
                .map((s) => _subjectRow(s, theme)),
          ],
        ),
      ),
    );
  }

  Widget _subjectRow(SubjectAttendance s, AppTheme theme) {
    final canBunk = s.canBunk(_target);
    final mustAttend = s.mustAttend(_target);

    late String label;
    late Color c;


    if (canBunk > 0) {
      label = '✓ Can skip $canBunk';
      c = theme.safeColor;
    } else if (mustAttend == -1) {
      label = '✗ Impossible';
      c = theme.dangerColor;
    } else if (mustAttend > 0) {
      label = '✗ Attend $mustAttend';
      c = theme.dangerColor;
    } else {
      label = '⚠ At limit';
      c = theme.warningColor;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        children: [
          Expanded(
            child: Text(
              s.title,
              style: theme.fontBuilder(color: theme.textColor.withAlpha(200), fontSize: 13, fontWeight: FontWeight.w600),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: c.withAlpha(30),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              label,
              style: theme.fontBuilder(color: c, fontSize: 12, fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}
