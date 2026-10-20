import 'dart:ui';
import 'package:creatures_rogue/game/maldicoes.dart';
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

  /// Com `Mãos Furadas`: segundos até a moeda sumir.
  static const double vidaComMaldicao = 3.0;

  /// Contagem da `Mãos Furadas`. Só começa com o jogador NA SALA da moeda:
  /// as moedas da sala secreta nascem com o andar, e um relógio corrido
  /// desde então as apagaria antes de alguém chegar.
  double? _restante;

  @override
  void update(double dt) {
    super.update(dt);
    final player = game.player;
    if (!player.temMaldicao(Maldicao.maosFuradas)) {
      _restante = null;
      return;
    }
    if (_restante == null) {
      final sala = player.currentRoom;
      if (sala == null || !sala.containsPoint(absolutePosition)) return;
      _restante = vidaComMaldicao;
    }
    _restante = _restante! - dt;
    if (_restante! <= 0) removeFromParent();
  }

  /// No último segundo pisca, pra avisar antes de sumir.
  @override
  void render(Canvas canvas) {
    final restante = _restante;
    if (restante != null && restante < 1.0 && (restante * 10).floor().isEven) {
      return;
    }
    super.render(canvas);
  }

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
