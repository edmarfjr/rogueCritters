import 'package:creatures_rogue/game/audio/sfx.dart';
import 'package:flame/components.dart';
import 'package:creatures_rogue/game/components/core/palette.dart';
import 'package:creatures_rogue/game/components/effects/text_effect.dart';
import 'package:creatures_rogue/l10n/l10n_extensions.dart';
import 'collectible.dart';
import '../player/player.dart';

/// Moeda da run. Ainda não tem onde gastar — a sala de loja é o passo
/// seguinte; por enquanto o valor só acumula em `Player.coins` e aparece na
/// Hud.
///
/// Gasta na loja (ver [ShopStand]).
class CoinPickup extends Collectible {
  final int valor;

  CoinPickup({required super.position, this.valor = 1})
      : super(
          spritePath: 'items/moeda.png',
          cor1: Palette.amarelo,
          cor2: Palette.laranja,
        );

  @override
  Sfx? get somDeColeta => Sfx.moeda;

  @override
  bool onCollect(Player player) {
    player.addCoins(valor);
    final l = player.game.buildContext!.l10n;
    player.parent?.add(TextEffect(
      text: l.effect_maisMoedas(valor, valor == 1 ? '' : 'S'),
      position: player.position.clone() + Vector2(0, -player.size.y / 2 - 4),
      color: Palette.amarelo,
    ));
    return true; // moeda sempre entra: não tem limite de slot nem teto útil
  }
}
