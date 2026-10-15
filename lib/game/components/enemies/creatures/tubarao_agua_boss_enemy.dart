import 'package:flame/components.dart';
import 'package:creatures_rogue/game/components/creatures/creature_registry.dart';
import 'package:creatures_rogue/game/components/map/obstacle.dart';
import 'package:creatures_rogue/game/components/map/wall_barrier.dart';
import 'package:creatures_rogue/game/components/projeteis/explosion_hitbox.dart';
import '../enemy.dart';
import '../enemy_mixins.dart';

/// Tubarão de Água Boss: o mesmo ciclo de mergulho-e-estouro da normal, só
/// que o pulo mira mais longe e o estouro cresce.
///
/// Fase 2 (≤50%): a explosão de pouso quase dobra de tamanho e dano, e o
/// intervalo entre mergulhos cai — persegue com mais fome.
class TubaraoAguaBossEnemy extends Enemy with JumpMovement {
  static const double _vidaInicial = 250.0; // 4x a normal (45)

  static const double _danoPousoFase1 = 5.0;
  static const double _danoPousoFase2 = 8.0;
  static const double _empurraoPouso = 70.0;
  static const double _tamanhoFase1 = 32.0;
  static const double _tamanhoFase2 = 48.0;

  bool _faseDois = false;
  bool _emVoo = false;

  TubaraoAguaBossEnemy({
    required super.position,
    required super.playerTarget,
  }) : super(
         creature: CreatureRegistry.tubaraoAguaEvo,
         moveAnim: null,
         speed: 0.0,
         health: _vidaInicial,
         dmg: 2,
         shadowOffset: Vector2(0, 8),
         size: Vector2(32, 32),        // dobro do padrão (16x16)
         hitboxSize: Vector2(26, 30),  // dobro do hitbox normal (13, 15)
         isPushable: false,
       );

  double get _danoPouso => _faseDois ? _danoPousoFase2 : _danoPousoFase1;
  double get _tamanhoPouso => _faseDois ? _tamanhoFase2 : _tamanhoFase1;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    setupJumpAnimations(prepTime: 0.4);
    idleDuration = 1.2;
    airDuration = 0.55; // alto e lento: dá tempo de prever a queda
  }

  @override
  void movimento(double dt) {
    if (!_faseDois && health <= _vidaInicial / 2) {
      _faseDois = true;
      idleDuration = 0.8;
    }

    updateJumpMovement(
      dt,
      alvoPosicao,
      mode: JumpMode.targetPlayer,
      jumpDistance: 44.0,
      jumpHeight: 28.0,
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
      size: Vector2(_tamanhoPouso, _tamanhoPouso),
      cor1: CreatureRegistry.tubaraoAguaEvo.corClara,
      cor2: CreatureRegistry.tubaraoAguaEvo.corEscura,
    ));
  }

  @override
  void death() {
    unlockCreature();
    super.death();
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
