import 'package:flame/components.dart';
import 'package:creatures_rogue/game/components/creatures/ability.dart';
import 'package:creatures_rogue/game/components/creatures/ability_user.dart';
import 'package:creatures_rogue/game/components/projeteis/feixe_eletrico.dart';

/// Zapeye — botão A. Raio contínuo: enquanto a mira está segurada, um feixe
/// sai do olho, acompanha a mira e para no primeiro alvo. Ficar
/// [tempoParaAtordoar] segundos seguidos no mesmo alvo o atordoa.
///
/// Contínuo por renovação: cada disparo (a cada 0,4s enquanto a mira está
/// segurada) RENOVA o feixe que já existe em vez de criar outro, então o
/// raio não pisca entre disparos e o acúmulo de atordoamento não zera. A
/// energia de cada disparo é o que limita quanto tempo dá pra segurar.
///
/// Dano por tique = ataque da criatura × [coef] — ver BaseStats.
class RaioOcular extends Ability {
  final double coef;
  final double tempoParaAtordoar;
  final double rampaMaxima;

  /// Largura do feixe em px (ver `FeixeEletrico.espessura`).
  final double espessura;

  const RaioOcular({
    this.coef = 0.5,
    this.tempoParaAtordoar = 0.8,
    this.rampaMaxima = 1.0,
    this.espessura = 4,
    super.nome = 'Raio Ocular',
    super.descricao =
        'Raio contínuo que para no primeiro alvo e o atordoa se mantido.',
    super.custoEnergia = 2.0,
  }) : super(cooldown: 0.4);

  /// Um pouco mais que o cooldown: o próximo disparo renova o feixe antes de
  /// ele apagar.
  static const double _vidaPorDisparo = 0.5;

  @override
  void execute(AbilityUser user, Vector2 dir) {
    final existente = user.parent?.children
        .whereType<FeixeEletrico>()
        .where((f) => f.dono == user && !f.isRemoving)
        .firstOrNull;
    if (existente != null) {
      existente.renovar(_vidaPorDisparo);
      return;
    }
    user.parent?.add(
      FeixeEletrico(
        dono: user,
        // Lida a cada quadro: o feixe segue a mira enquanto ela se move.
        direcao: () => user.lockedAb1Direction,
        vida: _vidaPorDisparo,
        danoPorTique: user.creatureData.stats.ataque * coef,
        tipo: user.creatureData.tipo,
        cor1: user.creatureData.corClara,
        cor2: user.creatureData.corEscura,
        tempoParaAtordoar: tempoParaAtordoar,
        rampaMaxima: rampaMaxima,
        espessura: espessura,
      ),
    );
  }
}

/// Evolução de [RaioOcular]: quanto mais tempo o feixe fica no mesmo alvo,
/// mais ele dói — até o dobro — e o atordoamento chega mais cedo. Premia
/// manter a mira em vez de varrer a sala.
class RaioConcentrado extends RaioOcular {
  const RaioConcentrado()
    : super(
        tempoParaAtordoar: 0.6,
        rampaMaxima: 2.0,
        // 50% mais grosso que o da base.
        espessura: 6,
        nome: 'Raio Concentrado',
        descricao: 'Raio contínuo que fica mais forte quanto mais tempo no mesmo alvo.',
        custoEnergia: 2.5,
      );
}
