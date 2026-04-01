import 'package:workmanager/workmanager.dart';
import 'pesu_scraper.dart';
import 'storage_service.dart';

const String _taskName = 'com.pesu.attendance.refresh';
const String _taskTag = 'attendance_refresh';

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((_, __) async {
    try {
      return await _refreshAttendance();
    } catch (_) {
      return true;
    }
  });
}


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


Future<bool> performManualRefresh() => _refreshAttendance();

Future<bool> _refreshAttendance() async {
  final creds = await StorageService.getCredentials();
  if (creds.username == null || creds.password == null) return true;

  final scraper = PesuScraper();
  final data = await scraper.fetchAttendance(
    username: creds.username!,
    password: creds.password!,
  );
  await StorageService.saveAttendanceData(data);

  try {
    final tt = await scraper.scrapeTimetable();
    await StorageService.saveTimetable(tt);
  } catch (_) {
    // Skip if timetable scraping fails, don't break attendance sync
  }

  await StorageService.syncToWidget(data);
  return true;
}
