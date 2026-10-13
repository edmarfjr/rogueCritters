import 'package:creatures_rogue/game/components/items/collectible.dart';
import 'package:creatures_rogue/game/game_settings.dart';
import 'dart:math';
import 'package:creatures_rogue/game/components/items/item_efeito.dart';
import 'package:creatures_rogue/game/components/map/floor_text.dart';
import 'package:creatures_rogue/game/components/creatures/creature_registry.dart';
import 'package:creatures_rogue/game/components/effects/boss_cutscene.dart';
import 'package:creatures_rogue/game/creatures_rogue_game.dart';
import 'dart:math' as math;
import 'package:creatures_rogue/game/components/map/spike_trap.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:creatures_rogue/game/components/core/dungeon_theme.dart';
import 'package:creatures_rogue/game/components/core/palette.dart';
import 'package:creatures_rogue/game/components/enemies/dummy_enemy.dart';
import 'package:creatures_rogue/game/components/enemies/enemy.dart';
import 'package:creatures_rogue/game/components/enemies/boss_registry.dart';
import 'package:creatures_rogue/game/components/enemies/enemy_spawner.dart';
import 'package:creatures_rogue/game/components/items/coin_pickup.dart';
import 'package:creatures_rogue/game/components/items/consumable_item.dart';
import 'package:creatures_rogue/game/components/items/heart_pickup.dart';
import 'package:creatures_rogue/game/components/items/power_up_item.dart';
import 'package:creatures_rogue/game/components/items/shop_stand.dart';
import 'package:creatures_rogue/game/components/map/door.dart';
import 'package:creatures_rogue/game/components/map/pedestal.dart';
import 'package:creatures_rogue/game/components/creatures/wild_creature_npc.dart';
import 'package:creatures_rogue/game/components/map/stairs.dart';
import 'package:creatures_rogue/game/components/map/wall_barrier.dart';
import 'package:creatures_rogue/game/components/map/wall_tile.dart';
import 'package:creatures_rogue/game/components/player/player.dart';
import 'package:creatures_rogue/game/components/utils/y_sort.dart';
import 'package:creatures_rogue/l10n/l10n_extensions.dart';
import 'dungeon_generator.dart';
import 'obstacle.dart';

/// Um dos quatro lados de uma sala. Usado pra descrever por onde alguém
/// entrou ou saiu, sem espalhar comparações de coordenada pelo código.
enum LadoSala {
  topo,
  direita,
  baixo,
  esquerda;

  LadoSala get oposto => switch (this) {
    LadoSala.topo => LadoSala.baixo,
    LadoSala.baixo => LadoSala.topo,
    LadoSala.esquerda => LadoSala.direita,
    LadoSala.direita => LadoSala.esquerda,
  };

  /// Gira 90° no sentido do relógio: topo → direita → baixo → esquerda.
  ///
  /// Sentido fixo em vez de sorteado: a cena do boss usa isto pra escolher por
  /// onde o treinador sai, e um sorteio ali deixaria a cena diferente a cada
  /// entrada sem o jogador entender por quê.
  LadoSala get perpendicular => switch (this) {
    LadoSala.topo => LadoSala.direita,
    LadoSala.direita => LadoSala.baixo,
    LadoSala.baixo => LadoSala.esquerda,
    LadoSala.esquerda => LadoSala.topo,
  };
}

class RoomComponent extends PositionComponent with HasGameRef {
  final RoomData data;
  final Player player;

  bool isLocked = false;

  /// Cena de abertura do boss rodando agora. Enquanto isso for true, a
  /// checagem de "sala limpa" fica suspensa — o boss só nasce no meio da cena,
  /// e sem essa guarda a sala se destrancaria no primeiro quadro (ver
  /// [update]), abrindo a porta e nascendo escada e recompensa antes de
  /// existir adversário.
  bool cutsceneAtiva = false;

  /// Uma vez por visita: sair e voltar não repete a cena. Morrer é run nova,
  /// com sala nova, então lá ela toca de novo — que é o desejado.
  bool _cutsceneBossJaRodou = false;
  List<Door> roomDoors = [];
  List activeEnemies = [];

  final Random _random = Random();

  static const double roomWidth = 16 * 12.0;
  static const double roomHeight = 16 * 12.0;
  static const double wallThickness = 16.0;
  static const double doorSize = 32.0;

  /// Faixa reservada pra HUD no topo — a linha 0 de tiles (16px). Room em si
  /// não cresce (a câmera é `withFixedResolution(roomWidth, roomHeight)`, e o
  /// stride da grade de salas usa `roomHeight` também — crescer quebraria os
  /// dois); a área jogável é que encolhe uma linha, de 10×10 pra 10×9 tiles.
  /// Linha 0 fica sem parede/piso/colisão nenhuma — só fundo vazio, pra HUD
  /// desenhar em cima sem disputar espaço com sprite de sala.
  static const double topoHud = 16.0;

  /// Chão da sala em coordenadas do mundo, sem paredes nem a faixa da HUD.
  /// Quem move algo SEM percorrer o caminho (o teleporte do Zapeye) confere
  /// o destino contra isto, senão atravessaria a parede pra sala vizinha.
  Rect get areaInterna => Rect.fromLTRB(
    position.x + 16,
    position.y + topoHud + 16,
    position.x + width - 16,
    position.y + height - 16,
  );

  /// Centro vertical da área JOGÁVEL (linhas 1-11, y de 16 a 192) — usado
  /// onde antes era `height / 2`, pra tudo que precisa ficar centralizado no
  /// que sobrou depois da faixa da HUD (portas, obstáculos, spawns...).
  /// `midX`/`width / 2` continuam valendo — só o eixo vertical mudou.
  static const double centerY = (topoHud + roomHeight) / 2;

  /// Piso/paredes/grama ficam SEMPRE atrás de qualquer ator ou obstáculo
  /// Y-sorted — inclusive nas salas ao norte da origem, onde a coordenada Y
  /// dos atores fica negativa. Um valor bem abaixo de qualquer Y de mundo
  /// possível garante isso sem depender de onde a sala está na grade.
  static const int _prioridadePiso = -1000000;

  /// Retângulos locais (mesmo espaço de `px, py` usado em [_spawnEnemies]) de
  /// cada obstáculo gerado, pra checar sobreposição no spawn de inimigo —
  /// funciona independente de o obstáculo continuar filho desta sala (Hole)
  /// ou ter sido reparentado pro mundo pra entrar no Z-sort global (Rock).
  final List<Rect> _obstacleRects = [];

  //late final Sprite floorSprite;
  //late final Sprite doorSprite;

  late final DungeonTheme theme;
  final int floor;
  final int dungeon;

  /// Quando não-nulo, esta sala de boss recebe O BOSS em vez de inimigos
  /// comuns. Quem constrói é o jogo (que também pendura a barra de vida na
  /// viewport da câmera) — a sala só precisa saber onde colocar e acompanhar
  /// a morte dele. Null = andar comum, sala de boss se comporta como antes.
  final Enemy? Function(Vector2 position)? bossBuilder;

  /// Criatura selvagem da sala da escada do quarto andar (ver
  /// PIVOT_CONTROLE_DIRETO.md §5) — mesmo padrão do `bossBuilder` acima: quem
  /// decide QUANDO e SE nasce é o jogo (que sabe se há slot livre no grupo),
  /// a sala só sabe onde colocar. `null` = andar comum, sem criatura nenhuma.
  ///
  /// Recebe o CENTRO da oferta e devolve as criaturas já posicionadas em
  /// volta dele — uma escolha entre até duas (ver
  /// `CreaturesRogueGame._buildWildCreatures`). Lista vazia = sem oferta.
  final List<WildCreatureNpc> Function(Vector2 centro)? wildCreatureBuilder;

  RoomComponent(
    this.data, {
    required this.player,
    this.floor = 1,
    this.dungeon = 1,
    this.bossBuilder,
    this.wildCreatureBuilder,
  }) : super(
         size: Vector2(roomWidth, roomHeight),
         position: Vector2(
           (data.x - dungeonGridOrigin) * roomWidth,
           (data.y - dungeonGridOrigin) * roomHeight,
         ),
         priority: _prioridadePiso,
       ) {
    theme = DungeonTheme.getThemeForLevel(dungeon);
  }

  late final Paint floorPaint;
  late final Paint doorPaint;
  late final Paint lockedDoorPaint;

  @override
  Future<void> onLoad() async {
    super.onLoad();

    //  floorSprite = await gameRef.loadSprite('tileset/floor.png');
    //  doorSprite = await gameRef.loadSprite('tileset/door1.png');

    floorPaint = Paint()
      ..filterQuality = FilterQuality.none
      ..colorFilter = ColorFilter.mode(Palette.cinza, BlendMode.modulate);

    doorPaint = Paint()
      ..filterQuality = FilterQuality.none
      ..colorFilter = ColorFilter.mode(Palette.cinzaEsc, BlendMode.modulate);

    lockedDoorPaint = Paint()
      ..filterQuality = FilterQuality.none
      ..colorFilter = const ColorFilter.mode(
        Palette.preto,
        BlendMode.srcATop,
      ); // Deixa a porta escura

    _generateWalls();
    _generateFloorDetails();
    _generateDoors();

    if (data.type == RoomType.normal) {
      _generateObstacles();
    } else if (data.type == RoomType.item) {
      _spawnTreasure();
    } else if (data.type == RoomType.shop) {
      _spawnShop();
    } else if (data.type == RoomType.desafio) {
      _spawnDesafio();
    } else if (data.type == RoomType.start) {
      if (floor ==1) {
        _spawnTreasure();
         if (dungeon ==1)_spawnTutorial();
        //_spawnSalaDeTeste();
      }
    }
  }

  /// Pedestal da sala de DESAFIO. Guardado porque é ele que dispara a briga:
  /// a sala fica vendo se o item ainda está ali.
  PedestalComponent? _pedestalDesafio;

  /// Passa a true assim que o pedestal REALMENTE mostra um item. Sem isso, a
  /// sala veria "pedestal sem item" no primeiro quadro — o `onLoad` do
  /// pedestal é assíncrono e o coletável só nasce um pouco depois — e
  /// começaria o desafio sozinho, antes de o jogador encostar em nada.
  bool _itemDesafioApareceu = false;

  /// Quantas ondas já foram invocadas. Vai de 0 a [ondasDoDesafio].
  int _ondaDesafio = 0;

  static const int ondasDoDesafio = 3;

  /// Sala de desafio: só o pedestal no centro. Nenhum inimigo nasce aqui na
  /// entrada — quem decide começar é o jogador, pegando o item.
  ///
  /// O prêmio vem ANTES da briga, de propósito: é o que faz a sala ser uma
  /// aposta ("levo isto e encaro três ondas?") em vez de mais uma sala
  /// trancada. Quem não quiser, sai pela porta aberta sem levar nada.
  void _spawnDesafio() {
    final centro = position + Vector2(width / 2 - 8, centerY);
    final oferta = PedestalComponent.sortearOferta(
      game as CreaturesRogueGame,
      _random,
    );
    final pedestal = PedestalComponent(
      position: centro,
      familia: oferta.familia,
      itemEfeito: oferta.item,
    );
    _pedestalDesafio = pedestal;
    parent?.add(pedestal);
  }

  /// Vigia o pedestal e começa o desafio quando o item sai dele.
  ///
  /// Por observação e não por callback: o coletável é filho do PEDESTAL, que
  /// por sua vez é filho do mundo (não desta sala), e ele mesmo nasce dentro
  /// de um `onLoad` assíncrono. Um gancho teria que atravessar
  /// `Collectible` -> `PedestalComponent` -> sala pra dizer algo que duas
  /// linhas de leitura já dizem.
  void _vigiarPedestalDesafio() {
    final pedestal = _pedestalDesafio;
    if (pedestal == null || _ondaDesafio > 0) return;

    final temItem = pedestal.children.whereType<Collectible>().isNotEmpty;
    if (temItem) {
      _itemDesafioApareceu = true;
      return;
    }
    if (!_itemDesafioApareceu) return;

    // Item coletado: a sala vira sala de combate.
    data.isCleared = false;
    _lockRoom();
    _proximaOndaDesafio();
  }

  void _proximaOndaDesafio() {
    _ondaDesafio++;
    // Onda maior a cada rodada: a primeira é do tamanho de uma sala comum do
    // andar e as outras sobem em cima dela.
    _spawnTurma(floor + _ondaDesafio);
  }

  /// Tutorial no chão da sala inicial. Filho DESTA sala de propósito: é o que
  /// coloca o texto acima do piso e abaixo dos atores sem escolher prioridade
  /// na mão (ver [FloorText]).
  void _spawnTutorial() {
    final contexto = game.buildContext;
    if (contexto == null) return;

    add(
      FloorText(
        // Sem controle na tela o jogador esta no teclado (ver
        // `Player.onKeyEvent`), e mandar ele arrastar o dedo seria instrucao
        // pra um controle que nem esta montado.
        texto: GameSettings.instance.controlesNaTela
            ? contexto.l10n.tutorial_controles
            : contexto.l10n.tutorial_controlesTeclado,
        position: Vector2(width / 2, centerY + 44),
        
      ),
    );
  }

  void _spawnSalaDeTeste() {
    final candidatas = CreatureRegistry.all
        .where((c) => c.evoluir != null && c.id != player.creatureData.id)
        .take(2)
        .toList();

    for (var i = 0; i < candidatas.length; i++) {
      parent?.add(
        WildCreatureNpc(
          position: position + Vector2(width / 2 - 24 + i * 48, centerY - 32),
          creatureData: candidatas[i],
        ),
      );
    }
    /*
    for (var i = 0; i < 4; i++) {
      parent?.add(
        ConsumablePickup(
          position: position + Vector2(width / 2 - 24 + i * 16, centerY + 24),
          tipo: ConsumableType.doce,
        ),
      );
    }
    */
   // parent?.add(ItemEfeitoPickup(position: Vector2(width / 2 - 32, centerY + 24), item: CascaDeOvo()));
    parent?.add(ItemEfeitoPickup(position: Vector2(width / 2 + 32, centerY + 24), item: Coleira()));
   // parent?.add(ItemEfeitoPickup(position: Vector2(width / 2 + 32, centerY + 48), item: Espolio()));
    parent?.add(ItemEfeitoPickup(position: Vector2(width / 2 - 32, centerY + 48), item: Ninhada()));
      Enemy enemy = DummyEnemy(
        position: Vector2(width / 2, height / 2 - 32),
        playerTarget: player,
      );
      parent?.add(enemy);
      
  }

  static const double _passoPedestais = 64.0;

  void _spawnTreasure({double offsetX = 0, double offsetY = 0}) {
    final centro =
        position + Vector2(width / 2 - 8, centerY) + Vector2(offsetX, offsetY);

    // Lido AQUI, na montagem da sala, e não num gancho: o item não tem gancho
    // nenhum. A consequência é que ele só vale do ANDAR SEGUINTE em diante,
    // porque todas as salas de um andar nascem de uma vez quando o andar é
    // gerado — está dito na doc do `MapaDoTesouro`.
    final quantos = player.itens.any((i) => i is BauDoTesouro) ? 3 : 2;

    final familias = [0, 1, 2]..shuffle();

    final pedestais = <PedestalComponent>[];
    for (var i = 0; i < quantos; i++) {
      // Fila centrada: com 2 as posições são -0,5 e +0,5 do passo; com 3 são
      // -1, 0 e +1.
      final desvio = i - (quantos - 1) / 2;
      // Sorteio AQUI, antes de o pedestal existir (ver
      // `PedestalComponent.sortearOferta`). O irmão citado é só pro desempate
      // de quando a pool de ITEM_EFEITO acaba. Com três pedestais as três
      // famílias já estão tomadas, então nesse caso raro (pool vazia, fim de
      // run) uma oferta pode repetir a família de outra. É barato de aceitar
      // e caro de evitar.
      final oferta = PedestalComponent.sortearOferta(
        game as CreaturesRogueGame,
        _random,
        familia: familias[i],
        familiaIrmao: familias[(i + 1) % quantos],
      );
      pedestais.add(
        PedestalComponent(
          position: centro + Vector2(desvio * _passoPedestais, 0),
          familia: oferta.familia,
          itemEfeito: oferta.item,
        ),
      );
    }

    // Antes do `add`: o `onLoad` de um deles pode terminar no mesmo quadro, e
    // ele precisa já conhecer os irmãos pra fechar a oferta se for o escolhido.
    for (final p in pedestais) {
      p.irmaos.addAll(pedestais.where((outro) => outro != p));
    }

    for (final p in pedestais) {
      parent?.add(p);
    }
  }

  /// Três balcões, sempre nas mesmas posições: cura, um item de uso único e um
  /// upgrade permanente. Os dois últimos são sorteados por andar, então a loja
  /// não vende sempre a mesma coisa.
  ///
  /// Os preços são o botão de ajuste da economia: hoje uma sala limpa dá 1
  /// moeda e um andar tem ~10 salas de combate, ou seja, ~10 moedas por andar.
  void _spawnShop() {
    final centro = position + Vector2(width / 2, centerY);

    // Cada balcão é montado por uma função, e não direto: com `Reposicao` a
    // compra pede um balcão NOVO pro mesmo lugar (`ShopStand.repor`), e a
    // mesma função sorteia o produto de novo.
    ShopStand balcaoCura() => ShopStand(
      position: centro + Vector2(-32, -8),
      preco: 4,
      spritePath: 'items/fruta.png',
      cor1: Palette.laranja,
      cor2: Palette.verdeEsc,
      // `heal` devolve false com a vida cheia — e é isso que evita cobrar por
      // uma cura que não curou.
      entregar: (p) => p.heal(2),
      msgFalha: game.buildContext!.l10n.effect_vidaCheia,
      descricao: (context) => context.l10n.effect_maisVida(2),
      repor: balcaoCura,
    );

    ShopStand balcaoConsumivel() {
      final consumivel =
          ConsumableType.values[_random.nextInt(ConsumableType.values.length)];
      return ShopStand(
        position: centro + Vector2(0, -8),
        preco: 7,
        spritePath: consumivel.spritePath,
        cor1: consumivel.cor1,
        cor2: consumivel.cor2,
        entregar: (p) => p.addConsumable(consumivel),
        descricao: consumivel.descricao,
        repor: balcaoConsumivel,
      );
    }

    // A terceira bancada é meio a meio entre upgrade de stat e item com
    // gatilho. Ao contrário do pedestal, a loja só ESPIA a pool — o item sai
    // dela na hora da compra (ver `entregar` abaixo). Expor não gasta: uma
    // loja que o jogador não tem moeda pra pagar deixa o item disponível pro
    // resto da run.
    ShopStand balcaoEspecial() {
      final jogo = game;
      final itemEfeito = _random.nextBool() && jogo is CreaturesRogueGame
          ? jogo.espiarItemEfeito()
          : null;
      if (itemEfeito != null) {
        // Mais caro que o upgrade de stat: muda como se joga, e a run só
        // oferece cada um uma vez.
        return ShopStand(
          position: centro + Vector2(32, -8),
          preco: 20,
          spritePath: itemEfeito.spritePath,
          cor1: itemEfeito.cor1,
          cor2: itemEfeito.cor2,
          entregar: (p) {
            // `consumirItemEfeito` devolve false se um pedestal entregou o
            // mesmo item enquanto a loja o exibia. Recusar aqui é o que impede
            // duas cópias na lista — e, como `ShopStand` só cobra quando
            // `entregar` devolve true, o jogador não paga por nada.
            final jogo = game;
            if (jogo is! CreaturesRogueGame) return false;
            if (!jogo.consumirItemEfeito(itemEfeito)) return false;
            p.itens.add(itemEfeito);
            return true;
          },
          msgFalha: game.buildContext!.l10n.effect_jaTemItem,
          descricao: itemEfeito.descricao,
          repor: balcaoEspecial,
        );
      }
      final upgrade =
          PowerUpType.values[_random.nextInt(PowerUpType.values.length)];
      return ShopStand(
        position: centro + Vector2(32, -8),
        preco: 14,
        spritePath: upgrade.spritePath,
        cor1: upgrade.cor1,
        cor2: upgrade.cor2,
        entregar: (p) {
          upgrade.aplicar(p);
          return true; // upgrade não tem como falhar
        },
        descricao: upgrade.descricao,
        repor: balcaoEspecial,
      );
    }

    parent?.add(balcaoCura());
    parent?.add(balcaoConsumivel());
    parent?.add(balcaoEspecial());
  }

  void _spawnRecompensa() {
    final pos = position + Vector2(width / 2, centerY + 24);

    //final podeCurar = player.currentHealth < player.maxHealth;
    final recompensaChance = _random.nextInt(100);
    if (recompensaChance < 12) {
      parent?.add(HeartPickup(position: pos));
    } else if (recompensaChance >= 12 && recompensaChance < 60){
      parent?.add(CoinPickup(position: pos));
    }
  }

  void _generateFloorDetails() {
    // Linha 1 (y=16) agora é parede (ver `_generateWalls`) — piso começa na
    // linha 2.
    for (double y = topoHud + 16.0; y < height - 16.0; y += 16.0) {
      for (double x = 16.0; x < width - 16.0; x += 16.0) {
        int roll = _random.nextInt(100);

        if (dungeon == 2 || dungeon == 4) {
          add(
            ChaoCave(
              position: Vector2(x, y),
              cor1: theme.corClara,
              cor2: theme.corEscura,
              cor3: theme.corBranca,
            ),
          );
        } else {
          if (roll < 45) {
            add(
              Grama(
                position: Vector2(x, y),
                cor1: theme.corClara,
                cor2: theme.corEscura,
                cor3: theme.corBranca,
              ),
            );
          }
        }
      }
    }
  }

  void _generateObstacles() {
    for (double y = topoHud + 16.0; y < height - 16.0; y += 16.0) {
      for (double x = 16.0; x < width - 16.0; x += 16.0) {
        // REGRA 1: Não spawnar pedras bem no meio da sala
        //bool isCenter = (x >= width / 2 - 24 && x <= width / 2 + 8) &&
        //                (y >= height / 2 - 24 && y <= height / 2 + 8);
        //
        // REGRA 2: Não spawnar bloqueando o corredor das portas
        bool isDoorPathHorizontal =
            (y >= height / 2 - 16 && y <= height / 2 + 16);
        bool isDoorPathVertical = (x >= width / 2 - 16 && x <= width / 2 + 16);

        if ( /*isCenter ||*/ isDoorPathHorizontal || isDoorPathVertical) {
          continue;
        }

        int roll = _random.nextInt(100);

        if (roll < 5) {
          // Pedra bloqueia e tem altura visual: precisa entrar no Z-sort
          // global (mundo), senão desenha sempre atrás/na frente do jogador
          // inteiro, e não conforme quem está "mais pra baixo" na tela — por
          // isso vai pro `parent` (mundo) em vez de filha desta sala.
          final rockPos = position + Vector2(x, y);
          final rock = Rock(
            position: rockPos,
            cor1: theme.corClara,
            cor2: theme.corEscura,
            cor3: theme.corBranca,
          );
          rock.priority = ySortPriority(rockPos.y + rock.size.y);
          _obstacleRects.add(Rect.fromLTWH(x, y, 16, 16));
          parent?.add(rock);
        } else if (roll >= 5 && roll < 8) {
          add(
            Hole(
              position: Vector2(x, y),
              cor1: theme.corClara,
              cor2: theme.corEscura,
              cor3: theme.corBranca,
            ),
          );
          _obstacleRects.add(Rect.fromLTWH(x, y, 16, 16));
        } else if (roll >= 8 && roll < 15) {
          if(dungeon == 2 || dungeon == 4){
            add(
            Cogumelos(
              position: Vector2(x, y),
              cor1: theme.corClara,
              cor2: theme.corEscura,
              cor3: theme.corBranca,
            ),);
          }else{
            add(GramaAlta(position: Vector2(x, y),cor1: theme.corClara,cor2: theme.corEscura,cor3: theme.corBranca));
          }
          _obstacleRects.add(Rect.fromLTWH(x, y, 16, 16));
        } else if (roll >= 15 && roll < 18) {
          add(
            SpikeTrap(
              position: Vector2(x, y),
              cor1: theme.corClara,
              cor2: theme.corEscura,
            ),
          );
          _obstacleRects.add(Rect.fromLTWH(x, y, 16, 16));
        }
      }
    }
  }

  void _generateDoors() {
    bool initialOpen =
        data.isCleared || data.type == RoomType.start || !data.isVisited;
    void addDoorHalf(Vector2 pos, double rot, {bool flipX = false}) {
      var spritePath = 'tileset/arvore2.png';
      if (dungeon == 2 || dungeon == 4) spritePath = 'tileset/pedraCave2.png';
      var d = Door(
        position: pos,
        angleVal: 0, //rot,
        isOpen: initialOpen,
        flipX: false, //flipX,
        cor1: theme.corClara,
        cor2: theme.corEscura,
        cor3: theme.corBranca,
        cor4: theme.corChao,
        spritePath: spritePath,
      );
      roomDoors.add(d);
      add(d);
    }

    if (data.doorTop) {
      addDoorHalf(
        Vector2((width / 2) - 16, topoHud),
        math.pi / 2,
        flipX: false,
      );
      addDoorHalf(Vector2(width / 2, topoHud), math.pi / 2, flipX: true);
    }
    if (data.doorBottom) {
      addDoorHalf(
        Vector2((width / 2) - 16, height - 16),
        -math.pi / 2,
        flipX: true,
      );
      addDoorHalf(Vector2(width / 2, height - 16), -math.pi / 2, flipX: false);
    }
    if (data.doorLeft) {
      addDoorHalf(Vector2(0, (height / 2) - 16), 0, flipX: true);
      addDoorHalf(Vector2(0, height / 2), 0, flipX: false);
    }
    if (data.doorRight) {
      addDoorHalf(
        Vector2(width - 16, (height / 2) - 16),
        math.pi,
        flipX: false,
      );
      addDoorHalf(Vector2(width - 16, height / 2), math.pi, flipX: true);
    }
  }

  /// [ladoEntrada] é a porta POR ONDE o jogador entrou nesta sala — usada pela
  /// cena do boss pra montar a coreografia em relação a ele.
  void onPlayerEnter(LadoSala ladoEntrada) {
    // Antes de marcar como visitada: a carga é por sala INÉDITA, então voltar
    // pra uma sala já andada não rende nada. É isso que impede o jogador de
    // fabricar carga andando de um lado pro outro.
    if (!data.isVisited) player.ganharCargaDeSala();
    data.isVisited = true;
    // Sala de ESCADA: nunca tranca. Antes ela era uma sala de boss com
    // `bossBuilder` nulo, então trancava, não invocava ninguém e destrancava
    // no quadro seguinte — as portas piscavam fechadas por nada. Agora o tipo
    // diz que não há luta, e a escada nasce direto.
    if (data.type == RoomType.stairs) {
      if (!data.isCleared) {
        data.isCleared = true;
        _spawnEscadaEArredores();
      }
      return;
    }

    if (!data.isCleared && (data.type == RoomType.normal || data.type == RoomType.boss)) {
      _lockRoom();
      _spawnEnemies(ladoEntrada);
    }
  }

  void _lockRoom() {
    isLocked = true;
    for (var door in roomDoors) {
      door.close();
    }
  }

  void _unlockRoom() {
    isLocked = false;
    data.isCleared = true;

    for (var door in roomDoors) {
      door.open();
    }

    if (data.type == RoomType.boss) {
      _spawnEscadaEArredores();
      return;
    }

    _spawnRecompensa();
  }

  /// Escada pro andar seguinte, as pedras em volta dela e a criatura selvagem
  /// do andar — tudo o que a ÚLTIMA sala do andar precisa ter.
  ///
  /// Extraído do `_unlockRoom` porque agora há dois caminhos até aqui:
  /// [RoomType.boss] chama depois de a luta acabar, e [RoomType.stairs] chama
  /// assim que o jogador entra, já que ali não há luta nenhuma.
  void _spawnEscadaEArredores() {
    final posList = [
      Vector2(-24, -24),
      Vector2(-8, -24),
      Vector2(8, -24),
      Vector2(-24, -8),
      Vector2(8, -8),
      Vector2(-24, 8),
      Vector2(8, 8),
    ];

    for (var pos in posList){
      final rockPos = position + Vector2(width / 2, centerY) + pos;
      final rock = Rock(
        position: rockPos,
        cor1: theme.corClara,
        cor2: theme.corEscura,
        cor3: theme.corBranca,
      );
      rock.priority = ySortPriority(rockPos.y + rock.size.y);
      _obstacleRects.add(Rect.fromLTWH(x, y, 16, 16));
      parent?.add(rock);
    }

    parent?.add(Stairs(position: position + Vector2(width / 2, centerY)));

    final construirCriatura = wildCreatureBuilder;
    if (construirCriatura != null) {
      // Posição própria (centerY - 28), livre da escada (centerY) e da
      // recompensa (centerY + 28) — ver PIVOT_CONTROLE_DIRETO.md §5.2.
      final npcs = construirCriatura(
        position + Vector2(width / 2, centerY - 32),
      );
      for (final npc in npcs) {
        parent?.add(npc);
      }
    }
  }

  /// Ponto logo DENTRO da parede de [lado], em coordenadas locais. A parede
  /// tem 16px, e o topo perde outros 16 pra HUD (ver [topoHud]).
  Vector2 _pontoNaBorda(LadoSala lado) => switch (lado) {
    LadoSala.topo => Vector2(width / 2, topoHud + 16 + 8),
    LadoSala.baixo => Vector2(width / 2, height - 16 - 8),
    LadoSala.esquerda => Vector2(16 + 8, centerY),
    LadoSala.direita => Vector2(width - 16 - 8, centerY),
  };

  static const double _afastamentoBoss = 24.0;

  Vector2 _afastamento(LadoSala lado) => switch (lado) {
    LadoSala.topo => Vector2(0, -_afastamentoBoss),
    LadoSala.baixo => Vector2(0, _afastamentoBoss),
    LadoSala.esquerda => Vector2(-_afastamentoBoss, 0),
    LadoSala.direita => Vector2(_afastamentoBoss, 0),
  };

  /// A cena segura o controle do jogador e a checagem de sala limpa; o boss
  /// nasce no meio dela, pelas mãos do treinador.
  ///
  /// A coreografia é toda relativa a [ladoJogador], a porta por onde o jogador
  /// entrou: o treinador vem pelo lado OPOSTO (encara o jogador em vez de
  /// nascer às costas dele), o boss nasce ainda mais além, do mesmo lado de
  /// onde o treinador veio (ou seja, oposto ao jogador), e a saída é
  /// PERPENDICULAR à entrada — sair de volta pela porta de onde veio leria
  /// como desistência, e sair pela porta do jogador o faria atravessá-lo.
  void _iniciarCutsceneBoss(LadoSala ladoJogador) {
    cutsceneAtiva = true;
    player.emCutscene = true;

    final ladoTreinador = ladoJogador.oposto;
    final centro = Vector2(width / 2, centerY);
    final posBoss = centro + _afastamento(ladoTreinador);

    add(
      BossCutscene(
        entrada: _pontoNaBorda(ladoTreinador),
        centro: centro,
        saida: _pontoNaBorda(ladoTreinador.perpendicular),
        posBoss: posBoss,
        aoInvocar: () => _spawnBoss(posBoss),
        aoTerminar: () {
          cutsceneAtiva = false;
          player.emCutscene = false;
          for (final inimigo in activeEnemies) {
            if (inimigo is Enemy) inimigo.emCutscene = false;
          }
        },
      ),
    );
  }

  /// [posLocal] nulo = posição padrão (acima do centro), usada quando não há
  /// cena de abertura pra escolher o lado.
  void _spawnBoss([Vector2? posLocal]) {
    final construirBoss = bossBuilder;
    if (construirBoss != null) {
      final boss = construirBoss(
        position + (posLocal ?? Vector2(width / 2, centerY - _afastamentoBoss)),
      );
      if (boss != null) {
        // Nasce inerte se a cena ainda está rodando: ele aparece na invocação
        // mas só age quando o treinador sai. Derivado de `cutsceneAtiva` em
        // vez de um parâmetro — quem chama fora da cena não precisa saber
        // que isso existe.
        boss.emCutscene = cutsceneAtiva;
        activeEnemies.add(boss);
        parent?.add(boss);
      }
    }
  }

  void _spawnEnemies(LadoSala ladoEntrada) {
    // Sala de BOSS: nunca turma comum. Sem esse desvio por tipo de sala, a
    // conta de quantidade lá embaixo valia pra QUALQUER sala do andar — no
    // andar de boss, até a loja spawnava boss.
    //
    // Andar SEM boss não cai mais aqui: a sala final dele nasce como
    // `RoomType.stairs` e é tratada no `onPlayerEnter`, sem trancar. O
    // `bossBuilder` nulo abaixo virou caminho de segurança, não o caso comum
    // — gerador e jogo tiram os dois do mesmo `isBossFloor`, então só chegam
    // aqui discordando se alguém mexer num sem o outro.
    if (data.type == RoomType.boss) {
      if (bossBuilder != null && !_cutsceneBossJaRodou) {
        _cutsceneBossJaRodou = true;
        _iniciarCutsceneBoss(ladoEntrada);
      } else {
        _spawnBoss();
      }
      return;
    }

    _spawnTurma(floor + _random.nextInt(3));
  }

  /// Nasce [count] inimigos em posições livres da sala. Separado de
  /// [_spawnEnemies] porque as ondas do desafio precisam exatamente disto, sem
  /// a parte de boss/cutscene.
  void _spawnTurma(int count) {

    // Os inimigos são criados aqui e só montados no fim: entre uma coisa e
    // outra um deles pode virar campeão, e isso precisa acontecer antes do
    // `onLoad`.
    final novos = <Enemy>[];

    for (int i = 0; i < count; i++) {
      double px = 0;
      double py = 0;
      bool validPosition = false;
      int attempts = 0;

      while (!validPosition && attempts < 30) {
        px = 64 + _random.nextInt(4) * 16.0;
        py = 64 + _random.nextInt(4) * 16.0;

        Rect enemyRect = Rect.fromLTWH(px, py, 16, 16);
        // `_obstacleRects` (não `children`) porque a Rock foi reparentada pro
        // mundo pro Z-sort — checar `children` perderia essa colisão.
        validPosition = !_obstacleRects.any((r) => r.overlaps(enemyRect));
        attempts++;
      }

      Vector2 spawnPos = position + Vector2(px, py) + Vector2(8, 8);

      Enemy enemy = EnemySpawner.getRandomEnemy(spawnPos, player, dungeon);

      activeEnemies.add(enemy);
      novos.add(enemy);
    }

    // Sorteio POR SALA, e não por inimigo: 10% por inimigo pareceria 10% mas
    // na prática dava de 10% a 27% de campeão por sala no andar 1 e mais de
    // 40% no andar 5, porque a quantidade cresce com o andar. Por sala, os
    // 10% são os 10% — e o campeão também lê melhor sendo um só.
    if (novos.isNotEmpty && _random.nextDouble() < chanceCampeaoPorSala) {
      // Promover ANTES do `add`: `Enemy.onLoad` monta sprite, hitbox e sombra
      // a partir de `size`/`hitboxSize`, e depois de montado mexer neles não
      // reconstrói nada.
      // Tipo sorteado com peso igual entre os três: sem dado pra calibrar
      // ainda, e um peso desigual agora seria chute em cima de chute.
      final tipo =
          CampeaoTipo.values[_random.nextInt(CampeaoTipo.values.length)];
      novos[_random.nextInt(novos.length)].promoverACampeao(tipo);
    }

    for (final enemy in novos) {
      parent?.add(enemy);
    }
  }

  /// Chance de uma sala de combate ter UM inimigo campeão (ver
  /// `Enemy.promoverACampeao`).
  ///
  /// Na dungeon final a chance quadruplica: ela é dos neutros, o elenco mais
  /// fraco, e sem compensação o clímax da run seria a dungeon mais fácil.
  /// Lido de `BossRegistry.all.length` em vez de um 5 fixo pra continuar
  /// valendo se outra dungeon entrar depois dela.
  double get chanceCampeaoPorSala =>
      dungeon >= BossRegistry.all.length ? 0.40 : 0.10;

  @override
  void update(double dt) {
    super.update(dt);

    if (data.type == RoomType.desafio) _vigiarPedestalDesafio();

    if (isLocked && !cutsceneAtiva) {
      activeEnemies.removeWhere((enemy) => enemy.isRemoved);

      if (activeEnemies.isEmpty) {
        // Ainda tem onda pra vir: a sala continua trancada e chama a próxima
        // em vez de destrancar.
        if (data.type == RoomType.desafio && _ondaDesafio < ondasDoDesafio) {
          _proximaOndaDesafio();
        } else {
          _unlockRoom();
        }
      }
    }
  }

  void _generateWalls() {
    final double tileSize = 16.0;
    final int tilesX = (width / tileSize).round();
    final int tilesY = (height / tileSize).round();

    String pathWall = 'tileset/arvore1.png'; //'tileset/wall.png';
    //final String pathCorner = 'tileset/arvore1.png';//'tileset/wallQuina.png';
    if (dungeon == 2 || dungeon == 4) {
      pathWall = 'tileset/pedraCave.png';
    }

    // Linha 0 fica de fora — reservada pra HUD (ver `topoHud`), sem parede
    // nem piso ali. A parede "de cima" vira a linha 1.
    for (int y = 1; y < tilesY; y++) {
      for (int x = 0; x < tilesX; x++) {
        bool isTop = y == 1;
        bool isBottom = y == tilesY - 1;
        bool isLeft = x == 0;
        bool isRight = x == tilesX - 1;

        if (isTop || isBottom || isLeft || isRight) {
          bool isDoorTop =
              isTop &&
              data.doorTop &&
              (x >= (tilesX / 2) - 1 && x <= (tilesX / 2));
          bool isDoorBottom =
              isBottom &&
              data.doorBottom &&
              (x >= (tilesX / 2) - 1 && x <= (tilesX / 2));
          bool isDoorLeft =
              isLeft &&
              data.doorLeft &&
              (y >= (tilesY / 2) - 1 && y <= (tilesY / 2));
          bool isDoorRight =
              isRight &&
              data.doorRight &&
              (y >= (tilesY / 2) - 1 && y <= (tilesY / 2));

          if (isDoorTop || isDoorBottom || isDoorLeft || isDoorRight) {
            continue;
          }

          String spriteToUse = pathWall;
          double rotation = 0.0;

          /*
          if (isTop && isLeft)        { spriteToUse = pathCorner; rotation = 0; }
          else if (isTop && isRight)    { spriteToUse = pathCorner; rotation = math.pi / 2; }
          else if (isBottom && isRight) { spriteToUse = pathCorner; rotation = math.pi; }
          else if (isBottom && isLeft)  { spriteToUse = pathCorner; rotation = 3 * math.pi / 2; }
          else if (isTop)    { spriteToUse = pathWall; rotation = math.pi / 2; }
          else if (isBottom) { spriteToUse = pathWall; rotation = 3 * math.pi / 2; }
          else if (isLeft)   { spriteToUse = pathWall; rotation = 0; }
          else if (isRight)  { spriteToUse = pathWall; rotation = math.pi; }
          */

          if (spriteToUse.isNotEmpty) {
            add(
              WallTile(
                position: Vector2(x * tileSize, y * tileSize),
                spritePath: spriteToUse,
                angleVal: rotation,
                cor1: theme.corClara,
                cor2: theme.corEscura,
                cor3: theme.corBranca,
              ),
            );
          }
        }
      }
    }

    double midX = width / 2;
    double midY = height / 2;
    double doorSpan = 32.0;

    // Parede "de cima" agora fica na linha 1 (`topoHud`) — linha 0 é a faixa
    // reservada pra HUD, sem barreira nenhuma ali.
    if (data.doorTop) {
      add(
        WallBarrier(
          position: Vector2(0, topoHud),
          size: Vector2(midX - (doorSpan / 2), 16),
        ),
      );
      add(
        WallBarrier(
          position: Vector2(midX + (doorSpan / 2), topoHud),
          size: Vector2(midX - (doorSpan / 2), 16),
        ),
      );
    } else {
      add(
        WallBarrier(
          position: Vector2(0, topoHud),
          size: Vector2(width, 16),
        ),
      );
    }

    if (data.doorBottom) {
      add(
        WallBarrier(
          position: Vector2(0, height - 16),
          size: Vector2(midX - (doorSpan / 2), 16),
        ),
      );
      add(
        WallBarrier(
          position: Vector2(midX + (doorSpan / 2), height - 16),
          size: Vector2(midX - (doorSpan / 2), 16),
        ),
      );
    } else {
      add(
        WallBarrier(
          position: Vector2(0, height - 16),
          size: Vector2(width, 16),
        ),
      );
    }

    // Segmento de cima das barreiras laterais também para na linha 1 (não em
    // 0) — o de baixo do vão da porta não muda, já fica bem abaixo da faixa
    // reservada.
    if (data.doorLeft) {
      add(
        WallBarrier(
          position: Vector2(0, topoHud),
          size: Vector2(16, midY - (doorSpan / 2) - topoHud),
        ),
      );
      add(
        WallBarrier(
          position: Vector2(0, midY + (doorSpan / 2)),
          size: Vector2(16, midY - (doorSpan / 2)),
        ),
      );
    } else {
      add(
        WallBarrier(
          position: Vector2(0, topoHud),
          size: Vector2(16, height - topoHud),
        ),
      );
    }

    if (data.doorRight) {
      add(
        WallBarrier(
          position: Vector2(width - 16, topoHud),
          size: Vector2(16, midY - (doorSpan / 2) - topoHud),
        ),
      );
      add(
        WallBarrier(
          position: Vector2(width - 16, midY + (doorSpan / 2)),
          size: Vector2(16, midY - (doorSpan / 2)),
        ),
      );
    } else {
      add(
        WallBarrier(
          position: Vector2(width - 16, topoHud),
          size: Vector2(16, height - topoHud),
        ),
      );
    }
  }

  // Criado uma única vez (antes era um Paint novo por sala, por frame)
  //late final Paint _roomBackgroundPaint = Paint()..color = Palette.branco;
  // Começa em `topoHud`, não 0 — senão a cor de chão pinta por baixo da HUD
  // a faixa que devia ficar vazia.
  late final Rect _roomBackgroundRect = Rect.fromLTWH(
    0,
    topoHud,
    width,
    height - topoHud,
  );

  @override
  void render(Canvas canvas) {
    canvas.drawRect(_roomBackgroundRect, Paint()..color = theme.corChao);
    //canvas.drawRect(Rect.fromLTWH(64, 64, 16*4, 16*4), Paint()..color = Palette.vermelho..style = PaintingStyle.stroke);

    super.render(canvas);
  }

  CameraComponent? _camera;

  bool _isOnCamera() {
    final cam = _camera ?? CameraComponent.currentCamera;
    if (cam == null || !cam.isMounted)
      return true; // sem câmera ainda: não corta nada
    _camera = cam;
    return cam.visibleWorldRect.overlaps(toAbsoluteRect());
  }

  @override
  void updateTree(double dt) {
    if (!_isOnCamera()) return;
    super.updateTree(dt);
  }

  @override
  void renderTree(Canvas canvas) {
    if (!_isOnCamera()) return;
    super.renderTree(canvas);
  }
}
