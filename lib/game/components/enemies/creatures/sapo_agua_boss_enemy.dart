import 'dart:math';

import 'package:flame/components.dart';
import 'package:creatures_rogue/game/components/creatures/creature_registry.dart';
import 'package:creatures_rogue/game/components/map/obstacle.dart';
import 'package:creatures_rogue/game/components/map/wall_barrier.dart';
import 'package:creatures_rogue/game/components/projeteis/explosion_hitbox.dart';
import '../enemy.dart';
import '../enemy_mixins.dart';

/// Sapo de Água Boss: a normal pula errático e cospe um jato só depois de
/// pousar, com os pés no chão. Este é o oposto — o pulo em si é a mira (mais
/// alto e mais lento que a normal, tempo de sobra pra prever onde cai), e o
/// ataque acontece NO instante do impacto: um leque de gosmas que estouram
/// ao redor do ponto de queda, tudo de uma vez.
///
/// Nota de implementação: não usa o `explosionSize` do Projectile — esse
/// caminho genérico não repassa dano nem marca `isEnemy`, então explodiria
/// sem machucar o jogador. O leque é montado com `ExplosionHitbox` direto.
///
/// Fase 2 (≤50%): o leque vai de 3 pra 5 gosmas — cobre um arco bem mais
/// largo ao redor da queda, não só mais dano por gosma.
class SapoAguaBossEnemy extends Enemy with JumpMovement {
  static const double _vidaInicial = 200.0; // 4x a normal (40)
  static const double _alcanceAtaque = 70.0;

  static const int _numGosmasFase1 = 3;
  static const int _numGosmasFase2 = 5;
  static const double _danoGosmaFase1 = 3.0;
  static const double _danoGosmaFase2 = 4.0;
  static const double _anguloLequeGraus = 25.0;
  static const double _offsetLeque = 20.0;
  static const double _empurraoGosma = 40.0;

  bool _faseDois = false;
  bool _emVoo = false;

  SapoAguaBossEnemy({
    required super.position,
    required super.playerTarget,
  }) : super(
         creature: CreatureRegistry.sapoAguaEvo,
         moveAnim: null, // o pulo é a animação
         speed: 0.0,     // quem move é o JumpMovement
         health: _vidaInicial,
         dmg: 2,
         shadowOffset: Vector2(0, 6),
         size: Vector2(48, 48),        // dobro do padrão (16x16)
         hitboxSize: Vector2(24, 20),  // dobro do hitbox normal (12, 10)
         isPushable: false,
       );

  int get _numGosmas => _faseDois ? _numGosmasFase2 : _numGosmasFase1;
  double get _danoGosma => _faseDois ? _danoGosmaFase2 : _danoGosmaFase1;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    setupJumpAnimations(prepTime: 0.4);

    idleDuration = 1.2;
    airDuration = 0.6; // alto e lento: dá tempo de prever a queda
  }

  @override
  void movimento(double dt) {
    if (!_faseDois && health <= _vidaInicial / 2) _faseDois = true;

    final distancia = (alvoPosicao - absolutePosition).length;
    final estavaNoAr = jumpState == JumpState.inAir;

    updateJumpMovement(
      dt,
      alvoPosicao,
      mode: distancia <= _alcanceAtaque ? JumpMode.targetPlayer : JumpMode.random,
      jumpDistance: distancia <= _alcanceAtaque ? _alcanceAtaque : 24.0,
      jumpHeight: 28.0,
    );

    if (jumpState == JumpState.inAir) _emVoo = true;

    // Aterrissou neste frame: o leque de gosmas estoura ao redor da queda.
    if (estavaNoAr && jumpState != JumpState.inAir && _emVoo) {
      _emVoo = false;
      _dispararLequeAoPousar();
    }
  }

  void _dispararLequeAoPousar() {
    final direcaoJogador = (alvoPosicao - absolutePosition).normalized();
    final direcaoBase = direcaoJogador.length > 0 ? direcaoJogador : Vector2(0, 1);
    final passoRad = _anguloLequeGraus * pi / 180;
    final metade = (_numGosmas - 1) / 2;

    for (int i = 0; i < _numGosmas; i++) {
      final anguloOffset = (i - metade) * passoRad;
      final direcao = direcaoBase.clone()..rotate(anguloOffset);

      parent?.add(ExplosionHitbox(
        explosao: true,
        position: position.clone() + direcao * _offsetLeque,
        isEnemy: true, // sem isso a gosma machuca inimigos em vez do jogador
        origem: creature,
        dono: this,
        dmg: _danoGosma,
        knockback: _empurraoGosma,
        size: Vector2(24, 24),
        cor1: CreatureRegistry.sapoAgua.corClara,
        cor2: CreatureRegistry.sapoAgua.corEscura,
      ));
    }
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
