import 'dart:math';

import 'package:creatures_rogue/game/components/items/collectible.dart';
import 'package:creatures_rogue/game/components/items/consumable_item.dart';
import 'package:flame/components.dart';
import 'package:flame/collisions.dart';
import 'package:creatures_rogue/game/components/core/palette.dart';
import 'package:creatures_rogue/game/components/items/item_efeito.dart';
import 'package:creatures_rogue/game/components/items/power_up_item.dart';
import 'package:creatures_rogue/game/components/map/obstacle.dart';
import 'package:creatures_rogue/game/creatures_rogue_game.dart';

class PedestalComponent extends Obstacle {
  late final Sprite pedestalSprite;

  /// Este pedestal ainda tem algo a oferecer?
  ///
  /// Vira false de duas formas: o jogador levou o item daqui, ou levou o do
  /// [irmao] e esta oferta foi encerrada junto (ver [encerrarOferta]).
  bool hasItem = true;

  /// Os OUTROS pedestais da mesma oferta (ver `RoomComponent._spawnTreasure`).
  /// Vazia num pedestal sozinho — é o caso da sala de desafio —, e aí nada
  /// nesta classe muda em relação a antes.
  ///
  /// Lista, e não uma referência só, por causa do `MapaDoTesouro`: com ele a
  /// sala põe três.
  final List<PedestalComponent> irmaos = [];

  /// Família do que este pedestal oferece, já DECIDIDA: 0 = ITEM_EFEITO,
  /// 1 = CONSUMÍVEL, 2 = UPGRADE. Vem de [sortearOferta].
  final int familia;

  /// O item da família ITEM_EFEITO, já tirado da pool da run. Nulo nas outras
  /// famílias.
  final ItemEfeito? itemEfeito;

  /// Outras ofertas que se alternam com [itemEfeito] (ver `CoroaInstavel`).
  /// Vazia = o item fica parado, como sempre.
  final List<ItemEfeito> alternativas;

  /// Segundos que cada oferta fica antes de trocar pela próxima.
  static const double intervaloCoroa = 1.0;

  double _tempoTroca = 0.0;
  int _indiceOferta = 0;

  /// Coletável da troca, enquanto ainda monta. Entre o antigo sair e este
  /// entrar o pedestal fica sem coletável por alguns quadros — sem isto, quem
  /// observa a ausência (os irmãos, a sala de desafio) leria a troca como
  /// "o jogador levou".
  ItemEfeitoPickup? _trocaMontando;

  /// Já vi um coletável nascer aqui?
  ///
  /// Sem isto, [update] veria "pedestal sem item" no primeiro quadro — o
  /// [onLoad] é assíncrono e o coletável só nasce um pouco depois — e
  /// encerraria a oferta do irmão sozinho, antes de o jogador encostar em
  /// nada. Mesma armadilha que a sala de desafio já tinha (ver
  /// `RoomComponent._itemDesafioApareceu`).
  bool _itemApareceu = false;

  PedestalComponent({
    required super.position,
    super.cor1 = Palette.indigo,
    super.cor2 = Palette.cinzaEsc,
    required this.familia,
    this.itemEfeito,
    this.alternativas = const [],
  }) : super(
         spritePath: 'tileset/pedestal.png',
         size: Vector2(16, 16),
         collisionType: CollisionType.passive,
       );

  /// Sorteia o que um pedestal vai oferecer — chamado pela SALA, no instante
  /// em que ela monta os pedestais, e não pelo `onLoad` do pedestal.
  ///
  /// O sorteio de ITEM_EFEITO tira o item da pool da run na hora. Feito
  /// aqui, de forma síncrona, ele acontece antes de qualquer outra coisa do
  /// andar — inclusive antes do save que o andar grava logo depois de nascer.
  /// No `onLoad` (assíncrono) ele caía DEPOIS do save, e continuar a run
  /// recriava o andar com aqueles itens ainda na pool. Assim, item oferecido
  /// e recusado (sala de desafio evitada, pedestal não escolhido) nunca volta
  /// a aparecer na mesma run.
  ///
  /// [familia] `null` sorteia a família (pedestal sozinho, sala de desafio).
  /// [familiaIrmao] é o desempate de quando a pool de ITEM_EFEITO acaba: o
  /// pedestal cai na família que o irmão NÃO tem, senão a escolha poderia
  /// oferecer duas vezes a mesma coisa.
  ///
  /// Com a `CoroaInstavel`, a oferta de ITEM_EFEITO tira da pool também as
  /// [alternativas] que vão se alternar com ela — pelo mesmo motivo: o que o
  /// jogador viu passar e não levou não volta.
  static ({int familia, ItemEfeito? item, List<ItemEfeito> alternativas})
  sortearOferta(
    CreaturesRogueGame jogo,
    Random rng, {
    int? familia,
    int? familiaIrmao,
  }) {
    final escolhida = familia ?? rng.nextInt(3);
    if (escolhida == 0) {
      final item = jogo.sortearItemEfeito();
      if (item != null) {
        final alternativas = <ItemEfeito>[];
        if (jogo.player.itens.any((i) => i is CoroaInstavel)) {
          for (var i = 1; i < CoroaInstavel.opcoes; i++) {
            final outro = jogo.sortearItemEfeito();
            if (outro != null) alternativas.add(outro);
          }
        }
        return (familia: 0, item: item, alternativas: alternativas);
      }
    }
    final int familiaFinal;
    if (escolhida != 0) {
      familiaFinal = escolhida;
    } else if (familiaIrmao != null) {
      familiaFinal = familiaIrmao == 1 ? 2 : 1;
    } else {
      familiaFinal = rng.nextBool() ? 1 : 2;
    }
    return (familia: familiaFinal, item: null, alternativas: const []);
  }

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    // O jogador pode ter levado o item do irmão enquanto este aqui ainda
    // carregava: aí não há mais oferta pra montar.
    if (!hasItem) return;

    final item = itemEfeito;
    if (item != null) {
      add(ItemEfeitoPickup(position: Vector2(8, -4), item: item));
      return;
    }

    // Consumível e upgrade não vêm de pool nenhuma, então o tipo pode ser
    // sorteado aqui mesmo.
    final rng = Random();
    if (familia == 1) {
      add(
        ConsumablePickup(
          position: Vector2(8, -4),
          tipo:
              ConsumableType.values[rng.nextInt(ConsumableType.values.length)],
        ),
      );
    } else {
      add(
        PowerUpItem(
          position: Vector2(8, -4),
          tipo: PowerUpType.values[rng.nextInt(PowerUpType.values.length)],
        ),
      );
    }
  }

  /// Vigia o próprio item pra avisar o [irmao] quando ele for levado.
  ///
  /// Por observação e não por callback, pela mesma razão que a sala de
  /// desafio observa o pedestal dela: o coletável nasce dentro de um `onLoad`
  /// assíncrono, e `Collectible.onCollect` pode devolver false (inventário
  /// cheio, vida já no topo) — aí o item CONTINUA no pedestal e a oferta não
  /// pode fechar. Observar a ausência acerta esse caso de graça; um gancho no
  /// toque teria que saber da recusa.
  @override
  void update(double dt) {
    super.update(dt);
    _alternarOferta(dt);
    if (irmaos.isEmpty || !hasItem) return;

    if (temColetavel) {
      _itemApareceu = true;
      return;
    }
    if (!_itemApareceu) return;

    // O item daqui sumiu: o jogador escolheu. Fecha os dois lados — este
    // primeiro, pra que o `encerrarOferta` do irmão não volte batendo aqui.
    hasItem = false;
    for (final outro in irmaos) {
      outro.encerrarOferta();
    }
  }

  /// Há um coletável aqui — ou um a caminho, no meio da troca da
  /// `CoroaInstavel`. É o que os observadores devem ler, e não `children`.
  bool get temColetavel {
    final novo = _trocaMontando;
    if (novo != null && !novo.isMounted && !novo.isRemoved) return true;
    return children.whereType<Collectible>().isNotEmpty;
  }

  void _alternarOferta(double dt) {
    final principal = itemEfeito;
    if (principal == null || alternativas.isEmpty || !hasItem) return;
    final novo = _trocaMontando;
    if (novo != null && !novo.isMounted && !novo.isRemoved) return;

    _tempoTroca += dt;
    if (_tempoTroca < intervaloCoroa) return;
    _tempoTroca = 0.0;

    final atual = children.whereType<ItemEfeitoPickup>().toList();
    // Já levado (ou sendo levado neste quadro): nada pra trocar. Sem esta
    // guarda, o item coletado sairia e outro nasceria no lugar.
    if (atual.isEmpty || atual.any((c) => c.isRemoving)) return;
    for (final c in atual) {
      c.removeFromParent();
    }

    final ofertas = [principal, ...alternativas];
    _indiceOferta = (_indiceOferta + 1) % ofertas.length;
    final proximo = ItemEfeitoPickup(
      position: Vector2(8, -4),
      item: ofertas[_indiceOferta],
    );
    _trocaMontando = proximo;
    add(proximo);
  }

  /// Tira o item daqui porque a escolha foi feita no outro pedestal.
  ///
  /// Idempotente e sem efeito colateral no irmão: é o que impede os dois
  /// lados de ficarem se avisando em círculo.
  void encerrarOferta() {
    if (!hasItem) return;
    hasItem = false;
    for (final coletavel in children.whereType<Collectible>().toList()) {
      coletavel.removeFromParent();
    }
  }
}
