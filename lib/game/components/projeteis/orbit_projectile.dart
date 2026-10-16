import 'dart:math';
import 'package:flame/components.dart';
import 'projectile.dart';

/// Projétil que gira preso a [owner] em vez de viajar em linha reta — usado
/// pelos espinhos orbitais do Toco de Madeira. Herda dano/colisão/hits do
/// Projectile normal; só a posição é recalculada todo frame a partir do
/// ângulo. `speed: 0` desliga o deslocamento em linha reta do pai, e
/// `atravessa` bem alto evita que o primeiro acerto o destrua — quem encerra
/// a órbita é o `lifeTime` (null = gira pra sempre, até o dono limpar).
class OrbitProjectile extends Projectile {
  double anguloAtual;
  final double raioOrbita;
  final double velocidadeAngular;

  OrbitProjectile({
    required super.owner,
    required this.anguloAtual,
    required this.raioOrbita,
    required this.velocidadeAngular,
    super.dmg,
    super.tipo,
    super.sprPath,
    super.cor1,
    super.cor2,
    super.isEnemy,
    super.lifeTime,
    super.atravessaObstaculos,
    super.radius,
    super.size,
  }) : super(
          position: owner.absolutePosition,
          direction: Vector2(1, 0),
          speed: 0,
          atravessa: 1000000,
        );

  @override
  void update(double dt) {
    super.update(dt);
    anguloAtual += velocidadeAngular * dt;
    position = owner.absolutePosition + Vector2(cos(anguloAtual), sin(anguloAtual)) * raioOrbita;
    angle = anguloAtual;
  }
}
