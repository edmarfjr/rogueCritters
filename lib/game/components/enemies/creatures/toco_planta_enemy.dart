import 'package:creatures_rogue/game/components/core/palette.dart';
import 'package:flame/components.dart';
import 'package:creatures_rogue/game/components/creatures/creature_registry.dart';
import 'package:creatures_rogue/game/components/map/obstacle.dart';
import 'package:creatures_rogue/game/components/map/wall_barrier.dart';
import 'package:creatures_rogue/game/components/projeteis/orbit_projectile.dart';
import '../enemy.dart';

/// Toco de Madeira como inimigo: quase não anda, e três espinhos giram ao
/// redor dele o tempo todo — a mesma órbita da versão jogável, só que
/// permanente em vez de sob cooldown. O perigo não é perseguição, é chegar
/// perto demais.
class TocoPlantaEnemy extends Enemy {
  static const int _numEspinhos = 5;
  static const double _raio = 20;
  static const double _velocidadeAngular = 3;

  final List<OrbitProjectile> _espinhos = [];

  TocoPlantaEnemy({
    required super.position,
    required super.playerTarget,
  }) : super(
         creature: CreatureRegistry.tocoPlanta,
         speed: 20.0, // mal se move: a ameaça é a órbita, não a perseguição
         health: 20, // stats.maxHp 16 / defesa 2 → aguenta, mas não é o foco
         dmg: 1,     // dano de cada espinho orbital, não de toque corporal
       );

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    for (int i = 0; i < _numEspinhos; i++) {
      final espinho = OrbitProjectile(
        owner: this,
        anguloAtual: (2 * 3.14159265 / _numEspinhos) * i,
        raioOrbita: _raio,
        velocidadeAngular: _velocidadeAngular,
        dmg: dmg.toDouble(),
        isEnemy: true,
        sprPath: 'projeteis/folha.png',
        cor1: Palette.verde,
        cor2: Palette.verdeEsc,
        lifeTime: 999
      );
      _espinhos.add(espinho);
      parent?.add(espinho);
    }
  }

  @override
  void movimento(double dt) {
    updateWanderMovement(dt, minPause: 1.5, maxPause: 3.0, minMove: 0.2, maxMove: 0.5);
  }

  @override
  void death() {
    for (final espinho in _espinhos) {
      espinho.removeFromParent();
    }
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
