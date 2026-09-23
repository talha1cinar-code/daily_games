import 'package:flutter/material.dart';
import 'game_exit_dialog.dart';


import '../services/stats_service.dart';

class GameExitWrapper extends StatefulWidget {
  final Widget child;
  final String? gameId;
  final bool isDailyMode;
  final void Function(double score, [int durationMs])? onGameComplete;

  const GameExitWrapper({
    super.key, 
    required this.child,
    this.gameId,
    this.isDailyMode = false,
    this.onGameComplete,
  });

  @override
  State<GameExitWrapper> createState() => _GameExitWrapperState();
}

class _GameExitWrapperState extends State<GameExitWrapper> {
  bool _canPop = false;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _canPop,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldPop = await showExitConfirmDialog(context);
        if (shouldPop && mounted) {
          if (widget.onGameComplete != null) {
            widget.onGameComplete!(0, 0); // Daily Run'da 0 puan, 0 süre
          } else if (widget.gameId != null) {
            // Biletli (Normal) oyun modunda erken çıkışta 0 puan ve mağlubiyet ver
            StatsService().saveDailyStat(
              gameId: widget.gameId!,
              isWin: false,
              score: 0,
              attempts: 999,
              maxAttempts: 999,
              durationMs: 0,
            );
          }
          setState(() {
            _canPop = true;
          });
          if (context.mounted) {
            Navigator.of(context).pop();
          }
        }
      },
      child: widget.child,
    );
  }
}
