import 'package:flutter/material.dart';
import 'wordle/wordle_screen.dart';
import 'tempole/tempole_screen.dart';
import 'nerdle/nerdle_screen.dart';
import 'fitle/fitle_screen.dart';
import 'rgble/rgble_screen.dart';
import 'sound/sound_screen.dart';
import 'timele/timele_screen.dart';
import 'huedle/huedle_screen.dart';
import 'memorle/memorle_screen.dart';
import 'reactle/reactle_screen.dart';
import 'quickle/quickle_screen.dart';
import 'slicele/slicele_screen.dart';
import 'stackle/stackle_screen.dart';
import 'mirrorle/mirrorle_screen.dart';
import 'anglele/anglele_screen.dart';
import 'dropple/dropple_screen.dart';
import 'icele/icele_screen.dart';
import 'countle/countle_screen.dart';
import 'balancele/balancele_screen.dart';
import 'centerle/centerle_screen.dart';
import 'mazele/mazele_screen.dart';
import 'echole/echole_screen.dart';
import 'shadowle/shadowle_screen.dart';
import 'rotatle/rotatle_screen.dart';

typedef GameCompleteCallback = void Function(double score, [int durationMs]);

/// Oyun kimliğinden ekranı üretir. Yeni oyun eklerken yalnızca burası,
/// game_model.dart ve DailyRunService.gamePool güncellenir.
Widget? buildGameScreen(String id, {required bool isDailyMode, GameCompleteCallback? onGameComplete}) {
  final d = isDailyMode;
  final c = onGameComplete;
  return switch (id) {
    'wordle' => WordleScreen(isDailyMode: d, onGameComplete: c),
    'tempole' => TempoleScreen(isDailyMode: d, onGameComplete: c),
    'nerdle' => NerdleScreen(isDailyMode: d, onGameComplete: c),
    'fitle' => FitleScreen(isDailyMode: d, onGameComplete: c),
    'rgble' => RgbleScreen(isDailyMode: d, onGameComplete: c),
    'sound' => SoundScreen(isDailyMode: d, onGameComplete: c),
    'timele' => TimeleScreen(isDailyMode: d, onGameComplete: c),
    'huedle' => HuedleScreen(isDailyMode: d, onGameComplete: c),
    'memorle' => MemorleScreen(isDailyMode: d, onGameComplete: c),
    'reactle' => ReactleScreen(isDailyMode: d, onGameComplete: c),
    'quickle' => QuickleScreen(isDailyMode: d, onGameComplete: c),
    'slicele' => SliceleScreen(isDailyMode: d, onGameComplete: c),
    'stackle' => StackleScreen(isDailyMode: d, onGameComplete: c),
    'mirrorle' => MirrorleScreen(isDailyMode: d, onGameComplete: c),
    'anglele' => AngleleScreen(isDailyMode: d, onGameComplete: c),
    'dropple' => DroppleScreen(isDailyMode: d, onGameComplete: c),
    'icele' => IceleScreen(isDailyMode: d, onGameComplete: c),
    'countle' => CountleScreen(isDailyMode: d, onGameComplete: c),
    'balancele' => BalanceleScreen(isDailyMode: d, onGameComplete: c),
    'centerle' => CenterleScreen(isDailyMode: d, onGameComplete: c),
    'mazele' => MazeleScreen(isDailyMode: d, onGameComplete: c),
    'echole' => EcholeScreen(isDailyMode: d, onGameComplete: c),
    'shadowle' => ShadowleScreen(isDailyMode: d, onGameComplete: c),
    'rotatle' => RotatleScreen(isDailyMode: d, onGameComplete: c),
    _ => null,
  };
}
