import 'package:flame/components.dart';
import 'package:creatures_rogue/game/components/creatures/creature_registry.dart';
import 'package:creatures_rogue/game/components/projeteis/projectile.dart';
import '../enemy.dart';
import 'slime_planta_enemy.dart';

/// Slime de Planta Boss — "Mãe-Lodo": mesma ameaça passiva do normal (larga
/// poça, nunca persegue de verdade), mas vagueia com viés fraco em direção ao
/// jogador, então a poça se acumula perto de quem joga em vez de espalhar
/// aleatório pela sala.
///
/// Fase 2 (≤50%): racha em 2 SlimePlantaEnemy normais, reaproveitando a
/// classe já pronta como "filhote" — dobra a fonte de poça na arena.
class SlimePlantaBossEnemy extends Enemy {
  static const double _vidaInicial = 250.0; // 4x a normal (34)
  static const double _intervaloPoca = 2.2;
  static const double _duracaoPoca = 5.0;
  static const double _danoPoca = 2.0;
  static const double _tamanhoPoca = 16.0;

  /// Quanto o rumo aleatório é puxado na direção do jogador a cada frame em
  /// movimento — fraco de propósito: ainda vagueia, só não ignora o jogador.
  static const double _viesJogador = 0.4;

  double _pocaTimer = 0.0;
  bool _faseDois = false;

  SlimePlantaBossEnemy({
    required super.position,
    required super.playerTarget,
  }) : super(
         creature: CreatureRegistry.slimePlantaEvo,
         speed: 26.0,
         health: _vidaInicial,
         dmg: 2,
         size: Vector2(32, 32),        // dobro do padrão (16x16)
         hitboxSize: Vector2(16, 20),  // dobro do hitbox normal (8, 10)
         isPushable: false,
       );

  @override
  void movimento(double dt) {
    if (!_faseDois && health <= _vidaInicial / 2) {
      _faseDois = true;
      _split();
      return;
    }

    updateWanderMovement(dt);

    if (isMoving) {
      final rumoJogador = (alvoPosicao - absolutePosition).normalized();
      currentDirection = (currentDirection + rumoJogador * _viesJogador).normalized();
    }

    _pocaTimer += dt;
    if (_pocaTimer >= _intervaloPoca) {
      _pocaTimer = 0.0;
      _largarPoca();
    }
  }

  void _largarPoca() {
    parent?.add(Projectile(
      owner: this,
      position: position.clone(),
      direction: Vector2.zero(),
      isEnemy: true,
      speed: 0,
      kbForce: 0,
      dmg: _danoPoca,
      sprPath: 'projeteis/bolaGrande.png',
      cor1: CreatureRegistry.slimePlantaEvo.corClara,
      cor2: CreatureRegistry.slimePlantaEvo.corEscura,
      lifeTime: _duracaoPoca,
      atravessa: 10,
      atravessaObstaculos: true,
      size: Vector2.all(_tamanhoPoca),
      radius: _tamanhoPoca / 2,
      noChao: true,
    ));
  }

  /// Referência clássica de gênero: slime que racha em 2 na metade da vida.
  /// Cada filhote continua largando poça, dobrando a pressão de terreno sem
  /// precisar de mecânica nova nenhuma.
  void _split() {
    for (int i = 0; i < 2; i++) {
      parent?.add(SlimePlantaEnemy(
        position: position.clone() + Vector2((i - 0.5) * 20.0, 0),
        playerTarget: playerTarget,
      ));
    }
  }

  @override
  void death() {
    unlockCreature();
    super.death();
  }
}
