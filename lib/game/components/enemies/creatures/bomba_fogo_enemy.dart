import 'package:flame/components.dart';
import 'package:creatures_rogue/game/components/creatures/creature_registry.dart';
import 'package:creatures_rogue/game/components/projeteis/explosion_hitbox.dart';
import '../enemy.dart';

/// Bomba de Fogo como inimigo: corre atrás do jogador e se explode ao chegar
/// perto. Também explode quando morre — matar ele de perto não é de graça.
/// É o inimigo "resolva ele longe": ignorar significa levar a explosão, e
/// matar em cima também.
///
/// Sem ShooterAttack, então `saltitar` fica livre pra escrever visual.scale
/// pelo ChaseMovement. O pavio não mexe em escala nenhuma — só conta tempo.
class BombaFogoEnemy extends Enemy{
  static const double _alcanceGatilho = 20.0;
  static const double _pavio = 0.5;
  static const double _danoExplosao = 4.0;
  static const double _empurraoExplosao = 50.0;

  double _pavioTimer = 0.0;
  bool _acendeu = false;
  bool _explodiu = false;

  BombaFogoEnemy({
    required super.position,
    required super.playerTarget,
  }) : super(
         creature: CreatureRegistry.bombaFogo,
         speed: 40.0,
         health: 15, // stats.maxHp 10 / defesa 3 → aguenta o caminho até você
         dmg: 1,
       );

  @override
  void movimento(double dt) {
    // Pavio aceso: não anda mais, só conta. Aqui é a janela pra sair de perto.
    if (_acendeu) {
      _pavioTimer += dt;
      animateMovement(dt, isMoving: false);
      if (_pavioTimer >= _pavio) death();
      return;
    }

    final distancia = (alvoPosicao - absolutePosition).length;
    if (distancia <= _alcanceGatilho) {
      _acendeu = true;
      _pavioTimer = 0.0;
      spawnAlerta(duracao: _pavio);
      return;
    }

    updateChaseMovement(dt);
  }

  /// Morrer e explodir são a mesma coisa pra ele: o pavio chama `death()`, e
  /// levar dano fatal cai aqui também. A guarda garante uma explosão só.
  /// `isEnemy: true` também basta pra ele nunca se ferir na própria explosão
  /// — o ExplosionHitbox só machuca Enemy quando isEnemy é false.
  @override
  void death() {
    if (!_explodiu) {
      _explodiu = true;
      parent?.add(ExplosionHitbox(
        explosao: true,
        position: position.clone(),
        isEnemy: true,
        origem: creature,
        dono: this,
        dmg: _danoExplosao,
        knockback: _empurraoExplosao,
        size: Vector2(38, 38),
        cor1: CreatureRegistry.bombaFogo.corClara,
        cor2: CreatureRegistry.bombaFogo.corEscura,
      ));
    }
    super.death();
  }
}
