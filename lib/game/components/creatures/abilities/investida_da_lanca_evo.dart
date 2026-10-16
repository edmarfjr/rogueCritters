import 'package:flame/components.dart';
import 'package:creatures_rogue/game/components/creatures/ability.dart';
import 'package:creatures_rogue/game/components/effects/ghost_effect.dart';
import 'package:creatures_rogue/game/components/creatures/ability_user.dart';
import 'package:creatures_rogue/game/components/projeteis/explosion_hitbox.dart';

/// Evolução de [InvestidaDaLanca]: investida mais longa, e o golpe do fim
/// PARALISA além de empurrar.
///
/// O que NÃO mudou é o essencial: o trajeto continua sem acertar ninguém, só
/// o pouso machuca. É o que separa esta habilidade das disparadas que
/// atropelam no caminho — quem quer dano tem que escolher onde parar, não só
/// por onde passar.
///
/// A paralisia é o prêmio por acertar esse ponto: fechar distância com i-
/// frames e ainda prender o alvo é o que permite ao Leão evoluído emendar a
/// investida na estocada seguinte.
class InvestidaDaLancaEvo extends Ability {
  final double distancia;
  final double duracao;
  final double coef;
  final double empurrao;
  final double duracaoParalise;

  const InvestidaDaLancaEvo({
    this.distancia = 52,
    this.duracao = 0.5,
    this.coef = 2.8,
    this.empurrao = 90,
    this.duracaoParalise = 1.2,
  }) : super(
         nome: 'Investida Trovejante',
         descricao:
             'Salto com estocada de lança no chão que paralisa o alvo.',
         cooldown: 2.5,
         target: AbilityTarget.plrDir,
         tipo: AbilityTipo.esquiva,
       );

  @override
  void execute(AbilityUser user, Vector2 dir) {
    final dano = user.creatureData.stats.ataque * coef;
    user.grantInvulnerability(duracao+0.3);

    GhostEffect.spawnTrail(
      visual: user.visual,
      add: (g) => user.parent?.add(g),
      overDuration: duracao,
    );

    user.startJump(
      direction: dir,
      distance: distancia,
      // `duracao`, e NÃO `duracao - 0.2`: aquele subtraendo veio do
      // Mergulho e Estouro, onde a duração é 0,6. Aqui ela é 0,2, então a
      // conta dava ZERO e o `startJump` fazia `distance / 0` — velocidade
      // infinita, posição infinita, e o jogo travava no `ySortPriority`,
      // que chama `.round()` num double que não é finito.
      duration: duracao,
      height: 32,
      onLand: () {
        user.parent?.add(
          ExplosionHitbox(
              position: user.position.clone(),
              dmg: dano,
              knockback: empurrao,
              size: Vector2(32, 32),
              tipo: user.creatureData.tipo,
            ),
        );
      },
    );
  }
}
