import 'package:creatures_rogue/game/components/utils/y_sort.dart';
import 'package:flame/components.dart';
import 'package:flame/collisions.dart';
import 'package:flutter/material.dart';
import 'package:creatures_rogue/game/creatures_rogue_game.dart';

import '../player/player.dart';

class Stairs extends PositionComponent
    with CollisionCallbacks, HasGameReference<CreaturesRogueGame> {
  late final Sprite sprite;
  final Paint _paint = Paint()..filterQuality = FilterQuality.none;

  /// `Player.playerHitbox` e `Player.physicsHitbox` são dois hitboxes ativos
  /// distintos — os dois podem disparar `onCollisionStart` aqui no mesmo
  /// frame. Sem essa trava, `nextLevel()` rodava duas vezes seguidas e
  /// avançava dois andares de uma vez em vez de um.
  bool _avancado = false;

  Stairs({required Vector2 position})
    : super(position: position, size: Vector2(16, 16), anchor: Anchor.center);

  @override
  Future onLoad() async {
    // Crie um trapdoor.png na sua pasta de assets
    sprite = await game.loadSprite('tileset/stairs.png');
    add(RectangleHitbox(collisionType: CollisionType.passive));
    priority = ySortPriority(position.y + size.y / 2);
  }

  @override
  void render(Canvas canvas) {
    sprite.render(canvas, size: size, overridePaint: _paint);
  }

  @override
  void onCollisionStart(Set intersectionPoints, PositionComponent other) {
    super.onCollisionStart(intersectionPoints.cast(), other);

    if (_avancado) return;
    if (other is Player) {
      // Quando o jogador pisa no alçapão, anima a transição (círculo fecha,
      // troca o andar por baixo, círculo abre) em vez de trocar na cara.
      _avancado = true;
      game.startLevelTransition();
    }
  }
}
