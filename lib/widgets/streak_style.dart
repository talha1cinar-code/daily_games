import 'package:flutter/material.dart';
import '../services/language_service.dart';
import '../services/streak_service.dart';

/// Serinin uzunluğuna göre alev rengi ve adı. Seri büyüdükçe alev "evrilir".
class StreakTier {
  final int minDays;
  final String nameTr, nameEn;
  final Color color; // ana alev rengi
  final Color glow; // açık ton (parıltı, gradyan)

  const StreakTier(this.minDays, this.nameTr, this.nameEn, this.color, this.glow);

  String get name => LanguageService().isTurkish ? nameTr : nameEn;

  static const Color frozenColor = Color(0xFF4FC3F7);
  static const Color frozenGlow = Color(0xFFB3ECFF);

  static const List<StreakTier> all = [
    StreakTier(0, 'Sönük', 'Unlit', Color(0xFF6E7391), Color(0xFFA5A9C4)),
    StreakTier(1, 'Kıvılcım', 'Spark', Color(0xFFFF9800), Color(0xFFFFD180)),
    StreakTier(7, 'Alev', 'Flame', Color(0xFFFF4D4D), Color(0xFFFFA07A)),
    StreakTier(30, 'Mor Alev', 'Violet Flame', Color(0xFFB45CFF), Color(0xFFE2B8FF)),
    StreakTier(100, 'Altın Alev', 'Golden Flame', Color(0xFFFFC107), Color(0xFFFFF0A8)),
    StreakTier(365, 'Efsane', 'Legend', Color(0xFF00E5FF), Color(0xFFB2FCFF)),
  ];

  static StreakTier of(int streak) => all.lastWhere((t) => streak >= t.minDays);

  /// Sonraki alev kademesi (yoksa null)
  static StreakTier? next(int streak) {
    for (final t in all) {
      if (t.minDays > streak) return t;
    }
    return null;
  }

  /// Bir sonraki hedef: kilometre taşı ya da alev kademesi, hangisi önce gelirse
  static int? nextGoal(int streak) {
    final goals = {...StreakService.milestones, for (final t in all) t.minDays}.where((g) => g > streak).toList()
      ..sort();
    return goals.isEmpty ? null : goals.first;
  }

  /// Önceki hedef (ilerleme çubuğunun başlangıcı)
  static int prevGoal(int streak) {
    final goals = {0, ...StreakService.milestones, for (final t in all) t.minDays}.where((g) => g <= streak).toList()
      ..sort();
    return goals.last;
  }
}

/// Serinin durumuna göre başlık ve motive edici söz. Her gün farklı bir söz seçilir.
class StreakMood {
  final String headline;
  final String line;
  const StreakMood(this.headline, this.line);

  static StreakMood of(StreakService s) {
    final tr = LanguageService().isTurkish;
    final n = s.currentStreak;
    final day = DateTime.now().difference(DateTime(2024)).inDays;
    String pick(List<String> list) => list[day % list.length];

    if (s.isFrozenToday) {
      return StreakMood(
        tr ? 'Serin buzda ❄️' : 'Streak on ice ❄️',
        tr
            ? 'Donma hakkın dünkü günü kurtardı. Bugün oyna, alev yeniden yansın.'
            : 'A freeze saved yesterday. Play today to relight the flame.',
      );
    }
    if (n == 0) {
      return StreakMood(
        tr ? 'Alevi yak!' : 'Light the flame!',
        pick(
          tr
              ? [
                  'Bugün bir Daily Run bitir, serin başlasın.',
                  'Her efsane tek bir günle başlar.',
                  'İlk kıvılcım bir koşu uzağında.',
                ]
              : [
                  'Finish a Daily Run today to start a streak.',
                  'Every legend starts with one day.',
                  'The first spark is one run away.',
                ],
        ),
      );
    }
    if (!s.isPlayedToday) {
      return StreakMood(
        tr ? 'Serin seni bekliyor' : 'Your streak is waiting',
        pick(
          tr
              ? [
                  '$n günlük emeğini bugün kaybetme!',
                  'Gece yarısına kadar bir koşu yeter.',
                  'Alev sönmesin, bugün de oyna.',
                ]
              : [
                  'Don\'t lose $n days of work today!',
                  'One run before midnight is enough.',
                  'Keep the flame alive, play today.',
                ],
        ),
      );
    }
    final List<String> lines;
    if (n < 3) {
      lines = tr
          ? [
              'Güzel başlangıç! Yarın da gel.',
              'Kıvılcım yandı, şimdi büyütme zamanı.',
              'İkinci gün en zorudur, başardın!',
            ]
          : [
              'Nice start! Come back tomorrow.',
              'The spark is lit, now grow it.',
              'Day two is the hardest, you did it!',
            ];
    } else if (n < 7) {
      lines = tr
          ? ['Isınıyorsun! Bir haftaya az kaldı.', 'Alışkanlık oluşuyor, bırakma!', 'Her gün biraz daha keskin.']
          : ['Heating up! A week is close.', 'A habit is forming, keep going!', 'A little sharper every day.'];
    } else if (n < 30) {
      lines = tr
          ? ['Alev aldın! Durdurulamazsın.', 'Bu artık bir rutin. Harika gidiyorsun.', 'Beyin kasların çalışıyor!']
          : ['You\'re ablaze! Unstoppable.', 'This is a routine now. Great job.', 'Your brain muscles are working!'];
    } else if (n < 100) {
      lines = tr
          ? ['Mor alev! Az kişi buraya gelir.', 'Gerçek bir müdavimsin.', 'Bu disiplin herkeste yok.']
          : ['Violet flame! Few get this far.', 'A true regular.', 'Not everyone has this discipline.'];
    } else {
      lines = tr
          ? ['Efsanevi bir seri!', 'Sen artık bir ilhamsın.', 'Bu alev hiç sönmüyor.']
          : ['A legendary streak!', 'You\'re an inspiration now.', 'This flame never goes out.'];
    }
    return StreakMood(tr ? 'Bugün tamam! 🔥' : 'Done for today! 🔥', pick(lines));
  }
}

/// Gradyanlı, hafifçe titreyen alev ikonu
class StreakFlame extends StatefulWidget {
  final int streak;
  final bool frozen;
  final double size;
  final bool animate;

  const StreakFlame({super.key, required this.streak, this.frozen = false, this.size = 64, this.animate = true});

  @override
  State<StreakFlame> createState() => _StreakFlameState();
}

class _StreakFlameState extends State<StreakFlame> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));

  @override
  void initState() {
    super.initState();
    if (widget.animate && widget.streak > 0) _c.repeat(reverse: true);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tier = StreakTier.of(widget.streak);
    final color = widget.frozen ? StreakTier.frozenColor : tier.color;
    final glow = widget.frozen ? StreakTier.frozenGlow : tier.glow;
    final icon = widget.frozen ? Icons.ac_unit_rounded : Icons.local_fire_department_rounded;
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final t = Curves.easeInOut.transform(_c.value);
        return Transform.scale(
          scale: 1 + t * 0.05,
          child: ShaderMask(
            blendMode: BlendMode.srcIn,
            shaderCallback: (r) => LinearGradient(
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
              colors: [color, Color.lerp(color, glow, 0.6 + t * 0.4)!],
            ).createShader(r),
            child: Icon(
              icon,
              size: widget.size,
              shadows: widget.streak > 0 || widget.frozen
                  ? [
                      Shadow(
                        color: color.withValues(alpha: 0.55 + t * 0.2),
                        blurRadius: widget.size * 0.35,
                      ),
                    ]
                  : null,
            ),
          ),
        );
      },
    );
  }
}
