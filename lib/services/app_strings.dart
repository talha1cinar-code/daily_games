import 'language_service.dart';

/// Uygulama genelinde kullanılan tüm UI metinleri.
/// LanguageService'e göre Türkçe veya İngilizce döner.
class AppStrings {
  static String get _lang => LanguageService().currentLanguage;

  // ─── Genel ──────────────────────────────────────────────────────
  static String get settings => _lang == 'tr' ? 'Ayarlar' : 'Settings';
  static String get close => _lang == 'tr' ? 'Kapat' : 'Close';
  static String get music => _lang == 'tr' ? 'Müzik' : 'Music';
  static String get soundEffects => _lang == 'tr' ? 'Ses Efektleri' : 'Sound Effects';
  static String get vibration => _lang == 'tr' ? 'Titreşim' : 'Vibration';
  static String get language => _lang == 'tr' ? 'Dil' : 'Language';
  static String get languageValue => _lang == 'tr' ? 'Türkçe' : 'English';
  static String get homePage => _lang == 'tr' ? 'Ana Sayfa' : 'Home';
  static String get next => _lang == 'tr' ? 'Sonraki' : 'Next';
  static String get moreSettings => _lang == 'tr' ? 'Daha Fazla' : 'More Settings';
  static String get privacyPolicy => _lang == 'tr' ? 'Gizlilik Politikası' : 'Privacy Policy';
  static String get termsOfService => _lang == 'tr' ? 'Kullanım Koşulları' : 'Terms of Service';

  // ─── Ana Ekran ─────────────────────────────────────────────────
  static String get games => _lang == 'tr' ? 'Oyunlar' : 'Games';
  static String get streak => _lang == 'tr' ? 'Seri' : 'Streak';
  static String get renewalIn => _lang == 'tr' ? 'Yenilenmeye' : 'Resets in';
  static String get dailyRunInternetRequired => _lang == 'tr'
      ? 'Daily Run için internet bağlantısı gerekiyor.'
      : 'Internet connection required for Daily Run.';
  static String get leaderboardInternetRequired => _lang == 'tr'
      ? 'Sıralamayı görmek için internet bağlantısı gerekiyor.'
      : 'Internet connection required to view leaderboard.';
  static String get todaysRanking => _lang == 'tr' ? 'GÜNÜN SIRALAMASI' : 'TODAY\'S RANKING';
  static String get noPlayersYet => _lang == 'tr'
      ? 'Henüz oynayan yok. İlk sen ol!'
      : 'No players yet. Be the first!';
  static String get seeAll => _lang == 'tr' ? 'TÜMÜNÜ GÖR' : 'SEE ALL';
  static String get you => _lang == 'tr' ? 'SEN' : 'YOU';

  // ─── Oyunlar Ekranı ─────────────────────────────────────────────
  static String gameCount(int count) =>
      _lang == 'tr' ? '$count oyun' : '$count games';
  static String comingSoon(String name) =>
      _lang == 'tr' ? '$name yakında geliyor! 🎮' : '$name coming soon! 🎮';
  static String get comingSoonLabel => _lang == 'tr' ? 'Yakında' : 'Soon';

  // ─── Oyun Detayları (Bottom Sheet) ────────────────────────────────
  static String get play => _lang == 'tr' ? '🎟️ Oyna' : '🎟️ Play';
  static String ticketsRemaining(int current, int max) =>
      _lang == 'tr' ? '$current / $max Bilet Kaldı' : '$current / $max Tickets Left';
  static String nextTicket(String timer) =>
      _lang == 'tr' ? 'Sonraki bilet: $timer' : 'Next ticket: $timer';
  static String get ticketsUsedUp => _lang == 'tr' ? '⏳ Biletin Bitti' : '⏳ No Tickets';
  static String renewalTimer(String timer) =>
      _lang == 'tr' ? 'Yenilenme: $timer' : 'Renewal: $timer';
  static String get waiting => _lang == 'tr' ? 'Bekleniyor...' : 'Waiting...';
  static String get adWaiting => _lang == 'tr' ? '⏳ Reklam Bekleniyor' : '⏳ Ad Waiting';
  static String adTimer(String timer) =>
      _lang == 'tr' ? 'Yeniden izlemek için: $timer' : 'Watch again in: $timer';
  static String get refillTickets =>
      _lang == 'tr' ? '🎬 Biletini Doldur' : '🎬 Refill Tickets';
  static String get watchAdRefill =>
      _lang == 'tr' ? 'Reklam izle, biletlerini yenile' : 'Watch ad to refill tickets';

  // ─── Wordle ────────────────────────────────────────────────────
  static String get loadingWords => _lang == 'tr' ? 'Kelimeler yükleniyor...' : 'Loading words...';
  static String get notEnoughLetters => _lang == 'tr' ? 'Yeterli harf yok!' : 'Not enough letters!';
  static String get invalidWord => _lang == 'tr' ? 'Geçersiz kelime!' : 'Invalid word!';
  static String get congratulations => _lang == 'tr' ? 'Tebrikler!' : 'Congratulations!';
  static String get sorry => _lang == 'tr' ? 'Maalesef!' : 'Too bad!';
  static String get outOfAttempts => _lang == 'tr' ? 'Hakkın bitti!' : 'Out of attempts!';
  static String guessedIn(int attempts, int max) =>
      _lang == 'tr' ? '$attempts/$max denemede bildin!' : 'Guessed in $attempts/$max attempts!';
  static String correctWord(String word) =>
      _lang == 'tr' ? 'Doğru kelime: $word' : 'Correct word: $word';
  static String get enterKey => _lang == 'tr' ? 'GİR' : 'GO';

  // ─── Daily Run ────────────────────────────────────────────────
  static String get morningRound => _lang == 'tr' ? 'Sabah Turu' : 'Morning Round';
  static String get eveningRound => _lang == 'tr' ? 'Akşam Turu' : 'Evening Round';
  static String get totalScore => _lang == 'tr' ? 'Toplam Puan' : 'Total Score';
  static String get start => _lang == 'tr' ? 'BAŞLA' : 'START';
  static String get generalRanking => _lang == 'tr' ? 'GENEL SIRALAMA' : 'OVERALL RANKING';
  static String get dailyRunCompleted =>
      _lang == 'tr' ? 'Daily Run Tamamlandı!' : 'Daily Run Completed!';
  static String get ranking => _lang == 'tr' ? 'Sıralama' : 'Ranking';

  // ─── Leaderboard ─────────────────────────────────────────────
  static String get daily => _lang == 'tr' ? 'GÜNLÜK' : 'DAILY';
  static String get weekly => _lang == 'tr' ? 'HAFTALIK' : 'WEEKLY';
  static String get daytime => _lang == 'tr' ? 'GÜNDÜZ' : 'DAYTIME';
  static String get night => _lang == 'tr' ? 'GECE' : 'NIGHT';
  static String get noPlayersToday => _lang == 'tr'
      ? 'Henüz bugün kimse oynamamış.\nİlk sen oyna! 🎮'
      : 'No one has played today.\nBe the first! 🎮';
  static String get noPlayersWeek => _lang == 'tr'
      ? 'Bu hafta henüz kimse oynamamış.\nİlk sen oyna! 🎮'
      : 'No one has played this week.\nBe the first! 🎮';
  static String daysPlayed(int days) =>
      _lang == 'tr' ? '$days gün' : '$days days';

  // ─── Profil ────────────────────────────────────────────────────
  static String get profileAndStats =>
      _lang == 'tr' ? 'Profil ve İstatistikler' : 'Profile & Statistics';
  static String get welcome => _lang == 'tr' ? 'Hoş Geldin,' : 'Welcome,';
  static String get dailyStreak => _lang == 'tr' ? 'Günlük Seri' : 'Daily Streak';
  static String get freezeChance => _lang == 'tr' ? 'Donma Hakkı' : 'Freeze Chance';
  static String get bestStreak => _lang == 'tr' ? 'En İyi Seri' : 'Best Streak';
  static String get days => _lang == 'tr' ? 'Gün' : 'Days';
  static String get streakZero => _lang == 'tr' ? 'Hemen seriye başla!' : 'Start your streak now!';
  static String get streakLow => _lang == 'tr' ? 'İyi başlangıç!' : 'Good start!';
  static String get streakMedium => _lang == 'tr' ? 'Ateş ediyorsun!' : 'You are on fire!';
  static String get streakHigh => _lang == 'tr' ? 'Durdurulamazsın!' : 'Unstoppable!';
  static String get streakSuper => _lang == 'tr' ? 'Bir efsanesin!' : 'You are a legend!';
  static String get mon => _lang == 'tr' ? 'Pt' : 'Mo';
  static String get tue => _lang == 'tr' ? 'Sa' : 'Tu';
  static String get wed => _lang == 'tr' ? 'Ça' : 'We';
  static String get thu => _lang == 'tr' ? 'Pe' : 'Th';
  static String get fri => _lang == 'tr' ? 'Cu' : 'Fr';
  static String get sat => _lang == 'tr' ? 'Ct' : 'Sa';
  static String get sun => _lang == 'tr' ? 'Pa' : 'Su';
  static String restoreStreak(int count) =>
      _lang == 'tr' ? 'Seriyi Geri Getir ($count 🔥)' : 'Restore Streak ($count 🔥)';
  static String get restoreStreakTitle =>
      _lang == 'tr' ? 'Seriyi Geri Getir!' : 'Restore Streak!';
  static String restoreStreakBody(int count) => _lang == 'tr'
      ? 'Bir reklam izleyerek $count günlük serini geri getirebilirsin!'
      : 'Watch an ad to restore your $count day streak!';
  static String get limitedTimeOffer =>
      _lang == 'tr' ? 'Bu hak kısıtlı sürelidir.' : 'This offer is limited time.';
  static String get watchAdAndRestore =>
      _lang == 'tr' ? 'Reklam İzle ve Geri Getir' : 'Watch Ad & Restore';
  static String get cancel => _lang == 'tr' ? 'Vazgeç' : 'Cancel';
  static String get streakRestored =>
      _lang == 'tr' ? 'Serin geri geldi! 🔥' : 'Streak restored! 🔥';
  static String get dailyRunHistory =>
      _lang == 'tr' ? 'Daily Run Geçmişi' : 'Daily Run History';
  static String get noDailyRunHistory => _lang == 'tr'
      ? 'Henüz Daily Run geçmişiniz bulunmuyor.\nİlk Daily Run\'ınızı tamamlayın!'
      : 'No Daily Run history yet.\nComplete your first Daily Run!';
  static String get unknown => _lang == 'tr' ? 'Bilinmiyor' : 'Unknown';
  static String get completed => _lang == 'tr' ? 'Tamamlanan' : 'Completed';
  static String get bestRank => _lang == 'tr' ? 'En İyi Sıra' : 'Best Rank';
  static String get notPlayed => _lang == 'tr' ? 'Oynanmadı' : 'Not Played';

  // ─── Oyundan Çıkış ──────────────────────────────────────────
  static String get areYouSure => _lang == 'tr' ? 'Emin misin?' : 'Are you sure?';
  static String get exitConfirmation => _lang == 'tr'
      ? 'Oyundan çıkmak istediğine emin misin? İlerlemen kaydedilmeyecek.'
      : 'Are you sure you want to quit? Your progress will not be saved.';
  static String get continueGame => _lang == 'tr' ? 'Devam Et' : 'Continue';
  static String get quit => _lang == 'tr' ? 'Çık' : 'Quit';

  // ─── Daily Run Slot Labels ──────────────────────────────────
  static String get morning => _lang == 'tr' ? 'Sabah' : 'Morning';
  static String get evening => _lang == 'tr' ? 'Akşam' : 'Evening';
  static String dailyRunSlotName(int slot) => _lang == 'tr'
      ? 'Daily Run (${slot == 1 ? 'Sabah' : 'Akşam'})'
      : 'Daily Run (${slot == 1 ? 'Morning' : 'Evening'})';

  // ─── Bildirimler ──────────────────────────────────────────────
  static String get morningRunStartedTitle =>
      _lang == 'tr' ? 'Sabah Daily Run\'ı Başladı!' : 'Morning Daily Run Started!';
  static String get runStartedBody =>
      _lang == 'tr' ? 'Oyunlar yenilendi. Hemen Oyna' : 'Games refreshed. Play Now';
  static String get eveningRunStartedTitle =>
      _lang == 'tr' ? 'Akşam Daily Run\'ı Başladı!' : 'Evening Daily Run Started!';
  static String get morningRunReminderTitle =>
      _lang == 'tr' ? 'Sabah Daily Run\'ı Bitmek Üzere' : 'Morning Daily Run Ending Soon';
  static String get morningRunReminderBody =>
      _lang == 'tr' ? 'Sabah oyunlarını tamamlamak için son 1 saatin kaldı.' : 'You have 1 hour left to complete morning games.';
  static String get eveningRunReminderTitle =>
      _lang == 'tr' ? 'Akşam Daily Run\'ı Bitmek Üzere' : 'Evening Daily Run Ending Soon';
  static String get eveningRunReminderBody =>
      _lang == 'tr' ? 'Akşam oyunlarını tamamlamak için son 1 saatin kaldı.' : 'You have 1 hour left to complete evening games.';
  static String get streakSavedTitle => _lang == 'tr' ? 'Serin Dondu' : 'Streak Frozen';
  static String get streakSavedBody => _lang == 'tr'
      ? 'Dondurma hakkın kullanıldı, hakkın bitmeden serini kurtar.'
      : 'Your freeze chance was used, save your streak before it runs out.';
  static String get streakLostTitle => _lang == 'tr' ? 'Son Şans!' : 'Last Chance!';
  static String get streakLostBody => _lang == 'tr'
      ? 'Serini kurtarmak için son şansın, hemen kurtar.'
      : 'This is your last chance to restore your streak, do it now.';
}
