import 'language_service.dart';
import 'friends_service.dart';
import '../models/duel.dart';

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
  static String get todaysRankingTitle => _lang == 'tr' ? 'Günün sıralaması' : 'Today\'s ranking';
  static String get seeAllShort => _lang == 'tr' ? 'Tümü' : 'All';
  static String get startRun => _lang == 'tr' ? 'Başla' : 'Start';
  static String get continueRun => _lang == 'tr' ? 'Devam et' : 'Continue';
  static String get seeResults => _lang == 'tr' ? 'Sonuçları gör' : 'See results';
  static String runSubtitle(int n) =>
      _lang == 'tr' ? '$n oyun · herkes aynı sırayla oynar' : '$n games · everyone plays the same order';
  static String runProgressText(int done, int total) =>
      _lang == 'tr' ? '$done/$total oyun tamamlandı' : '$done of $total games done';
  static String runDoneSubtitle(String score) =>
      _lang == 'tr' ? 'Tamamlandı · $score puan' : 'Completed · $score points';
  static String get profileAndBadges => _lang == 'tr' ? 'Profil ve rozetler' : 'Profile & badges';
  static String get streakFrozenShort => _lang == 'tr' ? 'Seri donduruldu' : 'Streak frozen';
  static String get playButton => _lang == 'tr' ? 'OYNA' : 'PLAY';
  static String get continueButton => _lang == 'tr' ? 'DEVAM' : 'CONTINUE';
  static String get resultsButton => _lang == 'tr' ? 'SONUÇLAR' : 'RESULTS';
  static String get rankingShort => _lang == 'tr' ? 'Sıralama' : 'Ranking';
  static String get todaysGames => _lang == 'tr' ? 'Bugünün oyunları' : 'Today\'s games';
  static String nextRunIn(String t) => _lang == 'tr' ? 'Sonraki tur: $t' : 'Next run in $t';
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
  static String personalBest(String s) => _lang == 'tr' ? 'En iyi skorun: $s' : 'Personal best: $s';
  static String newPersonalBest(String s, String prev) =>
      _lang == 'tr' ? 'Yeni rekor! $s (önceki: $prev)' : 'New personal best! $s (was $prev)';
  static String firstScore(String s) => _lang == 'tr' ? 'İlk skorun: $s. Şimdi bunu geç!' : 'First score: $s. Now beat it!';
  static String scoreVsBest(String s, String best) =>
      _lang == 'tr' ? 'Skor: $s · Rekorun: $best' : 'Score: $s · Your best: $best';
  static String get howToPlay => _lang == 'tr' ? 'Nasıl oynanır' : 'How to play';
  static String dailyRunProgress(int done, int total) =>
      _lang == 'tr' ? '$done/$total oyun' : '$done/$total games';
  static String get dailyRunDone => _lang == 'tr' ? 'Tamamlandı' : 'Completed';
  static String get comingSoonLabel => _lang == 'tr' ? 'Yakında' : 'Soon';

  // ─── Oyun Detayları (Bottom Sheet) ────────────────────────────────
  static String get play => _lang == 'tr' ? 'Oyna' : 'Play';
  static String ticketsRemaining(int current, int max) =>
      _lang == 'tr' ? '$current / $max Bilet Kaldı' : '$current / $max Tickets Left';
  static String nextTicket(String timer) =>
      _lang == 'tr' ? 'Sonraki bilet: $timer' : 'Next ticket: $timer';
  static String get ticketsUsedUp => _lang == 'tr' ? 'Biletin Bitti' : 'No Tickets';
  static String renewalTimer(String timer) =>
      _lang == 'tr' ? 'Yenilenme: $timer' : 'Renewal: $timer';
  static String get waiting => _lang == 'tr' ? 'Bekleniyor...' : 'Waiting...';
  static String get adWaiting => _lang == 'tr' ? 'Reklam Bekleniyor' : 'Ad Cooling Down';
  static String adTimer(String timer) =>
      _lang == 'tr' ? 'Yeniden izlemek için: $timer' : 'Watch again in: $timer';
  static String get refillTickets =>
      _lang == 'tr' ? 'Biletini Doldur' : 'Refill Tickets';
  static String get watchAdRefill =>
      _lang == 'tr' ? 'Reklam izle, biletlerini yenile' : 'Watch ad to refill tickets';

  // ─── Coin & Mağaza ─────────────────────────────────────────────
  static String get store => _lang == 'tr' ? 'Mağaza' : 'Store';
  static String get freeCoins => _lang == 'tr' ? 'Ücretsiz coin' : 'Free coins';
  static String watchForCoins(int n) => _lang == 'tr' ? 'Reklam izle, +$n coin' : 'Watch an ad, +$n coins';
  static String get adOncePerDay => _lang == 'tr' ? 'Günde 1 kez' : 'Once a day';
  static String get adTakenToday => _lang == 'tr' ? 'Bugün aldın, yarın tekrar gel' : 'Claimed today, come back tomorrow';
  static String get howToEarn => _lang == 'tr' ? 'Coin nasıl kazanılır?' : 'How to earn coins';
  static String get earnPlay => _lang == 'tr' ? 'Her bitirdiğin oyun: 5-10 coin' : 'Every game you finish: 5-10 coins';
  static String get earnChest => _lang == 'tr' ? 'Daily Run sandığı: 20-90 coin' : 'Daily Run chest: 20-90 coins';
  static String get earnDaily => _lang == 'tr' ? 'Günlük ödül: 10-100 coin' : 'Daily reward: 10-100 coins';
  static String get earnBadges => _lang == 'tr' ? 'Her rozet: 50 coin' : 'Each badge: 50 coins';
  static String get editLook => _lang == 'tr' ? 'Görünümü düzenle' : 'Edit look';
  static String get purchased => _lang == 'tr' ? 'Satın alındı ve kullanılıyor!' : 'Bought and equipped!';
  static String get previewing => _lang == 'tr' ? 'ÖNİZLEME' : 'PREVIEW';
  static String get buy => _lang == 'tr' ? 'SATIN AL' : 'BUY';
  static String needMoreCoins(int n) => _lang == 'tr' ? '$n coin daha gerekli' : 'Need $n more coins';
  static String get dailyGift => _lang == 'tr' ? 'Günlük hediye' : 'Daily gift';
  static String dailyGiftDesc(int n) => _lang == 'tr' ? 'Kısa bir reklam izle, $n coin kap' : 'Watch a short ad, grab $n coins';
  static String nextGiftIn(String t) => _lang == 'tr' ? 'Yeni hediye: $t' : 'Next gift in $t';
  static String get shelf => _lang == 'tr' ? 'Vitrin' : 'Shop';
  static String freezeOwnedShort(int n, int max) => _lang == 'tr' ? 'Sende $n/$max' : 'You have $n/$max';
  static String get todaysPick => _lang == 'tr' ? 'GÜNÜN SEÇİMİ' : 'TODAY\'S PICK';
  static String get bannerLabel => _lang == 'tr' ? 'Profil banner\'ı' : 'Profile banner';
  static String get todaysAvatar => _lang == 'tr' ? 'Günün avatarı' : 'Avatar of the day';
  static String get owned => _lang == 'tr' ? 'Sende var' : 'Owned';
  static String get myLook => _lang == 'tr' ? 'Görünümüm' : 'My look';
  static String get allItems => _lang == 'tr' ? 'Tüm avatar ve banner\'lar' : 'All avatars & banners';
  static String get edit => _lang == 'tr' ? 'Düzenle' : 'Edit';
  static String get look => _lang == 'tr' ? 'Görünüm' : 'Look';
  static String get banners => _lang == 'tr' ? 'Banner\'lar' : 'Banners';
  static String get changeLookDesc => _lang == 'tr'
      ? 'Avatarın ve banner\'ın sıralamada herkese görünür'
      : 'Your avatar and banner show on every leaderboard';
  static String get watch => _lang == 'tr' ? 'İzle' : 'Watch';
  static String get boosts => _lang == 'tr' ? 'Güçlendirmeler' : 'Boosts';
  static String get streakFreeze => _lang == 'tr' ? 'Seri dondurma' : 'Streak freeze';
  static String freezeOwned(int n) =>
      _lang == 'tr' ? 'Kaçırdığın günü kurtarır · Sende: $n/2' : 'Saves a missed day · You have $n/2';
  static String get chooseAvatar => _lang == 'tr' ? 'Profilin' : 'Your profile';
  static String get characters => _lang == 'tr' ? 'Karakterler' : 'Characters';
  static String get emojis => _lang == 'tr' ? 'Emojiler' : 'Emojis';
  static String get changeAvatarRow => _lang == 'tr' ? 'Avatar ve banner' : 'Avatar & banner';
  static String get changeAvatarDesc =>
      _lang == 'tr' ? 'Karakter, emoji ve banner seç' : 'Pick a character, emoji and banner';
  static String get avatars => _lang == 'tr' ? 'Avatarlar' : 'Avatars';
  static String get adNotReady => _lang == 'tr' ? 'Reklam henüz hazır değil, birazdan dene.' : 'Ad not ready yet, try again shortly.';
  static String coinsEarned(int n) => _lang == 'tr' ? '+$n coin kazandın!' : '+$n coins!';
  static String get freezeFull => _lang == 'tr' ? 'En fazla 2 donma hakkı taşıyabilirsin.' : 'You can hold at most 2 freezes.';
  static String get freezeBought => _lang == 'tr' ? 'Donma hakkı eklendi!' : 'Freeze added!';
  static String get balance => _lang == 'tr' ? 'Bakiye' : 'Balance';
  static String get notEnoughCoins => _lang == 'tr' ? 'Yeterli coin yok.' : 'Not enough coins.';
  static String refillWithCoins(int n) => _lang == 'tr' ? 'Coin ile doldur · $n' : 'Refill with coins · $n';

  // ─── Günlük ödül & sandık ──────────────────────────────────────
  static String get dailyReward => _lang == 'tr' ? 'Günlük Ödül' : 'Daily Reward';
  static String get dailyRewardDesc => _lang == 'tr'
      ? 'Her gün gel, ödül büyüsün. Bir gün kaçırırsan başa dönersin.'
      : 'Come back daily and it grows. Miss a day and it resets.';
  static String day(int n) => _lang == 'tr' ? '$n. Gün' : 'Day $n';
  static String get claim => _lang == 'tr' ? 'TOPLA' : 'CLAIM';
  static String get runChest => _lang == 'tr' ? 'Koşu sandığı' : 'Run chest';
  static String get openChest => _lang == 'tr' ? 'SANDIĞI AÇ' : 'OPEN CHEST';
  static String get doubleWithAd => _lang == 'tr' ? 'Reklamla 2 katı' : 'Double with ad';
  static String get collect => _lang == 'tr' ? 'Topla' : 'Collect';

  // ─── Hedef skor ────────────────────────────────────────────────
  static String targetToBeat(String who, String score) =>
      _lang == 'tr' ? 'Hedef: $who · $score' : 'Target: $who · $score';
  static String get pointsShort => _lang == 'tr' ? 'puan' : 'pts';
  static String get yourLastRun => _lang == 'tr' ? 'Rekorun' : 'Your best';
  static String targetBeaten(String who) => _lang == 'tr' ? '$who geçildi!' : 'Beat $who!';

  // ─── Oyun içi coin kullanımı (yalnızca bilet modu) ───────────────
  static String get hint => _lang == 'tr' ? 'İpucu' : 'Hint';
  static String get wordleHintDesc => _lang == 'tr'
      ? 'Henüz bulmadığın bir harfi ve yerini açar.'
      : 'Reveals a letter you haven\'t found and its position.';
  static String wordleHintResult(int pos, String letter) =>
      _lang == 'tr' ? '$pos. harf: $letter' : 'Letter $pos: $letter';
  static String get keepGoing => _lang == 'tr' ? 'Devam et' : 'Keep going';
  static String get plusTime => _lang == 'tr' ? '+10 sn' : '+10 s';
  static String get secondChance => _lang == 'tr' ? 'İkinci şans!' : 'Second chance!';
  static String get secondChanceDesc => _lang == 'tr'
      ? 'Coin harcayarak kaldığın yerden devam et.'
      : 'Spend coins to continue where you left off.';
  static String get noThanks => _lang == 'tr' ? 'Hayır, bitir' : 'No thanks';

  // ─── Düello ───────────────────────────────────────────────────
  static String get duel => _lang == 'tr' ? 'Düello' : 'Duel';
  static String get findOpponent => _lang == 'tr' ? 'RAKİP BUL' : 'FIND OPPONENT';
  static String get challengeFriend => _lang == 'tr' ? 'Arkadaşını çağır' : 'Challenge a friend';
  static String get searchingOpponent =>
      _lang == 'tr' ? 'Rakip aranıyor… Biri bulununca düellon burada belirecek.' : 'Looking for an opponent… Your duel will appear here.';
  static String get duelHowTo => _lang == 'tr'
      ? '3 tur, aynı bulmacalar. Turlarını istediğin zaman oyna; 48 saatte bitirmeyen kaybeder.'
      : '3 rounds, same puzzles. Play your rounds any time; finish within 48 hours or lose.';
  static String get activeDuels => _lang == 'tr' ? 'Düellolarım' : 'My duels';
  static String get finishedDuels => _lang == 'tr' ? 'Bitenler' : 'Finished';
  static String get noDuelsYet => _lang == 'tr'
      ? 'Henüz düellon yok.\nRakip bul ya da bir arkadaşını çağır!'
      : 'No duels yet.\nFind an opponent or challenge a friend!';
  static String get yourTurn => _lang == 'tr' ? 'Sıra sende!' : 'Your turn!';
  static String get waitingOpponent => _lang == 'tr' ? 'Rakip oynuyor' : 'Opponent\'s turn';
  static String get yourTurnLong => _lang == 'tr' ? 'Sıra sende, turunu oyna!' : 'Your turn, play your round!';
  static String get waitingOpponentLong =>
      _lang == 'tr' ? 'Turlarını bitirdin, rakibini bekliyorsun' : 'You\'re done, waiting for your opponent';
  static String duelExpiresIn(int h) => _lang == 'tr' ? '$h saat içinde bitmeli' : 'Must finish within $h hours';
  static String get round => _lang == 'tr' ? 'Tur' : 'Round';
  static String get trophyLeague => _lang == 'tr' ? 'Kupa Ligi' : 'Trophy League';
  static String leagueName(String n) => _lang == 'tr' ? '$n Ligi' : '$n League';
  static String toNextLeague(int n, String league) =>
      _lang == 'tr' ? '$league için $n kupa' : '$n trophies to $league';
  static String get winShort => _lang == 'tr' ? 'G' : 'W';
  static String get lossShort => _lang == 'tr' ? 'M' : 'L';
  static String get drawShort => _lang == 'tr' ? 'B' : 'D';
  static String duelResult(DuelResult r) => switch (r) {
        DuelResult.win => _lang == 'tr' ? 'Kazandın' : 'You won',
        DuelResult.loss => _lang == 'tr' ? 'Kaybettin' : 'You lost',
        DuelResult.draw => _lang == 'tr' ? 'Berabere' : 'Draw',
      };
  static String duelResultTitle(DuelResult r) => switch (r) {
        DuelResult.win => _lang == 'tr' ? 'Kazandın!' : 'Victory!',
        DuelResult.loss => _lang == 'tr' ? 'Kaybettin' : 'Defeat',
        DuelResult.draw => _lang == 'tr' ? 'Berabere' : 'Draw',
      };
  static String duelResultToast(DuelResult r, String name, int trophies, int coins) {
    final t = '${trophies >= 0 ? '+' : ''}$trophies 🏆 · +$coins 🪙';
    return switch (r) {
      DuelResult.win => _lang == 'tr' ? '$name\'ı yendin! $t' : 'You beat $name! $t',
      DuelResult.loss => _lang == 'tr' ? '$name kazandı. $t' : '$name won. $t',
      DuelResult.draw => _lang == 'tr' ? '$name ile berabere. $t' : 'Draw with $name. $t',
    };
  }
  static String get duelNeedsInternet =>
      _lang == 'tr' ? 'Düello için internet bağlantısı gerekiyor.' : 'Duels need an internet connection.';
  static String get duelError => _lang == 'tr' ? 'Bir sorun oldu, tekrar dene.' : 'Something went wrong, try again.';
  static String get duelNoFriends =>
      _lang == 'tr' ? 'Önce Sıralama > Arkadaş sekmesinden arkadaş ekle.' : 'Add friends first from Ranking > Friends.';
  static String get duelPickFriend => _lang == 'tr' ? 'Kimi çağıralım?' : 'Who do you challenge?';
  static String get duelSent => _lang == 'tr' ? 'Düello gönderildi! İlk turunu oyna.' : 'Duel sent! Play your first round.';
  static String get duelReminderTitle => _lang == 'tr' ? 'Düellonda sıra sende ⚔️' : 'Your move in a duel ⚔️';
  static String duelReminderBody(int n) => _lang == 'tr'
      ? (n == 1 ? 'Rakibin bekliyor. Turunu oyna, kupaları kap!' : '$n düellonda sıra sende. Kupalar seni bekliyor!')
      : (n == 1 ? 'Your opponent is waiting. Play your round!' : 'It\'s your turn in $n duels. Trophies await!');

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
  static String get shareResult => _lang == 'tr' ? 'Sonucu Paylaş' : 'Share Result';
  static String get outOf => _lang == 'tr' ? 'üzerinden' : 'max';
  static String topPercent(int pct) => _lang == 'tr' ? 'Oyuncuların ilk %$pct\'i' : 'Top $pct% of players';
  static String rankOf(int rank, int total) => _lang == 'tr' ? '$total oyuncu içinde $rank.' : '#$rank of $total players';
  static String streakDays(int n) => _lang == 'tr' ? '$n günlük seri' : '$n-day streak';
  static String get freezeEarned => _lang == 'tr' ? '+1 donma hakkı' : '+1 streak freeze';
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
  static String get friends => _lang == 'tr' ? 'ARKADAŞ' : 'FRIENDS';
  static String get addFriend => _lang == 'tr' ? 'Arkadaş Ekle' : 'Add Friend';
  static String get shareMyCode => _lang == 'tr' ? 'Kodumu Paylaş' : 'Share My Code';
  static String get pasteFriendCode => _lang == 'tr' ? 'Arkadaş kodunu yapıştır' : 'Paste a friend code';
  static String get add => _lang == 'tr' ? 'Ekle' : 'Add';
  static String get remove => _lang == 'tr' ? 'Çıkar' : 'Remove';
  static String get time => _lang == 'tr' ? 'Süre' : 'Time';
  static String get playNow => _lang == 'tr' ? 'Hemen oyna' : 'Play now';
  static String get longPressToRemove => _lang == 'tr' ? 'Arkadaşı çıkarmak için uzun bas' : 'Long-press a friend to remove';
  static String get notPlayedToday => _lang == 'tr' ? 'bugün oynamadı' : 'not played today';
  static String get noFriendsYet => _lang == 'tr'
      ? 'Henüz arkadaşın yok.\nKodunu paylaş, arkadaşının kodunu ekle,\nkim daha iyi görelim!'
      : 'No friends yet.\nShare your code, add theirs,\nand see who is better!';
  static String removeFriendQuestion(String name) =>
      _lang == 'tr' ? '$name listenden çıkarılsın mı?' : 'Remove $name from your list?';
  static String addFriendResult(AddFriendResult r) {
    final tr = _lang == 'tr';
    switch (r) {
      case AddFriendResult.added:
        return tr ? 'Arkadaş eklendi!' : 'Friend added!';
      case AddFriendResult.invalid:
        return tr ? 'Geçerli bir arkadaş kodu bulunamadı.' : 'That doesn\'t look like a friend code.';
      case AddFriendResult.self:
        return tr ? 'Bu senin kendi kodun.' : 'That\'s your own code.';
      case AddFriendResult.duplicate:
        return tr ? 'Bu arkadaş zaten listende.' : 'Already in your list.';
      case AddFriendResult.full:
        return tr
            ? 'Arkadaş listen dolu (en fazla ${FriendsService.maxFriends}).'
            : 'Friend list is full (max ${FriendsService.maxFriends}).';
    }
  }
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
  static String get badges => _lang == 'tr' ? 'Rozetler' : 'Badges';
  static String get locked => _lang == 'tr' ? 'kilitli' : 'locked';
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
  static String get exitConfirmationDailyRun => _lang == 'tr'
      ? 'Çıkarsan bu oyun 0 puanla kapanır ve bu Daily Run\'da tekrar oynanamaz.'
      : 'If you quit, this game ends with 0 points and can\'t be replayed in this Daily Run.';
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
  // Duolingo tarzı seri bildirimleri: her gün farklı metin
  static (String, String) streakReminderNotif(int n, int variant) {
    final tr = _lang == 'tr';
    final options = tr
        ? [
            ('🔥 $n günlük seri!', 'Bugünkü oyununu oyna, serin $n+1 olsun.'),
            ('Alevin sönmesin 🔥', '$n gündür buradasın. Bugün de bir oyun yeter!'),
            ('Günün oyunları hazır 🎮', 'Tek bir oyun bitir, $n günlük serini koru.'),
            ('Rakiplerin oynadı 👀', 'Sıra sende! $n günlük serini sürdür.'),
          ]
        : [
            ('🔥 $n-day streak!', 'Play today to make it ${n + 1}.'),
            ('Keep the flame alive 🔥', '$n days in a row. One game today is enough!'),
            ('Today\'s games are ready 🎮', 'Finish one game to protect your $n-day streak.'),
            ('Your rivals played 👀', 'Your turn! Keep your $n-day streak going.'),
          ];
    final i = (DateTime.now().day + variant) % options.length;
    return options[i];
  }

  static (String, String) comeBackNotif(int variant) {
    final tr = _lang == 'tr';
    final options = tr
        ? [
            ('Yeni Daily Run hazır 🎮', '7 oyun, 10 dakika. Bugün bir seri başlat!'),
            ('Beynini ısıt 🧠', 'Tek oyun bitir, ilk 🔥 günün başlasın.'),
            ('Sıralamada yerin boş 🏆', 'Bugünün turunu oyna, ilk sıralara yerleş.'),
          ]
        : [
            ('A new Daily Run is ready 🎮', '7 games, 10 minutes. Start a streak today!'),
            ('Warm up your brain 🧠', 'Finish one game to light your first 🔥.'),
            ('Your spot is open 🏆', 'Play today\'s run and climb the ranks.'),
          ];
    return options[(DateTime.now().day + variant) % options.length];
  }

  static String get streakDayTitle => _lang == 'tr' ? 'günlük seri!' : 'day streak!';
  static String get streakComeBackTomorrow => _lang == 'tr'
      ? 'Harika! Yarın tek bir oyun daha, seri büyümeye devam etsin.'
      : 'Nice! One game tomorrow keeps it growing.';
  static String streakMilestone(int n) => _lang == 'tr'
      ? '$n gün üst üste! Bu bir alışkanlık oldu bile 🎉'
      : '$n days in a row! That\'s a habit now 🎉';
  static String get freezeEarnedLong =>
      _lang == 'tr' ? '7 günlük ödül: +1 donma hakkı' : '7-day reward: +1 streak freeze';
  static String get streakAtRiskTitle => _lang == 'tr' ? 'Serin tehlikede! ⏰' : 'Streak at risk! ⏰';
  static String streakAtRiskBody(int n) => _lang == 'tr'
      ? 'Gün bitmeden 2 saat kaldı. $n günlük serini kurtarmak için tek oyun yeter.'
      : '2 hours left today. One game saves your $n-day streak.';
  static String get streakLastChanceTitle => _lang == 'tr' ? 'Son şans! 🚨' : 'Last chance! 🚨';
  static String get streakFreezeWillSave => _lang == 'tr'
      ? 'Bugün oynamazsan donma hakkın kullanılacak. Hakkını harcama, hemen bir oyun bitir!'
      : 'Skip today and a streak freeze gets used. Save it, play one game now!';
  static String streakWillReset(int n) => _lang == 'tr'
      ? 'Gece yarısı $n günlük serin sıfırlanacak!'
      : 'Your $n-day streak resets at midnight!';
  static String get streakFrozenNotifTitle => _lang == 'tr' ? 'Donma hakkın serini kurtardı ❄️' : 'A freeze saved your streak ❄️';
  static String streakFrozenNotifBody(int n) => _lang == 'tr'
      ? 'Dün oynamadın ama $n günlük serin duruyor. Bugün oyna, alevi yeniden yak!'
      : 'You missed yesterday, but your $n-day streak survived. Play today to relight it!';
  static String streakRestoreNotifTitle(int n) =>
      _lang == 'tr' ? '$n günlük serin bitti 💔' : 'Your $n-day streak ended 💔';
  static String get streakRestoreNotifBody => _lang == 'tr'
      ? '48 saat içinde geri getirebilirsin. Uygulamayı aç ve serini kurtar!'
      : 'You can bring it back within 48 hours. Open the app to restore it!';

  static String get streakReminderTitle =>
      _lang == 'tr' ? 'Serini Kaybetme! 🔥' : 'Keep Your Streak! 🔥';
  static String get streakReminderBody => _lang == 'tr'
      ? 'Bugün tek bir oyun bitir, serin bozulmasın!'
      : 'Finish one game today to keep your streak alive!';
  static String get streakSavedTitle => _lang == 'tr' ? 'Serin Dondu' : 'Streak Frozen';
  static String get streakSavedBody => _lang == 'tr'
      ? 'Dondurma hakkın kullanıldı, hakkın bitmeden serini kurtar.'
      : 'Your freeze chance was used, save your streak before it runs out.';
  static String get streakLostTitle => _lang == 'tr' ? 'Son Şans!' : 'Last Chance!';
  static String get streakLostBody => _lang == 'tr'
      ? 'Serini kurtarmak için son şansın, hemen kurtar.'
      : 'This is your last chance to restore your streak, do it now.';
}
