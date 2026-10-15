import 'package:creatures_rogue/game/audio/sfx.dart';
import 'package:flame/components.dart';
import 'package:creatures_rogue/game/components/core/palette.dart';
import 'package:creatures_rogue/game/components/effects/text_effect.dart';
import 'package:creatures_rogue/l10n/l10n_extensions.dart';
import 'collectible.dart';
import '../player/player.dart';

// Herda de Collectible
class HeartHalfPickup extends Collectible {
  HeartHalfPickup({required super.position})
      // Passamos a imagem pro 'super' carregar!
      : super(spritePath: 'items/meiaFruta.png',cor1: Palette.laranja,cor2: Palette.verdeEsc);

  // Apenas implementamos a lógica do jogo
  @override
  Sfx? get somDeColeta => null;

  @override
  bool onCollect(Player player) {
    // O método heal() do Player já retorna 'true' se curou ou 'false' se a vida estava cheia
    final curou = player.heal(1);
    if (curou) {
      player.parent?.add(TextEffect(
        text: player.game.buildContext!.l10n.effect_maisVida(1),
        position: player.position.clone() + Vector2(0, -player.size.y / 2 - 4),
        color: Palette.verde,
      ));
    }
    return curou;
  }
}