import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:daily_games/services/coin_service.dart';
import 'package:daily_games/services/daily_reward_service.dart';
import 'package:daily_games/services/daily_run_service.dart';
import 'package:daily_games/services/avatar_service.dart';

String _key(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CoinService', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await CoinService().init();
    });

    test('ilk açılışta başlangıç coini verilir', () {
      expect(CoinService().balance, CoinService.startingCoins);
    });

    test('yetersiz bakiyede harcama reddedilir', () async {
      final before = CoinService().balance;
      expect(await CoinService().spend(before + 1, 'test'), isFalse);
      expect(CoinService().balance, before);
      expect(await CoinService().spend(before, 'test'), isTrue);
      expect(CoinService().balance, 0);
    });

    test('reklam ödülü günde yalnızca bir kez verilir', () async {
      expect(CoinService().canWatchAdToday, isTrue);
      for (var i = 0; i < 3; i++) {
        await CoinService().rewardAdWatched();
      }
      expect(CoinService().canWatchAdToday, isFalse);
      expect(CoinService().balance, CoinService.startingCoins + CoinService.adReward);
    });

    test('oyun ödülü skora göre 5-10 coin', () {
      expect(CoinService.gameReward(0), CoinService.gameRewardBase);
      expect(CoinService.gameReward(100), CoinService.gameRewardMax);
      expect(CoinService.gameReward(150), CoinService.gameRewardMax);
      expect(CoinService.gameReward(50), inInclusiveRange(CoinService.gameRewardBase, CoinService.gameRewardMax));
    });

    test('banner bir kez satın alınır, ikinci kez ücret alınmaz', () async {
      await CoinService().earn(500, 'test');
      final before = CoinService().balance;
      expect(await CoinService().buyBanner('gold', 500), isTrue);
      expect(CoinService().ownsBanner('gold'), isTrue);
      expect(await CoinService().buyBanner('gold', 500), isTrue);
      expect(CoinService().balance, before - 500);
      expect(CoinService().ownedAvatars, isEmpty, reason: 'banner avatar listesine karışmamalı');
    });
  });

  group('DailyRewardService', () {
    Future<void> setup(Map<String, Object> prefs) async {
      SharedPreferences.setMockInitialValues(prefs);
      await CoinService().init();
      await DailyRewardService().init();
    }

    test('ilk gün 1. ödül, aynı gün ikinci kez alınamaz', () async {
      await setup({});
      expect(DailyRewardService().currentDay, 0);
      expect(await DailyRewardService().claim(), DailyRewardService.rewards[0]);
      expect(DailyRewardService().canClaim, isFalse);
      expect(await DailyRewardService().claim(), 0);
    });

    test('dün alındıysa takvim ilerler', () async {
      final yesterday = _key(DailyRunService.turkeyNow.subtract(const Duration(days: 1)));
      await setup({'daily_reward_last': yesterday, 'daily_reward_day': 3});
      expect(DailyRewardService().currentDay, 3);
    });

    test('gün atlanırsa takvim başa döner', () async {
      final old = _key(DailyRunService.turkeyNow.subtract(const Duration(days: 3)));
      await setup({'daily_reward_last': old, 'daily_reward_day': 5});
      expect(DailyRewardService().currentDay, 0);
    });

    test('7. günden sonra yeniden 1. gün', () async {
      final yesterday = _key(DailyRunService.turkeyNow.subtract(const Duration(days: 1)));
      await setup({'daily_reward_last': yesterday, 'daily_reward_day': 7});
      expect(DailyRewardService().currentDay, 0);
    });
  });

  group('Avatarlar', () {
    test('başlangıçta yalnızca 4 karakter ücretsiz, emojiler ücretli', () {
      expect(AvatarService.freeCharacters.length, 4);
      expect(AvatarService.isFree('img:fox'), isTrue);
      expect(AvatarService.isFree('img:frog'), isFalse);
      expect(AvatarService.isFree('🦊'), isFalse);
      expect(CoinService.priceOfAvatar('img:panda'), CoinService.avatarPrice);
      expect(CoinService.priceOfAvatar('🦊'), CoinService.emojiPrice);
    });

    test('eskiden ücretsiz avatarı takılı olan kullanıcı onu kaybetmez', () async {
      SharedPreferences.setMockInitialValues({'leaderboard_avatar': 'img:penguin'});
      await CoinService().init();
      expect(CoinService().ownedAvatars, contains('img:penguin'));
    });
  });
}
