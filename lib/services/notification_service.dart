import 'dart:io' as io;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();

  factory NotificationService() => _instance;

  NotificationService._internal();

  Future<void> init() async {
    tz.initializeTimeZones();
    
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    
    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
    );

    await _notifications.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (details) {
        // Handle notification tap
      },
    );

    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'daily_reminders',
      'Daily Reminders',
      description: 'Daily reminder to take a photo',
      importance: Importance.max,
    );

    await _notifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }

  Future<void> scheduleDailyReminder(TimeOfDay time) async {
    if (io.Platform.isAndroid) {
      final status = await Permission.notification.status;
      if (!status.isGranted) {
        await Permission.notification.request();
      }
      
      // For Android 12+, we may need to request exact alarm permission
      if (await Permission.scheduleExactAlarm.isDenied) {
        await Permission.scheduleExactAlarm.request();
      }
    }

    await _notifications.cancel(0); // Regular reminder ID

    final now = tz.TZDateTime.now(tz.local);
    var scheduledDate = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      time.hour,
      time.minute,
    );
    
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    await _notifications.zonedSchedule(
      0,
      'Time to SnapLog!',
      'Don\'t forget to capture your moment for today.',
      scheduledDate,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'daily_reminders',
          'Daily Reminders',
          channelDescription: 'Daily reminder to take a photo',
          importance: Importance.max,
          priority: Priority.high,
          showWhen: true,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );
    
    // Schedule a "Revive Streak" reminder 2 hours later if count is still 0
    // Note: This is a static schedule. In a production app, we'd check the DB 
    // before showing the notification.
    _scheduleStreakRevive(scheduledDate.add(const Duration(hours: 2)));
  }

  Future<void> _scheduleStreakRevive(tz.TZDateTime scheduledDate) async {
    await _notifications.zonedSchedule(
      1,
      '🔥 Streak at risk!',
      'Revive your streak by taking a snap now! Don\'t let it die.',
      scheduledDate,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'streak_revive',
          'Streak Revive',
          channelDescription: 'Reminders to keep your streak alive',
          importance: Importance.max,
          priority: Priority.max,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  Future<void> cancelAllReminders() async {
    await _notifications.cancelAll();
  }
}
