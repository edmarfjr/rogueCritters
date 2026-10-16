import 'package:creatures_rogue/game/components/core/palette.dart';
import 'package:flame/components.dart';
import 'package:creatures_rogue/game/components/creatures/creature_registry.dart';
import 'package:creatures_rogue/game/components/map/obstacle.dart';
import 'package:creatures_rogue/game/components/map/wall_barrier.dart';
import 'package:creatures_rogue/game/components/projeteis/orbit_projectile.dart';
import '../enemy.dart';

/// Toco de Madeira Boss: dois anéis de espinhos, um girando em cada sentido,
/// em vez de um só — a leitura vira "onde os dois anéis se cruzam", não só
/// "quão perto eu tô".
///
/// Fase 2 (≤50%): nasce um terceiro anel, mais apertado e mais rápido que os
/// dois primeiros — o espaço seguro perto do centro desaparece.
class TocoPlantaBossEnemy extends Enemy{
  static const double _vidaInicial = 200.0; // 4x a normal (24)

  static const int _numEspinhosAnel = 4;
  static const double _raioAnel1 = 22;
  static const double _raioAnel2 = 34;
  static const double _raioAnel3 = 14;
  static const double _velAngular = 2.0;

  bool _faseDois = false;
  final List<OrbitProjectile> _espinhos = [];

  TocoPlantaBossEnemy({
    required super.position,
    required super.playerTarget,
  }) : super(
         creature: CreatureRegistry.tocoPlantaEvo,
         speed: 6.0,
         health: _vidaInicial,
         dmg: 2,
         size: Vector2(32, 32),        // dobro do padrão (16x16)
         hitboxSize: Vector2(26, 26),  // dobro do hitbox normal (13, 13)
         isPushable: false,
       );

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    _criarAnel(quantidade: _numEspinhosAnel, raio: _raioAnel1, velAngular: _velAngular);
    _criarAnel(quantidade: _numEspinhosAnel, raio: _raioAnel2, velAngular: -_velAngular * 0.7);
  }

  void _criarAnel({required int quantidade, required double raio, required double velAngular}) {
    for (int i = 0; i < quantidade; i++) {
      final espinho = OrbitProjectile(
        owner: this,
        anguloAtual: (2 * 3.14159265 / quantidade) * i,
        raioOrbita: raio,
        velocidadeAngular: velAngular,
        dmg: dmg.toDouble(),
        isEnemy: true,
        sprPath: 'projeteis/folha.png',
        cor1: Palette.verde,
        cor2: Palette.verdeEsc,
      );
      _espinhos.add(espinho);
      parent?.add(espinho);
    }
  }

  @override
  void movimento(double dt) {
    if (!_faseDois && health <= _vidaInicial / 2) {
      _faseDois = true;
      _criarAnel(quantidade: _numEspinhosAnel, raio: _raioAnel3, velAngular: _velAngular * 1.8);
    }

    updateWanderMovement(dt, minPause: 1.2, maxPause: 2.2, minMove: 0.3, maxMove: 0.7);
  }

  @override
  void death() {
    unlockCreature();
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
