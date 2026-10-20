import 'package:creatures_rogue/game/maldicoes.dart';
import 'dart:ui' as ui;
import 'package:creatures_rogue/game/audio/game_audio.dart';
import 'package:creatures_rogue/game/audio/sfx.dart';
import 'package:creatures_rogue/game/components/utils/y_sort.dart';
import 'package:flame/components.dart';
import 'package:flame/collisions.dart';
import 'package:flutter/material.dart';
import 'package:creatures_rogue/game/components/core/palette.dart';
import 'package:creatures_rogue/game/components/utils/palette_swapper.dart';
import 'package:creatures_rogue/game/creatures_rogue_game.dart';

import '../player/player.dart';

// A classe é abstrata, não pode ser instanciada diretamente.
abstract class Collectible extends PositionComponent
    with CollisionCallbacks, HasGameReference<CreaturesRogueGame> {
  final String spritePath; // Cada filho dirá qual imagem carregar
  final Color cor1;
  final Color cor2;

  late final Sprite _sprite;
  final Paint _paint = Paint()..filterQuality = FilterQuality.none;

  /// Silhueta preta da `Cegueira` — mesmo filtro da Hud pra ícone apagado.
  static final Paint _silhueta = Paint()
    ..filterQuality = FilterQuality.none
    ..colorFilter = const ColorFilter.mode(Palette.preto, BlendMode.srcATop);

  /// A `Cegueira` esconde este coletável? Só os que têm rótulo (pedestal,
  /// chão de evento) e a loja: moeda e coração aparecem aos montes e não
  /// são decisão nenhuma.
  bool get cegavel => _nome != null;

  /// Nome resolvido uma vez no [onLoad]: traduzir a cada quadro custaria uma
  /// busca de l10n por item por frame, e o texto nunca muda enquanto o item
  /// está no chão.
  String? _nome;

  /// Rótulo mostrado acima do sprite. `null` (padrão) = sem rótulo — é o caso
  /// de moeda, coração, bomba e XP, que aparecem aos montes e viram poluição
  /// visual etiquetados. Sobrescrito por quem nasce no pedestal ou na loja,
  /// onde saber o que se está pegando é a decisão do jogador.
  String? nomeExibido(BuildContext context) => null;

  /// Mesmo desenho do texto de dano (ver `TextEffect`): `pixelFont` 6px com
  /// contorno preto nas 8 direções, que é o que mantém o texto legível em
  /// cima de qualquer tile.
  static final TextPaint _nomePaint = TextPaint(
    style: const TextStyle(
      color: Palette.branco,
      fontSize: 6.0,
      fontFamily: 'pixelFont',
      fontWeight: FontWeight.bold,
      shadows: [
        Shadow(color: Palette.preto, offset: Offset(1, 1)),
        Shadow(color: Palette.preto, offset: Offset(-1, -1)),
        Shadow(color: Palette.preto, offset: Offset(1, -1)),
        Shadow(color: Palette.preto, offset: Offset(-1, 1)),
        Shadow(color: Palette.preto, offset: Offset(0, 1)),
        Shadow(color: Palette.preto, offset: Offset(0, -1)),
        Shadow(color: Palette.preto, offset: Offset(1, 0)),
        Shadow(color: Palette.preto, offset: Offset(-1, 0)),
      ],
    ),
  );

  /// `removeFromParent()` só tira o componente no FIM do frame — até lá,
  /// `Player.playerHitbox` e `Player.physicsHitbox` (dois hitboxes ativos
  /// distintos) podem cada um disparar `onCollisionStart` contra este hitbox
  /// passivo no mesmo instante. Sem essa trava, os dois eventos chamavam
  /// `onCollect` antes da remoção surtir efeito — um item de inventário (ex.:
  /// escudo) entrava duas vezes, preenchendo os dois slots de uma vez.
  bool _coletado = false;

  Collectible({
    required Vector2 position,
    required this.spritePath,
    this.cor1 = Palette.cinza,
    this.cor2 = Palette.cinzaEsc,
    Vector2? size,
    // Sem `size` explícito, todo item cai no 16x16 de sempre (moeda,
    // coração, power-up). `XpPickup` passa 8x8 — o sprite dele é menor.
  }) : super(
         position: position,
         size: size ?? Vector2(16, 16),
         anchor: Anchor.center,
       );

  @override
  Future onLoad() async {
    final ui.Image img = await PaletteSwapper.createSwappedImage(
      imagePath: spritePath,
      lightGrayReplacement: cor1,
      darkGrayReplacement: cor2,
    );

    _sprite = Sprite(img);
    _nome = nomeExibido(game.buildContext!);

    add(
      RectangleHitbox(
        size: size,
        anchor: Anchor.center,
        position: size / 2,
        collisionType: CollisionType.passive,
      ),
    );

    priority = ySortPriority(position.y + size.y / 2);
  }

  @override
  void render(Canvas canvas) {
    // Decidido a cada quadro, e não no `onLoad`: o andar inteiro nasce de uma
    // vez, então os itens já estavam carregados quando a maldição chegou.
    final cego = cegavel && game.player.temMaldicao(Maldicao.cegueira);
    _sprite.render(
      canvas,
      size: size,
      overridePaint: cego ? _silhueta : _paint,
    );

    final nome = cego && _nome != null ? '???' : _nome;
    if (nome == null) return;
    _nomePaint.render(
      canvas,
      nome,
      Vector2(size.x / 2, -2),
      anchor: Anchor.bottomCenter,
    );
  }

  @override
  void onCollisionStart(Set intersectionPoints, PositionComponent other) {
    super.onCollisionStart(intersectionPoints.cast(), other);

    if (_coletado) return;
    if (other is Player) {
      // Chama o método abstrato que os filhos vão implementar
      bool wasCollected = onCollect(other);

      if (wasCollected) {
        _coletado = true;
        final som = somDeColeta;
        if (som != null) GameAudio.instance.play(som);
        removeFromParent();
      }
    }
  }

  // NOVO: Método abstrato!
  // Retorna 'true' se o item foi consumido, ou 'false' se não (ex: vida já estava cheia)
  bool onCollect(Player player);

  /// Som da coleta. `null` = quem coleta já toca o seu (o coração cura, e a
  /// cura tem som próprio em `Player.heal`).
  Sfx? get somDeColeta => Sfx.pick;
}
