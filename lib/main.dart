import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:home_widget/home_widget.dart';
import 'services/background_service.dart';
import 'services/storage_service.dart';
import 'services/update_service.dart';
import 'screens/login_screen.dart';
import 'screens/attendance_screen.dart';
import 'theme/theme_notifier.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  // Transparent bars so the app content flows edge-to-edge under
  // the status bar and the gesture navigation bar.
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: Colors.transparent,
    systemNavigationBarIconBrightness: Brightness.light,
  ));
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

  await HomeWidget.setAppGroupId('com.example.pesu_attendance');
  HomeWidget.registerInteractivityCallback(homeWidgetBackgroundCallback);

  runApp(const PesuAttendanceApp());
}

/// Called by the native widget when the user taps refresh.
@pragma('vm:entry-point')
Future<void> homeWidgetBackgroundCallback(Uri? uri) async {
  if (uri?.host == 'refresh') {
    try {
      await performManualRefresh();
    } catch (_) {}
  }
}

class PesuAttendanceApp extends StatelessWidget {
  const PesuAttendanceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: ThemeNotifier.instance,
      builder: (context, theme, _) {
        return MaterialApp(
          title: 'PESU Attendence',
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            brightness: Brightness.dark,
            scaffoldBackgroundColor: theme.backgroundColor,
            colorScheme: ColorScheme.fromSeed(
              seedColor: theme.safeColor,
              brightness: Brightness.dark,
            ),
            fontFamily: 'Roboto',
            useMaterial3: true,
          ),
          home: const _EntryPoint(),
        );
      },
    );
  }
}

class _EntryPoint extends StatefulWidget {
  const _EntryPoint();

  @override
  State<_EntryPoint> createState() => _EntryPointState();
}

class _EntryPointState extends State<_EntryPoint> {
  @override
  void initState() {
    super.initState();
    // Fire the update check once the widget tree is ready.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      UpdateService.checkForUpdate(context);
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: StorageService.hasCredentials(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            body: Center(
              child: CircularProgressIndicator(
                color: ThemeNotifier.instance.value.safeColor,
              ),
            ),
          );
        }

        if (snapshot.data == true) return const AttendanceScreen();
        return const LoginScreen();
      },
    );
  }
}
