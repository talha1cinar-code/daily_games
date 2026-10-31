import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:ntp/ntp.dart';

/// Sayfa açmadan önceki internet kontrolü. Kontrol sürerken gelen dokunuşlara null
/// döner; böylece aynı sayfa üst üste açılmaz.
class InternetGate {
  bool _checking = false;
  bool get isChecking => _checking;

  Future<bool?> check() async {
    if (_checking) return null;
    _checking = true;
    try {
      return await NetworkUtils.checkInternet();
    } finally {
      _checking = false;
    }
  }
}

class NetworkUtils {
  static Duration timeOffset = Duration.zero;

  @visibleForTesting
  static Future<List<InternetAddress>> Function(String host) lookup = InternetAddress.lookup;
  @visibleForTesting
  static Duration checkTimeout = const Duration(seconds: 4);

  /// Süre sınırı var: kötü ağda cevap gelmezse ekran beklemede kalmasın
  static Future<bool> checkInternet() async {
    try {
      final result = await lookup('example.com').timeout(checkTimeout);
      if (result.isNotEmpty && result[0].rawAddress.isNotEmpty) {
        return true;
      }
    } on SocketException catch (_) {
      return false;
    } on TimeoutException catch (_) {
      return false;
    }
    return false;
  }

  static Future<void> syncTime() async {
    final hasInternet = await checkInternet();
    if (!hasInternet) return;
    
    try {
      final myTime = DateTime.now();
      final ntpTime = await NTP.now();
      timeOffset = ntpTime.difference(myTime);
      debugPrint('NTP sync successful. Offset: ${timeOffset.inSeconds} seconds');
    } catch (e) {
      debugPrint('NTP sync failed: $e');
    }
  }
}
