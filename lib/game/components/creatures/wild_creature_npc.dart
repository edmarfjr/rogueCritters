import 'dart:ui' as ui;
import 'package:flame/components.dart';
import 'package:flame/collisions.dart';
import 'package:flutter/material.dart';
import 'package:creatures_rogue/game/audio/game_audio.dart';
import 'package:creatures_rogue/game/audio/sfx.dart';
import 'package:creatures_rogue/game/components/core/palette.dart';
import 'package:creatures_rogue/game/components/creatures/creature_data.dart';
import 'package:creatures_rogue/game/components/effects/companion_revive_effect.dart';
import 'package:creatures_rogue/game/components/player/player.dart';
import 'package:creatures_rogue/game/components/utils/palette_swapper.dart';
import 'package:creatures_rogue/game/components/utils/y_sort.dart';
import 'package:creatures_rogue/game/creatures_rogue_game.dart';

/// Criatura selvagem parada na sala da escada do quarto andar de cada
/// dungeon (ver PIVOT_CONTROLE_DIRETO.md §5) — sem IA de combate nenhuma, só
/// um sprite e um hitbox passivo. Encostar abre a ficha dela, com VOLTAR e
/// ESCOLHER; escolher põe no banco com vida cheia (ver [recrutar]).
class WildCreatureNpc extends PositionComponent
    with CollisionCallbacks, HasGameReference<CreaturesRogueGame> {
  final CreatureData creatureData;

  late final SpriteComponent _visual;

  /// `removeFromParent()` só tira o componente no FIM do frame — até lá,
  /// `Player.playerHitbox` e `Player.physicsHitbox` (dois hitboxes ativos
  /// distintos) podem cada um disparar `onCollisionStart` contra este hitbox
  /// passivo no mesmo instante. Sem essa trava, os dois eventos chamavam
  /// `recrutarCriaturaSelvagem` antes da remoção surtir efeito e preenchiam
  /// dois slots do grupo com a mesma criatura.
  bool _recrutado = false;

  /// As outras criaturas da mesma oferta. Recrutar esta faz as irmãs sumirem
  /// — a escolha é uma OU outra (ver `CreaturesRogueGame._buildWildCreatures`).
  final List<WildCreatureNpc> irmas = [];

  WildCreatureNpc({required Vector2 position, required this.creatureData})
      : super(size: Vector2(16, 16), anchor: Anchor.center, position: position);

  @override
  Future<void> onLoad() async {
    super.onLoad();

    final ui.Image spriteImage = await PaletteSwapper.createSwappedImage(
      imagePath: creatureData.spritePath,
      lightGrayReplacement: creatureData.corClara,
      darkGrayReplacement: creatureData.corEscura,
    );

    final visualBasePosition = Vector2(size.x / 2, size.y);

    _visual = SpriteComponent(
      sprite: Sprite(spriteImage),
      // Mesma regra do `Player`: o visual usa a resolução do PNG, não o
      // `size` do componente — hoje toda selvagem é forma base (16x16), mas
      // uma evoluída apareceria espremida aqui pelo mesmo motivo que já
      // aconteceu com três evoluções no jogador.
      size: Vector2(
        spriteImage.width.toDouble(),
        spriteImage.height.toDouble(),
      ),
      anchor: Anchor.bottomCenter,
      position: visualBasePosition,
      paint: Paint()..filterQuality = FilterQuality.none,
      priority: 1,
    );
    add(_visual);

    final shadow = CircleComponent(
      radius: creatureData.hitboxSize.x / 2,
      anchor: Anchor.center,
      position: visualBasePosition,
      paint: Paint()..color = Palette.preto,
      priority: -1,
    )..scale = Vector2(1.2, 0.75);
    add(shadow);

    add(RectangleHitbox(
      size: creatureData.hitboxSize,
      anchor: Anchor.bottomCenter,
      position: visualBasePosition,
      collisionType: CollisionType.passive,
    ));

    priority = ySortPriority(position.y + size.y / 2);
  }

  /// Depois de "VOLTAR", um instante em que encostar não reabre a janela:
  /// os dois hitboxes do jogador entram em momentos diferentes, e o segundo
  /// reabriria a janela logo depois de fechada.
  double _ignorarToque = 0.0;
  static const double _pausaAposVoltar = 0.6;

  @override
  void update(double dt) {
    super.update(dt);
    if (_ignorarToque > 0) _ignorarToque -= dt;
  }

  /// Encostar abre a ficha da criatura (ver `WildCreatureInfoOverlay`); quem
  /// recruta é o botão ESCOLHER, via [recrutar].
  @override
  void onCollisionStart(Set<Vector2> intersectionPoints, PositionComponent other) {
    super.onCollisionStart(intersectionPoints, other);
    if (_recrutado || _ignorarToque > 0 || other is! Player) return;
    game.abrirInfoCriaturaSelvagem(this);
  }

  /// Chamado ao fechar a ficha com VOLTAR.
  void recusada() => _ignorarToque = _pausaAposVoltar;

  /// Entra no grupo e faz as irmãs da oferta sumirem. Se a corrida rara
  /// acontecer (grupo cheio entre a sala nascer e a escolha), nada muda e a
  /// criatura continua ali.
  void recrutar() {
    if (_recrutado) return;
    if (!game.recrutarCriaturaSelvagem(creatureData)) return;
    _recrutado = true;
    GameAudio.instance.play(Sfx.liberar);
    parent?.add(CompanionReviveEffect(position: position.clone()));
    removeFromParent();
    // Trava as irmãs ANTES de removê-las: a remoção só vale no fim do
    // quadro, e até lá o jogador ainda pode estar encostando nelas.
    for (final irma in irmas) {
      irma._recrutado = true;
      irma.removeFromParent();
    }
  }
}
