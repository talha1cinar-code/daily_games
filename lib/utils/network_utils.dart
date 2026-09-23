import 'dart:io';
import 'package:flutter/material.dart';
import 'package:ntp/ntp.dart';

class NetworkUtils {
  static Duration timeOffset = Duration.zero;

  static Future<bool> checkInternet() async {
    try {
      final result = await InternetAddress.lookup('example.com');
      if (result.isNotEmpty && result[0].rawAddress.isNotEmpty) {
        return true;
      }
    } on SocketException catch (_) {
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
