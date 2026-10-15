import 'package:flame/components.dart';
import 'package:creatures_rogue/game/components/core/palette.dart';
import 'package:creatures_rogue/game/components/creatures/ability.dart';
import 'package:creatures_rogue/game/components/creatures/ability_user.dart';
import 'package:creatures_rogue/game/components/projeteis/explosion_hitbox.dart';

/// Evolução de [CascoFechado] (ver `PIVOT_EVOLUCAO`): mesma imunidade total +
/// reflexo de projétil, duração maior e cooldown menor, mais um estouro ao
/// FECHAR o casco — quem já estava colado na Tartaruga apanha na hora.
class CascoFechadoEvo extends Ability {
  final double reducaoDano;
  final double duracao;
  final double coefEstouro;

  const CascoFechadoEvo({
    this.reducaoDano = 1,
    this.duracao = 0.6,
    this.coefEstouro = 1.5,
  }) : super(
         nome: 'Casco Espinhoso',
         descricao:
             'Casco reforçado: mesma imunidade e reflexo, dura mais e ainda estoura ao fechar.',
         cooldown: 1.5,
         tipo: AbilityTipo.defesa,
       );

  @override
  void execute(AbilityUser user, Vector2 dir) {
    user.damageReduction = reducaoDano;
    user.speedLocked = true;
    user.shieldVisualActive = true;
    user.refleteProjetil = true;

    user.parent?.add(
      ExplosionHitbox(
        explosao: true,
        position: user.position.clone(),
        dmg: user.creatureData.stats.ataque * coefEstouro,
        stunDuration: 1.0,
        cor1: Palette.verde,
        cor2: Palette.marrom,
        tipo: user.creatureData.tipo,
      ),
    );

    Future.delayed(Duration(milliseconds: (duracao * 1000).round()), () {
      if (user.isMounted) {
        user.damageReduction = 0.0;
        user.speedLocked = false;
        user.shieldVisualActive = false;
        user.refleteProjetil = false;
      }
    });
  }
}
