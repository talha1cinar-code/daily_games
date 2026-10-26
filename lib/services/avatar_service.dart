/// Avatar kataloğu. Avatar değerleri sıralama kayıtlarında tek bir metin olarak tutulur:
///   - emoji: '🦊'
///   - çizilmiş karakter: 'img:fox'  → assets/avatars/fox.png
class AvatarService {
  static const String imagePrefix = 'img:';

  /// Oyuna başlarken yalnızca bu 4 karakter ücretsiz; geri kalan her şey coin ile açılır
  static const List<String> freeCharacters = ['fox', 'cat', 'bear', 'rabbit'];
  static const List<String> premiumCharacters = [
    'frog', 'penguin', 'panda', 'tiger', 'owl', 'koala', 'robot', 'alien',
  ];

  static bool isFree(String avatar) =>
      avatar.startsWith(imagePrefix) && freeCharacters.contains(avatar.substring(imagePrefix.length));

  static String character(String id) => '$imagePrefix$id';

  static String? assetFor(String avatar) =>
      avatar.startsWith(imagePrefix) ? 'assets/avatars/${avatar.substring(imagePrefix.length)}.png' : null;
}
