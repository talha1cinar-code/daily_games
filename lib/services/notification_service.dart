import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter/foundation.dart';
import 'dart:io';
import 'daily_run_service.dart';
import 'app_strings.dart';
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  // Sabit ID'ler (aynı ID ile zamanlanan bildirim önceki kaydı ezer/günceller)
  static const int _morningRunStartId = 101; // Sabah 12:00
  static const int _eveningRunStartId = 102; // Akşam 17:00
  static const int _morningRunReminderId = 201; // Sabah hatırlatması (16:00)
  static const int _eveningRunReminderId = 202; // Akşam hatırlatması (23:00)

  Future<void> init() async {
    // Zaman dilimi verilerini yükle (timezone)
    tz.initializeTimeZones();
    // Türkiye saat dilimini ayarla
    tz.setLocalLocation(tz.getLocation('Europe/Istanbul'));

    // Android için init
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    // iOS için init (Darwin)
    const DarwinInitializationSettings initializationSettingsDarwin =
        DarwinInitializationSettings(
      requestSoundPermission: false,
      requestBadgePermission: false,
      requestAlertPermission: false,
    );

    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsDarwin,
    );

    await flutterLocalNotificationsPlugin.initialize(
      settings: initializationSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );
  }

  void _onNotificationTapped(NotificationResponse response) {
    debugPrint('Bildirime tıklandı: ${response.payload}');
    // Bildirime tıklanınca uygulamayı açma işlemi (şu an default açılıyor zaten)
  }

  Future<void> requestPermissions() async {
    if (Platform.isIOS) {
      await flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          );
    } else if (Platform.isAndroid) {
      final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
          flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();

      await androidImplementation?.requestNotificationsPermission();
      await androidImplementation?.requestExactAlarmsPermission();
    }
  }

  /// Tüm planlamaları yapar
  Future<void> scheduleDailyNotifications() async {
    await _scheduleDailyNotification(
      id: _morningRunStartId,
      title: AppStrings.morningRunStartedTitle,
      body: AppStrings.runStartedBody,
      hour: 12, // Kullanıcı isteği: Gündüz 12
      minute: 0,
    );

    await _scheduleDailyNotification(
      id: _eveningRunStartId,
      title: AppStrings.eveningRunStartedTitle,
      body: AppStrings.runStartedBody,
      hour: 17, // Akşam 17:00
      minute: 0,
    );

    // Sabah oturumu bugün başlatılmışsa (veya tamamlandıysa),
    // bugünün hatırlatıcısını atla, yarına kur (tekrarlayan olacağı için her gün kurar ama ilk tetiklenme yarın olur)
    bool skipMorningReminderToday = DailyRunService().isRunStartedToday(1);
    await _scheduleDailyNotification(
      id: _morningRunReminderId,
      title: AppStrings.morningRunReminderTitle,
      body: AppStrings.morningRunReminderBody,
      hour: 16, // Bitime 1 saat kala (16:00)
      minute: 0,
      skipToday: skipMorningReminderToday,
    );

    // Akşam oturumu bugün başlatılmışsa (veya tamamlandıysa),
    // bugünün hatırlatıcısını atla, yarına kur.
    bool skipEveningReminderToday = DailyRunService().isRunStartedToday(2);
    await _scheduleDailyNotification(
      id: _eveningRunReminderId,
      title: AppStrings.eveningRunReminderTitle,
      body: AppStrings.eveningRunReminderBody,
      hour: 23, // Bitime 1 saat kala (23:00)
      minute: 0,
      skipToday: skipEveningReminderToday,
    );
  }

  Future<void> _scheduleDailyNotification({
    required int id,
    required String title,
    required String body,
    required int hour,
    required int minute,
    bool skipToday = false,
  }) async {
    await flutterLocalNotificationsPlugin.zonedSchedule(
      id: id,
      title: title,
      body: body,
      scheduledDate: _nextInstanceOfTime(hour, minute, skipToday: skipToday),
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'daily_run_channel',
          'Daily Run Bildirimleri',
          channelDescription: 'Daily Run başlangıç ve hatırlatma bildirimleri',
          importance: Importance.max,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time, // Her gün aynı saatte tekrarla
    );
  }

  tz.TZDateTime _nextInstanceOfTime(int hour, int minute, {bool skipToday = false}) {
    final tz.TZDateTime now = tz.TZDateTime.now(tz.local);
    tz.TZDateTime scheduledDate =
        tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (scheduledDate.isBefore(now) || skipToday) {
      // Eğer saat geçmişse veya skipToday istenmişse bir sonraki güne at
      // Ancak saat zaten geçmişse ve skipToday true ise bir gün daha atlamamalıyız.
      // Sadece tek bir gün atmak yeterlidir, çünkü amaç 'bugün' için çalmamasıdır.
      if (scheduledDate.isBefore(now)) {
        scheduledDate = scheduledDate.add(const Duration(days: 1));
      } else if (skipToday) {
        scheduledDate = scheduledDate.add(const Duration(days: 1));
      }
    }
    return scheduledDate;
  }

  /// O anki Sabah hatırlatıcısını iptal eder (Oyuna başlandığında çağrılır)
  Future<void> cancelMorningReminder() async {
    await flutterLocalNotificationsPlugin.cancel(id: _morningRunReminderId);
  }

  /// O anki Akşam hatırlatıcısını iptal eder (Oyuna başlandığında çağrılır)
  Future<void> cancelEveningReminder() async {
    await flutterLocalNotificationsPlugin.cancel(id: _eveningRunReminderId);
  }

  /// Tüm bildirimleri iptal eder (Ayarlardan kapatıldığında)
  Future<void> cancelAll() async {
    await flutterLocalNotificationsPlugin.cancelAll();
  }

  /// Seri durumuna göre bildirimleri programlar
  Future<void> scheduleStreakNotifications(int freezeCount) async {
    // Önceki seri bildirimlerini temizle
    for (int i = 0; i < 5; i++) {
      await flutterLocalNotificationsPlugin.cancel(id: 301 + i);
    }

    final now = tz.TZDateTime.now(tz.local);
    // Bugünün 21:00'i referans alınarak üzerine eklenecek
    final baseDate = tz.TZDateTime(tz.local, now.year, now.month, now.day, 21, 0);

    for (int i = 0; i <= freezeCount; i++) {
      final notificationDate = baseDate.add(Duration(days: 2 + i));
      final id = 301 + i;
      
      // Eğer saat 10:00 geçmiş ve 0. gün eklenecek olsaydı diye kontrol ama
      // +2 gün olduğu için geçmiş olma ihtimali yok.
      
      if (i < freezeCount) {
        // Donma kullanıldı bildirimi
        await _scheduleOneTimeNotification(
          id: id,
          title: AppStrings.streakSavedTitle,
          body: AppStrings.streakSavedBody,
          scheduledDate: notificationDate,
        );
      } else {
        // Seri tamamen sıfırlandı bildirimi
        await _scheduleOneTimeNotification(
          id: id,
          title: AppStrings.streakLostTitle,
          body: AppStrings.streakLostBody,
          scheduledDate: notificationDate,
        );
      }
    }
  }

  Future<void> _scheduleOneTimeNotification({
    required int id,
    required String title,
    required String body,
    required tz.TZDateTime scheduledDate,
  }) async {
    await flutterLocalNotificationsPlugin.zonedSchedule(
      id: id,
      title: title,
      body: body,
      scheduledDate: scheduledDate,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'streak_channel',
          'Seri Bildirimleri',
          channelDescription: 'Seri durumu ve dondurma hakkı bildirimleri',
          importance: Importance.max,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: null, // Tek seferlik
    );
  }
}
