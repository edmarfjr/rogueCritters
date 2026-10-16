import 'package:flame/components.dart';
import 'package:creatures_rogue/game/components/creatures/creature_registry.dart';
import 'package:creatures_rogue/game/components/projeteis/explosion_hitbox.dart';
import '../enemy.dart';

/// Urso de Planta como inimigo: sem projétil nenhum, só avança devagar e sem
/// parar. Chegando perto, prepara e solta uma pancada que repele. É o inimigo
/// "corra" — pesado demais pra ser empurrado, resistente demais pra ser
/// ignorado, mas lento o bastante pra ser driblado.
///
/// Sem ShooterAttack, então `caminhada` fica livre pra escrever visual.scale.
/// A pancada usa visual.scale também, mas nunca no mesmo frame: a caminhada só
/// roda quando não está preparando o golpe.
class UrsoPlantaEnemy extends Enemy{
  static const double _alcancePancada = 22.0;
  static const double _preparoPancada = 0.6;
  static const double _recuperacao = 1.2;
  static const int _danoPancada = 2;
  static const double _empurraoPancada = 50.0;

  double _preparoTimer = 0.0;
  double _recuperacaoTimer = 0.0;
  bool _preparando = false;

  UrsoPlantaEnemy({
    required super.position,
    required super.playerTarget,
  }) : super(
         creature: CreatureRegistry.ursoPlanta,
         speed: 14.0,  // stats.speed 22 → o mais lento de todos
         health: 50,    // stats.maxHp 22 → o mais duro do elenco
         dmg: 1,
         isPushable: false, // pesado demais pra ser empurrado por outro inimigo
       );

  @override
  void movimento(double dt) {
    // Recuperação pós-pancada: fica exposto, é a janela de contra-ataque.
    if (_recuperacaoTimer > 0) {
      _recuperacaoTimer -= dt;
      animateMovement(dt, isMoving: false);
      return;
    }

    if (_preparando) {
      _preparoTimer += dt;

      // Tell visual: encolhe e recua antes de descer a pata.
      final flip = visual.scale.x.isNegative ? -1.0 : 1.0;
      final progresso = (_preparoTimer / _preparoPancada).clamp(0.0, 1.0);
      visual.scale = Vector2((1.0 + progresso * 0.25) * flip, 1.0 - progresso * 0.2);

      if (_preparoTimer >= _preparoPancada) {
        _preparando = false;
        _preparoTimer = 0.0;
        _recuperacaoTimer = _recuperacao;
        visual.scale = Vector2(flip, 1.0);
        _descerPancada();
      }
      return;
    }

    final distancia = (alvoPosicao - absolutePosition).length;
    if (distancia <= _alcancePancada) {
      _preparando = true;
      _preparoTimer = 0.0;
      return;
    }

    updateChaseMovement(dt);
  }

  void _descerPancada() {
    parent?.add(ExplosionHitbox(
      position: position.clone(),
      isEnemy: true, // sem isso a explosão não machuca o jogador
      origem: creature,
      dono: this,
      dmg: _danoPancada.toDouble(),
      knockback: _empurraoPancada,
      size: Vector2(34, 34),
      cor1: CreatureRegistry.ursoPlanta.corClara,
      cor2: CreatureRegistry.ursoPlanta.corEscura,
    ));
  }
}
