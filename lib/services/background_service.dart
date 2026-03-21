import 'package:workmanager/workmanager.dart';
import 'pesu_scraper.dart';
import 'storage_service.dart';

const String _taskName = 'com.pesu.attendance.refresh';
const String _taskTag = 'attendance_refresh';

/// Top-level entry point for WorkManager.
/// Must be a static / top-level function so Android can invoke it
/// even when the Flutter engine isn't running.
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((_, __) async {
    try {
      return await _refreshAttendance();
    } catch (_) {
      // Always return true so WorkManager doesn't apply increasing backoff.
      return true;
    }
  });
}

/// Schedules a periodic background refresh (roughly every hour).
Future<void> registerBackgroundTask() async {
  await Workmanager().initialize(callbackDispatcher, isInDebugMode: false);
  await Workmanager().registerPeriodicTask(
    _taskName,
    _taskName,
    tag: _taskTag,
    frequency: const Duration(hours: 1),
    constraints: Constraints(
      networkType: NetworkType.connected,
      requiresBatteryNotLow: true,
    ),
    existingWorkPolicy: ExistingWorkPolicy.replace,
    backoffPolicy: BackoffPolicy.linear,
    backoffPolicyDelay: const Duration(minutes: 15),
  );
}

Future<void> cancelBackgroundTask() async {
  await Workmanager().cancelByTag(_taskTag);
}

/// One-shot refresh usable from both the widget tap and pull-to-refresh.
Future<bool> performManualRefresh() => _refreshAttendance();

Future<bool> _refreshAttendance() async {
  final creds = await StorageService.getCredentials();
  if (creds.username == null || creds.password == null) return true;

  final data = await PesuScraper().fetchAttendance(
    username: creds.username!,
    password: creds.password!,
  );

  await StorageService.saveAttendanceData(data);
  await StorageService.syncToWidget(data);
  return true;
}
