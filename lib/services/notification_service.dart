import 'dart:io';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;
import '../db/database_helper.dart';

class ScheduledReminderSpec {
  final int notificationId;
  final String reminderType; // '30d' | '7d' | '1d' | 'custom'
  final DateTime scheduledAt;
  final String title;
  final String body;

  const ScheduledReminderSpec({
    required this.notificationId,
    required this.reminderType,
    required this.scheduledAt,
    required this.title,
    required this.body,
  });
}

/// Abstract backend for OS local notifications, enabling deterministic unit testing.
abstract class NotificationBackend {
  Future<void> initialize();
  Future<bool> requestPermissions();
  Future<void> schedule(ScheduledReminderSpec spec);
  Future<void> cancel(int notificationId);
}

class FlutterLocalNotificationBackend implements NotificationBackend {
  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  @override
  Future<void> initialize() async {
    if (_initialized) return;
    tz_data.initializeTimeZones();
    try {
      final tzInfo = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(tzInfo.identifier));
    } catch (_) {
      tz.setLocalLocation(tz.UTC);
    }

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwinInit = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    const settings = InitializationSettings(
      android: androidInit,
      iOS: darwinInit,
    );
    await _plugin.initialize(settings: settings);
    _initialized = true;
  }

  @override
  Future<bool> requestPermissions() async {
    await initialize();
    if (Platform.isAndroid) {
      final android = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      return await android?.requestNotificationsPermission() ?? true;
    }
    if (Platform.isIOS) {
      final ios = _plugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >();
      return await ios?.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          ) ??
          false;
    }
    return true;
  }

  @override
  Future<void> schedule(ScheduledReminderSpec spec) async {
    await initialize();
    final tzDate = tz.TZDateTime.from(spec.scheduledAt, tz.local);

    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'family_docs_expiry',
        'Document Expiry Reminders',
        channelDescription: 'Reminders for upcoming document renewals',
        importance: Importance.high,
        priority: Priority.high,
      ),
      iOS: DarwinNotificationDetails(),
    );

    await _plugin.zonedSchedule(
      id: spec.notificationId,
      title: spec.title,
      body: spec.body,
      scheduledDate: tzDate,
      notificationDetails: details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    );
  }

  @override
  Future<void> cancel(int notificationId) async {
    await initialize();
    await _plugin.cancel(id: notificationId);
  }
}

/// Manages expiry reminder scheduling, cancellation, and rescheduling.
class NotificationService {
  static final NotificationService instance = NotificationService._internal();

  final NotificationBackend _backend;
  final DatabaseHelper _db;

  NotificationService._internal({
    NotificationBackend? backend,
    DatabaseHelper? db,
  }) : _backend = backend ?? FlutterLocalNotificationBackend(),
       _db = db ?? DatabaseHelper.instance;

  factory NotificationService.forTesting({
    required NotificationBackend backend,
    DatabaseHelper? db,
  }) {
    return NotificationService._internal(backend: backend, db: db);
  }

  /// Deterministic notification ID prevents duplicate reminders per slot.
  static int notificationIdFor(int documentId, String reminderType) {
    final slot = switch (reminderType) {
      '30d' => 1,
      '7d' => 2,
      '1d' => 3,
      'custom' => 4,
      _ => 9,
    };
    return (documentId * 10) + slot;
  }

  Future<bool> requestPermissions() => _backend.requestPermissions();

  /// Cancels any existing reminders for [documentId] and schedules new ones
  /// based on confirmed expiry metadata.
  Future<List<ScheduledReminderSpec>> scheduleExpiryReminders({
    required int documentId,
    required String documentName,
    required DateTime expiryDate,
    bool remind30Days = true,
    bool remind7Days = true,
    bool remind1Day = true,
    DateTime? customReminderDate,
    DateTime? nowOverride,
  }) async {
    // Always clear previous reminders for this document first (no duplicates)
    await cancelDocumentReminders(documentId);

    final now = nowOverride ?? DateTime.now();
    final specs = <ScheduledReminderSpec>[];

    void tryAddOffset(int daysBefore, String type, String label) {
      final targetDay = expiryDate.subtract(Duration(days: daysBefore));
      final scheduled = DateTime(
        targetDay.year,
        targetDay.month,
        targetDay.day,
        9,
        0,
      );
      if (scheduled.isAfter(now)) {
        specs.add(
          ScheduledReminderSpec(
            notificationId: notificationIdFor(documentId, type),
            reminderType: type,
            scheduledAt: scheduled,
            title: 'Document Renewal Reminder',
            body: '$documentName expires $label.',
          ),
        );
      }
    }

    if (remind30Days) tryAddOffset(30, '30d', 'in 30 days');
    if (remind7Days) tryAddOffset(7, '7d', 'in 7 days');
    if (remind1Day) tryAddOffset(1, '1d', 'tomorrow');

    if (customReminderDate != null) {
      final scheduled = DateTime(
        customReminderDate.year,
        customReminderDate.month,
        customReminderDate.day,
        9,
        0,
      );
      if (scheduled.isAfter(now)) {
        specs.add(
          ScheduledReminderSpec(
            notificationId: notificationIdFor(documentId, 'custom'),
            reminderType: 'custom',
            scheduledAt: scheduled,
            title: 'Document Renewal Reminder',
            body: 'Scheduled reminder for $documentName.',
          ),
        );
      }
    }

    if (specs.isNotEmpty) {
      await _backend.requestPermissions();
      for (final spec in specs) {
        await _backend.schedule(spec);
        await _db.addReminder(
          documentId: documentId,
          notificationId: spec.notificationId,
          reminderDate: spec.scheduledAt.toIso8601String(),
          reminderType: spec.reminderType,
        );
      }
    }

    return specs;
  }

  Future<void> cancelDocumentReminders(int documentId) async {
    final existing = await _db.getRemindersForDocument(documentId);
    for (final row in existing) {
      final notifId = row['notification_id'] as int?;
      if (notifId != null) {
        await _backend.cancel(notifId);
      }
    }
    await _db.deactivateRemindersForDocument(documentId);
  }
}
