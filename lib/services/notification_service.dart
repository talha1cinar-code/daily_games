import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter/foundation.dart';
import 'dart:io';

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
      title: 'Günün İlk Daily Run\'ı Hazır!',
      body: 'Sabah oturumu başladı. Günlük kelimeni ve oyunlarını oynamayı unutma!',
      hour: 12, // Kullanıcı isteği: Gündüz 12
      minute: 0,
    );

    await _scheduleDailyNotification(
      id: _eveningRunStartId,
      title: 'Akşam Daily Run\'ı Başladı!',
      body: 'Akşam oturumu için oyunlar yenilendi. Hemen oyna!',
      hour: 17, // Akşam 17:00
      minute: 0,
    );

    // Hatırlatıcılar da varsayılan olarak her gün için kurulur.
    // Oynandıkça `daily_run_service` içinden bugününki iptal edilir.
    await _scheduleDailyNotification(
      id: _morningRunReminderId,
      title: 'Sabah Oturumu Bitmek Üzere!',
      body: 'Sabah oyunlarını tamamlamak için son 1 saatin kaldı.',
      hour: 16, // Bitime 1 saat kala (16:00)
      minute: 0,
    );

    await _scheduleDailyNotification(
      id: _eveningRunReminderId,
      title: 'Akşam Oturumu Bitmek Üzere!',
      body: 'Akşam oyunlarını tamamlamak için son 1 saatin kaldı. Günü boş geçme!',
      hour: 23, // Bitime 1 saat kala (23:00)
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
    await flutterLocalNotificationsPlugin.zonedSchedule(
      id: id,
      title: title,
      body: body,
      scheduledDate: _nextInstanceOfTime(hour, minute),
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

  tz.TZDateTime _nextInstanceOfTime(int hour, int minute) {
    final tz.TZDateTime now = tz.TZDateTime.now(tz.local);
    tz.TZDateTime scheduledDate =
        tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
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
}
