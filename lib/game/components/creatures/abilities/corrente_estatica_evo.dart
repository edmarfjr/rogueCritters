import 'package:flame/components.dart';
import 'package:creatures_rogue/game/components/core/palette.dart';
import 'package:creatures_rogue/game/components/creatures/ability.dart';
import 'package:creatures_rogue/game/components/creatures/ability_user.dart';
import 'package:creatures_rogue/game/components/projeteis/explosion_hitbox.dart';

/// Evolução de [CorrenteEstatica] (ver `PIVOT_EVOLUCAO`): a área ao redor do
/// corpo fica maior e mais forte, e dispara um SEGUNDO pulso logo em seguida
/// — quem sobrevive ao primeiro choque ainda apanha do coice.
class CorrenteEstaticaEvo extends Ability {
  final double coef;
  final double duracaoStun;
  final double atrasoSegundoPulso;

  const CorrenteEstaticaEvo({
    this.coef = 5.0,
    this.duracaoStun = 3.5,
    this.atrasoSegundoPulso = 0.3,
  }) : super(
         nome: 'Tempestade Estática',
         descricao:
             'Descarga maior e mais forte, com um segundo pulso logo em seguida.',
         cooldown: 3.5,
         tipo: AbilityTipo.defesa,
       );

  void _pulso(AbilityUser user, double coefPulso) {
    if (!user.isMounted) return;
    user.parent?.add(
      ExplosionHitbox(
        explosao: true,
        position: user.position.clone(),
        dmg: user.creatureData.stats.ataque * coefPulso,
        stunDuration: duracaoStun,
        cor1: Palette.amarelo,
        cor2: Palette.laranja,
        tipo: user.creatureData.tipo,
        size: Vector2(52, 52),
      ),
    );
  }

  @override
  void execute(AbilityUser user, Vector2 dir) {
    _pulso(user, coef);
    Future.delayed(
      Duration(milliseconds: (atrasoSegundoPulso * 1000).round()),
      () => _pulso(user, coef * 0.5),
    );
  }
}
