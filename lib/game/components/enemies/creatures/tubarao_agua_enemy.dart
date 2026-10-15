import 'package:flame/components.dart';
import 'package:creatures_rogue/game/components/creatures/creature_registry.dart';
import 'package:creatures_rogue/game/components/map/obstacle.dart';
import 'package:creatures_rogue/game/components/map/wall_barrier.dart';
import 'package:creatures_rogue/game/components/projeteis/explosion_hitbox.dart';
import '../enemy.dart';
import '../enemy_mixins.dart';

/// Tubarão de Água como inimigo: sem ataque à distância. A única ameaça dele
/// é o próprio pulo em cima do jogador, que estoura ao pousar — igual à
/// versão jogável, só que sem controle de quando (é o `JumpMovement` que
/// decide o timing, não um botão).
///
/// `moveAnim` fica null pelo mesmo motivo do Sapo de Água: o pulo já É a
/// animação.
class TubaraoAguaEnemy extends Enemy with JumpMovement {
  static const double _danoPouso = 1.0;
  static const double _empurraoPouso = 60.0;

  bool _emVoo = false;

  TubaraoAguaEnemy({
    required super.position,
    required super.playerTarget,
  }) : super(
         creature: CreatureRegistry.tubaraoAgua,
         moveAnim: null,
         speed: 0.0, // quem move é o JumpMovement
         health: 20, // stats.maxHp 20 / defesa 3, atk 5 → bombado de verdade
         dmg: 1,
         shadowOffset: Vector2(0, 4),
       );

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    setupJumpAnimations(prepTime: 0.35);
    idleDuration = 1.4;
    airDuration = 0.5;
  }

  @override
  void movimento(double dt) {
    updateJumpMovement(
      dt,
      alvoPosicao,
      mode: JumpMode.targetPlayer,
      jumpDistance: 34.0,
      jumpHeight: 20.0,
    );

    if (jumpState == JumpState.inAir) _emVoo = true;

    if (jumpState != JumpState.inAir && _emVoo) {
      _emVoo = false;
      _estourarAoPousar();
    }
  }

  void _estourarAoPousar() {
    parent?.add(ExplosionHitbox(
      explosao: true,
      position: position.clone(),
      isEnemy: true,
      origem: creature,
      dono: this,
      dmg: _danoPouso,
      knockback: _empurraoPouso,
      size: Vector2(28, 28),
      cor1: CreatureRegistry.tubaraoAgua.corClara,
      cor2: CreatureRegistry.tubaraoAgua.corEscura,
    ));
  }

  @override
  void onCollision(Set<Vector2> intersectionPoints, PositionComponent other) {
    super.onCollision(intersectionPoints, other);
    if (other is WallBarrier || other is Obstacle) {
      if (!isPhysicsCollision(other)) return;
      cancelJump();
    }
  }
}
