import 'dart:math';
import 'dart:ui' as ui;

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:creatures_rogue/game/audio/game_audio.dart';
import 'package:creatures_rogue/game/audio/sfx.dart';
import 'package:creatures_rogue/game/components/core/palette.dart';
import 'package:creatures_rogue/game/components/creatures/creature_data.dart';
import 'package:creatures_rogue/game/components/effects/companion_revive_effect.dart';
import 'package:creatures_rogue/game/components/items/consumable_item.dart';
import 'package:creatures_rogue/game/components/items/item_efeito.dart';
import 'package:creatures_rogue/game/components/items/power_up_item.dart';
import 'package:creatures_rogue/game/components/enemies/enemy.dart';
import 'package:creatures_rogue/game/components/map/room_component.dart';
import 'package:creatures_rogue/game/components/player/player.dart';
import 'package:creatures_rogue/game/components/utils/palette_swapper.dart';
import 'package:creatures_rogue/game/components/utils/y_sort.dart';
import 'package:creatures_rogue/game/creatures_rogue_game.dart';
import 'package:creatures_rogue/l10n/creature_i18n.dart';
import 'package:creatures_rogue/l10n/l10n_extensions.dart';

/// Os eventos da sala de evento (`RoomType.evento`). Sorteados sem repetir
/// na run (ver `CreaturesRogueGame.sortearEvento`).
enum EventoTipo {
  altar,
  mendigo,
  fonte,
  criaturaFerida,
  termas,
  mercador,
  ninho,
  dojo,
  duelo,
}

/// Um botão da janela do evento. [bloqueio] não nulo = botão apagado, com o
/// motivo escrito embaixo.
class OpcaoEvento {
  final String rotulo;
  final String? bloqueio;
  final VoidCallback acao;

  const OpcaoEvento({required this.rotulo, required this.acao, this.bloqueio});
}

/// O objeto do evento no meio da sala. Encostar pausa o jogo e abre a janela
/// dele (ver `EventoOverlay`), igual à criatura selvagem — quem decide é o
/// botão, não o toque, então não dá pra gastar vida ou moeda sem querer.
///
/// Guarda o estado do evento (usos, resultado do último botão). Não vai pro
/// save: continuar a run gera o andar de novo, e o evento junto.
class EventoNpc extends PositionComponent
    with CollisionCallbacks, HasGameReference<CreaturesRogueGame> {
  final EventoTipo tipo;

  /// A criatura caída da `criaturaFerida`. Nula nos outros eventos.
  final CreatureData? criatura;

  /// Sala onde o evento está — o Duelo tranca ela.
  final RoomComponent? sala;

  /// O desafiante do Duelo, já montado mas fora do mundo até o aceite.
  final Enemy? rival;

  /// As três aulas do Dojo, sorteadas uma vez por dojo.
  late final List<PowerUpType> _aulas =
      (List.of(PowerUpType.values)..shuffle(_rng)).take(3).toList();

  EventoNpc({
    required Vector2 position,
    required this.tipo,
    this.criatura,
    this.sala,
    this.rival,
  }) : super(size: Vector2(16, 16), anchor: Anchor.center, position: position);

  // ------------------------------------------------------------ números

  /// Altar: o 4º sacrifício dá item garantido e encerra.
  static const int usosAltar = 4;

  /// Mendigo: a doação nº [doacoesMendigo] dá item e encerra.
  static const int doacoesMendigo = 6;

  /// Ninho: salas limpas até o ovo chocar.
  static const int salasOvo = 3;

  /// Dojo: preço da primeira aula, e quanto cada aula seguinte encarece.
  static const int precoDojo = 6;
  static const int encarecimentoDojo = 4;

  int _usos = 0;

  /// Roda ao fechar a janela, quando o botão escolhido só faz efeito com o
  /// jogo de volta (o Duelo começa a luta).
  VoidCallback? _aoFechar;

  /// O evento acabou: a janela só mostra o resultado, e o objeto some ao
  /// fechar.
  bool esgotado = false;

  /// Texto do que o último botão rendeu, mostrado na janela.
  String? resultado;

  final Random _rng = Random();

  // ------------------------------------------------------------ visual

  ({String caminho, Color cor1, Color cor2}) get _visual {
    final c = criatura;
    if (c != null) {
      // Caída: as duas cores no tom escuro dela, pra ler "fraca".
      return (caminho: c.spritePath, cor1: c.corEscura, cor2: c.corEscura);
    }
    final desafiante = rival?.creature;
    if (desafiante != null) {
      return (
        caminho: desafiante.spritePath,
        cor1: desafiante.corClara,
        cor2: desafiante.corEscura,
      );
    }
    switch (tipo) {
      case EventoTipo.altar:
        return (
          caminho: 'items/altar.png',
          cor1: Palette.vermelho,
          cor2: Palette.burgundy,
        );
      case EventoTipo.mendigo:
        return (
          caminho: 'items/mendigo.png',
          cor1: Palette.bege,
          cor2: Palette.marrom,
        );
      case EventoTipo.fonte:
        return (
          caminho: 'items/fonte.png',
          cor1: Palette.azul,
          cor2: Palette.royal,
        );
      case EventoTipo.termas:
        return (
          caminho: 'items/termas.png',
          cor1: Palette.azul,
          cor2: Palette.indigo,
        );
      case EventoTipo.mercador:
        return (
          caminho: 'items/balanca.png',
          cor1: Palette.amarelo,
          cor2: Palette.marrom,
        );
      case EventoTipo.ninho:
        return (
          caminho: 'items/ninhoEvento.png',
          cor1: Palette.bege,
          cor2: Palette.marrom,
        );
      case EventoTipo.dojo:
        return (
          caminho: 'items/dojo.png',
          cor1: Palette.vermelho,
          cor2: Palette.marrom,
        );
      case EventoTipo.criaturaFerida:
      case EventoTipo.duelo:
        return (
          caminho: 'actors/dummy.png',
          cor1: Palette.cinza,
          cor2: Palette.cinzaEsc,
        );
    }
  }

  String get spritePath => _visual.caminho;
  Color get cor1 => _visual.cor1;
  Color get cor2 => _visual.cor2;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    final v = _visual;
    final ui.Image imagem = await PaletteSwapper.createSwappedImage(
      imagePath: v.caminho,
      lightGrayReplacement: v.cor1,
      darkGrayReplacement: v.cor2,
    );
    final base = Vector2(size.x / 2, size.y);
    add(
      SpriteComponent(
        sprite: Sprite(imagem),
        size: Vector2(imagem.width.toDouble(), imagem.height.toDouble()),
        anchor: Anchor.bottomCenter,
        position: base,
        paint: Paint()..filterQuality = FilterQuality.none,
      ),
    );
    add(
      RectangleHitbox(
        size: Vector2(14, 10),
        anchor: Anchor.bottomCenter,
        position: base,
        collisionType: CollisionType.passive,
      ),
    );
    priority = ySortPriority(position.y + size.y / 2);
  }

  // ------------------------------------------------------------ toque

  /// Mesmo motivo da `WildCreatureNpc`: os dois hitboxes do jogador entram
  /// em momentos diferentes, e o segundo reabriria a janela recém-fechada.
  double _ignorarToque = 0.0;
  static const double _pausaAposFechar = 0.6;

  @override
  void update(double dt) {
    super.update(dt);
    if (_ignorarToque > 0) _ignorarToque -= dt;
  }

  @override
  void onCollisionStart(
    Set<Vector2> intersectionPoints,
    PositionComponent other,
  ) {
    super.onCollisionStart(intersectionPoints, other);
    if (_ignorarToque > 0 || other is! Player) return;
    resultado = null;
    game.abrirEvento(this);
  }

  /// Chamado ao fechar a janela. Esgotado, o objeto vai embora.
  void fechado() {
    _ignorarToque = _pausaAposFechar;
    final aoFechar = _aoFechar;
    _aoFechar = null;
    aoFechar?.call();
    if (!esgotado) return;
    parent?.add(CompanionReviveEffect(position: position.clone()));
    removeFromParent();
  }

  // ------------------------------------------------------------ textos

  String titulo(BuildContext context) {
    final l = context.l10n;
    switch (tipo) {
      case EventoTipo.altar:
        return l.evento_altarTitulo;
      case EventoTipo.mendigo:
        return l.evento_mendigoTitulo;
      case EventoTipo.fonte:
        return l.evento_fonteTitulo;
      case EventoTipo.criaturaFerida:
        return l.evento_feridaTitulo;
      case EventoTipo.termas:
        return l.evento_termasTitulo;
      case EventoTipo.mercador:
        return l.evento_mercadorTitulo;
      case EventoTipo.ninho:
        return l.evento_ninhoTitulo;
      case EventoTipo.dojo:
        return l.evento_dojoTitulo;
      case EventoTipo.duelo:
        return l.evento_dueloTitulo;
    }
  }

  String texto(BuildContext context) {
    final l = context.l10n;
    switch (tipo) {
      case EventoTipo.altar:
        return l.evento_altarTexto;
      case EventoTipo.mendigo:
        return l.evento_mendigoTexto;
      case EventoTipo.fonte:
        return l.evento_fonteTexto;
      case EventoTipo.criaturaFerida:
        return l.evento_feridaTexto(creatureName(context, criatura!.id));
      case EventoTipo.termas:
        return l.evento_termasTexto;
      case EventoTipo.mercador:
        return l.evento_mercadorTexto;
      case EventoTipo.ninho:
        return l.evento_ninhoTexto(salasOvo);
      case EventoTipo.dojo:
        return l.evento_dojoTexto;
      case EventoTipo.duelo:
        final desafiante = rival?.creature;
        return l.evento_dueloTexto(
          desafiante == null ? '???' : creatureName(context, desafiante.id),
        );
    }
  }

  /// Os botões do evento agora. Vazio quando esgotado — fica só o de sair.
  List<OpcaoEvento> opcoes(BuildContext context) {
    if (esgotado) return const [];
    final l = context.l10n;
    final player = game.player;
    switch (tipo) {
      case EventoTipo.altar:
        return [
          OpcaoEvento(
            rotulo: l.evento_altarAcao,
            // Nunca mata: o último meio coração não entra no altar.
            bloqueio: player.currentHealth <= 1 ? l.evento_vidaBaixa : null,
            acao: () => _sacrificar(context),
          ),
        ];
      case EventoTipo.mendigo:
        return [
          OpcaoEvento(
            rotulo: l.evento_mendigoAcao,
            bloqueio: player.coins < 1 ? l.effect_semMoeda : null,
            acao: () => _doar(context),
          ),
        ];
      case EventoTipo.fonte:
        return [
          OpcaoEvento(
            rotulo: l.evento_fonteAcao,
            bloqueio: player.coins < 1 ? l.effect_semMoeda : null,
            acao: () => _apostar(context),
          ),
        ];
      case EventoTipo.criaturaFerida:
        return [
          OpcaoEvento(
            rotulo: l.evento_feridaAcao,
            bloqueio: player.currentHealth <= 2 ? l.evento_vidaBaixa : null,
            acao: () => _curarCriatura(context),
          ),
        ];
      case EventoTipo.termas:
        return [
          OpcaoEvento(
            rotulo: l.evento_termasAcao,
            acao: () => _descansar(context),
          ),
        ];
      case EventoTipo.mercador:
        // Só item sorteável: passiva de aposentadoria é lembrança de uma
        // criatura, não mercadoria.
        final trocaveis = player.itens.where((i) => i.sorteavel).toList();
        if (trocaveis.isEmpty) {
          return [
            OpcaoEvento(
              rotulo: l.evento_mercadorAcao,
              bloqueio: l.evento_mercadorSemItens,
              acao: () {},
            ),
          ];
        }
        final semEstoque = game.poolItens.isEmpty;
        return [
          for (final item in trocaveis)
            OpcaoEvento(
              rotulo: l.evento_mercadorTrocar(item.nome(context)),
              bloqueio: semEstoque ? l.evento_mercadorSemEstoque : null,
              acao: () => _trocar(context, item),
            ),
        ];
      case EventoTipo.ninho:
        return [
          OpcaoEvento(
            rotulo: l.evento_ninhoAcao,
            bloqueio: player.ovoSalas > 0 ? l.evento_ninhoJaTem : null,
            acao: () => _pegarOvo(context),
          ),
        ];
      case EventoTipo.dojo:
        final preco = precoDojo + encarecimentoDojo * _usos;
        return [
          for (final aula in _aulas)
            OpcaoEvento(
              rotulo: l.evento_dojoTreinar(aula.descricao(context), preco),
              bloqueio: player.coins < preco ? l.effect_semMoeda : null,
              acao: () => _treinar(context, aula, preco),
            ),
        ];
      case EventoTipo.duelo:
        return [
          OpcaoEvento(
            rotulo: l.evento_dueloAceitar,
            acao: () => _aceitarDuelo(context),
          ),
        ];
    }
  }

  // ------------------------------------------------------------ eventos

  /// Cada sacrifício rende mais que o anterior; o 4º dá item e encerra.
  /// Tira a vida direto, sem `takeDamage`: é oferta, não golpe — não gasta
  /// escudo nem dispara item de "levou dano".
  void _sacrificar(BuildContext context) {
    game.player.currentHealth -= 1;
    _usos++;
    GameAudio.instance.play(Sfx.hit);
    switch (_usos) {
      case 1:
        _moedas(context, 3);
      case 2:
        _consumivel(context);
      case 3:
        if (_rng.nextBool()) {
          _item(context);
        } else {
          _moedas(context, 5);
        }
      default:
        _item(context);
    }
    if (_usos >= usosAltar) esgotado = true;
  }

  void _doar(BuildContext context) {
    final l = context.l10n;
    game.player.coins -= 1;
    _usos++;
    if (_usos >= doacoesMendigo) {
      _item(context);
      resultado = l.evento_mendigoFoi;
      esgotado = true;
      return;
    }
    final sorte = _rng.nextDouble();
    if (sorte < 0.10) {
      _cura(context);
    } else if (sorte < 0.20) {
      _consumivel(context);
    } else {
      resultado = l.evento_mendigoAgradece;
    }
  }

  void _apostar(BuildContext context) {
    final l = context.l10n;
    game.player.coins -= 1;
    final sorte = _rng.nextDouble();
    if (sorte < 0.45) {
      resultado = l.evento_nada;
    } else if (sorte < 0.75) {
      _moedas(context, 2);
    } else if (sorte < 0.90) {
      _cura(context);
    } else if (sorte < 0.97) {
      _consumivel(context);
    } else {
      _item(context);
      resultado = l.evento_fonteQuebrou;
      esgotado = true;
    }
  }

  void _curarCriatura(BuildContext context) {
    final c = criatura!;
    game.player.currentHealth -= 2;
    final passiva = game.entregarPassivaDe(c);
    GameAudio.instance.play(Sfx.liberar);
    resultado = passiva == null
        ? context.l10n.evento_nada
        : context.l10n.evento_feridaGrata(passiva.nome(context));
    esgotado = true;
  }

  void _descansar(BuildContext context) {
    game.curarGrupoInteiro();
    GameAudio.instance.play(Sfx.liberar);
    resultado = context.l10n.evento_termasCurou;
    esgotado = true;
  }

  /// Mercador: o item sai do inventário e um da pool cai no chão. O que saiu
  /// não volta pra pool — oferta recusada não repete, e trocada também não.
  void _trocar(BuildContext context, ItemEfeito item) {
    game.player.perderItem(item);
    _item(context);
    resultado = context.l10n.evento_mercadorTrocou;
    esgotado = true;
  }

  void _pegarOvo(BuildContext context) {
    game.player.ovoSalas = salasOvo;
    resultado = context.l10n.evento_ninhoLevou;
    esgotado = true;
  }

  void _treinar(BuildContext context, PowerUpType aula, int preco) {
    game.player.coins -= preco;
    aula.aplicar(game.player);
    _usos++;
    GameAudio.instance.play(Sfx.liberar);
    resultado = aula.descricao(context);
  }

  /// A luta começa ao FECHAR a janela, com o jogo de volta — começar com ele
  /// pausado deixaria o rival parado na frente da janela.
  void _aceitarDuelo(BuildContext context) {
    resultado = context.l10n.evento_dueloComeca;
    esgotado = true;
    final desafiante = rival;
    final local = sala;
    if (desafiante == null || local == null) return;
    _aoFechar = () => local.iniciarDuelo(desafiante);
  }

  // ------------------------------------------------------------ prêmios

  void _moedas(BuildContext context, int n) {
    game.player.addCoins(n);
    resultado = context.l10n.evento_moedas(n);
  }

  void _cura(BuildContext context) {
    game.player.heal(1);
    resultado = context.l10n.evento_cura;
  }

  /// Cai no chão, e não direto no inventário: os dois espaços podem estar
  /// cheios, e no chão o consumível espera.
  void _consumivel(BuildContext context) {
    parent?.add(
      ConsumablePickup(
        position: _ondeCai(),
        tipo: ConsumableType.values[_rng.nextInt(ConsumableType.values.length)],
      ),
    );
    resultado = context.l10n.evento_consumivel;
  }

  /// Item da pool da run, no chão — com nome e descrição, como num pedestal.
  /// Pool vazia (fim de run) vira moedas.
  void _item(BuildContext context) {
    final item = game.sortearItemEfeito();
    if (item == null) {
      _moedas(context, 5);
      return;
    }
    parent?.add(ItemEfeitoPickup(position: _ondeCai(), item: item));
    resultado = context.l10n.evento_item;
  }

  /// Logo abaixo do objeto, com um espalhamento pequeno pra dois prêmios
  /// seguidos não caírem empilhados.
  Vector2 _ondeCai() =>
      position + Vector2(_rng.nextDouble() * 24 - 12, 20 + _rng.nextDouble() * 6);
}
