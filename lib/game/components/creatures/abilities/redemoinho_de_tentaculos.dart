import 'dart:math';

import 'package:flame/components.dart';
import 'package:creatures_rogue/game/components/creatures/ability.dart';
import 'package:creatures_rogue/game/components/creatures/ability_user.dart';
import 'package:creatures_rogue/game/components/projeteis/golpe_de_tentaculo.dart';

/// Evolução de [Tentaculada]: o tentáculo dá a VOLTA INTEIRA. Troca "acerta
/// o que está na frente" por "limpa o que está em volta" — a mira passa a
/// decidir só por onde o giro começa.
///
/// `coef` um pouco menor que o da base: o giro pega todo mundo ao redor, e
/// com o mesmo dano por alvo ele dominaria qualquer sala cheia.
///
/// Dano = ataque da criatura × [coef] — ver BaseStats.
class RedemoinhoDeTentaculos extends Ability {
  final double coef;
  final double alcance;

  const RedemoinhoDeTentaculos({this.coef = 1.6, this.alcance = 48})
    : super(
        nome: 'Redemoinho de Tentáculos',
        descricao: 'O tentáculo gira em volta, acertando todos ao redor.',
        cooldown: 0.4,
        custoEnergia: 3.5,
      );

  @override
  void execute(AbilityUser user, Vector2 dir) {
    user.parent?.add(
      GolpeDeTentaculo(
        dono: user,
        direcao: dir,
        arco: 2 * pi,
        duracao: 0.25,
        alcance: alcance,
        dano: user.creatureData.stats.ataque * coef,
        tipo: user.creatureData.tipo,
        cor1: user.creatureData.corClara,
        cor2: user.creatureData.corEscura,
      ),
    );
  }
}
