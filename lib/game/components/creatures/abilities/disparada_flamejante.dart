import 'package:creatures_rogue/game/components/effects/dot.dart';
import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:creatures_rogue/game/components/core/palette.dart';
import 'package:creatures_rogue/game/components/creatures/ability.dart';
import 'package:creatures_rogue/game/components/effects/ghost_effect.dart';
import 'package:creatures_rogue/game/components/creatures/ability_user.dart';
import 'package:creatures_rogue/game/components/projeteis/projectile.dart';

/// Roedor de Fogo — botão B. Dash com i-frames, deixa rastro de dano.
/// Mobilidade é a defesa de uma criatura frágil.
class DisparadaFlamejante extends Ability {
  final double distancia;
  final double duracao;
  final double coefRastro;

  /// Quantos projéteis parados o rastro larga ao longo do dash — mesmo
  /// espaçamento proporcional do `GhostEffect.spawnTrail` (fantasmas
  /// visuais, logo abaixo), só que estes causam dano de verdade.
  final int pontosDoRastro;

  const DisparadaFlamejante({
    this.distancia = 32,
    this.duracao = 0.15,
    this.coefRastro = 0.67,
    this.pontosDoRastro = 6,
  }) : super(
         nome: 'Disparada Flamejante',
         descricao: 'Esquiva que deixa um rastro em chamas.',
         cooldown: 1.5,
         target: AbilityTarget.plrDir,
         tipo: AbilityTipo.esquiva,
       );

  @override
  void execute(AbilityUser user, Vector2 dir) {
    final danoRastro = user.creatureData.stats.ataque * coefRastro;
    user.grantInvulnerability(duracao);
  /* final ataque = user.creatureData.stats.ataque;
    
    final origem = user.position.clone();
    user.parent?.add(
      ExplosionHitbox(
        position: origem,
        dmg: ataque * coefRastro,
        cor2: Palette.laranja,
        tipo: user.creatureData.tipo,
        dotKind: DotKind.queimadura,
        dotTicks: 5,
        size: Vector2(24, 24)
      ),
    );
  */
    GhostEffect.spawnTrail(
      visual: user.visual,
      add: (g) => user.parent?.add(g),
      overDuration: duracao,
    );

    // Rastro de fogo: um projétil parado (`speed: 0`) a cada passo do dash,
    // amostrando `user.position` no instante do disparo — como o
    // `MoveByEffect` abaixo já está movendo o jogador quadro a quadro, cada
    // atraso pega um ponto diferente do caminho, sem precisar calcular a
    // trajetória à mão. Mesmo `Future.delayed` escalonado que
    // `GhostEffect.spawnTrail` usa pro rastro visual.
    for (int i = 1; i <= pontosDoRastro; i++) {
      final delayMs = (duracao * i / (pontosDoRastro + 1) * 1000).round();
      Future.delayed(Duration(milliseconds: delayMs), () {
        if (!user.isMounted) return;
        user.parent?.add(
          Projectile(
            owner: user,
            position: user.position.clone(),
            direction: Vector2.zero(),
            speed: 0,
            lifeTime: 3,
            dmg: danoRastro,
            sprPath: 'projeteis/fogo.png',
            cor1: Palette.vermelho,
            cor2: Palette.laranja,
            tipo: user.creatureData.tipo,
            radius: 6,
            atravessa: 100,
            dotKind: DotKind.queimadura,
            dotTicks: 5,
          ),
        );
      });
    }

    user.add(
      MoveByEffect(
        user.dashOffsetLivre(dir, distancia),
        EffectController(duration: duracao),
      ),
    );
  }
}
