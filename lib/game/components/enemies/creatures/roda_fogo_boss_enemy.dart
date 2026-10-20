import 'package:flame/components.dart';

import 'package:creatures_rogue/game/components/core/palette.dart';
import 'package:creatures_rogue/game/components/creatures/creature_registry.dart';
import 'package:creatures_rogue/game/components/effects/dot.dart';
import 'package:creatures_rogue/game/components/projeteis/explosion_hitbox.dart';
import 'package:creatures_rogue/game/components/projeteis/projectile.dart';
import '../enemy.dart';
import 'roda_fogo_enemy.dart';

/// Roda de Fogo Boss: mesma investida em linha reta da forma normal, com o
/// tamanho e a vida de boss, e uma fase 2 que transforma a arena.
///
/// Fase 1 — investe, bate na parede, estoura. Idêntica à normal, só mais
/// rápida e com aviso mais curto.
///
/// Fase 2 (≤50% da vida) — a investida passa a deixar RASTRO DE FOGO no
/// chão. Igual à passiva da forma evoluída jogável (`RodaDeFogoEvo`), e de
/// propósito: o jogador que já usou a Roda reconhece o padrão e sabe que a
/// sala vai ficar sem espaço. A ameaça deixa de ser o corpo dela e passa a
/// ser o terreno que ela escreve.
///
/// A direção continua TRAVADA no fim da mira nas duas fases — é o que mantém
/// a luta esquivável em vez de virar perseguição. O que a fase 2 tira é o
/// espaço de esquiva, não a possibilidade de esquivar.
class RodaFogoBossEnemy extends Enemy {
  static const double _vidaInicial = 140.0;

  static const double _alcanceInvestida = 130.0;
  static const double _duracaoMaxRodando = 1.4;
  static const double _velInvestida = 170.0;
  static const double _danoEstouro = 4.0;

  /// Mira e descanso encurtam na fase 2: a pressão sobe pelo ritmo, não por
  /// dano por acerto.
  static const double _miraFase1 = 0.5;
  static const double _miraFase2 = 0.3;
  static const double _descansoFase1 = 0.9;
  static const double _descansoFase2 = 0.5;

  /// Rastro da fase 2 — mesmos números de espírito da `RodaDeFogoEvo`.
  static const double _intervaloRastro = 0.09;
  static const double _danoRastro = 2.0;
  static const double _duracaoChama = 2.5;

  bool _faseDois = false;
  RodaFase _fase = RodaFase.vagando;
  double _timer = 0.0;
  double _rastroTimer = 0.0;
  Vector2 _direcao = Vector2.zero();

  double get _duracaoMira => _faseDois ? _miraFase2 : _miraFase1;
  double get _duracaoDescanso => _faseDois ? _descansoFase2 : _descansoFase1;

  RodaFogoBossEnemy({required super.position, required super.playerTarget})
    : super(
        creature: CreatureRegistry.rodaFogoEvo,
        speed: 36.0,
        health: _vidaInicial,
        dmg: 2,
        size: Vector2(32, 32), // dobro do padrão
        hitboxSize: Vector2(20, 20),
        shadowOffset: Vector2(0, 4),
        // Boss não é empurrado pelo esbarrão dos comuns, senão a investida
        // sairia da linha travada e a leitura da luta se perderia.
        isPushable: false,
      );

  @override
  void movimento(double dt) {
    if (!_faseDois && health <= _vidaInicial / 2) {
      _faseDois = true;
      // Aviso na virada: a sala vai mudar de regra, e mudar sem sinal leria
      // como bug.
      spawnAlerta(duracao: 0.6);
    }

    _timer += dt;

    switch (_fase) {
      case RodaFase.vagando:
        updateWanderMovement(dt);
        final distancia =
            (alvoPosicao - absolutePosition).length;
        if (distancia <= _alcanceInvestida) {
          _entrar(RodaFase.mirando);
          spawnAlerta(duracao: _duracaoMira);
        }

      case RodaFase.mirando:
        _direcao = (alvoPosicao - absolutePosition)
            .normalized();
        if (_timer >= _duracaoMira) {
          _rastroTimer = 0.0;
          _entrar(RodaFase.rodando);
        }

      case RodaFase.rodando:
        if (!direcaoLivre(_direcao, segundos: 0.12)) {
          _bater();
          _entrar(RodaFase.recuperando);
          return;
        }
        if (_timer >= _duracaoMaxRodando) {
          _entrar(RodaFase.recuperando);
          return;
        }

        position += _direcao * _velInvestida * dt;
        _virarPraDirecao();

        if (_faseDois) {
          _rastroTimer += dt;
          if (_rastroTimer >= _intervaloRastro) {
            _rastroTimer = 0.0;
            _largarChama();
          }
        }

      case RodaFase.recuperando:
        if (_timer >= _duracaoDescanso) _entrar(RodaFase.vagando);
    }
  }

  void _entrar(RodaFase nova) {
    _fase = nova;
    _timer = 0.0;
  }

  void _virarPraDirecao() {
    if (_direcao.x < 0 && !visual.isFlippedHorizontally) {
      visual.flipHorizontallyAroundCenter();
    } else if (_direcao.x > 0 && visual.isFlippedHorizontally) {
      visual.flipHorizontallyAroundCenter();
    }
  }

  void _bater() {
    parent?.add(
      ExplosionHitbox(
        explosao: true,
        position: position.clone(),
        isEnemy: true,
        origem: creature,
        dono: this,
        dmg: _danoEstouro,
        knockback: 60,
        size: Vector2(36, 36),
        cor1: Palette.laranja,
        cor2: Palette.vermelho,
        tipo: creature?.tipo ?? CreatureRegistry.rodaFogoEvo.tipo,
      ),
    );
  }

  void _largarChama() {
    parent?.add(
      Projectile(
        owner: this,
        position: position.clone(),
        direction: Vector2.zero(),
        speed: 0,
        isEnemy: true,
        lifeTime: _duracaoChama,
        dmg: _danoRastro,
        kbForce: 0,
        sprPath: 'projeteis/fogo2.png',
        cor1: Palette.laranja,
        cor2: Palette.vermelho,
        tipo: creature?.tipo ?? CreatureRegistry.rodaFogoEvo.tipo,
        radius: 6,
        atravessa: 100,
        dotKind: DotKind.queimadura,
        dotTicks: 3,
        // Sem som: uma chama a cada 0,09s estouraria o throttle do
        // `GameAudio` e abafaria o resto da luta.
        playSfx: false,
      ),
    );
  }
  @override
  void death() {
    unlockCreature();
    super.death();
  }
}
