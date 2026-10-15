import 'package:flame/components.dart';

import 'package:creatures_rogue/game/components/core/palette.dart';
import 'package:creatures_rogue/game/components/creatures/ability.dart';
import 'package:creatures_rogue/game/components/creatures/ability_user.dart';
import 'package:creatures_rogue/game/components/effects/dot.dart';
import 'package:creatures_rogue/game/components/projeteis/explosion_hitbox.dart';
import 'package:creatures_rogue/game/components/projeteis/projectile.dart';

/// Evolução de `ExplosaoVenenosa`: estouro maior e, sobretudo, uma POÇA que
/// fica muito mais tempo e envenena mais forte.
///
/// O que evolui é a permanência, não o estouro: a forma base dava um susto e
/// 3 segundos de poça; esta cria uma área de negação que o Slime pode usar
/// pra fechar um corredor ou proteger a própria retirada.
class ExplosaoVenenosaEvo extends Ability {
  final double coef;
  final double empurrao;
  final double ladoEstouro;
  final double ladoPoca;
  final double duracaoPoca;
  final int dotTicks;

  const ExplosaoVenenosaEvo({
    this.coef = 0.4,
    this.empurrao = 70,
    this.ladoEstouro = 48,
    this.ladoPoca = 40,
    this.duracaoPoca = 7,
    this.dotTicks = 3,
  }) : super(
         nome: 'Explosão Venenosa+',
         descricao: 'Estouro maior que deixa uma poça de veneno duradoura.',
         cooldown: 6.0,
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
        knockback: empurrao,
        size: Vector2.all(ladoEstouro),
        cor1: Palette.verde,
        cor2: Palette.verdeEsc,
        tipo: user.creatureData.tipo,
        dotKind: DotKind.veneno,
        dotTicks: dotTicks,
      ),
    );

    user.parent?.add(
      Projectile(
        owner: user,
        position: user.position.clone(),
        direction: Vector2.zero(),
        speed: 0,
        dmg: 0,
        kbForce: 0,
        sprPath: 'projeteis/bolaGrande.png',
        cor1: Palette.verde,
        cor2: Palette.verdeEsc,
        tipo: user.creatureData.tipo,
        dotKind: DotKind.veneno,
        dotTicks: dotTicks,
        // Alto porque a poça dura 7s e vai ser atravessada por muitos
        // inimigos — o `hitCooldown` do `Projectile` é que evita reacerto
        // rápido no mesmo alvo.
        atravessa: 100,
        size: Vector2.all(ladoPoca),
        lifeTime: duracaoPoca,
        radius: ladoPoca / 2,
        playSfx: false,
      ),
    );
  }
}
