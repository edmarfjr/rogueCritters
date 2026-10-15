import 'package:flame/components.dart';
import 'package:flame/effects.dart';

import 'package:creatures_rogue/game/components/core/palette.dart';
import 'package:creatures_rogue/game/components/creatures/ability.dart';
import 'package:creatures_rogue/game/components/creatures/ability_user.dart';
import 'package:creatures_rogue/game/components/effects/ghost_effect.dart';
import 'package:creatures_rogue/game/components/projeteis/explosion_hitbox.dart';
import 'package:creatures_rogue/game/components/projeteis/projectile.dart';

/// Evolução de `DisparadaCongelante`: o dash é mais longo e deixa gelo em
/// TRÊS pontos do caminho — saída, meio e chegada — em vez de só nas pontas.
///
/// Os três pontos são calculados por geometria, do deslocamento que o
/// `dashOffsetLivre` devolve, e não por temporizador escalonado (o padrão da
/// Disparada Flamejante). Sem timer há menos coisa pra dar errado: nada
/// pendurado se a criatura for trocada no meio do dash, e nada que continue
/// contando com o jogo pausado.
class DisparadaCongelanteEvo extends Ability {
  final double distancia;
  final double duracao;
  final double coefRastro;
  final double lentidaoDuracao;

  /// Lado das poças de gelo. Maior que as 24 da forma base — a poça do meio
  /// precisa cobrir o vão entre as duas pontas.
  final double ladoPoca;

  const DisparadaCongelanteEvo({
    this.distancia = 48,
    this.duracao = 0.2,
    this.coefRastro = 0.6,
    this.lentidaoDuracao = 4.0,
    this.ladoPoca = 32,
  }) : super(
         nome: 'Disparada Congelante+',
         descricao: 'Dash longo que congela o caminho inteiro.',
         cooldown: 3.0,
         target: AbilityTarget.plrDir,
         tipo: AbilityTipo.esquiva,
       );

  @override
  void execute(AbilityUser user, Vector2 dir) {
    final danoRastro = user.creatureData.stats.ataque * coefRastro;
    user.grantInvulnerability(duracao);

    final origem = user.position.clone();
    // Resolvido ANTES do `MoveByEffect`: é o mesmo deslocamento que o efeito
    // vai aplicar, então dá os três pontos sem esperar o dash acabar.
    final deslocamento = user.dashOffsetLivre(dir, distancia);

    for (final ponto in [
      origem,
      origem + deslocamento / 2,
      origem + deslocamento,
    ]) {
      _gelar(user, ponto, danoRastro);
    }

    GhostEffect.spawnTrail(
      visual: user.visual,
      add: (g) => user.parent?.add(g),
      overDuration: duracao,
    );

    user.add(
      MoveByEffect(deslocamento, EffectController(duration: duracao)),
    );
  }

  /// Uma explosão (o dano e a lentidão no instante) mais uma poça parada (a
  /// lentidão de quem passar depois). Mesmo par que a forma base usa nas
  /// pontas.
  void _gelar(AbilityUser user, Vector2 ponto, double dano) {
    user.parent?.add(
      ExplosionHitbox(
        explosao: true,
        position: ponto.clone(),
        dmg: dano,
        cor1: Palette.royal,
        cor2: Palette.azul,
        tipo: user.creatureData.tipo,
        lentidaoDuracao: lentidaoDuracao,
      ),
    );

    user.parent?.add(
      Projectile(
        owner: user,
        position: ponto.clone(),
        direction: Vector2.zero(),
        speed: 0,
        dmg: 0,
        kbForce: 0,
        sprPath: 'projeteis/bolaGrande.png',
        cor1: Palette.royal,
        cor2: Palette.azul,
        tipo: user.creatureData.tipo,
        lentidaoDuracao: lentidaoDuracao,
        atravessa: 10,
        size: Vector2.all(ladoPoca),
        lifeTime: 2.5,
        radius: ladoPoca / 2,
        // Três poças de uma vez: só a explosão faz som, senão vira ruído.
        playSfx: false,
      ),
    );
  }
}
