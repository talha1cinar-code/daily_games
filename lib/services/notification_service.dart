import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter/foundation.dart';
import 'dart:io';
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
  static const int _morningRunReminderId = 201; // Kaldırılan sabah hatırlatması (16:00)
  static const int _eveningRunReminderId = 202; // Kaldırılan akşam hatırlatması (23:00)

  // Seri bildirim ID'leri
  static const int _streakReminderTodayId = 300; // Bugünkü seriyi koruma hatırlatması
  static const int _streakSavedBaseId = 301; // Dondurma ve kayıp bildirimleri (301-306)

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

    // Android bildirim kanallarını oluştur
    if (Platform.isAndroid) {
      final androidImplementation = flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      if (androidImplementation != null) {
        await androidImplementation.createNotificationChannel(
          const AndroidNotificationChannel(
            'daily_run_channel',
            'Daily Run Bildirimleri',
            description: 'Daily Run başlangıç bildirimleri',
            importance: Importance.high,
          ),
        );
        await androidImplementation.createNotificationChannel(
          const AndroidNotificationChannel(
            'streak_channel',
            'Seri Bildirimleri',
            description: 'Seri durumu ve dondurma hakkı bildirimleri',
            importance: Importance.high,
          ),
        );
      }
    }
  }

  void _onNotificationTapped(NotificationResponse response) {
    debugPrint('Bildirime tıklandı: ${response.payload}');
  }

  Future<void> requestPermissions() async {
    try {
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
      }
    } catch (e) {
      debugPrint('Bildirim izni istenirken hata oluştu: $e');
    }
  }

  /// Daily Run başlangıç bildirimlerini planlar (12:00 ve 17:00).
  /// 1 saat kala olan bitiş bildirimleri kaldırıldı ve mevcut olanlar iptal edildi.
  Future<void> scheduleDailyNotifications() async {
    // 1 saat önceden gönderilen eski hatırlatıcıları iptal et
    await flutterLocalNotificationsPlugin.cancel(id: _morningRunReminderId);
    await flutterLocalNotificationsPlugin.cancel(id: _eveningRunReminderId);

    // Sabah Daily Run başlangıç (12:00)
    await _scheduleDailyNotification(
      id: _morningRunStartId,
      title: AppStrings.morningRunStartedTitle,
      body: AppStrings.runStartedBody,
      hour: 12,
      minute: 0,
    );

    // Akşam Daily Run başlangıç (17:00)
    await _scheduleDailyNotification(
      id: _eveningRunStartId,
      title: AppStrings.eveningRunStartedTitle,
      body: AppStrings.runStartedBody,
      hour: 17,
      minute: 0,
    );
  }

  Future<void> _scheduleDailyNotification({
    required int id,
    required String title,
    required String body,
    required int hour,
    required int minute,
  }) async {
    try {
      await flutterLocalNotificationsPlugin.zonedSchedule(
        id: id,
        title: title,
        body: body,
        scheduledDate: _nextInstanceOfTime(hour, minute),
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            'daily_run_channel',
            'Daily Run Bildirimleri',
            channelDescription: 'Daily Run başlangıç bildirimleri',
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
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time, // Her gün aynı saatte tekrarla
      );
    } catch (e) {
      debugPrint('Günlük bildirim zamanlanırken hata ($id): $e');
    }
  }

  tz.TZDateTime _nextInstanceOfTime(int hour, int minute) {
    final tz.TZDateTime now = tz.TZDateTime.now(tz.local);
    tz.TZDateTime scheduledDate =
        tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }
    return scheduledDate;
  }

  /// Eski hatırlatıcı iptal metodları (geriye dönük uyumluluk için)
  Future<void> cancelMorningReminder() async {
    await flutterLocalNotificationsPlugin.cancel(id: _morningRunReminderId);
  }

  Future<void> cancelEveningReminder() async {
    await flutterLocalNotificationsPlugin.cancel(id: _eveningRunReminderId);
  }

  /// Tüm bildirimleri iptal eder
  Future<void> cancelAll() async {
    await flutterLocalNotificationsPlugin.cancelAll();
  }

  /// Tüm seri bildirimlerini temizler
  Future<void> cancelAllStreakNotifications() async {
    for (int id = 300; id <= 315; id++) {
      try {
        await flutterLocalNotificationsPlugin.cancel(id: id);
      } catch (_) {}
    }
  }

  /// Seri durumuna göre bildirimleri programlar
  Future<void> scheduleStreakNotifications({
    required int currentStreak,
    required int freezeCount,
    required bool isPlayedToday,
  }) async {
    // Önceki tüm seri bildirimlerini temizle
    await cancelAllStreakNotifications();

    // Aktif bir seri yoksa seri bildirimi kurulmaz
    if (currentStreak <= 0) {
      return;
    }

    final now = tz.TZDateTime.now(tz.local);

    // 1. Bugün henüz oynanmadıysa seriyi koruma hatırlatması (Bugün 20:00)
    if (!isPlayedToday) {
      final todayReminderTime =
          tz.TZDateTime(tz.local, now.year, now.month, now.day, 20, 0);
      if (todayReminderTime.isAfter(now)) {
        await _scheduleOneTimeNotification(
          id: _streakReminderTodayId,
          title: AppStrings.streakReminderTitle,
          body: AppStrings.streakReminderBody,
          scheduledDate: todayReminderTime,
        );
      }
    }

    // 2. Gelecek günler için donma ve son şans bildirimleri:
    // Bugün oynandıysa: ilk kaçırma yarın olur, donma bildirimi yarından sonraki gün (2 gün sonra) başlar.
    // Bugün oynanmadıysa: ilk kaçırma bugündür, donma bildirimi yarın (1 gün sonra) başlar.
    final int daysOffset = isPlayedToday ? 2 : 1;
    final baseDate =
        tz.TZDateTime(tz.local, now.year, now.month, now.day, 20, 30);

    for (int i = 0; i <= freezeCount; i++) {
      final notificationDate =
          baseDate.add(Duration(days: daysOffset + i));
      final id = _streakSavedBaseId + i;

      if (i < freezeCount) {
        // Donma kullanıldı bildirimi
        await _scheduleOneTimeNotification(
          id: id,
          title: AppStrings.streakSavedTitle,
          body: AppStrings.streakSavedBody,
          scheduledDate: notificationDate,
        );
      } else {
        // Seri tamamen sıfırlandı / Son şans bildirimi
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
    try {
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
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        matchDateTimeComponents: null, // Tek seferlik
      );
    } catch (e) {
      debugPrint('Streak bildirim planlama hatası ($id): $e');
    }
  }
}
