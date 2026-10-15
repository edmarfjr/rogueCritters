import 'package:flame/components.dart';
import 'package:creatures_rogue/game/components/core/palette.dart';
import 'package:creatures_rogue/game/components/creatures/ability.dart';
import 'package:creatures_rogue/game/components/creatures/ability_user.dart';
import 'package:creatures_rogue/game/components/projeteis/explosion_hitbox.dart';

/// Sapo de Água — botão B. Escudo que absorve um golpe, com duração limitada.
///
/// Ao ESTOURAR (não ao expirar por tempo) solta um sopro sem dano que só
/// empurra: quem encostou pra furar a bolha sai de perto, e o jogador ganha o
/// espaço pra reagir em vez de ficar colado no inimigo com o escudo já gasto.
class BolhaProtetora extends Ability {
  final double duracao;

  /// Força do empurrão do estouro. Dano ZERO de propósito — a bolha é
  /// defensiva, e dar dano de graça a cada golpe absorvido mudaria o papel
  /// dela no kit do Sapo.
  static const double kbEstouro = 80.0;
  static const double raioEstouro = 36.0;

  const BolhaProtetora({this.duracao = 5.0})
    : super(
        nome: 'Bolha Protetora',
        descricao: 'Escudo que absorve um golpe e repele ao estourar.',
        cooldown: 4.0,
        tipo: AbilityTipo.defesa,
      );

  @override
  void execute(AbilityUser user, Vector2 dir) {
    user.adicionarEscudoTemporario(
      #bolhaProtetora,
      1,
      duracao,
      aoEstourar: () => estourar(user, kbEstouro, raioEstouro),
    );
  }

  /// Compartilhado com a forma evoluída, que muda só os números.
  static void estourar(AbilityUser user, double knockback, double raio) {
    user.parent?.add(
      ExplosionHitbox(
        explosao: true,
        position: user.position.clone(),
        dmg: 0,
        knockback: knockback,
        size: Vector2.all(raio),
        cor1: Palette.azul,
        cor2: Palette.branco,
        tipo: user.creatureData.tipo,
      ),
    );
  }
}
