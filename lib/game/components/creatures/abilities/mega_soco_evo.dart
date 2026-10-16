import 'package:flame/components.dart';
import 'package:creatures_rogue/game/components/creatures/ability.dart';
import 'package:creatures_rogue/game/components/creatures/ability_user.dart';
import 'package:creatures_rogue/game/components/projeteis/explosion_hitbox.dart';

/// Urso de Planta — botão A. Soco curto e pesado bem na frente do focinho.
/// Dano = ataque da criatura × [coef] — ver BaseStats.
class MegaSocoEvo extends Ability {
  final double coef;
  final double alcance;
  final double empurrao;

  const MegaSocoEvo({this.coef = 2, this.alcance = 16, this.empurrao = 75})
      : super(nome: 'Mega Soco', descricao: 'Soco curto e pesado bem na frente, com empurrão.', cooldown: 0.4, custoEnergia: 3.5);

  @override
  void execute(AbilityUser user, Vector2 dir) {
    final dano = user.creatureData.stats.ataque * coef;
    user.parent?.add(ExplosionHitbox(
      position: user.position.clone() + dir.normalized() * alcance,
      dmg: dano,
      size: Vector2(32, 32),
      knockback: empurrao,
      tipo: user.creatureData.tipo,
    ));
  }
}
