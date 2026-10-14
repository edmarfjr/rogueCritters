import 'package:creatures_rogue/game/components/items/item_efeito.dart';

/// Ordem de desbloqueio dos itens pela barra de progressão — O LUGAR PRA
/// EDITAR quando quiser mudar o que começa liberado ou o que cada nível dá.
///
/// Regras:
/// - O item na posição `i` de [porNivel] é liberado ao atingir o nível
///   `i + 1`. Reordenar a lista muda o prêmio de cada nível na hora, inclusive
///   pra quem já jogou: o nível é calculado do XP total salvo, e não guardado.
/// - Item sorteável que NÃO está aqui começa liberado. Então, pra um item novo
///   nascer disponível, não precisa fazer nada; pra ele ser prêmio de nível,
///   basta colocar nesta lista.
/// - Usa as instâncias, e não ids em texto, pra que um nome errado não
///   compile em vez de sumir com o item em silêncio. Pra pôr uma Pedra
///   Elemental aqui, importe `creature_type.dart` e use
///   `PedraElemental(CreatureType.fogo)`.
class ProgressaoItens {
  static const List<ItemEfeito> porNivel = [
    VeioRico(), //          nível 1
    PeDeCabra(), //         nível 2
    GatilhoFrio(), //       nível 3
    SangueFrio(), //        nível 4
    Ressonancia(), //       nível 5
    Espolio(), //           nível 6
    CapsulaFurada(), //     nível 7
    DiarioDeCampo(), //     nível 8
    CascaInstavel(), //     nível 9
    Miragem(), //           nível 10
    PeDeCoelho(), //        nível 11
    Aparar(), //            nível 12
    Ninhada(), //           nível 13
    Coleira(), //           nível 14
    PresaDoCampeao(), //    nível 15
    Esgotamento(), //       nível 16
    Imposto(), //           nível 17
    Prisma(), //            nível 18
    BauDoTesouro(), //      nível 19
    CascaDeOvo(), //        nível 20
    Jejum(), //             nível 21
    Cofrinho(), //          nível 22
    Cupom(), //             nível 23
    Agulha(), //            nível 24
    Bencao(), //            nível 25
    PresasDeVampiro(), //   nível 26
    Reposicao(), //         nível 27
    RelogioParado(), //     nível 28
    Enxame(), //            nível 29
    Telecinese(), //        nível 30
    Furia(), //             nível 31
    Pureza(), //            nível 32
    Contrato(), //          nível 33
    CoroaInstavel(), //     nível 34
    Heranca(), //           nível 35
    OlhoNoOlho(), //        nível 36
  ];

  /// XP pra passar do nível [nivel] pro seguinte (nível 0 → 1 custa 30).
  /// Cresce devagar: o primeiro nível sai quase sempre na primeira run.
  static int custoDoNivel(int nivel) => 30 + 15 * nivel;

  /// Nível alcançado com [xpTotal] acumulado. Nunca passa de
  /// `porNivel.length`: depois do último prêmio a barra fica no MÁXIMO.
  static int nivelPara(int xpTotal) {
    var nivel = 0;
    var resto = xpTotal;
    while (nivel < porNivel.length && resto >= custoDoNivel(nivel)) {
      resto -= custoDoNivel(nivel);
      nivel++;
    }
    return nivel;
  }

  /// XP já acumulado DENTRO do nível atual (o quanto da barra está cheio).
  static int xpNoNivel(int xpTotal) {
    var nivel = 0;
    var resto = xpTotal;
    while (nivel < porNivel.length && resto >= custoDoNivel(nivel)) {
      resto -= custoDoNivel(nivel);
      nivel++;
    }
    return resto;
  }

  static bool ehMaximo(int nivel) => nivel >= porNivel.length;

  /// O item ainda está atrás de um nível que [nivel] não alcançou?
  static bool bloqueado(ItemEfeito item, int nivel) {
    final posicao = porNivel.indexWhere((i) => i.id == item.id);
    return posicao != -1 && posicao >= nivel;
  }
}
