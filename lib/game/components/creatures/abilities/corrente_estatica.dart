import 'package:flame/components.dart';
import 'package:creatures_rogue/game/components/core/palette.dart';
import 'package:creatures_rogue/game/components/creatures/ability.dart';
import 'package:creatures_rogue/game/components/creatures/ability_user.dart';
import 'package:creatures_rogue/game/components/projeteis/explosion_hitbox.dart';

/// Ave de Eletricidade — botão B. Área ao redor do próprio corpo: dano baixo
/// mais atordoamento. É a habilidade de quebrar cerco de quem luta colado.
/// Dano = ataque da criatura × [coef] — ver BaseStats.
class CorrenteEstatica extends Ability {
  final double coef;
  final double duracaoStun;

  const CorrenteEstatica({this.coef = 3.0, this.duracaoStun = 2.5})
    : super(
        nome: 'Corrente Estática',
        descricao:
            'Descarga ao redor do corpo: dano baixo e atordoa quem está colado.',
        cooldown: 3.5,
        tipo: AbilityTipo.defesa,
      );

  @override
  void execute(AbilityUser user, Vector2 dir) {
    final dano = user.creatureData.stats.ataque * coef;
    user.parent?.add(
      ExplosionHitbox(
        explosao: true,
        position: user.position.clone(),
        dmg: dano,
        stunDuration: duracaoStun,
        cor1: Palette.amarelo,
        cor2: Palette.laranja,
        tipo: user.creatureData.tipo,
        size: Vector2(48, 48),
      ),
    );
  }
}
