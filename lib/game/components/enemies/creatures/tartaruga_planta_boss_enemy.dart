import 'package:flame/components.dart';
import 'package:creatures_rogue/game/components/creatures/creature_registry.dart';
import 'package:creatures_rogue/game/components/map/obstacle.dart';
import 'package:creatures_rogue/game/components/map/wall_barrier.dart';
import 'package:creatures_rogue/game/components/projeteis/explosion_hitbox.dart';
import '../enemy.dart';
import '../enemy_mixins.dart';

/// Tartaruga de Planta Boss — "Casco Ancestral": inverte o que a guarda
/// significa. Na normal, casco fechado é a janela SEGURA pro jogador parar de
/// gastar tiro. Aqui, fechar é só o aviso — o perigo é a ABERTURA: o casco
/// bate pra fora numa onda de choque em área. O momento que era "fica parado
/// sem fazer nada" virou o momento de sair correndo.
///
/// Fase 2 (≤50%): guarda quase total (reduz quase todo dano) e o ciclo
/// inteiro encurta — a onda vem com mais frequência, não só mais forte.
class TartarugaPlantaBossEnemy extends Enemy with ShooterAttack {
  static const double _vidaInicial = 320.0; // 4x a normal (80)
  static const double _fireRate = 2.8;

  static const double _tempoAteGuardarFase1 = 5.0;
  static const double _tempoAteGuardarFase2 = 3.5;
  static const double _duracaoGuardaFase1 = 2.0;
  static const double _duracaoGuardaFase2 = 1.3;
  static const double _reducaoGuardaFase1 = 0.85;
  static const double _reducaoGuardaFase2 = 0.97;
  static const double _danoOndaFase1 = 4.0;
  static const double _danoOndaFase2 = 6.0;
  static const double _raioOndaFase1 = 40.0;
  static const double _raioOndaFase2 = 52.0;
  static const double _empurrao = 45.0;

  /// Aviso nasce faltando isso pro fim da guarda — dá tempo de sair do raio
  /// antes da onda bater, mesma linguagem do pavio do Rei Bomba.
  static const double _avisoAntesAbrir = 0.5;

  double _guardaTimer = 0.0;
  bool _guardando = false;
  bool _avisou = false;
  bool _faseDois = false;

  TartarugaPlantaBossEnemy({
    required super.position,
    required super.playerTarget,
  }) : super(
         creature: CreatureRegistry.tartarugaPlantaEvo,
         speed: 18.0,
         health: _vidaInicial,
         dmg: 2,
         bltSpeed: 55,
         bltImg: 'projeteis/proj1.png',
         bltCor1: CreatureRegistry.tartarugaPlanta.corClara,
         bltCor2: CreatureRegistry.tartarugaPlanta.corEscura,
         size: Vector2(48, 48),        // dobro do padrão (16x16)
         hitboxSize: Vector2(28, 28),  // dobro do hitbox normal (14, 14)
         isPushable: false,
       );

  double get _tempoAteGuardar => _faseDois ? _tempoAteGuardarFase2 : _tempoAteGuardarFase1;
  double get _duracaoGuarda => _faseDois ? _duracaoGuardaFase2 : _duracaoGuardaFase1;
  double get _reducaoGuarda => _faseDois ? _reducaoGuardaFase2 : _reducaoGuardaFase1;
  double get _danoOnda => _faseDois ? _danoOndaFase2 : _danoOndaFase1;
  double get _raioOnda => _faseDois ? _raioOndaFase2 : _raioOndaFase1;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    setupAttackAnimation(duration: 0.45);
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
        // Tell visual: encolhe pra dentro do casco, igual à normal.
        final flip = visual.scale.x.isNegative ? -1.0 : 1.0;
        visual.scale = Vector2(1.15 * flip, 0.8);
      }
      return;
    }

    if (_guardaTimer >= _tempoAteGuardar) {
      _guardando = true;
      shieldVisualActive = true;
      _guardaTimer = 0.0;
      damageReduction = _reducaoGuarda;
      return;
    }

    if (updateAttack(dt, _fireRate, _cuspirSemente)) return;

    if (wantsToShoot) {
      triggerAttack();
      return;
    }

    updateWanderMovement(dt, minPause: 1.0, maxPause: 2.0);
  }

  void _cuspirSemente() {
    final direcao = (alvoPosicao - absolutePosition).normalized();
    shoot(direcao);
  }

  void _abrirComOnda() {
    parent?.add(ExplosionHitbox(
      explosao: true,
      position: position.clone(),
      isEnemy: true, // isEnemy true = machuca o Player e NÃO machuca inimigos
      origem: creature,
      dono: this,
      dmg: _danoOnda,
      knockback: _empurrao,
      size: Vector2.all(_raioOnda),
      cor1: CreatureRegistry.tartarugaPlanta.corClara,
      cor2: CreatureRegistry.tartarugaPlanta.corEscura,
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
