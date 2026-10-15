import 'package:flame/components.dart';
import 'package:creatures_rogue/game/components/core/palette.dart';
import 'package:creatures_rogue/game/components/creatures/ability.dart';
import 'package:creatures_rogue/game/components/effects/dot.dart';
import 'package:creatures_rogue/game/components/creatures/ability_user.dart';
import 'package:creatures_rogue/game/components/projeteis/explosion_hitbox.dart';
import 'package:creatures_rogue/game/components/projeteis/projectile.dart';

/// Dano = ataque da criatura × [coef] — ver BaseStats.
class ExplosaoVenenosa extends Ability {
  final double coef;
  final double empurrao;

  const ExplosaoVenenosa({this.coef = 0.25, this.empurrao = 50})
    : super(
        nome: 'Explosao Venenosa',
        descricao: 'Explosão que envenena a área ao redor.',
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
        size: Vector2(32,32),
        cor1: Palette.verde,
        cor2: Palette.verdeEsc,
        tipo: user.creatureData.tipo,
      ),
    );

    user.parent?.add(
      Projectile(
        owner: user,
        position: user.position.clone(),
        direction: dir,
        speed: 0,
        dmg: 0,
        kbForce: 0,
        sprPath: 'projeteis/bolaGrande.png',
        cor1: Palette.verde,
        cor2: Palette.verdeEsc,
        tipo: user.creatureData.tipo,
        dotKind: DotKind.veneno,
        dotTicks: 1, // igual ao poisonCount padrao de antes: nao virou buff
        atravessa: 10,
        size: Vector2(32,32),
        lifeTime: 3,
        radius: 12,
      ),
    );
  }
}
