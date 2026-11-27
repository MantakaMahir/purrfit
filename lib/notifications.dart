import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// Thin wrapper around Purrfit's optional daily checkpoint reminder.
class Notifications {
  Notifications._();
  static final Notifications instance = Notifications._();

  final _plugin = FlutterLocalNotificationsPlugin();
  var _ready = false;
  Future<void>? _initialization;

  static const _dailyReminderId = 1001;

  static const _details = NotificationDetails(
    android: AndroidNotificationDetails(
      'purrfit_reminders',
      'Reminders',
      channelDescription: 'Gentle nudges to keep your Purrfit habit going.',
      importance: Importance.high,
      priority: Priority.high,
    ),
    iOS: DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: false,
      presentSound: true,
    ),
  );

  Future<void> init() {
    if (_ready || kIsWeb) return Future.value();
    return _initialization ??= _initialize();
  }

  Future<void> _initialize() async {
    try {
      tzdata.initializeTimeZones();
      final timezone = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(timezone.identifier));
    } catch (e) {
      debugPrint('Notifications tz init failed: $e');
    }
    const settings = InitializationSettings(
      android: AndroidInitializationSettings('ic_notification'),
      iOS: DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      ),
    );
    try {
      await _plugin.initialize(settings);
      _ready = true;
      await cancelLegacyReminders();
    } catch (e) {
      debugPrint('Notifications init failed: $e');
    } finally {
      _initialization = null;
    }
  }

  /// Requests OS notification permission when the person enables reminders.
  Future<bool> requestPermission() async {
    if (kIsWeb) return false;
    await init();
    if (!_ready) return false;
    try {
      final ios = _plugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >();
      if (ios != null) {
        return await ios.requestPermissions(alert: true, sound: true) ?? false;
      }
      final android = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      return await android?.requestNotificationsPermission() ?? false;
    } catch (error) {
      debugPrint('Notification permission request failed: $error');
      return false;
    }
  }

  tz.TZDateTime _nextInstanceOf(int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );
    if (!scheduled.isAfter(now)) {
      scheduled = tz.TZDateTime(
        tz.local,
        now.year,
        now.month,
        now.day + 1,
        hour,
        minute,
      );
    }
    return scheduled;
  }

  /// Repeating daily reminder at [hour]:[minute].
  Future<bool> scheduleDailyReminder({
    required int hour,
    required int minute,
  }) async {
    if (kIsWeb) return false;
    await init();
    if (!_ready) return false;
    try {
      await _plugin.zonedSchedule(
        _dailyReminderId,
        'Purr is ready when you are 🐾',
        'Your next checkpoint is waiting. Move when you feel ready.',
        _nextInstanceOf(hour, minute),
        _details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time,
      );
      return true;
    } catch (e) {
      debugPrint('scheduleDailyReminder failed: $e');
      return false;
    }
  }

  Future<void> cancelDailyReminder() async {
    if (kIsWeb) return;
    await init();
    if (!_ready) return;
    try {
      await _plugin.cancel(_dailyReminderId);
    } catch (error) {
      debugPrint('Could not cancel daily reminder: $error');
    }
  }

  /// Retires the obsolete streak notification left by earlier app versions.
  Future<void> cancelLegacyReminders() async {
    if (kIsWeb) return;
    if (!_ready) await init();
    if (!_ready) return;
    try {
      await _plugin.cancel(1002);
    } catch (e) {
      debugPrint('cancelLegacyReminders failed: $e');
    }
  }
}
