import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:creatures_rogue/game/components/core/palette.dart';
import 'package:creatures_rogue/game/components/creatures/creature_registry.dart';
import 'package:creatures_rogue/game/components/creatures/creature_type.dart';
import 'package:creatures_rogue/game/components/map/obstacle.dart';
import 'package:creatures_rogue/game/components/map/wall_barrier.dart';
import 'package:creatures_rogue/game/components/projeteis/explosion_hitbox.dart';
import '../enemy.dart';

/// Ouriço Elétrico como inimigo: não persegue e não atira — só vaga devagar.
/// O perigo é bater nele: cada golpe recebido solta uma explosão elétrica ao
/// redor do próprio corpo, empurrando o jogador pra longe (Player não tem
/// atordoamento — knockback é o equivalente de "não fica perto disso").
/// Intervalo mínimo entre disparos pra não virar um combo de empurrão infinito.
class OuricoEletricoEnemy extends Enemy {
  static const double _cooldownRetaliacao = 1.0;
  static const double _danoRetaliacao = 2.0;
  static const double _empurraoRetaliacao = 60.0;

  double _retaliacaoTimer = 0.0;

  OuricoEletricoEnemy({
    required super.position,
    required super.playerTarget,
  }) : super(
         creature: CreatureRegistry.ouricoEletrico,
         speed: 14.0, // o mais lento do elenco: não foge, não persegue
         health: 20,  // stats.maxHp 14 / defesa 5 → aguenta apanhar de perto
         dmg: 1,
       );

  @override
  void update(double dt) {
    super.update(dt);
    if (_retaliacaoTimer > 0) _retaliacaoTimer -= dt;
  }

  @override
  void movimento(double dt) {
    updateWanderMovement(dt, minPause: 0.8, maxPause: 1.8, minMove: 0.5, maxMove: 1.2);
  }

  @override
  void takeDamage(
    double amount, {
    Color corTxt = Palette.amarelo,
    CreatureType tipoAtacante = CreatureType.neutro,
    bool doJogador = true,
    bool revela = true,
  }) {
    super.takeDamage(
      amount,
      corTxt: corTxt,
      tipoAtacante: tipoAtacante,
      doJogador: doJogador,
      revela: revela,
    );
    if (health <= 0) return;
    if (_retaliacaoTimer > 0) return;

    _retaliacaoTimer = _cooldownRetaliacao;
    parent?.add(ExplosionHitbox(
      explosao: true,
      position: position.clone(),
      isEnemy: true, // machuca o jogador, não outros inimigos
      origem: creature,
      dono: this,
      dmg: _danoRetaliacao,
      knockback: _empurraoRetaliacao,
      cor1: CreatureRegistry.ouricoEletrico.corClara,
      cor2: CreatureRegistry.ouricoEletrico.corEscura,
    ));
  }

  @override
  void onCollision(Set<Vector2> intersectionPoints, PositionComponent other) {
    super.onCollision(intersectionPoints, other);
    if (other is WallBarrier || other is Obstacle) {
      if (!isPhysicsCollision(other)) return;
      cancelWander();
    }
  }
}
