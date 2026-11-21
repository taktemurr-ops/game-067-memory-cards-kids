import 'package:flutter/material.dart';

import 'package:studio_core/app/game_api.dart';
import 'memory_view.dart';
import 'rules.dart';

/// Kids & Family game: kidsMode treats every player as a child (no
/// personalized ads, no analytics, child-directed ad requests, parental
/// gate in the shop).
final gameConfig = GameConfig(
  gameId: 'game-067-memory-cards-kids',
  title: const ['Çocuk Hafıza Kartları', 'Memory Cards Kids', 'Memo Karten Kinder', 'Cartas de Memoria', 'Cartes Mémoire'],
  tagline: const ['Kartları çevir, eşleri bul!', 'Flip the cards and find the pairs!', 'Karten umdrehen, Paare finden!', '¡Gira cartas y encuentra parejas!', 'Retourne les cartes, trouve les paires !'],
  seedColor: const Color(0xFF06D6A0),
  icon: Icons.style,
  rules: MemoryRules(),
  buildPlay: (ctx) => MemoryView(ctx: ctx),
  kidsMode: true,
  tutorial: const [
    TutorialStep(Icons.style, ['İki kart çevir.', 'Flip two cards.', 'Zwei Karten umdrehen.', 'Gira dos cartas.', 'Retourne deux cartes.']),
    TutorialStep(Icons.visibility, ['Başta kartlara iyi bak!', 'Look closely at the start!', 'Am Anfang gut schauen!', '¡Mira bien al principio!', 'Regarde bien au début !']),
    TutorialStep(Icons.auto_awesome, ['Eşleştir güçlendirmesi bir çifti açar.', 'The booster opens one pair.', 'Booster öffnet ein Paar.', 'El potenciador abre una pareja.', 'Le bonus ouvre une paire.']),
  ],
);
