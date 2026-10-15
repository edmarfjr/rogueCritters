import 'dart:math';

import 'package:flame/components.dart';
import 'package:creatures_rogue/game/components/creatures/creature_registry.dart';
import 'package:creatures_rogue/game/components/map/obstacle.dart';
import 'package:creatures_rogue/game/components/map/wall_barrier.dart';
import 'package:creatures_rogue/game/components/projeteis/explosion_hitbox.dart';
import 'package:creatures_rogue/game/components/projeteis/projectile.dart';
import '../enemy.dart';
import '../enemy_mixins.dart';

/// Pinguim de Água Boss — junta as duas metades do kit jogável: a salva que
/// estilhaça de volta e a investida congelante.
///
/// Regra de projeto que segura a luta inteira: **as duas nunca acontecem ao
/// mesmo tempo**. Jogador lento com caco voltando pela faixa não tem saída —
/// isso viraria sorteio, não dificuldade. Então o boss alterna: ou está
/// atirando, ou está congelando, com uma recuperação no meio.
///
/// Fase 1 pune ficar parado (os cacos varrem de volta a faixa que você
/// desviou). Fase 2 (≤50%) pune andar devagar: a investida passa a largar
/// campo de lentidão ao longo de TODO o trajeto, não só nas duas pontas, e a
/// sala vai fechando.
class PinguimAguaBossEnemy extends Enemy with ShooterAttack {
  static const double _vidaInicial = 250.0; // 4x a normal (30)
  static const double _fireRate = 2.8;

  static const double _velocidadeTiro = 70.0;
  static const double _anguloLequeGraus = 18.0;

  /// Mesma regra da normal: o tempo de voo vem da distância no disparo, pra
  /// que o estouro caia sempre logo além do jogador e os cacos voltem por
  /// cima dele. Ver PinguimAguaEnemy.
  static const double _sobraAlemDoJogador = 24.0;
  static const double _vooMinimo = 0.35;
  static const double _vooMaximo = 3.0;

  // --- Investida congelante ---
  static const double _investidaTelegraph = 0.5;
  static const double _investidaDuracao = 0.35;
  static const double _investidaDistancia = 80.0;
  static const double _investidaCooldownFase1 = 6.0;
  static const double _investidaCooldownFase2 = 4.5;

  /// Janela de exposição depois da investida. É também o que garante que a
  /// próxima salva não saia por cima do campo de lentidão recém-criado.
  static const double _investidaRecuperacao = 0.9;

  static const double _danoInvestida = 5.0;
  static const double _lentidaoInvestida = 3.0;

  /// Fase 2: intervalo entre um campo de lentidão e o próximo ao longo do
  /// trajeto, e quanto cada um dura no chão.
  static const double _rastroIntervalo = 0.06;
  static const double _rastroDuracao = 2.5;

  bool _faseDois = false;

  bool _investidaTelegrafando = false;
  bool _investidaEmAndamento = false;
  double _investidaTimer = 0.0;
  double _investidaCooldownTimer = _investidaCooldownFase1; // pronta desde já
  double _recuperacaoTimer = 0.0;
  double _rastroTimer = 0.0;
  Vector2 _investidaDirecao = Vector2.zero();

  PinguimAguaBossEnemy({
    required super.position,
    required super.playerTarget,
  }) : super(
         creature: CreatureRegistry.pinguimAguaEvo,
         speed: 20.0,
         health: _vidaInicial,
         dmg: 2,
         bltSpeed: _velocidadeTiro,
         bltImg: 'projeteis/proj1.png',
         bltCor1: CreatureRegistry.pinguimAguaEvo.corClara,
         bltCor2: CreatureRegistry.pinguimAguaEvo.corEscura,
         size: Vector2(32, 32),        // dobro do padrão (16x16)
         hitboxSize: Vector2(16, 32),  // dobro do hitbox normal (8, 16)
         isPushable: false,
       );

  double get _investidaCooldown =>
      _faseDois ? _investidaCooldownFase2 : _investidaCooldownFase1;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    setupAttackAnimation(duration: 0.35, telegraph: 0.6);
  }

  @override
  void movimento(double dt) {
    if (!_faseDois && health <= _vidaInicial / 2) _faseDois = true;

    if (_investidaCooldownTimer < _investidaCooldown) _investidaCooldownTimer += dt;

    // --- Investida em andamento: desliza e, na fase 2, vai congelando o chão
    if (_investidaEmAndamento) {
      _investidaTimer += dt;
      position += _investidaDirecao * (_investidaDistancia / _investidaDuracao) * dt;

      if (_faseDois) {
        _rastroTimer += dt;
        if (_rastroTimer >= _rastroIntervalo) {
          _rastroTimer = 0.0;
          _congelarChao();
        }
      }

      if (_investidaTimer >= _investidaDuracao) {
        _investidaEmAndamento = false;
        _investidaTimer = 0.0;
        _recuperacaoTimer = _investidaRecuperacao;
        _estouroCongelante(); // ponta de chegada
      }
      return;
    }

    // --- Aviso da investida: agacha e trava no lugar
    if (_investidaTelegrafando) {
      _investidaTimer += dt;
      final flip = visual.scale.x.isNegative ? -1.0 : 1.0;
      final progresso = (_investidaTimer / _investidaTelegraph).clamp(0.0, 1.0);
      visual.scale = Vector2((1.0 + progresso * 0.2) * flip, 1.0 - progresso * 0.2);

      if (_investidaTimer >= _investidaTelegraph) {
        _investidaTelegrafando = false;
        _investidaEmAndamento = true;
        _investidaTimer = 0.0;
        _rastroTimer = 0.0;
        visual.scale = Vector2(flip, 1.0);
        _investidaDirecao =
            (alvoPosicao - absolutePosition).normalized();
        _estouroCongelante(); // ponta de saída
      }
      return;
    }

    // --- Recuperação: exposto, e sem atirar por cima do gelo que acabou de pôr
    if (_recuperacaoTimer > 0) {
      _recuperacaoTimer -= dt;
      animateMovement(dt, isMoving: false);
      return;
    }

    if (_investidaCooldownTimer >= _investidaCooldown) {
      _investidaTelegrafando = true;
      _investidaTimer = 0.0;
      _investidaCooldownTimer = 0.0;
      spawnAlerta(duracao: _investidaTelegraph);
      return;
    }

    if (updateAttack(dt, _fireRate, _salvaDeGelo)) return;

    if (wantsToShoot) {
      triggerAttack();
      return;
    }

    updateWanderMovement(dt, minPause: 1.0, maxPause: 2.0);
  }

  /// Três tiros em leque, cada um estilhaçando pra trás: nove cacos varrendo
  /// de volta. O leque é estreito de propósito — o perigo é a faixa ficar
  /// larga na volta, não o tiro de ida cobrir a sala.
  void _salvaDeGelo() {
    final ate = alvoPosicao - absolutePosition;
    final direcao = ate.normalized();
    final tempoDeVoo =
        ((ate.length + _sobraAlemDoJogador) / _velocidadeTiro).clamp(_vooMinimo, _vooMaximo);
    final anguloRad = _anguloLequeGraus * pi / 180;

    for (final offset in [-anguloRad, 0.0, anguloRad]) {
      final rotacionada = direcao.clone()..rotate(offset);
      parent?.add(Projectile(
        owner: this,
        position: position.clone() + rotacionada * size.x / 2,
        direction: rotacionada,
        isEnemy: true,
        speed: _velocidadeTiro,
        dmg: dmg.toDouble(),
        sprPath: bltImg,
        cor1: bltCor1,
        cor2: bltCor2,
        tipo: CreatureRegistry.pinguimAguaEvo.tipo,
        lifeTime: tempoDeVoo,
        estilhaca: true,
      ));
    }
  }

  /// Estouro nas pontas da investida — espelha o que a habilidade jogável faz
  /// na saída e na chegada.
  void _estouroCongelante() {
    parent?.add(ExplosionHitbox(
      explosao: true,
      position: position.clone(),
      isEnemy: true,
      origem: creature,
      dono: this,
      dmg: _danoInvestida,
      tipo: CreatureRegistry.pinguimAguaEvo.tipo,
      lentidaoDuracao: _lentidaoInvestida,
      cor1: CreatureRegistry.pinguimAguaEvo.corClara,
      cor2: CreatureRegistry.pinguimAguaEvo.corEscura,
    ));
  }

  /// Fase 2: poça de gelo deixada no trajeto. Dano zero de propósito — ela
  /// nega terreno, não machuca; quem machuca são as pontas e a salva.
  void _congelarChao() {
    parent?.add(Projectile(
      owner: this,
      position: position.clone(),
      direction: Vector2.zero(),
      isEnemy: true,
      speed: 0,
      dmg: 0,
      kbForce: 0,
      sprPath: 'projeteis/bolaGrande.png',
      cor1: CreatureRegistry.pinguimAguaEvo.corClara,
      cor2: CreatureRegistry.pinguimAguaEvo.corEscura,
      lentidaoDuracao: _lentidaoInvestida,
      lifeTime: _rastroDuracao,
      atravessa: 10,
      atravessaObstaculos: true,
      size: Vector2.all(16),
      radius: 8,
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
      // A investida para na parede em vez de atravessar.
      if (_investidaEmAndamento) {
        _investidaEmAndamento = false;
        _investidaTimer = 0.0;
        _recuperacaoTimer = _investidaRecuperacao;
        _estouroCongelante();
        return;
      }
      cancelWander();
    }
  }
}
