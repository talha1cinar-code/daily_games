import 'dart:async';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:daily_games/utils/network_utils.dart';

void main() {
  tearDown(() {
    NetworkUtils.lookup = InternetAddress.lookup;
    NetworkUtils.checkTimeout = const Duration(seconds: 4);
  });

  test('kontrol sürerken gelen dokunuşlar sayfa açmaz, bitince yeniden denenebilir', () async {
    final pending = Completer<List<InternetAddress>>();
    NetworkUtils.lookup = (_) => pending.future;
    final gate = InternetGate();

    final first = gate.check();
    expect(gate.isChecking, isTrue);
    expect(await gate.check(), isNull);
    expect(await gate.check(), isNull);

    pending.complete([InternetAddress.loopbackIPv4]);
    expect(await first, isTrue);
    expect(gate.isChecking, isFalse);

    NetworkUtils.lookup = (_) async => [InternetAddress.loopbackIPv4];
    expect(await gate.check(), isTrue, reason: 'sayfadan dönünce buton yine çalışmalı');
  });

  test('internet yoksa kilit açılır', () async {
    NetworkUtils.lookup = (_) async => throw const SocketException('yok');
    final gate = InternetGate();
    expect(await gate.check(), isFalse);
    expect(gate.isChecking, isFalse);
  });

  test('cevap gelmezse süre sınırında biter, butonlar kilitli kalmaz', () async {
    NetworkUtils.lookup = (_) => Completer<List<InternetAddress>>().future;
    NetworkUtils.checkTimeout = const Duration(milliseconds: 50);
    final gate = InternetGate();
    expect(await gate.check(), isFalse);
    expect(gate.isChecking, isFalse);
  });
}
