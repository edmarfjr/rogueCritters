import 'package:flame/components.dart';
import 'package:creatures_rogue/game/components/creatures/creature_registry.dart';
import 'package:creatures_rogue/game/components/map/obstacle.dart';
import 'package:creatures_rogue/game/components/map/wall_barrier.dart';
import 'package:creatures_rogue/game/components/projeteis/explosion_hitbox.dart';
import '../enemy.dart';
import '../enemy_mixins.dart';

/// Cobra de Água como inimigo: rasteja de leve enquanto mede o jogador, e
/// quando ele chega perto dá o **bote** — um salto telegrafado que termina
/// numa explosão de impacto que repele. É o inimigo "desvia disso".
///
/// `moveAnim` null: o JumpMovement escreve visual.scale e visual.position.y,
/// mesmos canais que um MovementAnimator usaria.
class CobraAguaEnemy extends Enemy with JumpMovement {
  static const double _alcanceBote = 70.0;
  static const int _danoImpacto = 2;
  static const double _empurraoImpacto = 40.0;

  bool _boteEmVoo = false;

  CobraAguaEnemy({
    required super.position,
    required super.playerTarget,
  }) : super(
         creature: CreatureRegistry.cobraAgua,
         moveAnim: null, // o bote é a animação
         speed: 0.0,     // quem move é o JumpMovement
         health: 20,      // stats: def 4 / atk 4 → dura mais que a média
         dmg: 1,
         shadowOffset: Vector2(0, 3),
       );

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    setupJumpAnimations(prepTime: 0.45); // telegrafa bem: dá tempo de reagir

    idleDuration = 1.3;
    airDuration = 0.35;
  }

  @override
  void movimento(double dt) {
    final distancia = (alvoPosicao - absolutePosition).length;
    final estavaNoAr = jumpState == JumpState.inAir;

    updateJumpMovement(
      dt,
      alvoPosicao,
      // Perto: bote em cima do jogador. Longe: reposiciona à toa.
      mode: distancia <= _alcanceBote ? JumpMode.targetPlayer : JumpMode.random,
      jumpDistance: distancia <= _alcanceBote ? _alcanceBote : 24.0,
      jumpHeight: 18.0,
    );

    if (jumpState == JumpState.inAir) _boteEmVoo = true;

    // Aterrissou neste frame: solta a onda de impacto.
    if (estavaNoAr && jumpState != JumpState.inAir && _boteEmVoo) {
      _boteEmVoo = false;
      _impactoAoPousar();
    }
  }

  void _impactoAoPousar() {
    parent?.add(ExplosionHitbox(
      explosao: true,
      position: position.clone(),
      isEnemy: true, // sem isso a explosão não machuca o jogador
      origem: creature,
      dono: this,
      dmg: _danoImpacto.toDouble(),
      knockback: _empurraoImpacto,
      size: Vector2(30, 30),
      cor1: CreatureRegistry.cobraAgua.corClara,
      cor2: CreatureRegistry.cobraAgua.corEscura,
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
