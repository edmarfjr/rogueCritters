import 'dart:ui' as ui;

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:creatures_rogue/game/components/creatures/damageable_by_enemy.dart';
import 'package:creatures_rogue/game/components/enemies/enemy.dart';
import 'package:creatures_rogue/game/components/projeteis/explosion_hitbox.dart';
import 'package:creatures_rogue/game/components/core/palette.dart';
import 'package:creatures_rogue/game/components/utils/palette_swapper.dart';
import 'package:creatures_rogue/game/components/map/wall_barrier.dart';
import 'package:creatures_rogue/game/components/map/obstacle.dart';


// 1. A BOMBA
class Bomb extends SpriteAnimationComponent with CollisionCallbacks, HasGameRef {
  double timer = 2.0; 
  Vector2 velocity = Vector2.zero();
  final double friction = 80.0; // O quão rápido a bomba para de deslizar
  double acc = 100.0;
  Vector2 _previousPosition = Vector2.zero();
  double dmg = 5;

  Bomb({required Vector2 position}) 
      : super(position: position, size: Vector2(16, 16), anchor: Anchor.center);

  @override
  Future onLoad() async {
    final ui.Image bombImg = await PaletteSwapper.createSwappedImage(
      imagePath: 'projeteis/bomb.png',
      lightGrayReplacement: Palette.indigo,
      darkGrayReplacement: Palette.azulEsc,
    );
    animation = SpriteAnimation.fromFrameData(
      bombImg,
      SpriteAnimationData.sequenced(amount: 2, stepTime: 0.2, textureSize: Vector2(16, 16)),
    );

    paint = Paint()..filterQuality = FilterQuality.none;

    add(RectangleHitbox(collisionType: CollisionType.active));
    _previousPosition = position.clone();
  }

  @override
  void update(double dt) {
    _previousPosition = position.clone();
    super.update(dt);
    timer -= dt;
    
    if (timer < 0.5) animation?.stepTime = 0.05;

    if (timer <= 0) {
      _explode();
    }

    if (!velocity.isZero()) {
      double drop = friction * dt;
      if (velocity.length < drop) {
        velocity.setZero(); 
      } else {
        velocity -= velocity.normalized() * drop; 
      }
      position += velocity * dt;
    }
  }

  void _explode() {
    final currentWorld = parent; 
    currentWorld?.add(
      ExplosionHitbox(position: position.clone(), dmg: dmg, explosao: true),
    );
    
    removeFromParent();
  }

  @override
  void onCollision(Set<Vector2> intersectionPoints, PositionComponent other) {
    super.onCollision(intersectionPoints, other);

    if (other is DamageableByEnemy) {
      Vector2 pushDir = (absolutePosition - other.absolutePosition).normalized();
      velocity = pushDir * acc;
      
    } else if (other is Enemy) {
      velocity.setZero();
      _explode();
      
    } else if (other is WallBarrier || other is Obstacle) {
      velocity.setZero();
      
      if (intersectionPoints.isNotEmpty) {
        Vector2 collisionCenter = Vector2.zero();
        for (var point in intersectionPoints) {
          collisionCenter += point;
        }
        collisionCenter /= intersectionPoints.length.toDouble();

        Vector2 diff = absolutePosition - collisionCenter;
        
        if (diff.x.abs() > diff.y.abs()) {
          position.x = _previousPosition.x;
        } else {
          position.y = _previousPosition.y;
        }
      }
    }
  }
}

