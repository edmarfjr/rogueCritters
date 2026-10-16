import 'package:flame/components.dart';
import 'package:creatures_rogue/game/components/creatures/creature_registry.dart';
import 'package:creatures_rogue/game/components/projeteis/projectile.dart';
import '../enemy.dart';

/// Slime de Planta como inimigo: nunca persegue ninguém. Vagueia pela arena e
/// vai largando poças de veneno no chão, que ficam lá machucando quem pisar.
/// É o inimigo "o mapa piora se você demorar" — deixar vivo custa espaço.
///
/// A poça é um Projectile parado (speed 0) com `isEnemy: true`, mesmo truque
/// do tornado da Esquiva Tornado. Sem ShooterAttack: a cadência é um timer
/// simples, e `arrastar` precisa do visual.scale só pra si.
class SlimePlantaEnemy extends Enemy{
  static const double _intervaloPoca = 0.5;
  static const double _duracaoPoca = 5.0;
  static const double _danoPoca = 2.0;
  static const double _tamanhoPoca = 16.0;

  double _pocaTimer = 0.0;

  SlimePlantaEnemy({
    required super.position,
    required super.playerTarget,
  }) : super(
         creature: CreatureRegistry.slimePlanta,
         speed: 26.0, // devagar: a ameaça é o rastro, não ele
         health: 30,  // stats.defesa 3 → dá tempo de sujar bastante chão
         dmg: 1,
       );

  @override
  void movimento(double dt) {
    updateWanderMovement(dt);

    _pocaTimer += dt;
    if (_pocaTimer >= _intervaloPoca) {
      _pocaTimer = 0.0;
      _largarPoca();
    }
  }

  /// Bem abaixo de qualquer prioridade Y-sorted de ator (ver `ySortPriority`
  /// em Player/Enemy) — a poça é mancha de chão, não personagem: precisa
  /// desenhar por baixo de quem pisar nela, sempre, e não só de quem estiver
  /// "mais pra cima" na tela no instante em que nasce.
  static const int _prioridadePoca = -1000000;

  void _largarPoca() {
    parent?.add(Projectile(
      owner: this,
      position: position.clone(),
      direction: Vector2.zero(),
      isEnemy: true, // sem isso a poça machuca inimigos em vez do jogador
      speed: 0,
      kbForce: 0,
      dmg: _danoPoca,
      sprPath: 'projeteis/bolaGrande.png',
      cor1: CreatureRegistry.slimePlanta.corClara,
      cor2: CreatureRegistry.slimePlanta.corEscura,
      lifeTime: _duracaoPoca,
      atravessa: 10, // aguenta várias pisadas antes de sumir
      atravessaObstaculos: true,
      size: Vector2.all(_tamanhoPoca),
      radius: _tamanhoPoca / 2,
      priority: _prioridadePoca,
      noChao: true,
    ));
  }
}
