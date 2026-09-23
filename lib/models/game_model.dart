import 'package:flutter/material.dart';

class GameModel {
  final String name;
  final IconData icon;
  final String? imagePath;
  final String? routeName;
  final bool isComingSoon;

  const GameModel({
    required this.name,
    required this.icon,
    this.imagePath,
    this.routeName,
    this.isComingSoon = true,
  });

  String get id => name.toLowerCase();
}

// İlk oyun Wordle, diğerleri yakında
const List<GameModel> games = [
  GameModel(
    name: 'Wordle',
    icon: Icons.abc_rounded,
    imagePath: 'assets/images/wordle.png',
    routeName: '/wordle',
    isComingSoon: false,
  ),
  GameModel(
    name: 'Wikitrivia',
    icon: Icons.timeline_rounded,
    imagePath: 'assets/images/wikitrivia.png',
    routeName: '/wikitrivia',
    isComingSoon: false,
  ),
  GameModel(
    name: 'Nerdle',
    icon: Icons.calculate_rounded,
    imagePath: 'assets/images/nerdle.png',
    routeName: '/nerdle',
    isComingSoon: false,
  ),
  GameModel(
    name: 'Worldle',
    icon: Icons.public_rounded,
    imagePath: 'assets/images/worldle.png',
    routeName: '/worldle',
    isComingSoon: false,
  ),
  GameModel(
    name: 'RGBle',
    icon: Icons.color_lens_rounded,
    imagePath: 'assets/images/rgble.png',
    routeName: '/rgble',
    isComingSoon: false,
  ),
  GameModel(
    name: 'Sound',
    icon: Icons.graphic_eq_rounded,
    imagePath: 'assets/images/sound.png',
    routeName: '/sound',
    isComingSoon: false,
  ),
  GameModel(
    name: 'Timele',
    icon: Icons.av_timer_rounded,
    imagePath: 'assets/images/timele.png',
    routeName: '/timele',
    isComingSoon: false,
  ),
  GameModel(
    name: 'Linele',
    icon: Icons.timeline_rounded,
    imagePath: 'assets/images/linele.png',
    routeName: '/linele',
    isComingSoon: false,
  ),
  GameModel(
    name: 'Huedle',
    icon: Icons.grid_view_rounded,
    imagePath: 'assets/images/huedle.png',
    routeName: '/huedle',
    isComingSoon: false,
  ),
  GameModel(
    name: 'Fille',
    icon: Icons.water_drop_rounded,
    imagePath: 'assets/images/fille.png',
    routeName: '/fille',
    isComingSoon: false,
  ),
  GameModel(
    name: 'Memorle',
    icon: Icons.psychology_rounded,
    imagePath: 'assets/images/memorle.png',
    routeName: '/memorle',
    isComingSoon: false,
  ),
  GameModel(
    name: 'Reactle',
    icon: Icons.speed_rounded,
    imagePath: 'assets/images/reactle.png',
    routeName: '/reactle',
    isComingSoon: false,
  ),
];
