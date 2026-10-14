import 'package:creatures_rogue/game/components/UI/carga_sala_indicator.dart';
import 'dart:math' as math;
import 'package:creatures_rogue/game/components/items/item_efeito.dart';
import 'dart:ui' as ui;
import 'package:creatures_rogue/game/components/utils/palette_swapper.dart';
import 'package:creatures_rogue/game/creatures_rogue_game.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:creatures_rogue/game/components/UI/ability_cooldown_indicator.dart';
import 'package:creatures_rogue/game/components/UI/companion_portrait_indicator.dart';
import 'package:creatures_rogue/game/components/UI/cooldown_ring_indicator.dart';
import 'package:creatures_rogue/game/components/core/palette.dart';
import 'package:creatures_rogue/game/components/core/ui_theme.dart';
import 'package:creatures_rogue/game/components/creatures/creature_data.dart';
import '../player/player.dart';

class Hud extends PositionComponent with HasGameRef {
  final Player player;
  final CreaturesRogueGame game;

  /// Grupo de até três — cada função recebe o índice do slot (0/1/2).
  /// `companionCreatureAt` fica fixa mesmo quando o slot está no banco
  /// (`null` até a criatura selvagem da sala da escada preencher, ver
  /// PIVOT_CONTROLE_DIRETO.md §5). Ver `CompanionPortraitIndicator`.
  final CreatureData? Function(int slot) companionCreatureAt;

  /// 0 = ativa (ou vida cheia no banco), 1 = acabou de entrar no banco com a
  /// vida zerada — ver `CreaturesRogueGame.companionPocketFraction`.
  final double Function(int slot) companionPocketFractionAt;

  /// Cooldown de troca de criatura (1 = acabou de trocar, 0 = pronto), o mesmo
  /// pra todos os retratos — ver `CreaturesRogueGame.trocaCooldownFraction`.
  final double Function() trocaFraction;

  /// Qual slot é a criatura ativa agora — o retrato dela ganha o destaque
  /// visual.
  final bool Function(int slot) isCompanionAtivo;

  /// Toque em qualquer um dos três retratos — a decisão de "trocar de ativa"
  /// vs "ciclar postura da ativa" é de `CreaturesRogueGame.onTapCompanionSlot`,
  /// não da Hud nem do retrato.
  final void Function(int slot) onTapCompanionSlot;
  // Sprites
  late final Sprite heartSprite;
  late final Sprite heartHalfSprite;
  late final Sprite heartEmptySprite;
  late final Sprite shieldSprite;
  late final Sprite moedaSprite;

  final Paint emptyHeartPaint = Paint()
    ..colorFilter = const ColorFilter.mode(Palette.preto, BlendMode.srcATop)
    ..filterQuality = FilterQuality.none;

  final Paint paint = Paint()..filterQuality = FilterQuality.none;

  final Vector2 heartSize = Vector2(16, 16);
  final Vector2 bombIconSize = Vector2(16, 16);
  final double spacing = -11.0;

  /// Lado dos indicadores de cooldown. 16 é o tamanho nativo dos sprites
  /// (`ui/ataque.png` e `ui/defesa.png`), então a escala fica 1:1 e o pixel art
  /// não ganha artefato de reamostragem.
  static const double _iconeCooldownLado = 16;

  /// Deslocamento vertical entre um retrato e o de baixo. Menor que
  /// [_iconeCooldownLado] de propósito: eles se SOBREPÕEM, e só a faixa que
  /// sobra de cada um aparece — é o que comunica "tem mais criatura embaixo".
  static const double _retratoEmpilhamento = 5;

  //static final Vector2 _shieldBarSize = Vector2(3, 3);

  /// Largura máxima das barras de vida/escudo, em px da resolução fixa (192).
  /// Sem teto, cada `hpUp` somava 3px e a barra saía da tela depois de poucos
  /// upgrades. Passando desse ponto a barra para de crescer e cada ponto de
  // vida passa a valer menos pixel.
  // const double _barraLarguraMax = 60.0;

  /// Quantos px vale um ponto, dado o total [maxValor] da barra.
  // double _pxPorPonto(double maxValor) => maxValor <= 0
  //     ? 0
  //    : math.min(_shieldBarSize.x, _barraLarguraMax / maxValor);

  late final TextPaint textPaint;

  /// Barra de evolução (ver PIVOT_EVOLUCAO) — linha preta de fundo (o
  /// "comprimento alvo") com um preenchimento verde por cima que cresce
  /// conforme `player.xp`. Fica entre os corações e o ícone de moeda.
  final Paint _evoTrackPaint = Paint()..color = UiTheme.hudMolduraCor;
  final Paint _evoFundoPaint = Paint()..color = UiTheme.hudFundoCor;
  final Paint _evoFillPaint = Paint()..color = Palette.jade;
  static const double _evoBarWidth = 32;
  // Linha 0 (0-16px) é a faixa reservada da sala pra HUD (ver
  // `RoomComponent.topoHud`); linha 1 (16-32px) já é parede. 32 pousa na
  // linha 2, primeira linha de PISO — igual aos retratos do grupo, que já
  // flutuam sobre o chão sem reclamação.
  static const double _evoBarY = 184;
  static const double _evoBarHeight = 4;

  /// Barra de energia da habilidade 1 (substituiu o cooldown fixo — ver
  /// `Player.energia`/`custoEnergia`). Mesmo estilo da barra de evolução,
  /// logo abaixo dela, mas sempre visível (toda criatura usa energia agora).
  final Paint _energiaTrackPaint = Paint()..color = UiTheme.hudMolduraCor;
  final Paint _energiaFundoPaint = Paint()..color = UiTheme.hudFundoCor;
  final Paint _energiaFillPaint = Paint()..color = Palette.laranja;
  static const double _energiaBarWidth = 32;
  static const double _energiaBarY = 12;
  static const double _energiaBarHeight = 3;

  /// Regeneração do escudo passivo (defesa) — barra vertical (4x12 máx.) que
  /// cresce de baixo pra cima, no lugar onde o próximo `shieldSprite` nasce.
  //final Paint _shieldRegenPaint = Paint()..color = Palette.azul;
  //final Paint _shieldRegenBorderPaint = Paint()..color = Palette.preto..style = PaintingStyle.stroke..strokeWidth = 1.0;
  //static const double _shieldRegenLargura = 4;
  //static const double _shieldRegenAlturaMax = 10;
  // final Paint _shieldMoldura = Paint()..color = Palette.preto;
  // final Paint _shieldFundo = Paint()..color = Palette.preto;
  // final Paint _shieldPreenchimento = Paint()..color = Palette.azul;
  // final Paint _hpPreenchimento = Paint()..color = Palette.vermelho;

  Hud({
    required this.game,
    required this.player,
    required this.companionCreatureAt,
    required this.companionPocketFractionAt,
    required this.trocaFraction,
    required this.isCompanionAtivo,
    required this.onTapCompanionSlot,
  }) : super(position: Vector2(0, 0));

  @override
  Future<void> onLoad() async {
    super.onLoad();
    final ui.Image moedaImg = await PaletteSwapper.createSwappedImage(
      imagePath: 'ui/moeda.png',
      lightGrayReplacement: Palette.amarelo,
      darkGrayReplacement: Palette.laranja,
    );
    moedaSprite = Sprite(moedaImg);

    final ui.Image heartImg = await PaletteSwapper.createSwappedImage(
      imagePath: 'ui/heart.png',
      lightGrayReplacement: Palette.vermelho,
      darkGrayReplacement: Palette.roxoEsc,
    );

    final ui.Image heartHalfImg = await PaletteSwapper.createSwappedImage(
      imagePath: 'ui/heartHalf.png',
      lightGrayReplacement: Palette.vermelho,
      darkGrayReplacement: Palette.roxoEsc,
    );

    final ui.Image heartEmptyImg = await PaletteSwapper.createSwappedImage(
      imagePath: 'ui/heartEmpty.png',
      lightGrayReplacement: Palette.vermelho,
      darkGrayReplacement: Palette.roxoEsc,
    );

    final ui.Image shieldImg = await PaletteSwapper.createSwappedImage(
      imagePath: 'ui/escudo.png',
      lightGrayReplacement: Palette.azul,
      darkGrayReplacement: Palette.azulEsc,
    );

    heartSprite = Sprite(heartImg);
    heartHalfSprite = Sprite(heartHalfImg);
    heartEmptySprite = Sprite(heartEmptyImg);
    shieldSprite = Sprite(shieldImg);

    //bombSprite = Sprite(bombImg);

    // Indicadores de cooldown, logo abaixo das barras de vida/escudo. Ficam
    // como filhos e não dentro do render() da Hud pra cada um cuidar do seu
    // próprio sprite e do seu carregamento assíncrono.
    await addAll([
      // Duas habilidades diretas do jogador — voltou ao controle direto
      // (PIVOT_CONTROLE_DIRETO.md), então os dois indicadores lêem o
      // `Player` de novo, não mais uma criatura autônoma.
      /*  AbilityCooldownIndicator(
        tipo: () => player.creatureData.ability1.tipo,
        cooldownFraction: () => player.ability1CooldownFraction,
        lado: _iconeCooldownLado,
        position: Vector2(0, 14),
      ),
      AbilityCooldownIndicator(
        tipo: () => player.creatureData.ability2.tipo,
        cooldownFraction: () => player.ability2CooldownFraction,
        lado: _iconeCooldownLado,
        position: Vector2(_iconeCooldownLado + 2, 14),
      ),
      */
      // Anel de cooldown da habilidade 2 — antes vivia grudado no sprite do
      // Player (`CooldownRingIndicator`, ver `Player._montarVisualEHitboxInterno`),
      // agora fica fixo na Hud, do lado da barra de energia da habilidade 1.
      CooldownRingIndicator(
        tipo: () => player.creatureData.ability2.tipo,
        cooldownFraction: () => player.ability2CooldownFraction,
        raio: 4,
        position: Vector2(40, 12),
      ),

      // Cargas de sala, logo à direita do anel da habilidade 2 (que é
      // `Anchor.center` em x=40 com raio 4, então termina em x=44). Some
      // sozinho quando nenhum item em mãos gasta carga.
      CargaSalaIndicator(
        cargas: () => player.cargasDeSala,
        maximo: Player.cargasDeSalaMax,
        custo: SegundoFolego.custoCargas,
        deveAparecer: () => player.usaCargasDeSala,
        position: Vector2(46, 10),
      ),

      // Três retratos, um por slot do grupo — mesmo cinza que o indicador de
      // cooldown usa, agora mostrando quanto falta curar no banco, mais o
      // destaque de quem é a ativa (ver `CompanionPortraitIndicator`). Abaixo
      // da barra de energia (`_energiaBarY`+altura) pra não sobrepor.
      for (int slot = 0; slot < 3; slot++)
        CompanionPortraitIndicator(
          creatureData: () => companionCreatureAt(slot),
          pocketFraction: () => companionPocketFractionAt(slot),
          trocaFraction: trocaFraction,
          isAtiva: () => isCompanionAtivo(slot),
          onTap: () => onTapCompanionSlot(slot),
          lado: _iconeCooldownLado,
          position: Vector2(1, 17 + _retratoEmpilhamento * slot),
        ),
    ]);

    textPaint = TextPaint(
      style: const TextStyle(
        fontFamily: 'pixelFont',
        color: UiTheme.hudTxtCor,
        fontSize: 12,
        fontWeight: FontWeight.bold,
        shadows: UiTheme.hudTxtContorno,
      ),
    );
  }

  /// Afinidade do grupo (ver `Afinidade`): quadradinho na cor do tipo com o
  /// nível ao lado, apagado quando a criatura em campo não é do tipo. A
  /// Diversidade mostra as cores dos três tipos do grupo, sempre acesa.
  void _desenharAfinidade(Canvas canvas) {
    final afinidade = game.afinidade;
    if (!afinidade.ativa) return;
    const x = 64.0;
    const lado = 5.0;
    const y = _evoBarY - 1;

    final tipo = afinidade.tipo;
    if (tipo == null) {
      final tipos = game.grupo.nonNulls.map((m) => m.criatura.tipo).toList();
      for (var i = 0; i < tipos.length; i++) {
        canvas.drawRect(
          Rect.fromLTWH(x + i * (lado + 1), y, lado, lado),
          Paint()..color = UiTheme.corDoTipo(tipos[i]),
        );
      }
      return;
    }

    final ligada = player.creatureData.tipo == tipo;
    canvas.drawRect(
      Rect.fromLTWH(x - 1, y - 1, lado + 2, lado + 2),
      Paint()..color = UiTheme.hudMolduraCor,
    );
    canvas.drawRect(
      Rect.fromLTWH(x, y, lado, lado),
      Paint()
        ..color = UiTheme.corDoTipo(tipo).withAlpha(ligada ? 255 : 90),
    );
    textPaint.render(canvas, '${afinidade.nivel}', Vector2(x + lado + 2, y - 4));
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    /*
    final pxHp = _pxPorPonto(player.maxHealth);
    canvas.drawRect(Rect.fromLTWH(-1, 1 - 1, pxHp * player.maxHealth + 2, _shieldBarSize.y + 2), _shieldMoldura);
    canvas.drawRect(Rect.fromLTWH(0, 1, pxHp * player.maxHealth, _shieldBarSize.y), _shieldFundo);
    canvas.drawRect(Rect.fromLTWH(0, 1, pxHp * player.currentHealth, _shieldBarSize.y), _hpPreenchimento);


    final pxEscudo = _pxPorPonto(player.shieldMax);
    canvas.drawRect(Rect.fromLTWH(pxHp * player.maxHealth + 0, 0, pxEscudo * player.shieldMax + 2, _shieldBarSize.y + 2), _shieldMoldura);
    canvas.drawRect(Rect.fromLTWH(pxHp * player.maxHealth + 1, 1, pxEscudo * player.shieldMax, _shieldBarSize.y), _shieldFundo);
    canvas.drawRect(Rect.fromLTWH(pxHp * player.maxHealth + 1, 1, pxEscudo * player.shield, _shieldBarSize.y), _shieldPreenchimento);
*/
    // --- BARRA DE EVOLUÇÃO --- Só desenha pra quem tem forma evoluída
    // desenhada (`evoluir != null`) — as outras criaturas não têm o que
    // progredir ainda, então não ganham uma barra sempre vazia.
    canvas.drawRect(
      Rect.fromLTWH(0, 0, 192, 16),
      Paint()..color = Palette.branco,
    );
    // Antes o guard era so `evoluir != null`, e a forma EVOLUIDA nao tem
    // `evoluir` — a barra sumia justo quando passou a medir a aposentadoria.
    final naAposentadoria =
        player.evoluida &&
        PassivasAposentadoria.de(player.creatureData.id) != null;
    if (player.creatureData.evoluir != null || naAposentadoria) {
      textPaint.render(canvas, 'XP:', Vector2(2, _evoBarY - 6));
      canvas.drawRect(
        Rect.fromLTWH(25, _evoBarY - 1, _evoBarWidth + 1, _evoBarHeight + 2),
        _evoTrackPaint,
      );
      canvas.drawRect(
        Rect.fromLTWH(25, _evoBarY - 1, _evoBarWidth, _evoBarHeight + 1),
        _evoFundoPaint,
      );

      canvas.drawRect(
        Rect.fromLTWH(
          25,
          _evoBarY,
          _evoBarWidth * player.xpFracao,
          _evoBarHeight,
        ),
        _evoFillPaint,
      );
    }

    // --- BARRA DE ENERGIA (habilidade 1) ---
    // Criatura sem habilidade 1 (passiva no lugar, ver `CreatureData`) nunca
    // gasta energia: a barra ficaria cheia pra sempre, decorando.
    if (player.creatureData.ability1 != null) {
      canvas.drawRect(
        Rect.fromLTWH(
          1,
          _energiaBarY - 1,
          _energiaBarWidth + 1,
          _energiaBarHeight + 2,
        ),
        _energiaTrackPaint,
      );
      canvas.drawRect(
        Rect.fromLTWH(
          1,
          _energiaBarY - 1,
          _energiaBarWidth,
          _energiaBarHeight + 1,
        ),
        _energiaFundoPaint,
      );
      canvas.drawRect(
        Rect.fromLTWH(
          1,
          _energiaBarY,
          _energiaBarWidth * player.energiaFracao,
          _energiaBarHeight,
        ),
        _energiaFillPaint,
      );
    }

    _desenharAfinidade(canvas);

    moedaSprite.render(
      canvas,
      position: Vector2(90, 0),
      size: bombIconSize,
      overridePaint: paint,
    );
    textPaint.render(canvas, ':${player.coins}', Vector2(106, 1));

    
    // --- LÓGICA DO MEIO-CORAÇÃO ---
    // Quantos corações INICIAIS (capacidade total) o jogador tem na tela?
    // Como a escala do player é dobrada (maxHealth = 6), dividimos por 2 (3 corações na tela).
    int totalHeartsOnScreen = (player.maxHealth / 2).floor();

    // Quantos corações visualmente inteiros ele tem? (ex: vida 5 / 2 = 2 inteiros)
    int fullHearts = (player.currentHealth / 2).floor();

    // Tem algum resto? (ex: vida 5 % 2 = 1). Se sim, tem um meio-coração solto!
    bool hasHalfHeart = (player.currentHealth % 2) != 0;

    for (int i = 0; i < totalHeartsOnScreen; i++) {
      final xPosition =
          (i * (heartSize.x + spacing) - ((heartSize.x + spacing) + 2)) + 3;

      Sprite spriteToDraw;
      if (i < fullHearts) {
        // Desenha um coração completo
        spriteToDraw = heartSprite;
      } else if (i == fullHearts && hasHalfHeart) {
        // O próximo slot após os corações completos recebe a metade
        spriteToDraw = heartHalfSprite;
      } else {
        // O resto da capacidade máxima fica vazia
        spriteToDraw = heartEmptySprite;
      }

      spriteToDraw.render(
        canvas,
        position: Vector2(xPosition, -2),
        size: heartSize,
        overridePaint: paint,
      );
    }

    /*
    //barra de vida com logica sem meia vida

    for (int i = 0; i < player.maxHealth; i++) {
      double shieldX =
          (i * (heartSize.x + spacing) - ((heartSize.x + spacing) + 2)) + 3;
      final double shieldY = -2; //heartSize.y + 1;

      heartEmptySprite.render(
        canvas,
        position: Vector2(shieldX, shieldY),
        size: heartSize,
        overridePaint: paint,
      );
    }

    for (int i = 0; i < player.currentHealth; i++) {
      double shieldX =
          (i * (heartSize.x + spacing) - ((heartSize.x + spacing) + 2)) + 3;
      final double shieldY = -2; //heartSize.y + 1;

      heartSprite.render(
        canvas,
        position: Vector2(shieldX, shieldY),
        size: heartSize,
        overridePaint: paint,
      );
    }
  */
    // --- BARRA DE ESCUDO PASSIVO (defesa) ---
    for (int i = 0; i < player.shield; i++) {
      double shieldX =
          (i * (heartSize.x + spacing) - ((heartSize.x + spacing) + 2)) + 3;
      //3 +
      //player.maxHealth / 2 * (heartSize.x + spacing) +
      //(i * (heartSize.x + spacing)) -
      //((heartSize.x + spacing) + 2); // Posição X após os corações
      final double shieldY = -2; //heartSize.y + 1;
      //final fracao = (player.shield / player.shieldMax).clamp(0.0, 1.0);

      shieldSprite.render(
        canvas,
        position: Vector2(shieldX, shieldY),
        size: heartSize,
        overridePaint: paint,
      );
      //canvas.drawRect(Rect.fromLTWH(shieldX-1, shieldY - 1, _shieldBarSize.x + 2, _shieldBarSize.y + 2), _shieldMoldura);
      //canvas.drawRect(Rect.fromLTWH(shieldX, shieldY, _shieldBarSize.x, _shieldBarSize.y), _shieldFundo);
      //canvas.drawRect(Rect.fromLTWH(shieldX, shieldY, _shieldBarSize.x * fracao, _shieldBarSize.y), _shieldPreenchimento);
    }

    // --- REGENERAÇÃO DO ESCUDO PASSIVO (defesa) --- Indicador da PRÓXIMA
    // carga enchendo, no espaço onde o próximo `shieldSprite` vai nascer
    // quando a carga completar. NÃO é a bolha de habilidade
    // (`shieldVisualActive`/`shieldVisual`) — essa é outra coisa, desenhada
    // em cima do próprio sprite do jogador, não na Hud.
    /*if (player.shield < player.shieldMax) {
      final proximoIndice = player.shield.floor();
      final double regenX =
          3 +
          player.maxHealth / 2 * (heartSize.x + spacing) +
          (proximoIndice * (heartSize.x + spacing)) -
          ((heartSize.x + spacing) + 2);
      final double altura = _shieldRegenAlturaMax * player.shieldRegenFraction;
      canvas.drawOval(
        Rect.fromLTWH(
          regenX+6,
          heartSize.y - 3 - altura,
          _shieldRegenLargura,
          altura,
        ),
        _shieldRegenPaint,
      );
      canvas.drawOval(
        Rect.fromLTWH(
          regenX+6,
          heartSize.y - 3 - altura,
          _shieldRegenLargura,
          altura,
        ),
        _shieldRegenBorderPaint,
      );
    }
    */

    //double bombY = heartSize.y + 2;
    //bombSprite.render(canvas, position: Vector2(0, bombY), size: bombIconSize, overridePaint: paint);
    textPaint.render(
      canvas,
      '${game.currentFloor.toString()} - ${game.currentLevel.toString()}',
      Vector2(60, 1),
    );
  }
}
