import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:creatures_rogue/game/components/core/palette.dart';
import 'package:creatures_rogue/game/components/creatures/creature_registry.dart';
import 'package:creatures_rogue/game/components/creatures/creature_type.dart';
import 'package:creatures_rogue/game/components/map/obstacle.dart';
import 'package:creatures_rogue/game/components/map/wall_barrier.dart';
import 'package:creatures_rogue/game/components/projeteis/explosion_hitbox.dart';
import '../enemy.dart';
import '../enemy_mixins.dart';

/// Ouriço Elétrico Boss — mesma regra da normal (bater nele empurra você pra
/// longe numa explosão elétrica), só que ele também ataca por conta própria:
/// de tempos em tempos se enrosca (guarda, quase imune) e ao abrir solta uma
/// onda maior no lugar. Fase 2 (≤50%) encurta o ciclo e escala dano/raio —
/// igual ao padrão da Tartaruga Ancestral, mas com choque em vez de força.
class OuricoEletricoBossEnemy extends Enemy{
  static const double _vidaInicial = 200.0; // 4x a normal (20)

  static const double _cooldownRetaliacao = 0.8;
  static const double _danoRetaliacao = 3.0;
  static const double _empurraoRetaliacao = 60.0;

  static const double _tempoAteGuardarFase1 = 6.0;
  static const double _tempoAteGuardarFase2 = 4.0;
  static const double _duracaoGuardaFase1 = 1.8;
  static const double _duracaoGuardaFase2 = 1.2;
  static const double _danoOndaFase1 = 5.0;
  static const double _danoOndaFase2 = 7.0;
  static const double _raioOndaFase1 = 44.0;
  static const double _raioOndaFase2 = 58.0;
  static const double _empurraoOnda = 70.0;

  static const double _avisoAntesAbrir = 0.5;

  double _retaliacaoTimer = 0.0;
  double _guardaTimer = 0.0;
  bool _guardando = false;
  bool _avisou = false;
  bool _faseDois = false;

  OuricoEletricoBossEnemy({
    required super.position,
    required super.playerTarget,
  }) : super(
         creature: CreatureRegistry.ouricoEletricoEvo,
         speed: 14.0,
         health: _vidaInicial,
         dmg: 2,
         size: Vector2(32, 32),        // dobro do padrão (16x16)
         hitboxSize: Vector2(24, 24),  // dobro do hitbox normal (12, 12)
         isPushable: false,
       );

  double get _tempoAteGuardar => _faseDois ? _tempoAteGuardarFase2 : _tempoAteGuardarFase1;
  double get _duracaoGuarda => _faseDois ? _duracaoGuardaFase2 : _duracaoGuardaFase1;
  double get _danoOnda => _faseDois ? _danoOndaFase2 : _danoOndaFase1;
  double get _raioOnda => _faseDois ? _raioOndaFase2 : _raioOndaFase1;

  @override
  void update(double dt) {
    super.update(dt);
    if (_retaliacaoTimer > 0) _retaliacaoTimer -= dt;
  }

  @override
  void movimento(double dt) {
    if (!_faseDois && health <= _vidaInicial / 2) _faseDois = true;

    _guardaTimer += dt;

    if (_guardando) {
      if (!_avisou && _guardaTimer >= _duracaoGuarda - _avisoAntesAbrir) {
        _avisou = true;
        spawnAlerta(duracao: _avisoAntesAbrir);
      }

      if (_guardaTimer >= _duracaoGuarda) {
        _guardando = false;
        shieldVisualActive = false;
        _guardaTimer = 0.0;
        _avisou = false;
        damageReduction = 0.0;
        visual.scale = Vector2(visual.scale.x.isNegative ? -1.0 : 1.0, 1.0);
        _abrirComOnda();
      } else {
        final flip = visual.scale.x.isNegative ? -1.0 : 1.0;
        visual.scale = Vector2(1.15 * flip, 0.8);
      }
      return;
    }

    if (_guardaTimer >= _tempoAteGuardar) {
      _guardando = true;
      shieldVisualActive = true;
      _guardaTimer = 0.0;
      damageReduction = 0.9;
      return;
    }

    updateWanderMovement(dt, minPause: 0.8, maxPause: 1.8, minMove: 0.5, maxMove: 1.2);
  }

  void _abrirComOnda() {
    parent?.add(ExplosionHitbox(
      explosao: true,
      position: position.clone(),
      isEnemy: true,
      origem: creature,
      dono: this,
      dmg: _danoOnda,
      knockback: _empurraoOnda,
      size: Vector2.all(_raioOnda),
      cor1: CreatureRegistry.ouricoEletricoEvo.corClara,
      cor2: CreatureRegistry.ouricoEletricoEvo.corEscura,
    ));
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
      isEnemy: true,
      origem: creature,
      dono: this,
      dmg: _danoRetaliacao,
      knockback: _empurraoRetaliacao,
      cor1: CreatureRegistry.ouricoEletricoEvo.corClara,
      cor2: CreatureRegistry.ouricoEletricoEvo.corEscura,
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
      cancelWander();
    }
  }
}
