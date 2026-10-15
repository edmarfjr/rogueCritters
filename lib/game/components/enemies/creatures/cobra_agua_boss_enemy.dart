import 'package:flame/components.dart';
import 'package:creatures_rogue/game/components/creatures/creature_registry.dart';
import 'package:creatures_rogue/game/components/map/obstacle.dart';
import 'package:creatures_rogue/game/components/map/wall_barrier.dart';
import 'package:creatures_rogue/game/components/projeteis/explosion_hitbox.dart';
import 'package:creatures_rogue/game/components/projeteis/projectile.dart';
import '../enemy.dart';
import '../enemy_mixins.dart';

/// Cobra de Água Boss — "Serpente das Marés": mesmo bote da normal (salto
/// telegrafado, impacto ao pousar), só que maior e com mais alcance.
///
/// Fase 2 (≤50%): **bote duplo** — ao pousar o primeiro bote, encadeia
/// direto num segundo salto (sem voltar a esperar), miradas de novo na
/// posição atual do jogador. Fura quem confia em desviar de um bote só.
class CobraAguaBossEnemy extends Enemy with JumpMovement {
  static const double _vidaInicial = 200.0; // 4x a normal (40)
  static const double _alcanceBote = 90.0;  // maior que a normal (70): o boss ameaça de mais longe

  static const int _danoImpactoFase1 = 3;
  static const int _danoImpactoFase2 = 5;
  static const double _empurraoFase1 = 45.0;
  static const double _empurraoFase2 = 55.0;
  static const double _tamanhoImpactoFase1 = 40.0;
  static const double _tamanhoImpactoFase2 = 50.0;

  /// Quantos botes emendados por ciclo — 1 na fase 1 (normal), 2 na fase 2.
  static const int _botesPorCicloFase1 = 1;
  static const int _botesPorCicloFase2 = 2;

  static const double _danoMorte = 5.0;
  static const double _tamanhoMorte = 60.0;
  static const int _pocasNaMorte = 2;

  bool _boteEmVoo = false;
  bool _faseDois = false;
  int _botesFeitos = 0;
  bool _morreu = false;

  CobraAguaBossEnemy({
    required super.position,
    required super.playerTarget,
  }) : super(
         creature: CreatureRegistry.cobraAguaEvo,
         moveAnim: null, // o bote é a animação
         speed: 0.0,     // quem move é o JumpMovement
         health: _vidaInicial,
         dmg: 2,
         shadowOffset: Vector2(0, 5),
         size: Vector2(48, 48),        // dobro do padrão (14x14)
         hitboxSize: Vector2(18, 28),  // dobro do hitbox normal (9, 14)
         isPushable: false,
       );

  int get _danoImpacto => _faseDois ? _danoImpactoFase2 : _danoImpactoFase1;
  double get _empurraoImpacto => _faseDois ? _empurraoFase2 : _empurraoFase1;
  double get _tamanhoImpacto => _faseDois ? _tamanhoImpactoFase2 : _tamanhoImpactoFase1;
  int get _botesPorCiclo => _faseDois ? _botesPorCicloFase2 : _botesPorCicloFase1;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    setupJumpAnimations(prepTime: 0.45);

    idleDuration = 1.3;
    airDuration = 0.35;
  }

  @override
  void movimento(double dt) {
    if (!_faseDois && health <= _vidaInicial / 2) _faseDois = true;

    final distancia = (alvoPosicao - absolutePosition).length;
    final estavaNoAr = jumpState == JumpState.inAir;

    updateJumpMovement(
      dt,
      alvoPosicao,
      mode: distancia <= _alcanceBote ? JumpMode.targetPlayer : JumpMode.random,
      jumpDistance: distancia <= _alcanceBote ? _alcanceBote : 28.0,
      jumpHeight: 20.0,
    );

    if (jumpState == JumpState.inAir) _boteEmVoo = true;

    // Aterrissou neste frame: solta a onda de impacto.
    if (estavaNoAr && jumpState != JumpState.inAir && _boteEmVoo) {
      _boteEmVoo = false;
      _impactoAoPousar();
      _botesFeitos++;

      // Bote duplo (fase 2): emenda direto no próximo salto, sem esperar o
      // idle — é o que fura quem só desvia de UM bote e relaxa.
      if (_botesFeitos < _botesPorCiclo) {
        jumpState = JumpState.preparing;
        jumpTimer = 0.0;
        spawnAlerta();
      } else {
        _botesFeitos = 0;
      }
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
      size: Vector2.all(_tamanhoImpacto),
      cor1: CreatureRegistry.cobraAgua.corClara,
      cor2: CreatureRegistry.cobraAgua.corEscura,
    ));
  }

  @override
  void death() {
    if (!_morreu) {
      _morreu = true;
      parent?.add(ExplosionHitbox(
        explosao: true,
        position: position.clone(),
        isEnemy: true,
        origem: creature,
        dono: this,
        dmg: _danoMorte,
        knockback: _empurraoFase2,
        size: Vector2.all(_tamanhoMorte),
        cor1: CreatureRegistry.cobraAgua.corClara,
        cor2: CreatureRegistry.cobraAgua.corEscura,
      ));

      // Última cartada: poças d'água residuais, mesmo truque do Slime.
      for (int i = 0; i < _pocasNaMorte; i++) {
        parent?.add(Projectile(
          owner: this,
          position: position.clone() + Vector2((i - 0.5) * 20.0, 0),
          direction: Vector2.zero(),
          isEnemy: true,
          speed: 0,
          kbForce: 0,
          dmg: 2.0,
          sprPath: 'projeteis/bolaGrande.png',
          cor1: CreatureRegistry.cobraAgua.corClara,
          cor2: CreatureRegistry.cobraAgua.corEscura,
          lifeTime: 5.0,
          atravessa: 10,
          atravessaObstaculos: true,
          size: Vector2.all(16.0),
          radius: 8.0,
        ));
      }

      unlockCreature();
    }
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
